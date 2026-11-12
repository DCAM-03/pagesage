import 'dart:math' as math;
import 'dart:ui';

import '../../domain/books/reading_position.dart';
import '../../domain/ocr/ocr_models.dart';
import 'pdf_selection.dart';

/// Parses the renderer-facing OCR overlay blocks into typed text blocks.
///
/// Overlay JSON is intentionally permissive because it can come from a stored
/// result written by an older build. Invalid or geometry-less blocks are
/// dropped here rather than becoming phantom selection targets.
List<OcrTextBlock> parseOcrOverlayBlocks(Iterable<Map<String, Object?>> raw) {
  final blocks = <OcrTextBlock>[];
  for (final item in raw) {
    final text = item['text'];
    if (text is! String || text.trim().isEmpty) continue;
    final left = _number(item['left']);
    final top = _number(item['top']);
    final width = _number(item['width']);
    final height = _number(item['height']);
    if (left == null || top == null || width == null || height == null) {
      continue;
    }
    if (!left.isFinite ||
        !top.isFinite ||
        !width.isFinite ||
        !height.isFinite) {
      continue;
    }
    final x = left.clamp(0.0, 1.0).toDouble();
    final y = top.clamp(0.0, 1.0).toDouble();
    final right = (left + width).clamp(0.0, 1.0).toDouble();
    final bottom = (top + height).clamp(0.0, 1.0).toDouble();
    if (right <= x || bottom <= y) continue;
    blocks.add(
      OcrTextBlock(
        text: text.trim(),
        left: x,
        top: y,
        width: right - x,
        height: bottom - y,
      ),
    );
  }
  return List.unmodifiable(blocks);
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

/// A recognised page's text, ordered into lines with 0..1 geometry.
///
/// Parsing this once per overlay keeps a drag from rebuilding the page text on
/// every pointer move. [text] joins lines with newlines so a selection can
/// cross them while `pdfSelectionText` still collapses the excerpt to one line.
final class PdfOcrTextLayout {
  PdfOcrTextLayout._(this._lines, this.text);

  factory PdfOcrTextLayout.fromBlocks(Iterable<OcrTextBlock> blocks) {
    final lines = <_OcrLine>[];
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (!block.hasGeometry) continue;
      final text = block.text.trim();
      if (text.isEmpty) continue;
      final left = block.left!;
      final top = block.top!;
      final width = block.width!;
      final height = block.height!;
      if (!left.isFinite ||
          !top.isFinite ||
          !width.isFinite ||
          !height.isFinite) {
        continue;
      }
      final x = left.clamp(0.0, 1.0).toDouble();
      final y = top.clamp(0.0, 1.0).toDouble();
      final right = (left + width).clamp(0.0, 1.0).toDouble();
      final bottom = (top + height).clamp(0.0, 1.0).toDouble();
      if (right <= x || bottom <= y) continue;
      if (buffer.isNotEmpty) buffer.write('\n');
      final start = buffer.length;
      buffer.write(text);
      lines.add(
        _OcrLine(
          text: text,
          start: start,
          end: buffer.length,
          left: x,
          top: y,
          width: right - x,
          height: bottom - y,
        ),
      );
    }
    return PdfOcrTextLayout._(List.unmodifiable(lines), buffer.toString());
  }

  final List<_OcrLine> _lines;

  /// Page text in caret-index order, with newlines between OCR lines.
  final String text;

  bool get isEmpty => _lines.isEmpty;
}

/// Maps pointer gestures onto OCR line boxes on the displayed page.
///
/// OCR blocks are already normalised against the page the reader sees, so
/// unlike [PdfSelectionController] this controller must not project them
/// through `PdfPageGeometry`: a rotated page would otherwise be rotated twice.
final class PdfOcrSelectionController implements PdfTextSelectionSource {
  PdfOcrSelectionController({
    required this.pageIndex,
    required this.layout,
    required this.displayedSize,
    required this.layoutScale,
  });

  @override
  final int pageIndex;
  final PdfOcrTextLayout layout;

  /// Painted page size in logical pixels.
  final Size displayedSize;

  /// Logical pixels per PDF point at the current layout.
  ///
  /// Tap tolerances are physical distances a reader aims with, so they scale
  /// with the page: 4pt at 1x is 12px at 3x, the same as native text.
  final double layoutScale;

  double get _scale => layoutScale > 0 ? layoutScale : 1;

