import '../../domain/books/book.dart';
import '../../domain/books/book_repository.dart';
import '../../domain/books/reading_position.dart';
import '../../domain/ocr/ocr_models.dart';
import '../../domain/search/search_models.dart';
import '../../renderers/epub/epub_document.dart';
import '../../renderers/epub/epub_document_loader.dart';
import '../../renderers/markdown/markdown_document_loader.dart';
import '../../renderers/markdown/markdown_folder.dart';
import '../../domain/books/locator_excerpt.dart';
import '../ocr/ocr_cache_signature.dart';
import '../tasks/task_cancellation.dart';
import 'pdf_text_extractor.dart';
import 'structure_chunker.dart';

final class SearchIndexer {
  const SearchIndexer({
    required SearchRepository searchRepository,
    required BookRepository bookRepository,
    EpubDocumentLoader? epubLoader,
    PdfTextExtractorService? pdfTextExtractor,
    OcrSearchSource? ocrSearchSource,
  }) : this._(
         searchRepository,
         bookRepository,
         epubLoader ?? const EpubDocumentLoader(),
         pdfTextExtractor ?? const PdfTextExtractorService(),
         ocrSearchSource,
       );

  const SearchIndexer._(
    this._searchRepository,
    this._bookRepository,
    this._epubLoader,
    this._pdfTextExtractor,
    this._ocrSearchSource,
  );

  final SearchRepository _searchRepository;
  final BookRepository _bookRepository;
  final EpubDocumentLoader _epubLoader;
  final PdfTextExtractorService _pdfTextExtractor;
  final OcrSearchSource? _ocrSearchSource;
  final StructureAwareChunker _chunker = const StructureAwareChunker();

