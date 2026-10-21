import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/pdf/pdf_annotation_lines.dart';

/// F-02: a stored highlight must not paint into the line below it.
///
/// The rectangles are written at one zoom and repainted at another, so the
/// painter cannot trust their height; it snaps them onto the page's text lines
/// at paint time. These tests pin that pipeline against the cases that used to
/// show up as a slab: a legacy multi-line box, a box that drifted off its
/// line, and two lines that touch.
void main() {
  const noBands = <PdfLineBand>[];

  PdfLineRect rect({
    double x = 0.1,
    required double y,
    double width = 0.4,
    required double height,
    int page = 1,
  }) => PdfLineRect(page: page, x: x, y: y, width: width, height: height);

  List<PdfLineBand> Function(int) bands(List<PdfLineBand> list) =>
      (page) => list;

  group('prepareAnnotationRects', () {
    test('a box spanning two lines yields one strip per line', () {
      // Dense text: two lines 0.02 tall. The box stays under the legacy
      // mega-box threshold, so the band snap sees it whole.
      final result = prepareAnnotationRects(
        [rect(y: 0.20, height: 0.044)],
        lineBands: bands(const [
          PdfLineBand(top: 0.200, bottom: 0.220),
          PdfLineBand(top: 0.224, bottom: 0.244),
        ]),
      );

      // Covered lines are kept, not collapsed to the one nearest the centre:
      // the reader marked both.
      expect(result, hasLength(2));
      expect(result.first.y, closeTo(0.200, 0.001));
      expect(result.last.y, closeTo(0.224, 0.001));
      // Every strip ends before the next line starts.
      expect(result.first.bottom, lessThanOrEqualTo(result.last.y));
    });

    test('a mega-box collapses instead of splitting', () {
      // Stored legacy data sometimes holds one rectangle over half a page.
      // Splitting that would paint a dozen strips from a single bad row, so
      // it collapses to one readable band.
      final result = prepareAnnotationRects(
        [rect(y: 0.20, height: 0.30)],
        lineBands: bands(const [
          PdfLineBand(top: 0.20, bottom: 0.24),
          PdfLineBand(top: 0.25, bottom: 0.29),
          PdfLineBand(top: 0.30, bottom: 0.34),
        ]),
      );

      expect(result, hasLength(1));
      expect(result.single.height, lessThanOrEqualTo(0.022));
    });

    test('a tall box is capped when there is no line reference', () {
      // No line reference at all — the fallback cap is the only protection.
      final result = prepareAnnotationRects([
        rect(y: 0.4, height: 0.2),
      ], lineBands: bands(noBands));

      expect(result, hasLength(1));
      expect(result.single.height, lessThanOrEqualTo(0.016));
    });

    test('a box taller than its line snaps onto the line', () {
      final result = prepareAnnotationRects(
        // Taller than the line band, a common artefact of re-laying out at a
        // different size: it is taken to be that whole line.
        [rect(y: 0.25, height: 0.05)],
        lineBands: bands(const [PdfLineBand(top: 0.25, bottom: 0.29)]),
      );

      expect(result.single.y, closeTo(0.25, 0.001));
      expect(result.single.bottom, lessThanOrEqualTo(0.29));
    });

    test('a box that drifted above its line is pulled down', () {
      final result = prepareAnnotationRects([
        rect(y: 0.24, height: 0.015),
      ], lineBands: bands(const [PdfLineBand(top: 0.25, bottom: 0.29)]));

      // Starting above the band means the whole line is the best reading.
      expect(result.single.y, closeTo(0.25, 0.001));
    });

    test('a box shorter than its line keeps its own height', () {
      final result = prepareAnnotationRects([
        rect(y: 0.26, height: 0.01),
      ], lineBands: bands(const [PdfLineBand(top: 0.25, bottom: 0.29)]));

      expect(result.single.y, closeTo(0.26, 0.001));
      expect(result.single.height, closeTo(0.01, 0.001));
    });

    test('a strip never reaches past 78% of the line pitch', () {
      // A dense page: lines 0.02 apart, so a strip may be at most 0.0156 tall.
      final result = prepareAnnotationRects(
        [rect(y: 0.10, height: 0.02)],
        lineBands: bands(const [
          PdfLineBand(top: 0.10, bottom: 0.12),
          PdfLineBand(top: 0.12, bottom: 0.14),
        ]),
      );

      for (final band in result) {
        expect(band.height, lessThan(0.02));
      }
    });

    test('two touching lines are trimmed at the seam', () {
      final result = prepareAnnotationRects([
        rect(y: 0.10, height: 0.05),
        rect(y: 0.15, height: 0.05),
      ], lineBands: bands(noBands));

      for (var i = 0; i < result.length - 1; i += 1) {
        if (result[i].page != result[i + 1].page) continue;
        expect(result[i].bottom, lessThanOrEqualTo(result[i + 1].y));
      }
    });

    test('a full-width box is dropped', () {
      // Width > 0.98 is a page-wide artefact, not a text band.
      expect(
        prepareAnnotationRects([
          rect(y: 0.1, width: 0.99, height: 0.02),
        ], lineBands: bands(noBands)),
        isEmpty,
      );
    });

    test('an empty list stays empty', () {
      expect(
        prepareAnnotationRects(const [], lineBands: bands(noBands)),
        isEmpty,
      );
    });
  });

  group('mergeSameLineRects', () {
    test('word boxes on one line merge into one band', () {
      // Words of a single line arrive out of x order and interleaved with the
      // next line; merging by x order would leave two boxes on one line.
      final result = mergeSameLineRects([
        rect(x: 0.40, y: 0.10, width: 0.10, height: 0.02),
        rect(x: 0.10, y: 0.10, width: 0.10, height: 0.02),
        rect(x: 0.25, y: 0.10, width: 0.10, height: 0.02),
      ]);

      expect(result, hasLength(1));
      expect(result.single.x, closeTo(0.10, 0.001));
      expect(result.single.width, closeTo(0.40, 0.001));
    });

    test('separate lines stay separate', () {
      final result = mergeSameLineRects([
        rect(y: 0.10, height: 0.02),
        rect(y: 0.15, height: 0.02),
      ]);
      expect(result, hasLength(2));
    });

    test('pages are never merged together', () {
      final result = mergeSameLineRects([
        rect(y: 0.10, height: 0.02, page: 1),
        rect(y: 0.10, height: 0.02, page: 2),
      ]);
      expect(result.map((r) => r.page), [1, 2]);
    });

    test('a single inflated box does not inflate the merged band', () {
      // Median height, not the maximum: legacy boxes sometimes carry a height
      // several times the real line.
      final result = mergeSameLineRects([
        rect(x: 0.10, y: 0.10, width: 0.05, height: 0.02),
        rect(x: 0.16, y: 0.10, width: 0.05, height: 0.09),
        rect(x: 0.22, y: 0.10, width: 0.05, height: 0.02),
      ]);
      expect(result.single.height, closeTo(0.02, 0.001));
    });
  });

  group('lineBandsForPage', () {
    test('spans sharing a line become one band', () {
      final bands = lineBandsForPage([
        (top: 0.10, bottom: 0.13),
        (top: 0.105, bottom: 0.135),
        (top: 0.20, bottom: 0.23),
      ]);
      expect(bands, hasLength(2));
      expect(bands.first.top, 0.10);
    });

    test('boxes outside the page are ignored', () {
      expect(
        lineBandsForPage([(top: -0.5, bottom: 0.1), (top: 0.99, bottom: 1.5)]),
        isEmpty,
      );
    });

    test('an empty page has no bands', () {
      expect(lineBandsForPage(const []), isEmpty);
    });
  });
}
