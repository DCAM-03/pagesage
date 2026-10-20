import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/pdf/pdf_zoom.dart';

/// The zoom model is the single source of truth for S1: the page slot, the
/// picture transform and `locator.zoom` all come from here. These tests pin
/// the arithmetic against the WebView bridge's `resolveZoomForPage`, because
/// a scale that disagrees between renderers makes stored locators drift.
void main() {
  const letter = Size(612, 792);

  PdfZoomGeometry resolve(
    PdfZoomMode mode, {
    double customScale = 1,
    Size pageSize = letter,
    Size viewport = const Size(1280, 800),
    bool narrow = false,
    double margin = 24,
  }) => resolvePdfZoom(
    mode: mode,
    customScale: customScale,
    pageSize: pageSize,
    viewport: viewport,
    narrow: narrow,
    pageMargin: margin,
  );

  group('modes', () {
    test('fit-width fills the width inside the margins', () {
      final geometry = resolve(PdfZoomMode.fitWidth);
      // (1280 - 48) / 612
      expect(geometry.scale, closeTo(1232 / 612, 0.0001));
      expect(geometry.contentSize.width, closeTo(1232, 0.0001));
      expect(geometry.margin, 24);
    });

    test('fit-page picks the smaller of width and height', () {
      final geometry = resolve(PdfZoomMode.fitPage);
      // height: (800 - 48) / 792 = 0.9495…; width: 2.013… → height wins.
      expect(geometry.scale, closeTo(752 / 792, 0.0001));
      expect(geometry.contentSize.height, closeTo(752, 0.0001));
      expect(geometry.contentSize.width, lessThanOrEqualTo(1232));
    });

    test('actual is 100% when the page fits', () {
      expect(resolve(PdfZoomMode.actual).scale, 1);
    });

    test('actual is capped to fit-width on a phone', () {
      final geometry = resolve(
        PdfZoomMode.actual,
        narrow: true,
        viewport: const Size(360, 780),
        margin: 12,
      );
      // Bridge: min(1, widthScale). A 12px margin on a phone is floored to
      // 8, so the available width is 360 - 16 = 344.
      expect(geometry.scale, closeTo(344 / 612, 0.0001));
      expect(geometry.scale, lessThan(1));
    });

    test('custom honours the saved scale', () {
      expect(resolve(PdfZoomMode.custom, customScale: 1.75).scale, 1.75);
    });

    test('every mode is clamped to 0.5–3.0', () {
      expect(
        resolve(PdfZoomMode.custom, customScale: 9).scale,
        ReaderSettings.pdfScaleMax,
      );
      expect(
        resolve(PdfZoomMode.custom, customScale: 0.01).scale,
        ReaderSettings.pdfScaleMin,
      );
      // A tiny window would otherwise resolve to a nearly invisible page.
      final tiny = resolve(
        PdfZoomMode.fitWidth,
        viewport: const Size(120, 160),
        margin: 24,
      );
      expect(tiny.scale, ReaderSettings.pdfScaleMin);
    });
  });

  group('narrow phone heuristic', () {
    test('coerces a saved custom scale to fit-width on open', () {
      expect(
        effectivePdfZoomMode(
          mode: PdfZoomMode.custom,
          narrow: true,
          userAdjustedScale: false,
        ),
        PdfZoomMode.fitWidth,
      );
    });

    test('keeps the custom mode the user picked on this session', () {
      expect(
        effectivePdfZoomMode(
          mode: PdfZoomMode.custom,
          narrow: true,
          userAdjustedScale: true,
        ),
        PdfZoomMode.custom,
      );
    });

    test('leaves desktop custom scales alone', () {
      expect(
        effectivePdfZoomMode(
          mode: PdfZoomMode.custom,
          narrow: false,
          userAdjustedScale: false,
        ),
        PdfZoomMode.custom,
      );
    });

    test('clamps an oversized default that would overflow a phone', () {
      // 600pt page on a 360px screen: widthScale ≈ 0.57. The margin passed is
      // the configured one; the phone heuristic shrinks it to 8.
      final geometry = resolve(
        PdfZoomMode.custom,
        customScale: 1.2,
        narrow: true,
        pageSize: const Size(600, 800),
        viewport: const Size(360, 780),
        margin: 12,
      );
      expect(geometry.scale, closeTo(344 / 600, 0.0001));
    });

    test('leaves an intentional pinch past 1.25 alone', () {
      final geometry = resolve(
        PdfZoomMode.custom,
        customScale: 1.8,
        narrow: true,
        pageSize: const Size(600, 800),
        viewport: const Size(360, 780),
        margin: 12,
      );
      expect(geometry.scale, 1.8);
    });
  });

  test('rotated pages measure the rotated size', () {
    final geometry = resolve(
      PdfZoomMode.fitPage,
      pageSize: const Size(792, 612),
      viewport: const Size(800, 800),
      margin: 0,
    );
    // Landscape page inside a square box: width is the binding dimension.
    expect(geometry.scale, closeTo(800 / 792, 0.0001));
    expect(geometry.contentSize.height, lessThan(800));
  });

  test('phone margins shrink but stay visible', () {
    expect(pdfPageMargin(24, narrow: true), closeTo(9.6, 0.0001));
    expect(pdfPageMargin(72, narrow: true), 12);
    expect(pdfPageMargin(8, narrow: true), 8);
    expect(pdfPageMargin(24, narrow: false), 24);
  });

  test('degenerate page sizes fall back to 1:1 instead of NaN', () {
    final geometry = resolve(PdfZoomMode.fitWidth, pageSize: Size.zero);
    expect(geometry.scale, 1);
    expect(geometry.contentSize, Size.zero);
  });
}
