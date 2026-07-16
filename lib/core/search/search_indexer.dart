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

  Future<void> indexBook(Book book, {TaskCancelToken? cancelToken}) async {
    await _bookRepository.updateIndexingStatus(book.id, 'running');
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
      cancelToken?.throwIfCancelled();

      switch (book.format) {
        case BookFormat.epub:
          await _indexEpub(book, cancelToken: cancelToken);
        case BookFormat.pdf:
          await _indexPdf(book, cancelToken: cancelToken);
      }

      cancelToken?.throwIfCancelled();
      await _bookRepository.updateIndexingStatus(book.id, 'done');
    } on TaskCancelledException {
      await _searchRepository.deleteByBook(book.id);
      await _bookRepository.updateIndexingStatus(book.id, 'pending');
      rethrow;
    } catch (_) {
      await _bookRepository.updateIndexingStatus(book.id, 'failed');
      rethrow;
    }
  }

  Future<void> _indexPdf(Book book, {TaskCancelToken? cancelToken}) async {
    cancelToken?.throwIfCancelled();
    final document = await _pdfTextExtractor.extract(book.libraryFilePath);
    cancelToken?.throwIfCancelled();
    if (!document.hasText) {
      return;
    }

    for (final page in document.pages) {
      cancelToken?.throwIfCancelled();
      final chunks = _splitTextWithOffsets(page.text, targetLength: 1200);
      final pageProgress = document.pages.isEmpty
          ? 0.0
          : (page.pageNumber - 1) / document.pages.length;
      for (var i = 0; i < chunks.length; i += 1) {
        cancelToken?.throwIfCancelled();
        final chunk = chunks[i];
        // Without real page geometry, approximate vertical offset by chunk order.
        final scrollOffset = chunks.length <= 1
            ? 0.0
            : (i / chunks.length) * 800;
        await _searchRepository.indexText(
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
        );
      }
    }
  }

  Future<void> _indexEpub(Book book, {TaskCancelToken? cancelToken}) async {
    cancelToken?.throwIfCancelled();
    final document = await _epubLoader.load(book.libraryFilePath);
    cancelToken?.throwIfCancelled();
    for (final chapter in document.chapters) {
      cancelToken?.throwIfCancelled();
      final chunks = _splitTextWithOffsets(chapter.text, targetLength: 1200);
      for (var i = 0; i < chunks.length; i += 1) {
        cancelToken?.throwIfCancelled();
        final chunk = chunks[i];
        final start = chunk.startOffset.clamp(0, chapter.text.length);
        final end = (start + chunk.text.length).clamp(start, chapter.text.length);
        await _searchRepository.indexText(
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
        );
      }
    }
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
      return [
        (
          text: normalized.trim(),
          startOffset: start < 0 ? 0 : start,
        ),
      ];
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
      if (buffer.length + paragraph.length > targetLength && buffer.isNotEmpty) {
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
