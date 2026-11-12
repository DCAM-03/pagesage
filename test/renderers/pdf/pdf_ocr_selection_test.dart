import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/renderers/pdf/pdf_ocr_selection_controller.dart';
import 'package:pagesage/renderers/pdf/pdf_selection.dart';

/// OCR selection is geometric, so these tests use a 1000x1000 displayed page:
/// a block at 0.1/0.1/0.4/0.04 is exactly x 100..500, y 100..140.
void main() {
  const blocks = [
    OcrTextBlock(
      text: 'Hello world',
      left: 0.1,
      top: 0.1,
      width: 0.4,
      height: 0.04,
    ),
    OcrTextBlock(text: '第二行文字', left: 0.1, top: 0.2, width: 0.4, height: 0.04),
    OcrTextBlock(
      text: 'Third line here',
      left: 0.1,
      top: 0.3,
      width: 0.4,
      height: 0.04,
    ),
  ];

  PdfOcrSelectionController controller({
    List<OcrTextBlock> source = blocks,
    int pageIndex = 0,
  }) {
    return PdfOcrSelectionController(
      pageIndex: pageIndex,
      layout: PdfOcrTextLayout.fromBlocks(source),
      displayedSize: const Size(1000, 1000),
      layoutScale: 2,
    );
  }

  group('overlay parsing', () {
    test('keeps valid blocks and clamps them into the page', () {
      final parsed = parseOcrOverlayBlocks([
        {
          'text': '  hello  ',
          'left': '0.9',
          'top': 0.8,
          'width': 0.3,
          'height': 0.4,
        },
        {'text': 'no geometry'},
        {
          'text': 'zero width',
          'left': 0.1,
          'top': 0.1,
          'width': 0,
          'height': 0.1,
        },
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single.text, 'hello');
      expect(parsed.single.left, 0.9);
      expect(parsed.single.top, 0.8);
      expect(parsed.single.width, closeTo(0.1, 0.0001));
      expect(parsed.single.height, closeTo(0.2, 0.0001));
    });

    test('drops non-finite coordinates', () {
      final parsed = parseOcrOverlayBlocks([
        {
          'text': 'nan',
          'left': double.nan,
          'top': 0.1,
          'width': 0.2,
          'height': 0.1,
        },
      ]);

      expect(parsed, isEmpty);
    });
  });

  group('layout', () {
    test('joins lines with one separator and keeps block order', () {
      final layout = PdfOcrTextLayout.fromBlocks(blocks);

      expect(layout.text, 'Hello world\n第二行文字\nThird line here');
      expect(layout.isEmpty, isFalse);
    });

    test('geometry-less blocks do not contribute text', () {
      final layout = PdfOcrTextLayout.fromBlocks(const [
        OcrTextBlock(text: 'invisible'),
        OcrTextBlock(
          text: 'visible',
          left: 0.1,
          top: 0.1,
          width: 0.2,
          height: 0.1,
        ),
      ]);

      expect(layout.text, 'visible');
    });
  });

  group('caret mapping', () {
    test('a tap inside a line resolves to a word on that line', () {
      final source = controller();
      final caret = source.caretAt(const Offset(190, 120));

      expect(caret, isNotNull);
      expect(caret!.page, 0);
      final range = pdfWordRangeAt(source.pageText, caret.index);
      expect(range, isNotNull);
      expect(source.pageText.substring(range!.$1, range.$2), 'Hello');
    });

    test('a CJK tap resolves to one character', () {
      final source = controller();
      final caret = source.caretAt(const Offset(220, 220));

      expect(caret, isNotNull);
      final range = pdfWordRangeAt(source.pageText, caret!.index);
      expect(range, isNotNull);
      expect(range!.$2 - range.$1, 1);
      expect('第二行文字', contains(source.pageText.substring(range.$1, range.$2)));
    });

    test('a tap on blank paper selects nothing', () {
      expect(
        controller().caretAt(const Offset(900, 900), snapToNearest: false),
        isNull,
      );
    });

    test('a drag on blank paper snaps to the nearest line', () {
      final source = controller();
      final caret = source.caretAt(const Offset(900, 900));

      expect(caret, isNotNull);
      expect(
        caret!.index,
        greaterThanOrEqualTo(source.pageText.indexOf('Third')),
      );
    });

    test('a drag past a line end lands on its last character boundary', () {
      final source = controller();
      final end = source.caretAt(const Offset(900, 320));

      expect(end, isNotNull);
      expect(end!.index, source.pageText.length);
    });

    test('a point far outside the page is not a drag point', () {
      expect(controller().caretAt(const Offset(-100, 120)), isNull);
    });
  });

  group('selection rectangles', () {
    test('a cross-line selection paints one band per line', () {
      final source = controller(pageIndex: 1);
      final rects = source.readerRectsFor(2, source.pageText.length - 2);

      expect(rects, hasLength(3));
      expect(rects.first.page, 2);
      for (final rect in rects) {
        expect(rect.x, inInclusiveRange(0, 1));
        expect(rect.y, inInclusiveRange(0, 1));
        expect(rect.width, inInclusiveRange(0, 1));
        expect(rect.height, closeTo(0.04, 0.0001));
      }
      // The first line starts at character 2, so its band starts inside the
      // block rather than at the block's left edge.
      expect(rects.first.x, greaterThan(0.1));
      // Interior line is selected in full.
      expect(rects[1].x, closeTo(0.1, 0.0001));
      expect(rects[1].width, closeTo(0.4, 0.0001));
    });

    test('view rects use the displayed page size', () {
      final source = controller();
      final rects = source.viewRectsFor(0, 11);

      expect(rects, hasLength(1));
      expect(rects.single.left, closeTo(100, 0.001));
      expect(rects.single.top, closeTo(100, 0.001));
      expect(rects.single.width, closeTo(400, 0.001));
      expect(rects.single.height, closeTo(40, 0.001));
    });

    test('a collapsed or out-of-range selection paints nothing', () {
      final source = controller();

      expect(source.readerRectsFor(4, 4), isEmpty);
      expect(source.readerRectsFor(999, 1000), isEmpty);
    });
  });
}
