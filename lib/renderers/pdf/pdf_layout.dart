import 'dart:math' as math;
import '../../domain/books/reader_settings.dart';

/// How the canvas renderer lays pages out.
///
/// Derived from the shared [ReaderMode] rather than stored separately: adding
/// a `pdfDisplayMode` setting would duplicate state the rest of the reader
/// (`reader_page.dart`, the EPUB link) already reads from `readerMode`.
enum PdfDisplayMode {
  /// Vertical list of pages, one scroll surface.
  continuous,

  /// One page at a time, horizontally swiped/turned.
  single,

  /// Two pages side by side, horizontally swiped/turned. Desktop only.
  double,
}

/// Maps [ReaderMode] plus the viewport onto the PDF display mode.
///
/// Mirrors the WebView bridge's `preferredDisplayMode()`: on a narrow viewport
/// a spread never fits, so `paged` degrades to [PdfDisplayMode.single] instead
/// of two cramped columns.
PdfDisplayMode preferredPdfDisplayMode({
  required ReaderMode readerMode,
  required bool narrow,
}) {
  if (readerMode != ReaderMode.paged) return PdfDisplayMode.continuous;
  return narrow ? PdfDisplayMode.single : PdfDisplayMode.double;
}

/// The pages visible together in one spread.
///
/// Continuous mode has no spread: the caller reports whichever single page the
/// scroll anchor lands on. Double mode pairs (2,3), (4,5), ... with the cover
/// (1) alone, matching the bridge and every printed-book convention. Indices
/// here are zero-based, so the cover is 0 and pairs start at odd indices.
({int start, int end}) pdfSpreadFor({
  required int pageIndex,
  required int pageCount,
  required PdfDisplayMode mode,
}) {
  if (mode != PdfDisplayMode.double || pageCount <= 1) {
    return (start: pageIndex, end: pageIndex);
  }
  if (pageIndex <= 0) return (start: 0, end: 0);
  // Zero-based: the cover is 0, so pairs are (1,2), (3,4), ... — odd starts.
  final start = pageIndex.isOdd ? pageIndex : pageIndex - 1;
  final end = math.min(start + 1, pageCount - 1);
  return (start: start, end: end);
}

/// The index of the first page of the spread containing [pageIndex].
///
/// Used to align a jump or a page-turn to spread boundaries: turning from the
/// right-hand page of a spread must advance a whole spread, not half of one.
int pdfSpreadStart({required int pageIndex, required int pageCount}) {
  if (pageIndex <= 0) return 0;
  if (pageCount <= 1) return 0;
  return pageIndex.isOdd ? pageIndex : pageIndex - 1;
}

/// Total scrollable height of the continuous layout.
///
/// [pageHeights] are the laid-out heights in logical pixels, in page order;
/// [gap] is inserted between pages only (never before the first or after the
/// last), so the end of the list is exactly the end of the last page.
double pdfContinuousExtent({
  required List<double> pageHeights,
  required double gap,
}) {
  if (pageHeights.isEmpty) return 0;
  var total = 0.0;
  for (final height in pageHeights) {
    total += height;
  }
  return total + gap * (pageHeights.length - 1);
}

/// Top offset of each page in the continuous layout.
List<double> pdfPageTops({
  required List<double> pageHeights,
  required double gap,
}) {
  final tops = <double>[];
  var y = 0.0;
  for (final height in pageHeights) {
    tops.add(y);
    y += height + gap;
  }
  return tops;
}

/// The page shown at a given scroll position.
///
/// Uses the same anchor as the bridge (`bridge.js:196`): `scrollY` plus 28% of
/// the viewport height, floored at 48 px. Scrolling a little past a page break
/// should not flip the reported page while most of the previous page is still
/// on screen.
int pdfPageAtScroll({
  required double scrollY,
  required List<double> pageTops,
  required List<double> pageHeights,
  required double viewportHeight,
}) {
  if (pageTops.isEmpty) return 0;
  final anchor = scrollY + math.max(viewportHeight * 0.28, 48);
  var page = 0;
  for (var i = 0; i < pageTops.length; i += 1) {
    if (pageTops[i] > anchor) break;
    page = i;
  }
  return page;
}

/// Within-page offset for a scroll position, or 0 outside continuous mode.
///
/// The bridge reports 0 unless the display is `continuous`
/// (`bridge.js:180`), because a paged layout has no meaningful sub-page
/// position to restore into.
double pdfScrollOffset({
  required double scrollY,
  required List<double> pageTops,
  required int pageIndex,
  required PdfDisplayMode mode,
}) {
  if (mode != PdfDisplayMode.continuous) return 0;
  if (pageIndex < 0 || pageIndex >= pageTops.length) return 0;
  return math.max(0, scrollY - pageTops[pageIndex]);
}

/// Scroll position that restores [pageIndex] at [offset] inside the page.
double pdfScrollTarget({
  required List<double> pageTops,
  required List<double> pageHeights,
  required int pageIndex,
  required double offset,
  required double viewportHeight,
}) {
  if (pageTops.isEmpty) return 0;
  final index = pageIndex.clamp(0, pageTops.length - 1);
  // The offset may run to the end of the page itself: a page shorter than the
  // viewport still has a valid position "near its bottom" (it simply stays
  // fully visible), and the bridge restored that offset as well. Only the
  // page's own height bounds it, so a stale offset cannot run into the next
  // page.
  final maxOffset = math.max(0.0, pageHeights[index]);
  return pageTops[index] + offset.clamp(0.0, maxOffset);
}
