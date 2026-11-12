import 'dart:math' as math;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../domain/books/reading_position.dart';
import '../common/renderer_event.dart';
import 'pdf_canvas_renderer.dart';
import 'pdf_selection.dart';

/// A point in PDF page space (points, y-up), as opposed to widget space.
typedef PagePoint = ({double x, double y});

/// Maps pointer gestures on a painted PDF page onto text selection.
///
/// Two coordinate spaces are in play: widget space (y-down, device pixels) and
/// PDF page space (y-up, points). Everything here converts widget -> page before
/// calling `pdf_graphics`, and page -> widget when reporting rects, because the
/// renderer contract (`ReaderRect`) is expressed in the reader's own space.
final class PdfSelectionController implements PdfTextSelectionSource {
  PdfSelectionController({
    required this.renderer,
    required this.pageIndex,
    required this.box,
    required this.rotation,
    required this.paintSize,
    required this.displayedSize,
    required this.globalOrigin,
    required this.pageSize,
  });

  final PdfCanvasRenderer renderer;
  @override
  final int pageIndex;
  final PdfRect box;

  /// The page's /Rotate value. Every widget↔page conversion goes through
  /// [PdfPageGeometry], so a rotated page selects and reports rects in the
  /// same place a browser would.
  final int rotation;

  /// Size of the page's own coordinate space, in logical pixels. Pointer
  /// positions arrive in this space, so overlays are laid out against it.
  final Size paintSize;

  /// Size the page actually occupies on screen, in logical pixels.
  final Size displayedSize;

  /// Global position of the painted page's top-left corner.
  final Offset globalOrigin;

  /// The page's rotation-aware size in PDF points
  /// (`PdfPageRenderer.pageSize`), i.e. what [paintSize] represents.
  final Size pageSize;

  /// Widget space <-> PDF page space, including /Rotate.
  late final PdfPageGeometry _geometry = PdfPageGeometry(
    cropBox: box,
    rotation: rotation,
    viewSize: paintSize,
  );

  /// The same mapping at 1 unit per point, for normalising into 0..1.
  late final PdfPageGeometry _unitGeometry = PdfPageGeometry(
    cropBox: box,
    rotation: rotation,
    viewSize: pageSize,
  );

  /// Logical pixels per PDF point at the current layout.
  ///
  /// This is the value the WebView renderer exposed as `dataset.scale`, and
  /// what `locator.zoom` is expected to carry.
  double get layoutScale =>
      pageSize.width <= 0 ? 1 : displayedSize.width / pageSize.width;

  PdfPageText? _cached;

  PdfPageText get _text {
    final existing = _cached;
    if (existing != null) return existing;
    final computed = renderer.textOf(pageIndex);
    _cached = computed;
    return computed;
  }

  bool get hasText => _text.runs.isNotEmpty;

  /// Widget-local point -> PDF page coordinates, or null when outside the page.
  PagePoint? toPagePoint(Offset local) {
    if (paintSize.width <= 0 || paintSize.height <= 0) return null;
    final dx = local.dx;
    final dy = local.dy;
    if (dx < 0 || dy < 0 || dx > paintSize.width || dy > paintSize.height) {
      return null;
    }
    final (x, y) = _geometry.toPagePoint(local);
    return (x: x, y: y);
  }

  /// Like [toPagePoint], but a point just outside the page is pulled onto it.
  ///
  /// A drag that runs off the bottom of a page — reaching for the end of a
  /// paragraph, or carrying on into the next page — is normal, and the caret
  /// should follow to the page's edge rather than stop dead at it. This is the
  /// same courtesy `positionNear` used to provide accidentally, by snapping to
  /// the nearest run no matter how far away it was; here it is bounded to
  /// [overshoot] points so a pointer in the margin beside the page cannot
  /// reach text from a different column.
  PagePoint? clampedPagePoint(Offset local, {double overshoot = 0}) {
    if (paintSize.width <= 0 || paintSize.height <= 0 || overshoot < 0) {
      return toPagePoint(local);
    }
    if (local.dx < -overshoot ||
        local.dy < -overshoot ||
        local.dx > paintSize.width + overshoot ||
        local.dy > paintSize.height + overshoot) {
      return null;
    }
    final dx = local.dx.clamp(0.0, paintSize.width);
    final dy = local.dy.clamp(0.0, paintSize.height);
    final (x, y) = _geometry.toPagePoint(Offset(dx, dy));
    return (x: x, y: y);
  }

