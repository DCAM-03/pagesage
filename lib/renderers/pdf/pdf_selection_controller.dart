import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../domain/books/reading_position.dart';
import '../common/renderer_event.dart';
import 'pdf_canvas_renderer.dart';

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
    required this.paintSize,
    required this.displayedSize,
    required this.globalOrigin,
    required this.pageSize,
  });

  final PdfCanvasRenderer renderer;
  final int pageIndex;
  final PdfRect box;

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
    // Normalise against the painted box, then flip into the PDF's y-up space.
    final u = dx / paintSize.width;
    final v = dy / paintSize.height;
    return (x: box.left + u * box.width, y: box.top - v * box.height);
  }

  /// PDF page coordinates -> widget-local offset.
  Offset toWidgetPoint(double x, double y) => Offset(
    (x - box.left) / box.width * paintSize.width,
    (box.top - y) / box.height * paintSize.height,
  );

  /// Selection covering the drag from [anchorWidget] to [currentWidget].
  ///
  /// Returns null when the drag never crossed text, so the caller can treat it
  /// as a plain tap rather than opening an empty selection menu.
  RendererTextSelected? selectionBetween(
    Offset anchorWidget,
    Offset currentWidget,
  ) {
    final a = toPagePoint(anchorWidget);
    final b = toPagePoint(currentWidget);
    if (a == null || b == null) return null;

    // Select from caret to caret rather than by rectangle containment.
    // Rectangle selection needs a non-zero height (a horizontal drag along one
    // line has none) and, worse, `textIn` + `indexOf` resolves repeated text
    // to its first occurrence. Caret positions have neither problem and give
    // the same multi-line range a browser selection would.
    var start = _text.positionNear(a.x, a.y);
    var end = _text.positionNear(b.x, b.y);
    if (start < 0 || end < 0) return null;
    if (start > end) {
      final swap = start;
      start = end;
      end = swap;
    }
    if (end <= start) {
      // A tap inside a character still means that character; fall back to the
      // word under the pointer, matching `selectionAtWord`.
      return selectionAtWord(anchorWidget);
    }
    final text = _text.text.substring(start, end).trim();
    if (text.isEmpty) return null;
    return _buildEvent(start, end, text);
  }

  /// Word-sized selection at a tap, matching desktop reader behaviour.
  ///
  /// CJK characters count as single-character words so tapping one selects just
  /// that character, matching native CJK input behaviour.
  RendererTextSelected? selectionAtWord(Offset widgetPoint) {
    final page = toPagePoint(widgetPoint);
    if (page == null) return null;
    final index = _text.positionNear(page.x, page.y);
    if (index < 0) return null;

    final range = _wordRangeAt(index);
    if (range == null) return null;
    return _buildEvent(
      range.$1,
      range.$2,
      _text.text.substring(range.$1, range.$2),
    );
  }

  /// (start, end) of the word containing [index].
  ///
  /// CJK characters are words in themselves: Chinese has no spaces, so
  /// expanding over non-separator characters would swallow a whole sentence.
  /// A double-click selects the single character instead, matching native CJK
  /// input behaviour.
  (int, int)? _wordRangeAt(int index) {
    final text = _text.text;
    if (text.isEmpty) return null;
    final i = index.clamp(0, text.length - 1);

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

  static const _asciiSeparators = ' \t\n\r,.!?;:\'"()[]{}<>/\\|@#\$%^&*-_=+';
  static const _cjkPunctuation =
      '、。，．；：？！…—～·「」『』《》【】（）〔〕｛｝'
      '“”‘’　';

  /// CJK punctuation counts as a separator, but CJK ideographs do not: they are
  /// handled by [_wordRangeAt] as single-character words.
  bool _isSeparator(int codeUnit) {
    if (_cjkPunctuation.contains(String.fromCharCode(codeUnit))) return true;
    return _asciiSeparators.contains(String.fromCharCode(codeUnit));
  }

  static bool _isCjk(int codeUnit) =>
      (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) || // unified ideographs
      (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) || // extension A
      (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) || // compatibility
      (codeUnit >= 0x3040 && codeUnit <= 0x30FF) || // kana
      (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF); // hangul

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

  /// PDF page point -> 0..1 fraction of the page box.
  ///
  /// Rotation stays out of scope until S1 centralises geometry on
  /// [PdfPageGeometry]; see `docs/11-pdf-canvas-implementation-plan.md` §S0.
  Offset _normalisePagePoint(double x, double y) => Offset(
    ((x - box.left) / box.width).clamp(0.0, 1.0),
    ((box.top - y) / box.height).clamp(0.0, 1.0),
  );

  /// Highlight rectangles for a text range, in widget coordinates.
  List<Rect> highlightsFor(int start, int end) => [
    for (final quad in _text.quadsFor(start, end))
      _boundsOf(quad.corners.map((c) => toWidgetPoint(c.$1, c.$2)).toList()),
  ];

  Rect _boundsOf(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void invalidate() => _cached = null;
}
