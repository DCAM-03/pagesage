import 'dart:math' as math;

import 'package:pdf_document/pdf_document.dart';

import '../../domain/books/reading_position.dart';

/// One image found on a PDF page, in the coordinate space annotations use.
final class PdfDetectedImage {
  const PdfDetectedImage({
    required this.page,
    required this.ordinal,
    required this.rect,
    this.resourceName,
    this.pixelWidth,
    this.pixelHeight,
  });

  /// 1-based page number.
  final int page;

  /// Index among the page's image elements in paint order.
  final int ordinal;

  /// `/XObject` resource name, when the stream names one (inline images
  /// do not).
  final String? resourceName;

  /// The image's box on the displayed page, 0..1 with y down — the same basis
  /// `ReaderRect` uses for text selection, so both project through one path.
  final ReaderRect rect;

  final int? pixelWidth;
  final int? pixelHeight;
}

/// Finds the images a page's content stream paints.
///
/// This is a convenience for snapping and for reading captions; it is not the
/// only way to annotate an image. [PdfPageElements] does not descend into form
/// XObjects, so InDesign exports and many scanned files report fewer images
/// than they draw. Callers must therefore keep a drawn box working when this
/// returns nothing.
abstract final class PdfImageDetector {
  /// Parses [pageIndex] (0-based) once. Returns an empty list when the content
  /// stream cannot be parsed — a broken page must not stop the book opening.
  static List<PdfDetectedImage> detect(PdfDocument document, int pageIndex) {
    final page = document.page(pageIndex);
    final box = page.cropBox;
    if (box.width <= 0 || box.height <= 0) {
      return const [];
    }
    try {
      final elements = PdfPageElements.of(document, pageIndex);
      final detected = <PdfDetectedImage>[];
      for (final element in elements.elements) {
        if (element.kind != PdfElementKind.image &&
            element.kind != PdfElementKind.inlineImage) {
          continue;
        }
        final bounds = element.bounds;
        if (bounds == null) {
          continue;
        }
        final rect = pdfBoundsToDisplayRect(
          bounds,
          cropBox: box,
          rotation: page.rotation,
        );
        if (rect.width <= 0 || rect.height <= 0) {
          continue;
        }
        detected.add(
          PdfDetectedImage(
            page: pageIndex + 1,
            ordinal: detected.length,
            resourceName: element.resourceName,
            rect: rect,
            pixelWidth: element.imageWidth,
            pixelHeight: element.imageHeight,
          ),
        );
      }
      return detected;
    } on Object {
      return const [];
    }
  }
}

/// Maps a PDF user-space rectangle onto the displayed page box.
///
/// PDF user space has its origin at the crop box's lower-left with y growing
/// up; the reader draws the page after `/Rotate` with y growing down. Both
/// facts are easy to get wrong in a way that produces no exception — the box
/// simply lands mirrored or quarter-turned — so this is a pure function with
/// its own tests rather than an inline expression.
///
/// The result is clamped to the page: an image whose bounds extend past the
/// crop box (common with deliberately cropped artwork) must not produce a
/// rectangle that paints outside the page.
ReaderRect pdfBoundsToDisplayRect(
  PdfRect bounds, {
  required PdfRect cropBox,
  required int rotation,
}) {
  final width = cropBox.width;
  final height = cropBox.height;
  // Normalise against the crop box, flipping y so 0 is the top edge.
  final left = (bounds.left - cropBox.left) / width;
  final right = (bounds.right - cropBox.left) / width;
  final top = (cropBox.top - bounds.top) / height;
  final bottom = (cropBox.top - bounds.bottom) / height;

  final rotationClockwise = ((rotation % 360) + 360) % 360;
  final (
    double x0,
    double y0,
    double x1,
    double y1,
  ) = switch (rotationClockwise) {
    // Each quarter turn maps the normalised box onto the rotated display box.
    90 => (1 - bottom, left, 1 - top, right),
    180 => (1 - right, 1 - bottom, 1 - left, 1 - top),
    270 => (top, 1 - right, bottom, 1 - left),
    _ => (left, top, right, bottom),
  };

  final clampedLeft = math.min(x0, x1).clamp(0.0, 1.0);
  final clampedTop = math.min(y0, y1).clamp(0.0, 1.0);
  final clampedRight = math.max(x0, x1).clamp(0.0, 1.0);
  final clampedBottom = math.max(y0, y1).clamp(0.0, 1.0);

  return ReaderRect(
    x: clampedLeft,
    y: clampedTop,
    width: clampedRight - clampedLeft,
    height: clampedBottom - clampedTop,
  );
}