  /// PDF page coordinates -> widget-local offset.
  Offset toWidgetPoint(double x, double y) => _geometry.toViewOffset(x, y);

  /// Word-sized selection at a tap, matching desktop reader behaviour.
  ///
  /// CJK characters count as single-character words so tapping one selects just
  /// that character, matching native CJK input behaviour.
  RendererTextSelected? selectionAtWord(Offset widgetPoint) {
    final page = toPagePoint(widgetPoint);
    if (page == null) return null;
    final index = caretIndexAt(
      page.x,
      page.y,
      _tapHitSlop,
      lineSlop: _tapLineSlop,
    );
    if (index < 0) return null;

    final range = pdfWordRangeAt(_text.text, index);
    if (range == null) return null;
    return _buildEvent(
      range.$1,
      range.$2,
      _text.text.substring(range.$1, range.$2),
    );
  }

  /// The caret under a widget-local point, or null when outside the page.
  ///
  /// A drag across pages tracks one caret per page and orders them in reading
  /// order, so this deliberately ignores the pointer's closeness to the page
  /// edge: the page the pointer is over is the page the caret belongs to.
  @override
  PdfCaret? caretAt(Offset widgetPoint, {bool snapToNearest = true}) {
    // Overshoot the page by a few points: a drag reaching for the end of a
    // paragraph runs off the bottom edge, and the caret should follow to the
    // edge rather than stop dead outside it.
    final page = clampedPagePoint(
      widgetPoint,
      overshoot: snapToNearest ? _dragOvershoot : 0,
    );
    if (page == null) return null;
    final index = caretIndexAt(
      page.x,
      page.y,
      _dragHitSlop,
      lineSlop: _dragLineSlop,
      // A drag is aimed at a line rather than at a glyph, and it has to keep
      // working while the pointer is in the leading, in the margin, or held
      // outside the page to scroll toward the next one. Declining there would
      // freeze the selection mid-document; snapping to the nearest line keeps
      // it moving and is what every desktop reader does.
      snapToNearest: snapToNearest,
    );
    if (index < 0) return null;
    return (page: pageIndex, index: index);
  }

  /// How far outside the page's own box a drag still counts, in page points.
  static const _dragOvershoot = 24.0;

  /// How far past the end of a line a tap may land, in page points.
  ///
  /// Points, not em: this is a distance the reader aims with, and the same
  /// click should reach as far on a caption as on a heading. Six points is
  /// about half a body character — enough to forgive a click on the indent or
  /// just past the last glyph, short of reaching the next column.
  static const _tapHitSlop = 6.0;

  /// How far above or below a line's band a tap may land, in page points.
  ///
  /// Not zero: a reader aiming at a line of text routinely clicks the gap
  /// between it and its neighbour — the band covers the glyphs, not the
  /// leading, so roughly a quarter of every line's vertical space is outside
  /// it. Zero made that quarter select nothing at all, which reads as the
  /// reader ignoring the click.
  ///
  /// Half the smallest line pitch measured in the sample books (10.2pt) is the
  /// ceiling here: any larger and one point belongs to two lines, and the
  /// choice between them becomes arbitrary. At 4pt the two nearest lines'
  /// zones meet at the midpoint between their bands, so a click always goes to
  /// the line it is nearer.
  static const _tapLineSlop = 4.0;

  /// The same allowance for a drag.
  ///
  /// Larger because a drag is aimed at a line rather than a glyph and must be
  /// able to grab the line's first and last character.
  static const _dragHitSlop = 12.0;

