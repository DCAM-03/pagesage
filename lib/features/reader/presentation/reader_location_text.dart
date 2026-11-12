import '../../../domain/books/book.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';

/// A short label for where the reader is, used by the mobile and desktop bars.
String readerLocationText({
  required Book book,
  required ReadingLocator? locator,
  required String? chapterTitle,
  required int? pageNumber,
  required int? totalPages,
}) {
  if (book.format == BookFormat.pdf) {
    final page = pageNumber ?? locator?.page;
    final total = totalPages;
    if (page != null && total != null && total > 0) {
      return '第 $page / $total 页';
    }
    if (page != null) {
      return '第 $page 页';
    }
    return 'PDF 阅读中';
  }
  final chapter = chapterTitle?.trim();
  if (chapter != null && chapter.isNotEmpty) {
    return chapter;
  }
  final index = locator?.chapterIndex;
  if (index != null) {
    return '第 ${index + 1} 章';
  }
  return 'EPUB 阅读中';
}

String readerScaleText(Book book, ReaderSettings settings) {
  return switch (book.format) {
    BookFormat.epub || BookFormat.markdown => '字号 ${settings.fontSize.round()}',
    BookFormat.pdf => switch (settings.pdfZoomMode) {
      PdfZoomMode.fitWidth => '适宽',
      PdfZoomMode.fitPage => '整页',
      PdfZoomMode.actual => '100%',
      PdfZoomMode.custom => '${(settings.pdfScale * 100).round()}%',
    },
  };
}

String readerFormatLabel(BookFormat format) {
  return switch (format) {
    BookFormat.epub => 'EPUB',
    BookFormat.pdf => 'PDF',
    BookFormat.markdown => 'MD',
  };
}
