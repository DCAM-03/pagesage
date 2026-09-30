import '../../domain/books/book.dart';
import '../../domain/books/book_repository.dart';
import '../../domain/books/reading_position.dart';
import '../../domain/search/search_models.dart';
import '../../renderers/epub/epub_document_loader.dart';
import '../../renderers/epub/epub_jump.dart';
import '../tasks/task_cancellation.dart';
import 'pdf_text_extractor.dart';

final class SearchIndexer {
  const SearchIndexer({
    required SearchRepository searchRepository,
    required BookRepository bookRepository,
    EpubDocumentLoader? epubLoader,
    PdfTextExtractorService? pdfTextExtractor,
  }) : this._(
         searchRepository,
         bookRepository,
         epubLoader ?? const EpubDocumentLoader(),
         pdfTextExtractor ?? const PdfTextExtractorService(),
       );

  const SearchIndexer._(
    this._searchRepository,
    this._bookRepository,
    this._epubLoader,
    this._pdfTextExtractor,
  );

  final SearchRepository _searchRepository;
  final BookRepository _bookRepository;
  final EpubDocumentLoader _epubLoader;
  final PdfTextExtractorService _pdfTextExtractor;

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
    try {
      cancelToken?.throwIfCancelled();
      await _searchRepository.deleteByBook(book.id);
      cancelToken?.throwIfCancelled();
      await _searchRepository.indexBookMetadata(
        bookId: book.id,
        title: book.title,
        author: book.author,
        description: book.description,
      );
      onProgress?.call(0.12, message: '已写入元数据');
      cancelToken?.throwIfCancelled();

      final terminalStatus = switch (book.format) {
        BookFormat.epub => await _indexEpub(
          book,
          cancelToken: cancelToken,
          onProgress: onProgress,
        ),
        BookFormat.pdf => await _indexPdf(
          book,
          cancelToken: cancelToken,
          onProgress: onProgress,
        ),
      };

      cancelToken?.throwIfCancelled();
      await _bookRepository.updateIndexingStatus(book.id, terminalStatus);
    } on TaskCancelledException {
      await _searchRepository.deleteByBook(book.id);
      await _bookRepository.updateIndexingStatus(book.id, 'pending');
      rethrow;
    } catch (_) {
      await _bookRepository.updateIndexingStatus(book.id, 'failed');
      rethrow;
    }
  }

  /// Returns terminal indexing status: `done` or `no_text` (scan PDF / no body).
  Future<String> _indexPdf(
    Book book, {
    TaskCancelToken? cancelToken,
    void Function(double progress, {String? message})? onProgress,
  }) async {
    cancelToken?.throwIfCancelled();
    onProgress?.call(0.15, message: '提取 PDF 文本');
    // Heavy parse runs in a background isolate (see PdfTextExtractorService).
    final document = await _pdfTextExtractor.extract(book.libraryFilePath);
    cancelToken?.throwIfCancelled();
    if (!document.hasText) {
      // Metadata was already indexed; body search is unavailable until OCR.
      onProgress?.call(1, message: '无可索引正文');
      return 'no_text';
    }

    // Batch page chunks into SQLite writes (much faster than per-chunk awaits).
    const batchSize = 64;
    var pending = <SearchIndexEntry>[];
    final totalPages = document.pages.length;
    var lastReportedBucket = -1;

    Future<void> flushPending() async {
      if (pending.isEmpty) {
        return;
      }
      cancelToken?.throwIfCancelled();
      final batch = pending;
      pending = <SearchIndexEntry>[];
      await _searchRepository.indexTexts(batch);
    }

    for (var pageIndex = 0; pageIndex < totalPages; pageIndex += 1) {
      cancelToken?.throwIfCancelled();
      final page = document.pages[pageIndex];
      final chunks = _splitTextWithOffsets(page.text, targetLength: 1200);
      final pageProgress = totalPages == 0
          ? 0.0
          : (page.pageNumber - 1) / totalPages;
      for (var i = 0; i < chunks.length; i += 1) {
        final chunk = chunks[i];
        // Without real page geometry, approximate vertical offset by chunk order.
        final scrollOffset = chunks.length <= 1
            ? 0.0
            : (i / chunks.length) * 800;
        pending.add(
          SearchIndexEntry(
            sourceType: 'book',
            sourceId: '${book.id}:pdf:${page.pageNumber}:$i',
            bookId: book.id,
            title: '${book.title} - 第 ${page.pageNumber} 页',
            text: chunk.text,
            locator: ReadingLocator.pdf(
              page: page.pageNumber,
              scrollOffset: scrollOffset,
              progress: pageProgress,
              excerpt: compactLocatorExcerpt(chunk.text),
            ),
            sortOrder: page.pageNumber * 10000 + i,
          ),
        );
        if (pending.length >= batchSize) {
          await flushPending();
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
  }) async {
    cancelToken?.throwIfCancelled();
    onProgress?.call(0.15, message: '解析 EPUB');
    final document = await _epubLoader.load(book.libraryFilePath);
    cancelToken?.throwIfCancelled();
    const batchSize = 64;
    var pending = <SearchIndexEntry>[];
    final totalChapters = document.chapters.length;
    var lastReportedBucket = -1;

    Future<void> flushPending() async {
      if (pending.isEmpty) {
        return;
      }
      cancelToken?.throwIfCancelled();
      final batch = pending;
      pending = <SearchIndexEntry>[];
      await _searchRepository.indexTexts(batch);
    }

    for (
      var chapterIndex = 0;
      chapterIndex < totalChapters;
      chapterIndex += 1
    ) {
      cancelToken?.throwIfCancelled();
      final chapter = document.chapters[chapterIndex];
      final chunks = _splitTextWithOffsets(chapter.text, targetLength: 1200);
      for (var i = 0; i < chunks.length; i += 1) {
        final chunk = chunks[i];
        final start = chunk.startOffset.clamp(0, chapter.text.length);
        final end = (start + chunk.text.length).clamp(
          start,
          chapter.text.length,
        );
        pending.add(
          SearchIndexEntry(
            sourceType: 'book',
            sourceId: '${book.id}:epub:${chapter.index}:$i',
            bookId: book.id,
            title: chapter.title,
            text: chunk.text,
            locator: ReadingLocator.epub(
              href: chapter.href,
              chapterIndex: chapter.index,
              chapterOffset: start,
              chapterEndOffset: end,
              progress: document.progressForChapter(
                chapterIndex: chapter.index,
                chapterOffset: start,
              ),
              excerpt: compactLocatorExcerpt(chunk.text),
            ),
            sortOrder: chapter.index * 10000 + i,
          ),
        );
        if (pending.length >= batchSize) {
          await flushPending();
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
    onProgress?.call(0.99, message: '完成 EPUB 索引');
    return 'done';
  }

  /// Splits [text] into search chunks while preserving source offsets.
  ///
  /// Offsets are measured against the original [text], not the trimmed chunk
  /// copy, so EPUB jump can land near the indexed phrase.
  List<({String text, int startOffset})> _splitTextWithOffsets(
    String text, {
    required int targetLength,
  }) {
    final normalized = text;
    if (normalized.trim().isEmpty) {
      return const [];
    }
    if (normalized.trim().length <= targetLength) {
      final start = _firstNonWhitespace(normalized);
      return [(text: normalized.trim(), startOffset: start < 0 ? 0 : start)];
    }

    final chunks = <({String text, int startOffset})>[];
    final matches = RegExp(r'\S[\s\S]*?(?=\n\s*\n+|$)').allMatches(normalized);
    final buffer = StringBuffer();
    var bufferStart = -1;

    void flushBuffer() {
      if (buffer.isEmpty || bufferStart < 0) {
        return;
      }
      final raw = buffer.toString();
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        final leading = raw.indexOf(RegExp(r'\S'));
        chunks.add((
          text: trimmed,
          startOffset: bufferStart + (leading < 0 ? 0 : leading),
        ));
      }
      buffer.clear();
      bufferStart = -1;
    }

    if (matches.isEmpty) {
      for (var offset = 0; offset < normalized.length; offset += targetLength) {
        final end = (offset + targetLength).clamp(0, normalized.length);
        final slice = normalized.substring(offset, end);
        final trimmed = slice.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final leading = slice.indexOf(RegExp(r'\S'));
        chunks.add((
          text: trimmed,
          startOffset: offset + (leading < 0 ? 0 : leading),
        ));
      }
      return chunks;
    }

    for (final match in matches) {
      final paragraph = match.group(0) ?? '';
      final paragraphStart = match.start;
      if (paragraph.trim().isEmpty) {
        continue;
      }
      if (buffer.length + paragraph.length > targetLength &&
          buffer.isNotEmpty) {
        flushBuffer();
      }
      if (paragraph.trim().length > targetLength) {
        flushBuffer();
        for (
          var offset = 0;
          offset < paragraph.length;
          offset += targetLength
        ) {
          final end = (offset + targetLength).clamp(0, paragraph.length);
          final slice = paragraph.substring(offset, end);
          final trimmed = slice.trim();
          if (trimmed.isEmpty) {
            continue;
          }
          final leading = slice.indexOf(RegExp(r'\S'));
          chunks.add((
            text: trimmed,
            startOffset: paragraphStart + offset + (leading < 0 ? 0 : leading),
          ));
        }
      } else {
        if (buffer.isEmpty) {
          bufferStart = paragraphStart;
        }
        buffer.writeln(paragraph.trim());
        buffer.writeln();
      }
    }
    flushBuffer();
    return chunks;
  }

  int _firstNonWhitespace(String value) {
    final match = RegExp(r'\S').firstMatch(value);
    return match?.start ?? 0;
  }
}
