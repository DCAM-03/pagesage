import 'dart:io';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_renderer.dart';
import 'package:pagesage/renderers/pdf/pdf_selection_controller.dart';

/// Contract tests for the canvas renderer's S0 fixes.
///
/// These pin the three things the host depends on and that used to be wrong:
/// text-layer detection, the units of `locator.zoom`, and the coordinate
/// space of `sourceRect`. Geometry here is page-sized 1:1, so any offset the
/// controller introduces is visible as a plain number.
void main() {
  final standard = File('poc_pdf_canvas/samples/standard-text.pdf');
  final imageOnly = File('poc_pdf_canvas/samples/image-only.pdf');
  final broken = File('poc_pdf_canvas/samples/broken.pdf');

  PdfCanvasRenderer open(File file) =>
      PdfCanvasRenderer(PdfDocument.open(file.readAsBytesSync()));

  test('detects a native text layer', () async {
    expect(await open(standard).hasTextLayerAsync(), isTrue);
  });

  test('reports no text layer for a scanned page', () async {
    expect(await open(imageOnly).hasTextLayerAsync(), isFalse);
  });

  test('surfaces a parse failure as CosParseException', () {
    expect(
      () => PdfDocument.open(broken.readAsBytesSync()),
      throwsA(isA<CosParseException>()),
    );
  });

  group('selection contract', () {
    late PdfCanvasRenderer renderer;

    setUp(() => renderer = open(standard));

    PdfSelectionController controller({
      required double scale,
      Offset origin = Offset.zero,
    }) {
      final pageSize = renderer.displaySizeOf(0);
      return PdfSelectionController(
        renderer: renderer,
        pageIndex: 0,
        box: renderer.pageAt(0).cropBox,
        // 1:1 layout: the canvas is exactly the page's point size.
        paintSize: pageSize * scale,
        displayedSize: pageSize * scale,
        globalOrigin: origin,
        pageSize: pageSize,
      );
    }

    test('sourceRect is in global pixels, not 0..1', () {
      const origin = Offset(120, 64);
      final selection = controller(
        scale: 1,
        origin: origin,
      ).selectionAtWord(const Offset(80, 68));

      expect(selection, isNotNull);
      final rect = selection!.sourceRect!;
      // Word at (72, 730) on a 612x792 page: x lands right of the origin and
      // y below it, with pixel-sized width rather than a 0..1 fraction.
      expect(rect.x, greaterThan(origin.dx));
      expect(rect.y, greaterThan(origin.dy));
      expect(rect.width, greaterThan(1));
      expect(rect.height, greaterThan(1));
      // Page 1's first line starts at x=72, so the anchor sits near it.
      expect(rect.x - origin.dx, closeTo(72, 4));
    });

    test('locator.zoom carries the layout scale', () {
      final selection = controller(
        scale: 1.5,
      ).selectionAtWord(const Offset(80 * 1.5, 68 * 1.5));

      expect(selection, isNotNull);
      expect(selection!.locator.zoom, closeTo(1.5, 0.001));
    });

    test('selection rects stay normalised for annotation storage', () {
      final selection = controller(
        scale: 2,
      ).selectionAtWord(const Offset(80 * 2, 68 * 2));

      expect(selection, isNotNull);
      for (final rect in selection!.selectionRects) {
        expect(rect.x, inInclusiveRange(0, 1));
        expect(rect.y, inInclusiveRange(0, 1));
        expect(rect.width, inInclusiveRange(0, 1));
        expect(rect.height, inInclusiveRange(0, 1));
      }
    });
  });
}
