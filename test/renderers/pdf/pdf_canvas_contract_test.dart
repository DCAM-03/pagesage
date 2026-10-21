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

  group('hit testing', () {
    late PdfCanvasRenderer renderer;

    setUp(() => renderer = open(standard));

    /// 1:1 controller, so widget y = 792 - page y and every expectation below
    /// can be read straight off the sample's run boxes.
    PdfSelectionController controller({int pageIndex = 0}) {
      final pageSize = renderer.displaySizeOf(pageIndex);
      return PdfSelectionController(
        renderer: renderer,
        pageIndex: pageIndex,
        box: renderer.pageAt(pageIndex).cropBox,
        rotation: renderer.pageAt(pageIndex).rotation,
        paintSize: pageSize,
        displayedSize: pageSize,
        globalOrigin: Offset.zero,
        pageSize: pageSize,
      );
    }

    // standard-text.pdf page 1 draws two lines at 10.2pt pitch:
    //   line 1  page y 726.75..739.75  widget y 52.25..65.25
    //   line 2  page y 698.75..711.75  widget y 80.25..93.25
    // so widget y 68 is the leading between them, and y > 96 is blank paper.
    const line1 = 59.0;
    const line2 = 87.0;
    const leading = 68.0;

    test('a tap on a line selects a word from that line', () {
      // The defect this guards: `positionNear` scored by distance to a run's
      // bounding box, so a tap on the second line could resolve into the
      // first. 匿名样本 01, 匿名样本 03 and 匿名样本 02 each lost 60-72%
      // of a grid of points this way, by up to 412pt.
      final first = controller().selectionAtWord(const Offset(80, line1));
      final second = controller().selectionAtWord(const Offset(80, line2));

      expect(first?.text, startsWith('PageSage'));
      expect(second?.text, startsWith('Generated'));
    });

    test('a tap in the leading goes to the nearer line', () {
      final between = controller().selectionAtWord(const Offset(80, leading));

      expect(between, isNotNull);
      // 2.75pt below line 1's band, 12.25pt above line 2's.
      expect(between!.text, startsWith('PageSage'));
    });

    test('a tap on blank paper below the text selects nothing', () {
      // A tap identifies a word, so it must not guess one from halfway up the
      // page: only a drag gets the nearest-line fallback.
      expect(controller().selectionAtWord(const Offset(80, 400)), isNull);
    });

    test('a drag below the last line snaps to it instead of stopping', () {
      final caret = controller().caretAt(const Offset(80, 400));

      expect(caret, isNotNull);
      expect(caret!.index, greaterThan(60));
    });

    test('a drag past the end of a line lands on its last character', () {
      final inside = controller().caretAt(const Offset(400, line1));
      final past = controller().caretAt(const Offset(610, line1));

      expect(inside, isNotNull);
      expect(past, isNotNull);
      expect(past!.index, greaterThan(inside!.index));
      expect(past.index, lessThanOrEqualTo(controller().pageText.length));
    });

    test('a point outside the page is not a drag point', () {
      // The view clamps a pointer just off the page edge onto it; the
      // controller only accepts the overshoot band the view already applied.
      expect(controller().caretAt(const Offset(-200, line1)), isNull);
    });

    test('the caret follows the page it is given, not page 1', () {
      // Both pages of this sample draw the same words at the same place, so
      // only the caret's page field can tell them apart — but a controller
      // built for page 2 must still resolve text rather than borrow page 1's.
      final second = controller(pageIndex: 1).caretAt(const Offset(80, line1));
      expect(second, isNotNull);
      expect(second!.page, 1);
    });

    test('a tap on whitespace inside a long run selects nothing', () {
      // The chinese-embedded sample has a heading run far wider than its
      // glyphs' band; the point below it is blank paper and must stay blank.
      final cjk = open(File('poc_pdf_canvas/samples/chinese-embedded.pdf'));
      addTearDown(cjk.dispose);
      final pageSize = cjk.displaySizeOf(0);
      final text = PdfSelectionController(
        renderer: cjk,
        pageIndex: 0,
        box: cjk.pageAt(0).cropBox,
        rotation: cjk.pageAt(0).rotation,
        paintSize: pageSize,
        displayedSize: pageSize,
        globalOrigin: Offset.zero,
        pageSize: pageSize,
      );
      // Below the last line (page y 533 -> widget y 259) on a 842pt page.
      expect(text.selectionAtWord(Offset(200, pageSize.height - 20)), isNull);
    });

    test('a tap on a line of several runs picks the run it is on', () {
      // "本页使用真正嵌入的 CJK 字体，验证 pdf_graphics 的字形轮廓渲染路径。"
      // is five runs on one line, so every one of them ties at zero vertical
      // distance — and the first four are far apart horizontally. Ranking by
      // vertical distance alone let the *first* run win, putting the caret at
      // the far end of the line; the tie now breaks on the pointer's
      // horizontal distance within the run.
      final cjk = open(File('poc_pdf_canvas/samples/chinese-embedded.pdf'));
      addTearDown(cjk.dispose);
      final pageSize = cjk.displaySizeOf(0);
      final text = PdfSelectionController(
        renderer: cjk,
        pageIndex: 0,
        box: cjk.pageAt(0).cropBox,
        rotation: cjk.pageAt(0).rotation,
        paintSize: pageSize,
        displayedSize: pageSize,
        globalOrigin: Offset.zero,
        pageSize: pageSize,
      );
      // "CJK" is the second of the line's five runs, spanning x 181..202 in
      // page space; the line's band covers page y 725.8..743.3.
      final tap = Offset(192, pageSize.height - (725.8 + 743.3) / 2);

      final selection = text.selectionAtWord(tap);
      expect(selection, isNotNull);
      expect(selection!.text, 'CJK');
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