  /// How far across the baseline band a drag may stray, in page points.
  ///
  /// A drag continues past the end of a paragraph into the leading below it,
  /// which is how a reader selects a paragraph break, and it also *starts* in
  /// that leading far more often than it does on a glyph. Half the line pitch
  /// is the widest allowance that still leaves one line nearer than the other
  /// at every point in the gap, so the caret never has to guess: 5pt against
  /// the 10.2pt pitch measured in the sample books.
  ///
  /// The cost is that a drag starting on the blank line between two paragraphs
  /// picks the nearer paragraph rather than nothing. That is the behaviour a
  /// reader expects; a tap keeps the smaller [_tapLineSlop] because a tap is
  /// meant to identify a word, and picking one for the reader there would be a
  /// guess they did not ask for.
  static const _dragLineSlop = 5.0;

  /// Caret index at page point ([x], [y]), or -1 when the point is not on a
  /// line of text.
  ///
  /// This replaces `PdfPageText.positionNear`, which scores by distance to a
  /// run's whole *bounding box*. Extraction gives one run per show-text
  /// operator, and those boxes are not line bands: a run can cover a whole
  /// indented code block, a full paragraph, or a column with the leading
  /// between its lines. A point in the whitespace inside such a box is
  /// distance 0, so it wins over the run actually on that line, and a point
  /// just outside it can still snap to a line hundreds of points away — the
  /// measured cause of a selection that jumps between lines and of taps that
  /// select a word from elsewhere on the page. On a uniform grid over four
  /// anonymous PDF samples, 3–27% of points resolved
  /// to a line other than the one under the pointer, by up to 729pt.
  ///
  /// The rule here follows `dart_pdf_editor`'s own viewer
  /// (`_textPositionOnLine`): map the point into the run's em space and
  /// require it to fall inside the baseline band. Only runs on that visual
  /// line can win, so no amount of whitespace can pull the caret elsewhere.
  ///
  /// Two refinements on top of the viewer's version, both needed by a reader:
  ///
  /// * **A line is many runs.** Extraction splits a sentence at every kerning
  ///   pair — `The defa` / `ult program alwa` / `ys prin` are three runs on one
  ///   line. Judging each run against its own extent alone made the indent and
  ///   the gaps between runs unselectable, so runs sharing a band are unified
  ///   into one span first.
  /// * **The allowance is physical, not typographic.** [slop] is a distance a
  ///   reader aims with, so it is compared in page points rather than em; the
  ///   same click should not have a different reach in a caption and a heading.
  ///
  /// [slop] is how far past the line's ends a point may land.
  /// [lineSlop] is a separate allowance across the band that a drag gets so it
  /// can continue into the leading; pass 0 for a tap. With [snapToNearest] set
  /// a point that is on no line at all falls back to the closest line on the
  /// page instead of declining; see [caretAt].
  int caretIndexAt(
    double x,
    double y,
    double slop, {
    double lineSlop = 0,
    bool snapToNearest = false,
  }) {
    final hits = <_RunHit>[];
    for (final run in _text.runs) {
      if (run.text.isEmpty) continue;
      final inverse = run.transform.inverted();
      if (inverse == null) continue;
      final scaleSq =
          (run.transform.a * run.transform.a +
                  run.transform.b * run.transform.b)
              .abs();
      if (scaleSq <= 1e-12) continue;
      final scale = math.sqrt(scaleSq);
      final ey = inverse.transformY(x, y);
      final cross = ey < run.descent
          ? run.descent - ey
          : ey > run.ascent
          ? ey - run.ascent
          : 0.0;
      if (cross * scale > lineSlop) continue;
      hits.add(
        _RunHit(
          run: run,
          ex: inverse.transformX(x, y),
          crossPoints: cross * scale,
          band: _bandBox(run),
        ),
      );
    }
    if (hits.isEmpty) {
      return snapToNearest ? _nearestLineIndex(x, y) : -1;
    }

    // Test the point against each *line*, not each run: runs sharing a band
    // are unified into one horizontal span first, so the indent before a line
    // and the kerning gaps inside it are both part of that line.
    final onLine = <_RunHit>[];
    var bestCross = double.infinity;
    for (final hit in hits) {
      var left = hit.band.left;
      var right = hit.band.right;
      for (final other in hits) {
        if (identical(other, hit)) continue;
        if (!_sameLine(hit.band, other.band)) continue;
        left = math.min(left, other.band.left);
        right = math.max(right, other.band.right);
      }
      if (x < left - slop || x > right + slop) continue;
      onLine.add(hit);
      if (hit.crossPoints < bestCross) bestCross = hit.crossPoints;
    }
    if (onLine.isEmpty) {
      return snapToNearest ? _nearestLineIndex(x, y) : -1;
    }

    // Nearest line first, then nearest run *on* that line.
    //
    // Both comparisons are needed. Cross distance alone picks the line under
    // the pointer, but every run on that line ties at zero, so the first one
    // encountered wins: on a table-of-contents page, whose leader dots and
    // right-aligned page numbers are runs far apart on one line, that selects
    // a word from the other end of the row. Measured over three anonymous
    // PDF samples, this tie was 22–91% of points. Near-ties
    // across the band are treated as the same line, so differing font sizes on
    // one line cannot reorder the choice.
    const tie = 1.0;
    _RunHit? best;
    var bestAlong = double.infinity;
    for (final hit in onLine) {
      if (hit.crossPoints > bestCross + tie) continue;
      final along = hit.horizontalDistance(x);
      if (along < bestAlong) {
        bestAlong = along;
        best = hit;
      }
    }
    if (best == null) {
      return snapToNearest ? _nearestLineIndex(x, y) : -1;
    }
    return _offsetInRun(best.run, best.ex);
  }

