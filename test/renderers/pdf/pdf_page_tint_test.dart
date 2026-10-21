import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/pdf/pdf_page_tint.dart';

/// S6 theme work: a PDF keeps the colours its author chose, so a theme can
/// only be applied as a filter over the page. The bridge did this with CSS
/// filters; these tests pin the Dart equivalent at the points where a wrong
/// matrix degrades reading rather than merely looking off.
void main() {
  group('which presets adjust the page', () {
    test('day leaves the page untouched', () {
      final tint = PdfPageTint.forPreset(ReaderThemePreset.day, narrow: false);
      // No filter means the painter can skip its save layer entirely.
      expect(tint.filter, isNull);
      expect(tint.paper, ReaderThemePreset.day.background);
    });

    test('night inverts the page', () {
      final tint = PdfPageTint.forPreset(
        ReaderThemePreset.night,
        narrow: false,
      );
      expect(tint.inverted, isTrue);
      expect(tint.filter, isNotNull);
      // The paper behind the page is dark too, so margins do not flash white.
      expect(tint.paper.computeLuminance(), lessThan(0.05));
    });

    test('warm paper tints without inverting', () {
      final tint = PdfPageTint.forPreset(
        ReaderThemePreset.paper,
        narrow: false,
      );
      expect(tint.inverted, isFalse);
      expect(tint.sepia, greaterThan(0));
      expect(tint.filter, isNotNull);
    });

    test('eye-care presets tint too', () {
      for (final preset in [ReaderThemePreset.green, ReaderThemePreset.sage]) {
        final tint = PdfPageTint.forPreset(preset, narrow: false);
        expect(tint.sepia, greaterThan(0), reason: '$preset');
        expect(tint.inverted, isFalse, reason: '$preset');
      }
    });

    test('high contrast leaves the page alone', () {
      // Double-applying contrast to a document that already carries its own
      // would clip the last detail out of a scan.
      expect(
        PdfPageTint.forPreset(ReaderThemePreset.contrast, narrow: false).filter,
        isNull,
      );
    });

    test('an e-ink preset does not double-tint the page', () {
      for (final preset in [ReaderThemePreset.ink, ReaderThemePreset.inkWarm]) {
        expect(
          PdfPageTint.forPreset(preset, narrow: false).filter,
          isNull,
          reason: '$preset',
        );
      }
    });
  });

  group('narrow viewports', () {
    test('a phone gets no filter but keeps the theme paper', () {
      // A full-page colour matrix forces the page into its own layer every
      // frame; the bridge dropped it under 900 px for heat, and so do we.
      for (final preset in ReaderThemePreset.values) {
        final tint = PdfPageTint.forPreset(preset, narrow: true);
        expect(tint.filter, isNull, reason: '$preset');
      }
      expect(
        PdfPageTint.forPreset(ReaderThemePreset.night, narrow: true).paper,
        ReaderThemePreset.night.background,
      );
    });
  });

  group('matrix', () {
    test('night turning the page dark', () {
      final tint = PdfPageTint.forPreset(
        ReaderThemePreset.night,
        narrow: false,
      );
      final m = tint.colourMatrix;

      // White paper must come out dark and black text must come out light;
      // anything else means the invert and hue rotation are out of order.
      final white = _apply(m, 255, 255, 255);
      final black = _apply(m, 0, 0, 0);
      expect(_luma(white), lessThan(120));
      expect(_luma(black), greaterThan(120));
    });

    test('night keeps text and paper apart', () {
      final tint = PdfPageTint.forPreset(
        ReaderThemePreset.night,
        narrow: false,
      );
      final m = tint.colourMatrix;
      // Contrast between the two ends has to survive the inversion, or the
      // reader gets a grey page.
      final gap = (_luma(_apply(m, 0, 0, 0)) - _luma(_apply(m, 255, 255, 255)))
          .abs();
      expect(gap, greaterThan(90));
    });

    test('a warm tint leaves the paper lighter than its text', () {
      final tint = PdfPageTint.forPreset(
        ReaderThemePreset.paper,
        narrow: false,
      );
      final m = tint.colourMatrix;
      expect(
        _luma(_apply(m, 255, 255, 255)),
        greaterThan(_luma(_apply(m, 0, 0, 0))),
      );
    });

    test('presets with the same settings compare equal', () {
      // shouldRepaint relies on this: an unchanged theme must not repaint.
      expect(
        PdfPageTint.forPreset(ReaderThemePreset.paper, narrow: false),
        PdfPageTint.forPreset(ReaderThemePreset.warm, narrow: false),
      );
      expect(
        PdfPageTint.forPreset(ReaderThemePreset.paper, narrow: false),
        isNot(PdfPageTint.forPreset(ReaderThemePreset.paper, narrow: true)),
      );
    });
  });
}

/// Applies a 4x5 colour matrix to one RGB triple.
({double r, double g, double b}) _apply(
  List<double> m,
  double r,
  double g,
  double b,
) {
  double channel(int row) =>
      m[row * 5] * r + m[row * 5 + 1] * g + m[row * 5 + 2] * b + m[row * 5 + 4];
  return (r: channel(0), g: channel(1), b: channel(2));
}

double _luma(({double r, double g, double b}) c) =>
    0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
