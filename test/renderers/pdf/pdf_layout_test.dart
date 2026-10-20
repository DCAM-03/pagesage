import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/pdf/pdf_layout.dart';

/// S2 keeps layout arithmetic out of the widget so it can be pinned here: a
/// page-top or scroll-anchor mistake shows up as "reopens on the wrong page",
/// which is exactly what the milestone's acceptance test measures.
void main() {
  group('preferredPdfDisplayMode', () {
    test('continuous stays continuous on every width', () {
      expect(
        preferredPdfDisplayMode(
          readerMode: ReaderMode.continuous,
          narrow: false,
        ),
        PdfDisplayMode.continuous,
      );
      expect(
        preferredPdfDisplayMode(
          readerMode: ReaderMode.continuous,
          narrow: true,
        ),
        PdfDisplayMode.continuous,
      );
    });

    test('paged becomes a spread on desktop', () {
      expect(
        preferredPdfDisplayMode(readerMode: ReaderMode.paged, narrow: false),
        PdfDisplayMode.double,
      );
    });

    test('paged never becomes a spread on a phone', () {
      expect(
        preferredPdfDisplayMode(readerMode: ReaderMode.paged, narrow: true),
        PdfDisplayMode.single,
      );
    });
  });

  group('spreads', () {
    test('the cover is alone, then pairs line up as 2-3, 4-5', () {
      ({int start, int end}) spread(int page) => pdfSpreadFor(
        pageIndex: page,
        pageCount: 10,
        mode: PdfDisplayMode.double,
      );

      expect(spread(0), (start: 0, end: 0));
      expect(spread(1), (start: 1, end: 2));
      expect(spread(2), (start: 1, end: 2));
      expect(spread(3), (start: 3, end: 4));
      expect(spread(4), (start: 3, end: 4));
    });

    test('a trailing page without a partner is alone', () {
      // Ten pages: 0 | 1-2 | 3-4 | 5-6 | 7-8 | 9
      expect(
        pdfSpreadFor(pageIndex: 8, pageCount: 10, mode: PdfDisplayMode.double),
        (start: 7, end: 8),
      );
      expect(
        pdfSpreadFor(pageIndex: 9, pageCount: 10, mode: PdfDisplayMode.double),
        (start: 9, end: 9),
      );
    });

    test('single and continuous report the page itself', () {
      for (final mode in [PdfDisplayMode.single, PdfDisplayMode.continuous]) {
        expect(pdfSpreadFor(pageIndex: 3, pageCount: 10, mode: mode), (
          start: 3,
          end: 3,
        ));
      }
    });

    test('a one-page document has a one-page spread', () {
      expect(
        pdfSpreadFor(pageIndex: 0, pageCount: 1, mode: PdfDisplayMode.double),
        (start: 0, end: 0),
      );
    });

    test('spread start snaps the right-hand page back to the pair', () {
      expect(pdfSpreadStart(pageIndex: 0, pageCount: 10), 0);
      expect(pdfSpreadStart(pageIndex: 2, pageCount: 10), 1);
      expect(pdfSpreadStart(pageIndex: 3, pageCount: 10), 3);
    });
  });

  group('continuous geometry', () {
    test('the extent covers pages plus the gaps between them', () {
      expect(pdfContinuousExtent(pageHeights: [500, 500, 500], gap: 12), 1524);
      expect(pdfContinuousExtent(pageHeights: const [], gap: 12), 0);
      // A single page has no gap.
      expect(pdfContinuousExtent(pageHeights: [500], gap: 12), 500);
    });

    test('page tops accumulate heights and gaps', () {
      expect(pdfPageTops(pageHeights: [500, 600, 400], gap: 12), [
        0,
        512,
        1124,
      ]);
    });

    test('the scroll anchor picks the page you are mostly looking at', () {
      const tops = [0.0, 512.0, 1124.0];
      const heights = [500.0, 600.0, 400.0];

      int at(double y) => pdfPageAtScroll(
        scrollY: y,
        pageTops: tops,
        pageHeights: heights,
        viewportHeight: 800,
      );

      expect(at(0), 0);
      // 28% of an 800px viewport is 224: just past the first page's break.
      expect(at(280), 0);
      expect(at(300), 1);
      expect(at(1124), 2);
    });

    test('the anchor has a 48px floor in a tiny window', () {
      const tops = [0.0, 100.0];
      expect(
        pdfPageAtScroll(
          scrollY: 60,
          pageTops: tops,
          pageHeights: const [100.0, 100.0],
          viewportHeight: 100,
        ),
        1,
      );
    });

    test('the reported offset is zero outside continuous mode', () {
      const tops = [0.0, 512.0];
      expect(
        pdfScrollOffset(
          scrollY: 600,
          pageTops: tops,
          pageIndex: 1,
          mode: PdfDisplayMode.continuous,
        ),
        88,
      );
      expect(
        pdfScrollOffset(
          scrollY: 600,
          pageTops: tops,
          pageIndex: 1,
          mode: PdfDisplayMode.single,
        ),
        0,
      );
      expect(
        pdfScrollOffset(
          scrollY: 600,
          pageTops: tops,
          pageIndex: 1,
          mode: PdfDisplayMode.double,
        ),
        0,
      );
    });

    test('restoring targets the page top plus the saved offset', () {
      const tops = [0.0, 512.0];
      expect(
        pdfScrollTarget(
          pageTops: tops,
          pageHeights: const [500.0, 600.0],
          pageIndex: 1,
          offset: 88,
          viewportHeight: 800,
        ),
        600,
      );
    });

    test('an offset may run to the end of a short page', () {
      // The page is 600 tall in an 800 viewport, so the whole page stays
      // visible at any offset; the offset is still honoured up to its height.
      expect(
        pdfScrollTarget(
          pageTops: const [0.0, 512.0],
          pageHeights: const [500.0, 600.0],
          pageIndex: 1,
          offset: 400,
          viewportHeight: 800,
        ),
        912,
      );
    });

    test('an offset cannot run into the next page', () {
      // 2000-tall page: the furthest valid offset is its own height.
      expect(
        pdfScrollTarget(
          pageTops: const [100.0],
          pageHeights: const [2000.0],
          pageIndex: 0,
          offset: 9000,
          viewportHeight: 800,
        ),
        2100,
      );
    });

    test('an out-of-range page falls back to the first one', () {
      expect(
        pdfScrollTarget(
          pageTops: const [0.0, 512.0],
          pageHeights: const [500.0, 600.0],
          pageIndex: 9,
          offset: 0,
          viewportHeight: 800,
        ),
        512,
      );
    });
  });
}