  /// Caret on the page line closest to ([x], [y]), for a drag that is on none.
  ///
  /// This is the bounded version of what `positionNear` did: it may leave the
  /// page's text block, but it cannot skip to a distant line, because it picks
  /// the nearest band and then clamps into that one line's span. Used only by
  /// [caretAt]; a tap keeps the strict rule so a click on whitespace selects
  /// nothing rather than guessing.
  int _nearestLineIndex(double x, double y) {
    PdfExtractedRun? bestRun;
    var bestEx = 0.0;
    var bestDistance = double.infinity;
    for (final run in _text.runs) {
      if (run.text.isEmpty) continue;
      final band = _bandBox(run);
      final dx = x < band.left
          ? band.left - x
          : x > band.right
          ? x - band.right
          : 0.0;
      final dy = y < band.bottom
          ? band.bottom - y
          : y > band.top
          ? y - band.top
          : 0.0;
      final distance = dx * dx + dy * dy;
      if (distance >= bestDistance) continue;
      // Clamp into the run's own span in em space, so a pointer past the line's
      // end lands on its last character and one before it on the first. Using
      // the inverse transform rather than the band's x-extent keeps this right
      // for rotated pages and right-to-left runs.
      final inverse = run.transform.inverted();
      final ex = inverse == null
          ? ((x - band.left) / (band.right - band.left) * run.width).clamp(
              0.0,
              run.width,
            )
          : inverse.transformX(x, y).clamp(0.0, run.width);
      bestDistance = distance;
      bestRun = run;
      bestEx = ex;
    }
    if (bestRun == null) return -1;
    return _offsetInRun(bestRun, bestEx);
  }

