import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../domain/books/reading_position.dart';

/// A caret (insertion point) in a PDF's extracted text.
///
/// [page] is a zero-based page index; [index] is a character index into that
/// page's `PdfPageText.text`, as returned by `positionNear`. Cross-page
/// selection is expressed as two carets and normalised by [pdfOrderCarets],
/// which is how a drag that starts on one page and ends on another becomes a
/// single ordered selection.
typedef PdfCaret = ({int page, int index});

/// The part of a selection that falls on one page.
typedef PdfSelectionSegment = ({int page, int start, int end});

/// Text on one PDF page that pointer gestures can be mapped onto.
///
/// Native PDF text and OCR text live in different coordinate spaces: native
/// text comes from PDF page space and is projected through /Rotate, while OCR
/// blocks are already fractions of the displayed page. The reader only needs
/// one shape from either source: a caret for a pointer, page text for a
/// range, and rectangles that can be persisted and repainted.
abstract interface class PdfTextSelectionSource {
  /// Zero-based page index this source belongs to.
  int get pageIndex;

  /// The page's selectable text, in caret-index order.
  String get pageText;

  /// Caret under [widgetPoint], or null when this source cannot resolve one.
  ///
  /// [snapToNearest] is true while dragging: a pointer in the leading or just
  /// outside the page should still follow the nearest line. A tap passes false
  /// so blank paper selects nothing instead of guessing a word.
  PdfCaret? caretAt(Offset widgetPoint, {bool snapToNearest = true});

  /// Selection chrome rectangles in widget-local pixels.
  List<Rect> viewRectsFor(int start, int end);

  /// Selection rectangles normalised to 0..1 of the displayed page box.
  List<ReaderRect> readerRectsFor(int start, int end);
}

/// A selection between two carets, in either drag direction.
final class PdfSelection {
  const PdfSelection({required this.anchor, required this.focus});

  /// Where the gesture started.
  final PdfCaret anchor;

  /// Where the pointer is now.
  final PdfCaret focus;

  ({PdfCaret start, PdfCaret end}) get ordered => pdfOrderCarets(anchor, focus);

  bool get isEmpty => anchor.index == focus.index && anchor.page == focus.page;
}

/// Orders two carets in reading order: page first, then character index.
({PdfCaret start, PdfCaret end}) pdfOrderCarets(PdfCaret a, PdfCaret b) {
  if (a.page != b.page) {
    return a.page < b.page ? (start: a, end: b) : (start: b, end: a);
  }
  return a.index <= b.index ? (start: a, end: b) : (start: b, end: a);
}

/// (start, end) of the word containing [index], or null when there is none.
///
/// CJK characters are words in themselves: Chinese has no spaces, so
/// expanding over non-separator characters would swallow a whole sentence.
/// A long press on a CJK character therefore selects that single character,
/// matching native CJK input behaviour.
(int, int)? pdfWordRangeAt(String text, int index) {
  if (text.isEmpty) return null;
  final i = index.clamp(0, text.length - 1);

  // Pointing at a separator selects nothing. Expanding from one would glue
  // the words on either side into a single "word", which is what a caret
  // parked on a space would otherwise report.
  if (_isSeparator(text.codeUnitAt(i))) return null;

  if (_isCjk(text.codeUnitAt(i))) return (i, i + 1);

  var start = i;
  while (start > 0 && !_isSeparator(text.codeUnitAt(start - 1))) {
    start--;
  }
  var end = i;
  while (end < text.length && !_isSeparator(text.codeUnitAt(end))) {
    end++;
  }
  return end <= start ? null : (start, end);
}

const _asciiSeparators = ' \t\n\r,.!?;:\'"()[]{}<>/\\|@#\$%^&*-_=+';
const _cjkPunctuation =
    '、。，．；：？！…—～·「」『』《》【】（）〔〕｛｝'
    '“”‘’　';

/// CJK punctuation counts as a separator, but CJK ideographs do not: they are
/// handled by [pdfWordRangeAt] as single-character words.
bool _isSeparator(int codeUnit) {
  if (_cjkPunctuation.contains(String.fromCharCode(codeUnit))) return true;
  return _asciiSeparators.contains(String.fromCharCode(codeUnit));
}

bool _isCjk(int codeUnit) =>
    (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) || // unified ideographs
    (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) || // extension A
    (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) || // compatibility
    (codeUnit >= 0x3040 && codeUnit <= 0x30FF) || // kana
    (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF); // hangul

/// Splits a selection across the pages it covers.
///
/// Every page between the two carets contributes a segment: the start page
/// from the anchor caret to its last character, interior pages in full, and
/// the end page from its first character to the focus caret. Rectangles for a
/// stored annotation are clipped page by page with these same bounds, which is
/// what keeps a cross-page selection from leaking onto the wrong page.
///
/// [textLengthOf] must return the page's extracted text length; pages outside
/// the document may return 0 and are skipped.
List<PdfSelectionSegment> pdfSelectionSegments({
  required PdfCaret anchor,
  required PdfCaret focus,
  required int Function(int page) textLengthOf,
}) {
  final (:start, :end) = pdfOrderCarets(anchor, focus);
  final segments = <PdfSelectionSegment>[];

  if (start.page == end.page) {
    final length = math.max(0, textLengthOf(start.page));
    final from = start.index.clamp(0, length);
    final to = end.index.clamp(0, length);
    if (to > from) {
      segments.add((page: start.page, start: from, end: to));
    }
    return segments;
  }

  final startLength = math.max(0, textLengthOf(start.page));
  final from = start.index.clamp(0, startLength);
  if (startLength > from) {
    segments.add((page: start.page, start: from, end: startLength));
  }

  for (var page = start.page + 1; page < end.page; page++) {
    final length = math.max(0, textLengthOf(page));
    if (length > 0) segments.add((page: page, start: 0, end: length));
  }

  final endLength = math.max(0, textLengthOf(end.page));
  final to = end.index.clamp(0, endLength);
  if (to > 0) {
    segments.add((page: end.page, start: 0, end: to));
  }
  return segments;
}

/// Joins per-page selection text the way the WebView bridge did.
///
/// The browser reported `selection.toString().replace(/\s+/g, " ").trim()`,
/// so lines and page breaks become single spaces. Keeping the same rule means
/// stored excerpts and the clipboard text do not change shape with the
/// renderer.
String pdfSelectionText(Iterable<String> pageTexts) {
  final joined = pageTexts.where((text) => text.isNotEmpty).join(' ');
  return joined.replaceAll(RegExp(r'\s+'), ' ').trim();
}
