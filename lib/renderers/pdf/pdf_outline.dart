import 'package:pdf_document/pdf_document.dart';

import '../common/renderer_event.dart';

/// Flattens a PDF's `/Outlines` tree into the host's outline items.
///
/// The canvas renderer had no outline path at all, so the reader fell back to
/// a page-number list for every PDF even when the document carried a real
/// table of contents. `PdfOutline.of` resolves the tree once at open time;
/// this walks it in document order and records each item's nesting depth.
///
/// Items without a resolvable destination are skipped: the host's outline is a
/// list of jumps, and a row that cannot jump is a dead control. The library
/// already guards against cyclic `/First`-`/Next` chains while reading.
///
/// [pageHeight] is the display height of a 1-based page in PDF points, used to
/// turn a destination's user-space y into a fraction from the page's top. It
/// receives the page number because a document may mix page sizes.
List<PdfOutlineEntry> pdfOutlineEntries(
  PdfOutline outline, {
  required double Function(int page) pageHeight,
  int maxItems = 500,
}) {
  final out = <PdfOutlineEntry>[];
  void walk(List<PdfOutlineItem> items, int level) {
    for (final item in items) {
      if (out.length >= maxItems) return;
      final destination = item.destination;
      final pageIndex = destination?.pageIndex;
      if (pageIndex == null || pageIndex < 0) continue;
      final page = pageIndex + 1;
      final title = item.title.trim();
      final height = pageHeight(page);
      final top = destination?.top;
      out.add(
        PdfOutlineEntry(
          title: title.isEmpty ? '第 $page 页' : title,
          page: page,
          level: level,
          offsetFraction: top == null || height <= 0
              ? null
              : ((height - top) / height).clamp(0.0, 1.0),
        ),
      );
      walk(item.children, level + 1);
    }
  }

  walk(outline.items, 0);
  return out;
}

/// One outline row, before it becomes a [RendererOutlineItem].
final class PdfOutlineEntry {
  const PdfOutlineEntry({
    required this.title,
    required this.page,
    required this.level,
    this.offsetFraction,
  });

  final String title;

  /// 1-based page number.
  final int page;

  /// Nesting depth, 0 for a top-level heading.
  final int level;

  /// Where in the page the heading sits, 0..1 from the top, or null when the
  /// destination's fit style names no position.
  final double? offsetFraction;

  RendererOutlineItem toRendererItem() => RendererOutlineItem(
    title: title,
    page: page,
    level: level,
    offsetFraction: offsetFraction,
  );
}
