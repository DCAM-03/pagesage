import 'dart:math' as math;

/// One stored annotation band, normalised to 0..1 of the displayed page box.
///
/// Mutable on purpose: the pipeline below trims and snaps the bands in place,
/// and the bridge version this ports worked the same way. Each instance is
/// built fresh per paint, so mutating them cannot corrupt stored data.
final class PdfLineRect {
  PdfLineRect({
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int page;
  final double x;
  double y;
  final double width;
  double height;

  double get right => x + width;
  double get bottom => y + height;
  double get cy => y + height * 0.5;
}

/// A horizontal slice of a page that a line of text occupies, in 0..1.
final class PdfLineBand {
  const PdfLineBand({this.top = 0, this.bottom = 0});

  final double top;
  final double bottom;

  double get height => bottom - top;
  double get cy => (top + bottom) * 0.5;

  PdfLineBand widen(PdfLineBand other) => PdfLineBand(
    top: math.min(top, other.top),
    bottom: math.max(bottom, other.bottom),
  );
}

/// Trims stored highlight bands so they cannot bleed into the next line.
///
/// Annotation rectangles are written from the renderer's selection rects and
/// then outlive the page geometry that produced them: a note saved at one zoom
/// is repainted at another, and a legacy box may cover several lines as a
/// single tall rectangle. Left alone, those boxes paint over the line below
/// (defect F-02) — the highlight looks like a slab rather than text marking.
///
/// [lineBands] is the page's text lines, top to bottom. Pass an empty list for
/// a page whose lines cannot be determined; bands are then only capped to a
/// single line height.
///
/// Mirrors `prepareHighlightRects` in `assets/renderer/pdf/bridge.js`, which
/// this has to keep matching until the WebView renderer is deleted (S7).
List<PdfLineRect> prepareAnnotationRects(
  List<PdfLineRect> rects, {
  required List<PdfLineBand> Function(int page) lineBands,
}) {
  final items = <PdfLineRect>[];
  for (final rect in rects) {
    if (rect.width <= 0 || rect.height <= 0) continue;
    if (rect.width > 0.98) continue;
    // Legacy multi-line mega-box: collapse to a readable single-line band
    // before the band snap below can split it. Only boxes past a whole line's
    // height collapse — a mid-sized box is still a plausible multi-line
    // selection and the snap below handles it line by line.
    if (rect.height > _legacyMegaBox) rect.height = _legacyTallBox;
    items.add(rect);
  }
  if (items.isEmpty) return const [];
  return preventAdjacentBleed(
    snapRectsToLineBands(mergeSameLineRects(items), lineBands),
  );
}

/// Height at which a stored box is no longer a plausible line band.
const _legacyMegaBox = 0.055;

/// What a mega-box collapses to.
const _legacyTallBox = 0.022;

/// Two boxes closer than this vertically are the same line.
const _seam = 0.0012;

/// Merges fragments that share a visual line.
///
/// Word boxes from a selection arrive per word, and adjacent fragments
/// interleave, so clustering is by vertical centre rather than by x order — a
/// sequential x-merge left same-line clusters unmerged and painted the line
/// twice.
List<PdfLineRect> mergeSameLineRects(List<PdfLineRect> items) {
  if (items.isEmpty) return const [];
  final byPage = <int, List<PdfLineRect>>{};
  for (final item in items) {
    byPage.putIfAbsent(item.page, () => <PdfLineRect>[]).add(item);
  }
  final merged = <PdfLineRect>[];
  for (final entry in byPage.entries) {
    final list = [...entry.value]..sort((a, b) => a.cy.compareTo(b.cy));
    final clusters = <_Cluster>[];
    for (final item in list) {
      final last = clusters.isEmpty ? null : clusters.last;
      final tolerance = math.max(item.height, 0.004) * 0.5;
      if (last != null && (item.cy - last.cyRef).abs() <= tolerance) {
        last.members.add(item);
        continue;
      }
      clusters.add(_Cluster(cyRef: item.cy)..members.add(item));
    }
    for (final cluster in clusters) {
      final members = cluster.members;
      final tops = members.map((m) => m.y).toList()..sort();
      final heights = members.map((m) => m.height).toList()..sort();
      // Median top and height resist a single outlier box (legacy word
      // boxes frequently carry an inflated height).
      final y = tops[tops.length ~/ 2];
      final h = heights[heights.length ~/ 2];
      final left = members.map((m) => m.x).reduce(math.min);
      final right = members.map((m) => m.right).reduce(math.max);
      merged.add(
        PdfLineRect(
          page: entry.key,
          x: left,
          y: y,
          width: math.max(right - left, 0.001),
          height: math.max(h, 0.002),
        ),
      );
    }
  }
  merged.sort(_topLeft);
  return merged;
}

/// Snaps each band onto the nearest text line and caps its height by the local
/// line pitch, so a dense page cannot paint into the next line.
///
/// A stored rect that covers two or more lines is split into one strip per
/// line it covers, rather than trimmed to the one nearest its centre: the
/// annotation was made across those lines, and keeping only one would silently
/// drop half of what the reader marked.
List<PdfLineRect> snapRectsToLineBands(
  List<PdfLineRect> items,
  List<PdfLineBand> Function(int page) lineBands,
) {
  final bandsByPage = <int, List<PdfLineBand>>{};
  final out = <PdfLineRect>[];
  for (final item in items) {
    final bands = bandsByPage.putIfAbsent(
      item.page,
      () => lineBands(item.page),
    );
    if (bands.isEmpty) {
      // No line reference at all: cap so a legacy union box cannot paint as a
      // multi-line slab. A single line is under ~16‰ everywhere measured.
      if (item.height > 0.016) item.height = 0.016;
      out.add(item);
      continue;
    }
    final covered = [
      for (final band in bands)
        if (_overlap(item, band) > band.height * 0.35) band,
    ];
    if (covered.length >= 2) {
      for (final band in covered) {
        out.add(
          _clampStripToBand(
            PdfLineRect(
              page: item.page,
              x: item.x,
              y: band.top,
              width: item.width,
              height: band.height,
            ),
            bands,
            band,
          ),
        );
      }
      continue;
    }
    PdfLineBand? best;
    var bestDistance = double.infinity;
    for (final band in bands) {
      final distance = (band.cy - item.cy).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = band;
      }
    }
    if (best == null) {
      out.add(item);
      continue;
    }
    if (item.height > best.height * 1.15 ||
        item.y < best.top - best.height * 0.5) {
      item.y = best.top;
      item.height = best.height;
    } else {
      item.y = math.max(item.y, best.top);
      item.height = math.min(item.height, best.bottom - item.y);
    }
    out.add(_clampStripToBand(item, bands, best));
  }
  return out;
}

/// Caps a strip by the pitch to the next line: at most 78% of it, and never
/// past the next line's top edge.
PdfLineRect _clampStripToBand(
  PdfLineRect item,
  List<PdfLineBand> bands,
  PdfLineBand band,
) {
  final index = bands.indexOf(band);
  if (index >= 0 && index + 1 < bands.length) {
    final next = bands[index + 1];
    final pitch = next.top - band.top;
    if (pitch > 0.002) {
      final maxHeight = math.max(pitch * 0.78, band.height * 0.5);
      if (item.height > maxHeight) item.height = maxHeight;
      final maxBottom = next.top - _seam;
      if (item.y + item.height > maxBottom) {
        item.height = math.max(maxBottom - item.y, band.height * 0.5);
      }
    }
  }
  return item;
}

/// If two painted lines touch, shortens the upper strip from the bottom only.
///
/// Only a real next line counts: sub-line jitter used to be treated as one and
/// crushed marks into slivers, which is why the pitch has to exceed 70% of the
/// taller box.
List<PdfLineRect> preventAdjacentBleed(List<PdfLineRect> items) {
  items.sort(_topLeft);
  for (var i = 0; i < items.length - 1; i += 1) {
    final current = items[i];
    final next = items[i + 1];
    if (current.page != next.page) continue;
    final pitch = next.y - current.y;
    if (pitch < math.max(current.height, next.height) * 0.7) continue;
    if (current.y + current.height > next.y - _seam) {
      current.height = math.max(
        next.y - _seam - current.y,
        current.height * 0.5,
      );
    }
  }
  return items;
}

/// Text-line bands for a page, from text runs or OCR boxes.
///
/// Several runs share one visual line, so the raw boxes are clustered: taking
/// each span as its own band made "next line" a same-line sibling and crushed
/// heights. [boxes] are the line boxes in 0..1 page space.
List<PdfLineBand> lineBandsForPage(List<({double top, double bottom})> boxes) {
  final raw = [
    for (final box in boxes)
      if (box.top >= 0 && box.bottom > box.top && box.bottom <= 1.001)
        (top: box.top, bottom: box.bottom),
  ]..sort((a, b) => a.top.compareTo(b.top));
  if (raw.isEmpty) return const [];
  final bands = <({double top, double bottom})>[];
  for (final box in raw) {
    final last = bands.isEmpty ? null : bands.last;
    if (last != null && box.top - last.top < (last.bottom - last.top) * 0.55) {
      bands[bands.length - 1] = (
        top: math.min(last.top, box.top),
        bottom: math.max(last.bottom, box.bottom),
      );
      continue;
    }
    bands.add((top: box.top, bottom: box.bottom));
  }
  return [
    for (final band in bands) PdfLineBand(top: band.top, bottom: band.bottom),
  ];
}

int _topLeft(PdfLineRect a, PdfLineRect b) {
  final page = a.page.compareTo(b.page);
  if (page != 0) return page;
  final dy = a.y.compareTo(b.y);
  if (dy != 0) return dy;
  return a.x.compareTo(b.x);
}

double _overlap(PdfLineRect item, PdfLineBand band) =>
    math.min(item.bottom, band.bottom) - math.max(item.y, band.top);

final class _Cluster {
  _Cluster({required this.cyRef});

  final double cyRef;
  final List<PdfLineRect> members = <PdfLineRect>[];
}