  /// The page-space box of a run's baseline band, after /Rotate and scale.
  ///
  /// Built from the four corners of the em-space band rather than from
  /// `run.bounds`: the band is [descent]..[ascent] around the baseline, while
  /// `bounds` is the union of every glyph's ink, which for a paragraph-long
  /// run spans many lines.
  static PdfRect _bandBox(PdfExtractedRun run) {
    final t = run.transform;
    final corners = <(double, double)>[
      (t.transformX(0, run.descent), t.transformY(0, run.descent)),
      (
        t.transformX(run.width, run.descent),
        t.transformY(run.width, run.descent),
      ),
      (
        t.transformX(run.width, run.ascent),
        t.transformY(run.width, run.ascent),
      ),
      (t.transformX(0, run.ascent), t.transformY(0, run.ascent)),
    ];
    var minX = corners.first.$1, maxX = corners.first.$1;
    var minY = corners.first.$2, maxY = corners.first.$2;
    for (final (cx, cy) in corners.skip(1)) {
      minX = math.min(minX, cx);
      maxX = math.max(maxX, cx);
      minY = math.min(minY, cy);
      maxY = math.max(maxY, cy);
    }
    return PdfRect(minX, minY, maxX, maxY);
  }

  /// Whether two band boxes sit on the same visual line.
  ///
  /// Requires a real overlap rather than mere proximity: adjacent lines in the
  /// books sampled are 10.2–11.5pt apart with 8.5–10.5pt bands, so a half-band
  /// overlap separates them while still joining a line whose runs use
  /// different fonts or sizes.
  static bool _sameLine(PdfRect a, PdfRect b) {
    final overlap = math.min(a.top, b.top) - math.max(a.bottom, b.bottom);
    final shorter = math.min(a.height, b.height);
    return shorter > 0 && overlap > shorter * 0.5;
  }

