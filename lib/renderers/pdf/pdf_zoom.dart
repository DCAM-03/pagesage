import 'dart:math' as math;
import 'dart:ui';

import '../../domain/books/reader_settings.dart';

/// Zoom bounds shared by the renderer, the reader toolbar and the settings
/// sheets.
///
/// The WebView bridge used 0.5–3.0 (`bridge.js` `resolveZoomForPage`); keeping
/// the same range means a scale saved under one renderer opens identically
/// under the other.
const double pdfZoomMin = ReaderSettings.pdfScaleMin;
const double pdfZoomMax = ReaderSettings.pdfScaleMax;

/// A zoom step that lands on round percentages: 0.5 → 3.0 in 25 steps.
const double pdfZoomStep = 0.1;

/// Width below which the bridge treats the viewport as a phone
/// (`bridge.js` `isNarrowViewport`).
const double pdfNarrowViewportWidth = 900;

/// Page margin in logical pixels, mirroring `availablePageBox()`.
///
/// Phones keep a tight margin: the reader chrome already owns the edges, and a
/// 24px margin on a 360px screen wastes a third of the page.
double pdfPageMargin(double configured, {required bool narrow}) {
  if (!narrow) return configured;
  return (configured * 0.4).clamp(8.0, 12.0);
}

/// The mode a page should actually be laid out with.
///
/// The bridge coerced `custom` zoom to fit-width when a document opened on a
/// phone (`bridge.js:2877`): a saved desktop scale such as 1.2 made a 600pt
/// page overflow a 360px screen and look deformed. The coercion only applies
/// until the user zooms in this session; an explicit pinch below 1.25 is
/// still clamped by [resolvePdfZoom]'s own heuristic.
PdfZoomMode effectivePdfZoomMode({
  required PdfZoomMode mode,
  required bool narrow,
  required bool userAdjustedScale,
}) {
  if (narrow && !userAdjustedScale && mode == PdfZoomMode.custom) {
    return PdfZoomMode.fitWidth;
  }
  return mode;
}

/// Where a page lands on screen for a given zoom mode.
final class PdfZoomGeometry {
  const PdfZoomGeometry({
    required this.scale,
    required this.margin,
    required this.mode,
    required this.pageSize,
    required this.viewport,
  });

  /// Logical pixels per PDF point (after /Rotate).
  final double scale;

  /// Margin between the page and the reader chrome, in logical pixels.
  final double margin;

  final PdfZoomMode mode;

  /// Rotation-aware page size in PDF points.
  final Size pageSize;

  /// The box the page is laid out in, in logical pixels.
  final Size viewport;

  Size get contentSize => Size(pageSize.width * scale, pageSize.height * scale);

  /// Empty space on each axis when the page is smaller than the viewport.
  ///
  /// The page is centred inside this slack, and starts at the top-left when
  /// the content overflows.
  Size get slack => Size(
    math.max(0, (viewport.width - contentSize.width) / 2),
    math.max(0, (viewport.height - contentSize.height) / 2),
  );
}

/// Resolves the layout scale for one page.
///
/// This is the single source of truth for zoom on the canvas renderer: the
/// page slot, the raster density and `locator.zoom` all derive from it. The
/// arithmetic mirrors `bridge.js` `resolveZoomForPage`, including the
/// narrow-viewport guard for custom scales, so the two renderers agree.
PdfZoomGeometry resolvePdfZoom({
  required PdfZoomMode mode,
  required double customScale,
  required Size pageSize,
  required Size viewport,
  required bool narrow,
  double pageMargin = 24,
}) {
  final margin = pdfPageMargin(pageMargin, narrow: narrow);
  if (pageSize.width <= 0 || pageSize.height <= 0) {
    return PdfZoomGeometry(
      scale: 1,
      margin: margin,
      mode: mode,
      pageSize: pageSize,
      viewport: viewport,
    );
  }

  // The bridge floors the box so a collapsed window still yields a usable
  // scale instead of a degenerate one.
  final availableWidth = math.max(viewport.width - margin * 2, 120.0);
  final availableHeight = math.max(viewport.height - margin * 2, 180.0);
  final widthScale = availableWidth / pageSize.width;
  final heightScale = availableHeight / pageSize.height;

  var raw = switch (mode) {
    // True 100% overflows a phone; cap it like the bridge does.
    PdfZoomMode.actual => math.min(1.0, widthScale),
    PdfZoomMode.fitWidth => widthScale,
    PdfZoomMode.fitPage => math.min(widthScale, heightScale),
    PdfZoomMode.custom => customScale,
  };

  if (mode == PdfZoomMode.custom &&
      narrow &&
      raw > widthScale + 0.02 &&
      raw <= 1.25 &&
      widthScale < 1.2) {
    // Only the oversized defaults are clamped. A pinch past 1.25 is
    // intentional and is left alone.
    raw = widthScale;
  }

  final scale = raw.clamp(pdfZoomMin, pdfZoomMax).toDouble();
  return PdfZoomGeometry(
    scale: scale,
    margin: margin,
    mode: mode,
    pageSize: pageSize,
    viewport: viewport,
  );
}
