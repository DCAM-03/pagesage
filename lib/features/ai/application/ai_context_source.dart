import 'dart:io';
import 'dart:isolate';

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../../domain/books/reading_position.dart';
import '../../../renderers/epub/epub_document.dart';
import '../../../renderers/epub/epub_document_loader.dart';
import 'ai_context_range.dart';

/// A block of text the AI request will carry, with where it came from.
///
/// The panel lists these as references the reader can inspect, drop, or jump
/// back to. `AGENTS.md` requires the AI context range to be explicit, and a
/// list the reader can see is the only form of that which survives automatic
/// retrieval — the whole-book and whole-folder ranges will hand back several
/// of these, from more than one book, and the reader has to see each one.
final class ContextSource {
  const ContextSource({
    required this.title,
    required this.text,
    this.locator,
    this.bookTitle,
  });

  /// Human-readable origin, e.g. `第 3 章 · 用 Rust 写猜数字游戏`.
  final String title;

  final String text;

  /// Where to jump back to, when the block can be located.
  final ReadingLocator? locator;

  /// The book this came from, once retrieval can cross books.
  ///
  /// Null for the current book: the panel is open inside it, and repeating its
  /// title on every reference would only add noise.
  final String? bookTitle;

  /// One line naming where this came from, for the reference row.
  String get label => bookTitle == null ? title : '$bookTitle · $title';
}

/// Thrown when the book itself cannot be opened.
///
/// Distinct from returning null, which means the file opened and this page or
/// chapter simply has no text. The panel tells the reader which one happened;
/// blaming the page for a corrupt file sends them looking in the wrong place.
final class BookUnreadableException implements Exception {
  const BookUnreadableException();
}

/// Loads the text a context range needs, straight from the book on disk.
///
/// Until now `ContextBuilder` had an `availableText` parameter that nothing
/// ever passed, so "surrounding paragraphs", "current chapter" and "current
/// page" all quietly degraded to the selected snippet — the range selector
/// changed its label and nothing else. This is the missing supplier.
///
/// Reading from the file rather than from the mounted renderer is deliberate.
/// The panel also opens from search results and notes, where no renderer is
/// attached, and an attached renderer holds only the pages around the
/// viewport. The file always has all of it.
///
/// Not `final`: a widget test drives the panel through a stubbed `load`, and
/// the file reads below never complete under the test's fake clock.
class AiContextSource {
  const AiContextSource([this._epubLoader = const EpubDocumentLoader()]);

  final EpubDocumentLoader _epubLoader;

  /// Text for [range], or null when the range needs no outside text.
  ///
  /// Returns null for [AiContextRange.selectedText]: that range is the
  /// selection itself, which the caller already holds.
  ///
  /// Throws [BookUnreadableException] when the book cannot be opened. A null
  /// for a range that does need text means the file opened and the page or
  /// chapter is empty (a scanned page, a cover image).
  Future<ContextSource?> load({
    required AiContextRange range,
    required String bookPath,
    required ReadingLocator? locator,
    required bool isEpub,
  }) async {
    switch (range) {
      case AiContextRange.selectedText:
        return null;
      case AiContextRange.currentPage:
        return isEpub
            ? _epubChapter(bookPath, locator)
            : _pdfPage(bookPath, locator);
      case AiContextRange.currentChapter:
        return _epubChapter(bookPath, locator);
      case AiContextRange.surroundingParagraphs:
        // Narrowed from the body of text the selection sits in; the builder
        // cuts the paragraphs. Whole-book and whole-folder ranges are not
        // expressed here: they need retrieval, not one file read.
        return isEpub
            ? _epubChapter(bookPath, locator)
            : _pdfPage(bookPath, locator);
    }
  }

  /// One page of a PDF, or null when the page has no text.
  Future<ContextSource?> _pdfPage(
    String bookPath,
    ReadingLocator? locator,
  ) async {
    final pageNumber = locator?.page;
    if (pageNumber == null || pageNumber < 1) return null;
    final pageIndex = pageNumber - 1;
    if (!File(bookPath).existsSync()) throw const BookUnreadableException();
    final String? text;
    try {
      text = await Isolate.run(() => _extractPdfPage(bookPath, pageIndex));
    } on Object {
      // The file is there but the document would not open, or the page index
      // is past the end. Both mean "nothing to send", but the distinction
      // above already separated a missing file from an empty page.
      return null;
    }
    if (text == null || text.trim().isEmpty) return null;
    return ContextSource(
      title: '第 $pageNumber 页',
      text: text,
      locator: locator,
    );
  }

  /// One EPUB chapter, or null when it has no text.
  Future<ContextSource?> _epubChapter(
    String bookPath,
    ReadingLocator? locator,
  ) async {
    final EpubDocument document;
    try {
      document = await _epubLoader.load(bookPath);
    } on Object {
      throw const BookUnreadableException();
    }
    if (document.chapters.isEmpty) return null;
    final chapterIndex = (locator?.chapterIndex ?? 0).clamp(
      0,
      document.chapters.length - 1,
    );
    final chapter = document.chapters[chapterIndex];
    if (chapter.text.trim().isEmpty) return null;
    return ContextSource(
      title: chapter.title,
      text: chapter.text,
      locator: ReadingLocator.epub(
        href: chapter.href,
        chapterIndex: chapter.index,
        chapterOffset: 0,
        progress: document.progressForChapter(
          chapterIndex: chapter.index,
          chapterOffset: 0,
        ),
      ),
    );
  }
}

/// Extracts one page's text. Top-level so it can be sent to an isolate.
String? _extractPdfPage(String path, int pageIndex) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final document = PdfDocument.open(file.readAsBytesSync());
  if (pageIndex < 0 || pageIndex >= document.pageCount) return null;
  return PdfTextExtractor.reflowPage(document, pageIndex).text;
}