  /// The character boundary nearest [ex] (em-space) in [run].
  ///
  /// Uses the run's per-character offsets when extraction produced them, so a
  /// proportional font's caret lands on the glyph rather than on an even
  /// division of the run; falls back to a fraction of the advance otherwise.
  static int _offsetInRun(PdfExtractedRun run, double ex) {
    final offsets = run.isRightToLeft ? null : run.charOffsets;
    if (offsets != null) {
      var lo = 0;
      var hi = offsets.length - 1;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (offsets[mid] < ex) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo > 0 && ex - offsets[lo - 1] <= offsets[lo] - ex) lo--;
      return run.startIndex + lo;
    }
    final fraction = run.width > 0 ? (ex / run.width).clamp(0.0, 1.0) : 0.0;
    final logicalFraction = run.isRightToLeft ? 1 - fraction : fraction;
    return run.startIndex + (logicalFraction * run.text.length).round();
  }

  /// The extracted text of this page.
  @override
  String get pageText => _text.text;

  RendererTextSelected _buildEvent(int start, int end, String text) {
    final rects = _readerRectsFor(start, end);
    // Anchor on the largest run so the flash effect lands on real text rather
    // than a sliver.
    final anchor = rects.isEmpty
        ? null
        : rects.reduce(
            (a, b) => b.width * b.height > a.width * a.height ? b : a,
          );

    return RendererTextSelected(
      text: text,
      locator: ReadingLocator.pdf(
        page: pageIndex + 1,
        // The host compares this against the current device-pixel ratio, so it
        // must be the layout scale (CSS px per PDF point) the WebView
        // renderer reported — not the raster density.
        zoom: layoutScale,
        excerpt: text,
        selectionRects: rects,
      ),
      sourceRect: _toGlobalRect(anchor),
      selectionRects: rects,
    );
  }

  /// Normalised page rect -> global logical pixels.
  ///
  /// `RendererTextSelected.sourceRect` and `RendererAnnotationSelected`
  /// `sourceRect` are consumed by the host as window coordinates
  /// (`_toOverlayLocalRect` only subtracts the Overlay origin), so the
  /// renderer has to do the localToGlobal step the WebView renderer does in
  /// `_mapEventToFlutterCoords`.
  ReaderRect? _toGlobalRect(ReaderRect? normalized) {
    if (normalized == null) return null;
    return ReaderRect(
      page: normalized.page,
      x: globalOrigin.dx + normalized.x * displayedSize.width,
      y: globalOrigin.dy + normalized.y * displayedSize.height,
      width: normalized.width * displayedSize.width,
      height: normalized.height * displayedSize.height,
    );
  }

  /// Selection rects in the renderer contract's units.
  ///
  /// [ReaderRect] holds fractions of the page (0..1), not pixels: the WebView
  /// renderer normalised browser client rects against the page box before
  /// emitting them, and annotations persist these values and re-render from
  /// them at whatever size the reader happens to be at. Emitting pixels here
  /// would make every stored annotation scale wrongly.
  ///
  /// The normalised basis is the *displayed* page box, i.e. after /Rotate,
  /// which is what `annotation.locator.selectionRects` is projected onto.
  List<ReaderRect> _readerRectsFor(int start, int end) {
    final out = <ReaderRect>[];
    for (final quad in _text.quadsFor(start, end)) {
      final corners = quad.corners
          .map((c) => _normalisePagePoint(c.$1, c.$2))
          .toList(growable: false);
      if (corners.length < 4) continue;

      var minX = corners.first.dx, maxX = corners.first.dx;
      var minY = corners.first.dy, maxY = corners.first.dy;
      for (final c in corners.skip(1)) {
        minX = math.min(minX, c.dx);
        maxX = math.max(maxX, c.dx);
        minY = math.min(minY, c.dy);
        maxY = math.max(maxY, c.dy);
      }

      final x = minX.clamp(0.0, 1.0);
      final y = minY.clamp(0.0, 1.0);
      final width = (maxX - minX).clamp(0.0, 1.0 - x);
      final height = (maxY - minY).clamp(0.0, 1.0 - y);
      if (width <= 0 || height <= 0) continue;

      out.add(
        ReaderRect(
          page: pageIndex + 1,
          x: x,
          y: y,
          width: width,
          height: height,
        ),
      );
    }
    return out;
  }

  /// PDF page point -> 0..1 fraction of the displayed page box.
  ///
  /// The basis is the *rotated* page size, matching how stored
  /// `selectionRects` are projected back: `x * viewSize.width`, no page-space
  /// detour. Both directions therefore agree on 90°/270° pages too.
  Offset _normalisePagePoint(double x, double y) {
    final view = _unitGeometry.toViewOffset(x, y);
    return Offset(
      (view.dx / math.max(pageSize.width, 1)).clamp(0.0, 1.0),
      (view.dy / math.max(pageSize.height, 1)).clamp(0.0, 1.0),
    );
  }

  /// Normalised selection rects for [start]..[end] on this page.
  ///
  /// Cross-page selections clip their per-page ranges before calling this, so
  /// the same geometry that produces a single-page selection produces each
  /// page's share of a multi-page one.
  @override
  List<ReaderRect> readerRectsFor(int start, int end) =>
      _readerRectsFor(start, end);

  /// Normalised selection rects as widget-local rectangles.
  ///
  /// Selection chrome (drag feedback, touch handles) is painted inside the
  /// page box, so it works in the same view coordinates as pointer input.
  @override
  List<Rect> viewRectsFor(int start, int end) => [
    for (final rect in _readerRectsFor(start, end))
      Rect.fromLTWH(
        rect.x * displayedSize.width,
        rect.y * displayedSize.height,
        rect.width * displayedSize.width,
        rect.height * displayedSize.height,
      ),
  ];

  void invalidate() => _cached = null;
}

/// One run that the pointer is on the baseline band of.
final class _RunHit {
  _RunHit({
    required this.run,
    required this.ex,
    required this.crossPoints,
    required this.band,
  });

  final PdfExtractedRun run;

  /// The point in this run's em space, along its baseline.
  final double ex;

  /// How far outside the band the point was, in page points. Zero when the
  /// point is inside it.
  final double crossPoints;

  /// The band's page-space box, used to unify the runs of one visual line.
  final PdfRect band;

  /// How far along the line the point is from this run's own span, in page
  /// points. Zero inside the run, growing left or right of it.
  ///
  /// Breaks the tie between runs that share a line: without it the first run
  /// encountered would win, so a click between a heading and a right-aligned
  /// page number could resolve to either end of the row.
  double horizontalDistance(double x) {
    if (x < band.left) return band.left - x;
    if (x > band.right) return x - band.right;
    return 0;
  }
}