  /// How far outside the page a drag may stray.
  double get _dragOvershoot => 24.0 * _scale;

  /// How far above or below a line a tap may land, matching native text.
  double get _tapLineSlop => 4.0 * _scale;

  /// How far past a line's ends a tap may land, matching native text.
  double get _tapAlongSlop => 6.0 * _scale;

  @override
  String get pageText => layout.text;

  @override
  PdfCaret? caretAt(Offset widgetPoint, {bool snapToNearest = true}) {
    if (layout.isEmpty ||
        displayedSize.width <= 0 ||
        displayedSize.height <= 0) {
      return null;
    }
    final overshoot = snapToNearest ? _dragOvershoot : 0.0;
    if (widgetPoint.dx < -overshoot ||
        widgetPoint.dy < -overshoot ||
        widgetPoint.dx > displayedSize.width + overshoot ||
        widgetPoint.dy > displayedSize.height + overshoot) {
      return null;
    }
    final point = Offset(
      widgetPoint.dx.clamp(0.0, displayedSize.width),
      widgetPoint.dy.clamp(0.0, displayedSize.height),
    );
    final line = _lineNear(point, strict: !snapToNearest);
    if (line == null) return null;
    return (
      page: pageIndex,
      index: _indexInLine(line, point.dx, tap: !snapToNearest),
    );
  }

  _OcrLine? _lineNear(Offset point, {required bool strict}) {
    _OcrLine? best;
    var bestDistance = double.infinity;
    for (final line in layout._lines) {
      final rect = line.rect(displayedSize);
      final dx = point.dx < rect.left
          ? rect.left - point.dx
          : point.dx > rect.right
          ? point.dx - rect.right
          : 0.0;
      final dy = point.dy < rect.top
          ? rect.top - point.dy
          : point.dy > rect.bottom
          ? point.dy - rect.bottom
          : 0.0;
      if (strict && (dx > _tapAlongSlop || dy > _tapLineSlop)) continue;
      final distance = dx * dx + dy * dy;
      if (distance >= bestDistance) continue;
      bestDistance = distance;
      best = line;
    }
    return best;
  }

  int _indexInLine(_OcrLine line, double x, {required bool tap}) {
    final rect = line.rect(displayedSize);
    final fraction = rect.width <= 0 ? 0.0 : (x - rect.left) / rect.width;
    final clamped = fraction.clamp(0.0, 1.0);
    final length = line.text.length;
    if (length == 0) return line.start;
    if (tap) {
      final local = math.min(
        length - 1,
        math.max(0, (clamped * length).floor()),
      );
      return line.start + local;
    }
    final local = math.min(length, math.max(0, (clamped * length).round()));
    return line.start + local;
  }

  @override
  List<Rect> viewRectsFor(int start, int end) {
    final width = displayedSize.width;
    final height = displayedSize.height;
    if (width <= 0 || height <= 0) return const [];
    return [
      for (final rect in readerRectsFor(start, end))
        Rect.fromLTWH(
          rect.x * width,
          rect.y * height,
          rect.width * width,
          rect.height * height,
        ),
    ];
  }

  @override
  List<ReaderRect> readerRectsFor(int start, int end) {
    final from = start.clamp(0, pageText.length);
    final to = end.clamp(0, pageText.length);
    if (to <= from) return const [];
    final rects = <ReaderRect>[];
    for (final line in layout._lines) {
      final localStart = math.max(from, line.start);
      final localEnd = math.min(to, line.end);
      if (localEnd <= localStart) continue;
      final length = line.text.length;
      if (length <= 0) continue;
      final left =
          line.left + line.width * ((localStart - line.start) / length);
      final right = line.left + line.width * ((localEnd - line.start) / length);
      if (right <= left) continue;
      rects.add(
        ReaderRect(
          page: pageIndex + 1,
          x: left,
          y: line.top,
          width: right - left,
          height: line.height,
        ),
      );
    }
    return rects;
  }
}

final class _OcrLine {
  const _OcrLine({
    required this.text,
    required this.start,
    required this.end,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final int start;
  final int end;
  final double left;
  final double top;
  final double width;
  final double height;

  Rect rect(Size displayedSize) => Rect.fromLTWH(
    left * displayedSize.width,
    top * displayedSize.height,
    width * displayedSize.width,
    height * displayedSize.height,
  );
}
