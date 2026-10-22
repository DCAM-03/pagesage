import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/pdf/pdf_image_detector.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  // 600x800 page at the origin, so a rect's user-space coordinates are also
  // its fractions of the page divided by these numbers.
  const crop = PdfRect(0, 0, 600, 800);

  ReaderRect map(PdfRect bounds, {int rotation = 0}) {
    return pdfBoundsToDisplayRect(bounds, cropBox: crop, rotation: rotation);
  }

  void expectRect(
    ReaderRect actual, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    expect(actual.x, closeTo(x, 1e-9), reason: 'x');
    expect(actual.y, closeTo(y, 1e-9), reason: 'y');
    expect(actual.width, closeTo(width, 1e-9), reason: 'width');
    expect(actual.height, closeTo(height, 1e-9), reason: 'height');
  }

  group('pdf bounds -> displayed box', () {
    test('an upright page flips y because PDF space grows upward', () {
      // A 300x200 image sitting 100 above the page bottom and 150 from the
      // left edge. On screen its top edge is 800 - 300 = 500 from the top.
      final rect = map(const PdfRect(150, 100, 450, 300));
      expectRect(
        rect,
        x: 150 / 600,
        y: (800 - 300) / 800,
        width: 300 / 600,
        height: 200 / 800,
      );
    });

    test('the whole page maps to the whole box', () {
      expectRect(
        map(const PdfRect(0, 0, 600, 800)),
        x: 0,
        y: 0,
        width: 1,
        height: 1,
      );
    });

    test('a crop box offset is subtracted, not ignored', () {
      // A page whose media box starts at (100, 100): user space values are
      // relative to that origin.
      const offsetCrop = PdfRect(100, 100, 700, 900);
      final rect = pdfBoundsToDisplayRect(
        const PdfRect(100, 100, 700, 900),
        cropBox: offsetCrop,
        rotation: 0,
      );
      expectRect(rect, x: 0, y: 0, width: 1, height: 1);
    });

    test('/Rotate 90 turns the page clockwise', () {
      // A tall strip at the left edge of the unrotated page ends up along the
      // top edge once the page is turned a quarter clockwise.
      final rect = map(const PdfRect(0, 0, 120, 800), rotation: 90);
      expectRect(rect, x: 0, y: 0, width: 1, height: 120 / 600);
    });

    test('/Rotate 180 mirrors both axes', () {
      // The strip hugging the page's lower-left corner (user space) becomes
      // the upper-right corner of the displayed page.
      final rect = map(const PdfRect(0, 0, 300, 400), rotation: 180);
      expectRect(rect, x: 0.5, y: 0, width: 0.5, height: 0.5);
    });

    test('/Rotate 270 turns the page anticlockwise', () {
      final rect = map(const PdfRect(0, 0, 120, 800), rotation: 270);
      // Along the bottom edge, and the x extent is the rotated y thickness.
      expectRect(rect, x: 0, y: 1 - 120 / 600, width: 1, height: 120 / 600);
    });

    test('negative and over-360 rotations are normalised', () {
      final negative = map(const PdfRect(0, 0, 300, 400), rotation: -90);
      final equivalent = map(const PdfRect(0, 0, 300, 400), rotation: 270);
      expectRect(
        negative,
        x: equivalent.x,
        y: equivalent.y,
        width: equivalent.width,
        height: equivalent.height,
      );
      final fourTwenty = map(const PdfRect(0, 0, 300, 400), rotation: 450);
      final ninety = map(const PdfRect(0, 0, 300, 400), rotation: 90);
      expectRect(
        fourTwenty,
        x: ninety.x,
        y: ninety.y,
        width: ninety.width,
        height: ninety.height,
      );
    });

    test('bounds past the crop box are clamped to the page', () {
      // Artwork deliberately bled off the page edge must not paint outside it.
      final rect = map(const PdfRect(-100, -100, 700, 900));
      expectRect(rect, x: 0, y: 0, width: 1, height: 1);
    });

    test('an inverted rect still yields a positive box', () {
      // A malformed content stream can place an image upside-down.
      final rect = map(const PdfRect(450, 300, 150, 100));
      expectRect(
        rect,
        x: 150 / 600,
        y: (800 - 300) / 800,
        width: 300 / 600,
        height: 200 / 800,
      );
    });
  });

  group('against real page content', () {
    // `image-only.pdf` is not usable here: despite the name it draws its
    // checkerboard as vector paths, so it contains no image XObject at all.
    // These two samples were written for this test, one page each with a
    // 300x200 image placed at user-space (150, 400).
    PdfDetectedImage only(File file) {
      final doc = PdfDocument.open(file.readAsBytesSync());
      final found = PdfImageDetector.detect(doc, 0);
      expect(found, hasLength(1), reason: file.path);
      return found.single;
    }

    test('finds the image XObject and its box', () {
      final image = only(File('poc_pdf_canvas/samples/image-xobject.pdf'));
      expect(image.page, 1);
      expect(image.ordinal, 0);
      expect(image.resourceName, 'Im1');
      expect(image.pixelWidth, 120);
      expect(image.pixelHeight, 80);
      // 300/612 wide, 200/792 tall, 150 from the left, 400 above the bottom.
      expect(image.rect.x, closeTo(150 / 612, 1e-6));
      expect(image.rect.width, closeTo(300 / 612, 1e-6));
      expect(image.rect.height, closeTo(200 / 792, 1e-6));
      expect(image.rect.y, closeTo((792 - 600) / 792, 1e-6));
    });

    test('/Rotate 90 moves the image to the turned page\'s own axes', () {
      final image = only(
        File('poc_pdf_canvas/samples/image-xobject-rotated.pdf'),
      );
      final doc = PdfDocument.open(
        File(
          'poc_pdf_canvas/samples/image-xobject-rotated.pdf',
        ).readAsBytesSync(),
      );
      expect(doc.page(0).rotation, 90);
      // The box is now measured against the swapped page (792 wide), and the
      // image's 300-wide side runs vertically.
      expect(image.rect.width, closeTo(200 / 792, 1e-6));
      expect(image.rect.height, closeTo(300 / 612, 1e-6));
    });
  });

  group('display rect -> page fractions', () {
    test('round-trips through every rotation', () {
      for (final rotation in [0, 90, 180, 270]) {
        final source = map(
          const PdfRect(150, 100, 450, 300),
          rotation: rotation,
        );
        final back = displayRectToPageFractions(source, rotation: rotation);
        // The source image occupies x 150..450, y 100..300 in user space.
        expect(back.left, closeTo(150 / 600, 1e-9), reason: 'rot $rotation');
        expect(back.right, closeTo(450 / 600, 1e-9), reason: 'rot $rotation');
        expect(back.top, closeTo((800 - 300) / 800, 1e-9));
        expect(back.bottom, closeTo((800 - 100) / 800, 1e-9));
      }
    });
  });
}