/// The image a drawn box most likely means, or null when it means none.
///
/// Snapping is deliberately conservative: it fires when the box mostly covers
/// one image, or when the box is a small stroke that lands on one. A box that
/// spans several images (a figure plate, a two-column spread) stays as drawn,
/// because stretching it to one of them would mark the wrong picture.
PdfDetectedImage? snapToDetectedImage(
  ReaderRect drawn,
  List<PdfDetectedImage> images, {
  double minCoverage = 0.6,
  double edgeTolerance = 0.01,
}) {
  if (images.isEmpty) return null;
  PdfDetectedImage? best;
  var bestScore = 0.0;
  for (final image in images) {
    final overlap = _overlapArea(drawn, image.rect);
    if (overlap <= 0) continue;
    final drawnArea = drawn.width * drawn.height;
    if (drawnArea <= 0) continue;
    final coverage = overlap / drawnArea;
    // A small box drawn inside the image (a detail, a face) still snaps.
    final inside = _contains(image.rect, drawn, edgeTolerance);
    final near = _nearEdges(drawn, image.rect, edgeTolerance);
    final score = inside ? math.max(coverage, 0.9) : coverage;
    if (!inside && !near && coverage < minCoverage) continue;
    if (score > bestScore) {
      bestScore = score;
      best = image;
    }
  }
  return best;
}

double _overlapArea(ReaderRect a, ReaderRect b) {
  final left = math.max(a.x, b.x);
  final top = math.max(a.y, b.y);
  final right = math.min(a.x + a.width, b.x + b.width);
  final bottom = math.min(a.y + a.height, b.y + b.height);
  if (right <= left || bottom <= top) return 0;
  return (right - left) * (bottom - top);
}

bool _contains(ReaderRect outer, ReaderRect inner, double tolerance) {
  return inner.x >= outer.x - tolerance &&
      inner.y >= outer.y - tolerance &&
      inner.x + inner.width <= outer.x + outer.width + tolerance &&
      inner.y + inner.height <= outer.y + outer.height + tolerance;
}

bool _nearEdges(ReaderRect drawn, ReaderRect image, double tolerance) {
  return (drawn.x - image.x).abs() <= tolerance &&
      (drawn.y - image.y).abs() <= tolerance &&
      (drawn.width - image.width).abs() <= tolerance &&
      (drawn.height - image.height).abs() <= tolerance;
}

/// The inverse of [pdfBoundsToDisplayRect]'s rotation step, for the future
/// crop-on-render path: a region expressed on the displayed page box, back to
/// fractions of the unrotated page.
///
/// Kept next to the forward mapping so the two cannot drift apart.
({double left, double top, double right, double bottom})
displayRectToPageFractions(ReaderRect rect, {required int rotation}) {
  final rotationClockwise = ((rotation % 360) + 360) % 360;
  final x0 = rect.x;
  final y0 = rect.y;
  final x1 = rect.x + rect.width;
  final y1 = rect.y + rect.height;

  return switch (rotationClockwise) {
    90 => (left: y0, top: 1 - x1, right: y1, bottom: 1 - x0),
    180 => (left: 1 - x1, top: 1 - y1, right: 1 - x0, bottom: 1 - y0),
    270 => (left: 1 - y1, top: x0, right: 1 - y0, bottom: x1),
    _ => (left: x0, top: y0, right: x1, bottom: y1),
  };
}
