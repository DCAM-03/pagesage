import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:dart_pdf_editor/src/image_decoder.dart';
import 'package:flutter/material.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

/// Renders a PDF page onto a Flutter [Canvas] with `pdf_graphics`.
///
/// Wraps `dart_pdf_editor`'s `CanvasPdfDevice`, so the page paints without any
/// WebView, WebKit, or WPE dependency — which is what makes the PDF reader work
/// on Linux (see `docs/10-pdf-renderer-migration.md`).
final class PdfCanvasRenderer {
  PdfCanvasRenderer(this._doc);

  final PdfDocument _doc;

  CosDocument get cos => _doc.cos;

  int get pageCount => _doc.pageCount;

  PdfPage pageAt(int index) => _doc.page(index);

  /// Renders [pageIndex] at [scale] and returns the picture plus the size it
  /// was rasterised at.
  ///
  /// [zoom] scales the page in PDF user units; the caller is responsible for
  /// mapping [outputSize] back to widget space.
  Future<PdfRenderedPage> renderPage(int pageIndex, {double zoom = 1.0}) async {
    final page = _doc.page(pageIndex);
    final box = page.cropBox;

    // Pass 1: a scan-only walk collects every image request. Without this the
    // device has no bitmaps and drawImage paints nothing — silently, with no
    // exception.
    final collector = ImageCollector();
    PdfInterpreter(cos: cos, device: collector, scanImagesOnly: true)
        .drawPage(page);
    final images = await decodeImages(cos, collector.streams);

    // Rasterise at device pixels, capped so a huge page at high zoom cannot
    // allocate an unbounded buffer.
    const maxPixels = 64 * 1024 * 1024;
    var scale = zoom;
    while (scale > 0.05 &&
        (box.width * scale * box.height * scale) > maxPixels) {
      scale *= 0.8;
    }

    final w = (box.width * scale).round().clamp(1, 20000);
    final h = (box.height * scale).round().clamp(1, 20000);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    canvas.save();
    // Uniform scale first, then the page transform. The flip must pivot around
    // box.height — flipping around y=0 pushes content to negative y and the
    // page renders blank. Mirrors dart_pdf_editor's _applyPageTransform.
    canvas.scale(scale, scale);
    switch (page.rotation) {
      case 90:
        canvas.translate(h / scale, 0);
        canvas.rotate(mathPi / 2);
      case 180:
        canvas.translate(w / scale, h / scale);
        canvas.rotate(mathPi);
      case 270:
        canvas.translate(0, w / scale);
        canvas.rotate(-mathPi / 2);
    }
    canvas.translate(0, box.height);
    canvas.scale(1, -1);
    canvas.translate(-box.left, -box.bottom);

    PdfInterpreter(cos: cos, device: CanvasPdfDevice(canvas, images: images))
        .drawPage(page);
    canvas.restore();

    final picture = recorder.endRecording();
    for (final image in images.values) {
      image.dispose();
    }
    return PdfRenderedPage(picture: picture, pixels: w * h, zoom: scale);
  }

  /// Text of [pageIndex] with geometry, for selection and search.
  PdfPageText textOf(int pageIndex) =>
      PdfTextExtractor.extract(_doc, pageIndex);
}

const double mathPi = 3.1415926535897932;

/// A rasterised page: the picture plus the zoom actually used.
final class PdfRenderedPage {
  const PdfRenderedPage({
    required this.picture,
    required this.pixels,
    required this.zoom,
  });

  final ui.Picture picture;
  final int pixels;

  /// May be lower than requested when the pixel cap kicked in.
  final double zoom;

  void dispose() => picture.dispose();
}