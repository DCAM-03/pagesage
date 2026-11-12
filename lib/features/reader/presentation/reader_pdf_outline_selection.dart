import '../../../renderers/common/renderer_event.dart';

/// The one outline row that represents where the reader is.
///
/// A PDF often puts a chapter and several subsections on the same page.
/// Marking every row whose page equals the current page turns the whole
/// branch blue and tells the reader nothing. When the renderer knows the
/// within-page position, the last heading at or above that position wins.
/// Otherwise the row at the top of the current page wins; failing that, the
/// last heading before this page stays active because its section is still
/// being read.
int? activePdfOutlineIndex({
  required List<RendererOutlineItem> items,
  required int? currentPage,
  double? currentPageOffsetFraction,
}) {
  final page = currentPage;
  if (page == null) {
    return null;
  }
  final offset = currentPageOffsetFraction;
  if (offset != null && offset > 0.01) {
    int? active;
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item.page < page) {
        active = index;
        continue;
      }
      if (item.page > page) {
        break;
      }
      final headingOffset = item.offsetFraction ?? 0;
      if (headingOffset <= offset + 0.01) {
        active = index;
      }
    }
    return active;
  }

  int? beforePage;
  int? atPageTop;
  for (var index = 0; index < items.length; index += 1) {
    final item = items[index];
    if (item.page < page) {
      beforePage = index;
      continue;
    }
    if (item.page > page) {
      break;
    }
    final itemOffset = item.offsetFraction ?? 0;
    if (itemOffset <= 0.01) {
      // Duplicate destinations on one page still produce one active row.
      atPageTop ??= index;
    }
  }
  return atPageTop ?? beforePage;
}
