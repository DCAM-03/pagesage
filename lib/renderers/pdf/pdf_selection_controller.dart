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
final class PdfSelectionController {
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

  /// PDF page coordinates -> widget-local offset.
  Offset toWidgetPoint(double x, double y) => _geometry.toViewOffset(x, y);

  /// Word-sized selection at a tap, matching desktop reader behaviour.
  ///
  /// CJK characters count as single-character words so tapping one selects just
  /// that character, matching native CJK input behaviour.
  RendererTextSelected? selectionAtWord(Offset widgetPoint) {
    final page = toPagePoint(widgetPoint);
    if (page == null) return null;
    final index = _text.positionNear(page.x, page.y);
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
  PdfCaret? caretAt(Offset widgetPoint) {
    final page = toPagePoint(widgetPoint);
    if (page == null) return null;
    final index = _text.positionNear(page.x, page.y);
    if (index < 0) return null;
    return (page: pageIndex, index: index);
  }

  /// The length of this page's extracted text, for cross-page segment maths.
  int get textLength => _text.text.length;

  /// The extracted text of this page.
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
  List<ReaderRect> readerRectsFor(int start, int end) =>
      _readerRectsFor(start, end);

  /// Normalised selection rects as widget-local rectangles.
  ///
  /// Selection chrome (drag feedback, touch handles) is painted inside the
  /// page box, so it works in the same view coordinates as pointer input.
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