  /// Indexes [book] content for FTS.
  ///
  /// [onProgress] receives a 0..1 fraction and optional status message.
  Future<void> indexBook(
    Book book, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
  }) async {
    await _bookRepository.updateIndexingStatus(book.id, 'running');
    onProgress?.call(0.05, message: '准备索引');
    final generationRepository = _searchRepository is SearchGenerationRepository
        ? _searchRepository as SearchGenerationRepository
        : null;
    SearchIndexGeneration? generation;
    Future<void> writeTexts(List<SearchIndexEntry> entries) async {
      final current = generation;
      if (current != null) {
        await generationRepository!.indexGenerationTexts(current.id, entries);
        return;
      }
      await _searchRepository.indexTexts(entries);
    }

    try {
      cancelToken?.throwIfCancelled();
      if (generationRepository != null) {
        generation = await generationRepository.beginBookGeneration(book.id);
        cancelToken?.throwIfCancelled();
        await writeTexts([
          SearchIndexEntry(
            sourceType: 'book',
            sourceId: book.id,
            bookId: book.id,
            title: book.title,
            text: [
              book.title,
              book.author,
              book.description,
            ].whereType<String>().join('\n'),
          ),
        ]);
      } else {
        await _searchRepository.deleteByBook(book.id);
        cancelToken?.throwIfCancelled();
        await _searchRepository.indexBookMetadata(
          bookId: book.id,
          title: book.title,
          author: book.author,
          description: book.description,
        );
      }
      onProgress?.call(0.12, message: '已写入元数据');
      cancelToken?.throwIfCancelled();

      final terminalStatus = switch (book.format) {
        BookFormat.epub => await _indexEpub(
          book,
          cancelToken: cancelToken,
          onProgress: onProgress,
          writeTexts: writeTexts,
        ),
        BookFormat.pdf => await _indexPdf(
          book,
          cancelToken: cancelToken,
          onProgress: onProgress,
          writeTexts: writeTexts,
        ),
        BookFormat.markdown => await _indexMarkdown(
          book,
          cancelToken: cancelToken,
          onProgress: onProgress,
          writeTexts: writeTexts,
        ),
      };

      cancelToken?.throwIfCancelled();
      final current = generation;
      if (current != null) {
        await generationRepository!.publishBookGeneration(current.id);
      }
      await _bookRepository.updateIndexingStatus(book.id, terminalStatus);
    } on TaskCancelledException {
      final current = generation;
      if (current != null) {
        await generationRepository!.discardBookGeneration(current.id);
      } else {
        await _searchRepository.deleteByBook(book.id);
      }
      await _bookRepository.updateIndexingStatus(book.id, 'pending');
      rethrow;
    } catch (_) {
      final current = generation;
      if (current != null) {
        await generationRepository!.discardBookGeneration(current.id);
      }
      await _bookRepository.updateIndexingStatus(book.id, 'failed');
      rethrow;
    }
  }

  /// Returns terminal indexing status: `done` or `no_text` (scan PDF / no body).
  Future<String> _indexPdf(
    Book book, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
    required Future<void> Function(List<SearchIndexEntry>) writeTexts,
  }) async {
    cancelToken?.throwIfCancelled();
    onProgress?.call(0.15, message: '提取 PDF 文本');
    // Heavy parse runs in a background isolate (see PdfTextExtractorService).
    final document = await _pdfTextExtractor.extract(book.libraryFilePath);
    cancelToken?.throwIfCancelled();

    final nativePages = {
      for (final page in document.pages)
        if (page.text.trim().isNotEmpty) page.pageNumber: page.text.trim(),
    };
    final recognizedOcrPages = <int, OcrIndexPage>{};
    final ocrSource = _ocrSearchSource;
    if (ocrSource != null) {
      cancelToken?.throwIfCancelled();
      final pages = await ocrSource.pagesForBook(
        book.id,
        sourceRevision: book.fileHash,
      );
      for (final page in pages) {
        final text = page.text.trim();
        if (page.pageNumber < 1 ||
            text.isEmpty ||
            nativePages.containsKey(page.pageNumber)) {
          continue;
        }
        recognizedOcrPages[page.pageNumber] = OcrIndexPage(
          pageNumber: page.pageNumber,
          text: text,
          cacheSignature: page.cacheSignature,
          textRevision: page.textRevision,
        );
      }
    }
    final pageNumbers = <int>{
      ...nativePages.keys,
      ...recognizedOcrPages.keys,
    }.toList(growable: false)..sort();
    if (pageNumbers.isEmpty) {
      // Metadata was already indexed; body search is unavailable until OCR.
      onProgress?.call(1, message: '无可索引正文');
      return 'no_text';
    }

    // Batch page chunks into SQLite writes (much faster than per-chunk awaits).
    const batchSize = 64;
    var pending = <SearchIndexEntry>[];
    final totalPages = pageNumbers.length;
    var lastReportedBucket = -1;
    var sortOrder = 0;

    Future<void> flushPending() async {
      if (pending.isEmpty) {
        return;
      }
      cancelToken?.throwIfCancelled();
      final batch = pending;
      pending = <SearchIndexEntry>[];
      await writeTexts(batch);
    }

    for (var pageIndex = 0; pageIndex < totalPages; pageIndex += 1) {
      cancelToken?.throwIfCancelled();
      final pageNumber = pageNumbers[pageIndex];
      final ocrPage = recognizedOcrPages[pageNumber];
      final text = nativePages[pageNumber] ?? ocrPage!.text;
      final isOcr = nativePages[pageNumber] == null;
      final structured = _chunker.chunk(
        text: text,
        chapterTitle: isOcr ? '第 $pageNumber 页 · 识别文本' : '第 $pageNumber 页',
      );
      final pageProgress = totalPages == 0
          ? 0.0
          : (pageNumber - 1) / totalPages;
      var childIndex = 0;
      for (final parent in structured.parents) {
        final parentSortOrder = sortOrder;
        final parentId = isOcr
            ? '${book.id}:pdf:$pageNumber:ocr:p${parent.ordinal}'
            : '${book.id}:pdf:$pageNumber:p${parent.ordinal}';
        final parentLocator = ReadingLocator.pdf(
          page: pageNumber,
          scrollOffset: _pdfScrollOffset(text, parent.span.startOffset),
          progress: pageProgress,
          excerpt: compactLocatorExcerpt(parent.text),
        );
        for (final child in parent.children) {
          pending.add(
            SearchIndexEntry(
              sourceType: 'book',
              sourceId: isOcr
                  ? '${book.id}:pdf:$pageNumber:ocr:$childIndex'
                  : '${book.id}:pdf:$pageNumber:$childIndex',
              bookId: book.id,
              title: isOcr
                  ? '${book.title} - 第 $pageNumber 页 · 识别文本'
                  : '${book.title} - 第 $pageNumber 页',
              text: child.text,
              locator: ReadingLocator.pdf(
                page: pageNumber,
                scrollOffset: _pdfScrollOffset(text, child.span.startOffset),
                progress: pageProgress,
                excerpt: compactLocatorExcerpt(child.text),
              ),
              sortOrder: sortOrder++,
              parentId: parentId,
              parentTitle: isOcr ? '识别文本 · 第 $pageNumber 页' : '第 $pageNumber 页',
              parentText: parent.text,
              parentLocator: parentLocator,
              parentSortOrder: parentSortOrder,
              textOrigin: isOcr ? 'ocr' : 'native',
              sourceRevision: book.fileHash,
              textRevision: isOcr
                  ? ocrPage!.textRevision
                  : buildOcrTextRevision(
                      sourceRevision: book.fileHash,
                      text: text,
                      pipelineVersion: 'pdf-native-v1',
                    ),
            ),
          );
          childIndex += 1;
          if (pending.length >= batchSize) {
            await flushPending();
          }
        }
      }
      final fraction = totalPages <= 1 ? 1.0 : (pageIndex + 1) / totalPages;
      final mapped = 0.18 + fraction * 0.80;
      final bucket = (mapped * 20).floor();
      if (bucket != lastReportedBucket) {
        lastReportedBucket = bucket;
        onProgress?.call(
          mapped.clamp(0.18, 0.98),
          message: '索引 PDF ${pageIndex + 1}/$totalPages 页',
        );
      }
      // Cooperative yield so cancel / UI can run during long indexes.
      if (pageIndex % 8 == 7) {
        await flushPending();
        await Future<void>.delayed(Duration.zero);
      }
    }
    await flushPending();
    onProgress?.call(0.99, message: '完成 PDF 索引');
    return 'done';
  }

  Future<String> _indexEpub(
    Book book, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
    required Future<void> Function(List<SearchIndexEntry>) writeTexts,
  }) async {
    cancelToken?.throwIfCancelled();
    onProgress?.call(0.15, message: '解析 EPUB');
    final document = await _epubLoader.load(book.libraryFilePath);
    return _indexReflowable(
      book,
      document,
      cancelToken: cancelToken,
      onProgress: onProgress,
      sourceTag: 'epub',
      statusMessage: 'EPUB',
      writeTexts: writeTexts,
    );
  }

  Future<String> _indexMarkdown(
    Book book, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
    required Future<void> Function(List<SearchIndexEntry>) writeTexts,
  }) async {
    cancelToken?.throwIfCancelled();
    onProgress?.call(0.15, message: '解析 Markdown');
    if (book.isFolderBook) {
      return _indexMarkdownFolder(
        book,
        cancelToken: cancelToken,
        onProgress: onProgress,
        writeTexts: writeTexts,
      );
    }
    final document = await const MarkdownDocumentLoader().load(
      book.libraryFilePath,
    );
    return _indexReflowable(
      book,
      document,
      cancelToken: cancelToken,
      onProgress: onProgress,
      sourceTag: 'md',
      statusMessage: 'Markdown',
      writeTexts: writeTexts,
    );
  }

  /// Indexes a folder one file at a time.
  ///
  /// The reader no longer builds one merged document, so search must not
  /// either: every result carries the relative file path and the chapter
  /// index inside that file. Progress stays folder-wide so the shelf and
  /// search jump agree with the reader.
  Future<String> _indexMarkdownFolder(
    Book book, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
    required Future<void> Function(List<SearchIndexEntry>) writeTexts,
  }) async {
    final manifest = await const MarkdownFolderLoader().loadManifest(
      book.libraryFilePath,
    );
    const batchSize = 64;
    var pending = <SearchIndexEntry>[];
    var lastReportedBucket = -1;
    var sortOrder = 0;

    Future<void> flushPending() async {
      if (pending.isEmpty) {
        return;
      }
      cancelToken?.throwIfCancelled();
      final batch = pending;
      pending = <SearchIndexEntry>[];
      await writeTexts(batch);
    }

    for (var fileIndex = 0; fileIndex < manifest.files.length; fileIndex += 1) {
      cancelToken?.throwIfCancelled();
      final file = manifest.files[fileIndex];
      EpubDocument document;
      try {
        document = await const MarkdownDocumentLoader().load(file.absolutePath);
      } on Object {
        // One unreadable note does not stop the folder index; its absence is
        // visible when the reader tries to open it.
        continue;
      }
      for (final chapter in document.chapters) {
        final chapterTitle = chapter.title == file.title
            ? file.title
            : '${file.title} · ${chapter.title}';
        final structured = _chunker.chunk(
          text: chapter.text,
          chapterTitle: chapterTitle,
          blocks: _structuralBlocks(chapter),
        );
        var childIndex = 0;
        for (final parent in structured.parents) {
          final parentSortOrder = sortOrder;
          final parentLocator = _locatorFor(
            book,
            href: file.relativePath,
            chapterIndex: chapter.index,
            chapterOffset: parent.span.startOffset,
            chapterEndOffset: parent.span.endOffset,
            progress: manifest.progressForFile(
              file.relativePath,
              document.progressForChapter(
                chapterIndex: chapter.index,
                chapterOffset: parent.span.startOffset,
              ),
            ),
            excerpt: compactLocatorExcerpt(parent.text),
            folderFileLocal: true,
          );
          final parentId =
              '${book.id}:md:f$fileIndex:${chapter.index}:p${parent.ordinal}';
          for (final child in parent.children) {
            pending.add(
              SearchIndexEntry(
                sourceType: 'book',
                sourceId:
                    '${book.id}:md:f$fileIndex:${chapter.index}:$childIndex',
                bookId: book.id,
                title: parent.titlePath,
                text: child.text,
                locator: _locatorFor(
                  book,
                  href: file.relativePath,
                  chapterIndex: chapter.index,
                  chapterOffset: child.span.startOffset,
                  chapterEndOffset: child.span.endOffset,
                  progress: manifest.progressForFile(
                    file.relativePath,
                    document.progressForChapter(
                      chapterIndex: chapter.index,
                      chapterOffset: child.span.startOffset,
                    ),
                  ),
                  excerpt: compactLocatorExcerpt(child.text),
                  folderFileLocal: true,
                ),
                sortOrder: sortOrder++,
                parentId: parentId,
                parentTitle: parent.titlePath,
                parentText: parent.text,
                parentLocator: parentLocator,
                parentSortOrder: parentSortOrder,
              ),
            );
            childIndex += 1;
            if (pending.length >= batchSize) {
              await flushPending();
            }
          }
        }
      }
      final fraction = (fileIndex + 1) / manifest.files.length;
      final mapped = 0.18 + fraction * 0.80;
      final bucket = (mapped * 20).floor();
      if (bucket != lastReportedBucket) {
        lastReportedBucket = bucket;
        onProgress?.call(
          mapped.clamp(0.18, 0.98),
          message: '索引文件 ${fileIndex + 1}/${manifest.files.length}',
        );
      }
      if (fileIndex % 4 == 3) {
        await flushPending();
        await Future<void>.delayed(Duration.zero);
      }
    }
    await flushPending();
    onProgress?.call(0.99, message: '完成 Markdown 索引');
    return 'done';
  }

  /// Indexes a book that is read by chapter and character offset.
  ///
  /// EPUB and Markdown have the same shape here — chapters of text — so they
  /// share one pass. Only the locator type differs, and that is what the
  /// stored position has to say truthfully.
  Future<String> _indexReflowable(
    Book book,
    EpubDocument document, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
    required String sourceTag,
    required String statusMessage,
    required Future<void> Function(List<SearchIndexEntry>) writeTexts,
  }) async {
    const batchSize = 64;
    var pending = <SearchIndexEntry>[];
    final totalChapters = document.chapters.length;
    var lastReportedBucket = -1;
    var sortOrder = 0;

    Future<void> flushPending() async {
      if (pending.isEmpty) {
        return;
      }
      cancelToken?.throwIfCancelled();
      final batch = pending;
      pending = <SearchIndexEntry>[];
      await writeTexts(batch);
    }

    for (
      var chapterIndex = 0;
      chapterIndex < totalChapters;
      chapterIndex += 1
    ) {
      cancelToken?.throwIfCancelled();
      final chapter = document.chapters[chapterIndex];
      final structured = _chunker.chunk(
        text: chapter.text,
        chapterTitle: chapter.title,
        blocks: _structuralBlocks(chapter),
      );
      var childIndex = 0;
      for (final parent in structured.parents) {
        final parentSortOrder = sortOrder;
        final parentLocator = _locatorFor(
          book,
          href: chapter.href,
          chapterIndex: chapter.index,
          chapterOffset: parent.span.startOffset,
          chapterEndOffset: parent.span.endOffset,
          progress: document.progressForChapter(
            chapterIndex: chapter.index,
            chapterOffset: parent.span.startOffset,
          ),
          excerpt: compactLocatorExcerpt(parent.text),
        );
        final parentId =
            '${book.id}:$sourceTag:${chapter.index}:p${parent.ordinal}';
        for (final child in parent.children) {
          pending.add(
            SearchIndexEntry(
              sourceType: 'book',
              sourceId: '${book.id}:$sourceTag:${chapter.index}:$childIndex',
              bookId: book.id,
              title: parent.titlePath,
              text: child.text,
              locator: _locatorFor(
                book,
                href: chapter.href,
                chapterIndex: chapter.index,
                chapterOffset: child.span.startOffset,
                chapterEndOffset: child.span.endOffset,
                progress: document.progressForChapter(
                  chapterIndex: chapter.index,
                  chapterOffset: child.span.startOffset,
                ),
                excerpt: compactLocatorExcerpt(child.text),
              ),
              sortOrder: sortOrder++,
              parentId: parentId,
              parentTitle: parent.titlePath,
              parentText: parent.text,
              parentLocator: parentLocator,
              parentSortOrder: parentSortOrder,
            ),
          );
          childIndex += 1;
          if (pending.length >= batchSize) {
            await flushPending();
          }
        }
      }
      final fraction = totalChapters <= 1
          ? 1.0
          : (chapterIndex + 1) / totalChapters;
      final mapped = 0.18 + fraction * 0.80;
      final bucket = (mapped * 20).floor();
      if (bucket != lastReportedBucket) {
        lastReportedBucket = bucket;
        onProgress?.call(
          mapped.clamp(0.18, 0.98),
          message: '索引章节 ${chapterIndex + 1}/$totalChapters',
        );
      }
      if (chapterIndex % 4 == 3) {
        await flushPending();
        await Future<void>.delayed(Duration.zero);
      }
    }
    await flushPending();
    onProgress?.call(0.99, message: '完成 $statusMessage 索引');
    return 'done';
  }

  ReadingLocator _locatorFor(
    Book book, {
    required String href,
    required int chapterIndex,
    required int chapterOffset,
    required int chapterEndOffset,
    required double progress,
    String? excerpt,
    bool folderFileLocal = false,
  }) {
    if (book.format == BookFormat.markdown) {
      return ReadingLocator.markdown(
        href: href,
        chapterIndex: chapterIndex,
        chapterOffset: chapterOffset,
        chapterEndOffset: chapterEndOffset,
        progress: progress,
        excerpt: excerpt,
        folderFileLocal: folderFileLocal,
      );
    }
    return ReadingLocator.epub(
      href: href,
      chapterIndex: chapterIndex,
      chapterOffset: chapterOffset,
      chapterEndOffset: chapterEndOffset,
      progress: progress,
      excerpt: excerpt,
    );
  }

  List<StructuralBlock> _structuralBlocks(EpubChapter chapter) {
    final blocks = <StructuralBlock>[];
    for (final block in chapter.blocks) {
      if (block is EpubTextBlock) {
        final kind = switch (block.type) {
          EpubBlockType.heading => StructuralBlockKind.heading,
          EpubBlockType.code => StructuralBlockKind.code,
          EpubBlockType.math ||
          EpubBlockType.diagram => StructuralBlockKind.code,
          EpubBlockType.quote => StructuralBlockKind.quote,
          EpubBlockType.table => StructuralBlockKind.table,
          _ when block.listMarker != null => StructuralBlockKind.list,
          _ => StructuralBlockKind.paragraph,
        };
        blocks.add(
          StructuralBlock(
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            kind: kind,
            headingLevel: block.headingLevel,
          ),
        );
      } else if (block is EpubTableBlock) {
        blocks.add(
          StructuralBlock(
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            kind: StructuralBlockKind.table,
          ),
        );
      }
    }
    return blocks;
  }

  double _pdfScrollOffset(String text, int offset) {
    if (text.isEmpty) {
      return 0;
    }
    return (offset.clamp(0, text.length) / text.length) * 800;
  }
}
