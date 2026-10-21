import 'dart:io';
import 'dart:ui';

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

  final rotated = File('poc_pdf_canvas/samples/rotated-text.pdf');

  PdfCanvasRenderer open(File file) =>
      PdfCanvasRenderer(PdfDocument.open(file.readAsBytesSync()));

  test('detects a native text layer', () async {
    expect(await open(standard).hasTextLayerAsync(), isTrue);
  });

  test('reports no text layer for a scanned page', () async {
    expect(await open(imageOnly).hasTextLayerAsync(), isFalse);
  });

  group('off-thread rendering', () {
    test('renders through the worker when it is given the bytes', () async {
      // Reading the bytes is what lets the view hand interpretation to the
      // render isolate; without this path every page walk blocked the UI.
      final bytes = standard.readAsBytesSync();
      final renderer = PdfCanvasRenderer(
        PdfDocument.open(bytes),
        sourceBytes: bytes,
      );
      addTearDown(renderer.dispose);

      final page = await renderer.renderPage(0);

      expect(page, isNotNull);
      expect(page!.displaySize, renderer.displaySizeOf(0));
      expect(page.picture.approximateBytesUsed, greaterThan(0));
      page.dispose();
    });

    test('a cancelled page reports null instead of blocking locally', () async {
      final bytes = standard.readAsBytesSync();
      final renderer = PdfCanvasRenderer(
        PdfDocument.open(bytes),
        sourceBytes: bytes,
      );
      addTearDown(renderer.dispose);

      final pending = renderer.renderPage(1);
      renderer.cancelPage(1);

      expect(await pending, isNull);
    });

    test('exports a page as PNG bytes for OCR', () async {
      final renderer = open(standard);
      addTearDown(renderer.dispose);

      final bytes = await renderer.exportPageImage(0);

      // OCR needs a real bitmap with glyphs in it, not a placeholder: PNG
      // signature, a megapixel-scale image, and far bigger than an empty page
      // would compress to.
      expect(bytes, isNotNull);
      expect(bytes!.take(4), [0x89, 0x50, 0x4E, 0x47]);
      expect(bytes.length, greaterThan(4096));
    });

    test('export is independent of the reader zoom', () async {
      // OCR quality must not drop because the reader happens to be zoomed
      // out; the export resolves its own density from the page size.
      final renderer = open(standard);
      addTearDown(renderer.dispose);

      final first = await renderer.exportPageImage(0);
      final second = await renderer.exportPageImage(0);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.length, second!.length);
    });

    test('exporting an out-of-range page reports null', () async {
      final renderer = open(standard);
      addTearDown(renderer.dispose);

      expect(await renderer.exportPageImage(-1), isNull);
      expect(await renderer.exportPageImage(99), isNull);
    });

    test('falls back to a local render without bytes', () async {
      final renderer = open(standard);
      final page = await renderer.renderPage(0);

      expect(page, isNotNull);
      page!.dispose();
      // No worker was started, so there is nothing to dispose but the doc.
      renderer.dispose();
    });

    test('textOfAsync warms text that the sync path then reuses', () async {
      final bytes = standard.readAsBytesSync();
      final renderer = PdfCanvasRenderer(
        PdfDocument.open(bytes),
        sourceBytes: bytes,
      );
      addTearDown(renderer.dispose);

      final text = await renderer.textOfAsync(0);
      expect(text, isNotNull);
      expect(text!.text.trim(), isNotEmpty);
      expect(renderer.cachedTextOf(0)?.text, text.text);
    });
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
        rotation: renderer.pageAt(0).rotation,
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

  group('rotated page geometry', () {
    late PdfCanvasRenderer renderer;

    setUp(() => renderer = open(rotated));

    PdfSelectionController controller({required Size painted}) {
      final page = renderer.pageAt(0);
      return PdfSelectionController(
        renderer: renderer,
        pageIndex: 0,
        box: page.cropBox,
        rotation: page.rotation,
        paintSize: painted,
        displayedSize: painted,
        globalOrigin: Offset.zero,
        pageSize: renderer.displaySizeOf(0),
      );
    }

    test('the sample really is a 90-degree page', () {
      expect(renderer.pageAt(0).rotation, 90);
      // 612x792 portrait page shown as 792x612 landscape.
      expect(renderer.displaySizeOf(0), const Size(792, 612));
    });

    test('selection projects onto the rotated page, not the crop box', () {
      // Defect 6: layout used the unrotated crop box, so a 90° page was laid
      // out portrait and every overlay was rotated 90° away from the text.
      final painted = renderer.displaySizeOf(0);
      // /Rotate 90 turns the page's top edge into its right edge, so the
      // first line reads top-to-bottom near x ≈ 727 of 792. An unrotated
      // projection would look for it at the top-left and find nothing there.
      final selection = controller(
        painted: painted,
      ).selectionAtWord(const Offset(730, 80));

      expect(selection, isNotNull);
      for (final rect in selection!.selectionRects) {
        expect(rect.x, inInclusiveRange(0, 1));
        expect(rect.y, inInclusiveRange(0, 1));
        expect(rect.x, greaterThan(0.8));
      }
      // The word under the pointer must be the document's first word: if the
      // rotation were applied twice or not at all, positionNear would land
      // somewhere else entirely.
      expect(selection.text.trim(), startsWith('Rotated'));
    });

    test('round-trip through page space is stable on a rotated page', () {
      final painted = renderer.displaySizeOf(0);
      final selection = controller(painted: painted);
      const point = Offset(120, 80);
      final page = selection.toPagePoint(point);
      expect(page, isNotNull);
      final back = selection.toWidgetPoint(page!.x, page.y);
      expect(back.dx, closeTo(point.dx, 0.01));
      expect(back.dy, closeTo(point.dy, 0.01));
    });
  });
}
