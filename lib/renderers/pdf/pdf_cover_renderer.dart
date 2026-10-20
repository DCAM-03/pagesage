import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';

/// Paints a PDF's first page into a cover bitmap for the library grid.
///
/// Cover extraction used to scan the file for embedded JPEG streams and keep
/// the largest one. That picks whatever photograph happens to be in the
/// document — in a technical book usually a screenshot of body content — and
/// finds nothing when the cover is vector art, so the shelf showed wrong or
/// missing covers. Page 1 is what the reader sees when they open the book, so
/// it is what belongs on the shelf too; the byte scan survives only as the
/// fallback when a page cannot be rasterized.
///
/// This lives in `renderers/` rather than beside the extractor because it
/// needs `dart:ui`. Cover extraction runs on the app's isolate during import;
/// `MetadataExtractor` takes the renderer as a plain callback, so the
/// headless CLI tools can still use it without pulling Flutter in.
final class PdfCoverRenderer {
  const PdfCoverRenderer({this.pixelWidth = 600});

  /// Width the cover is baked at.
  ///
  /// The grid's `_BookCover` decodes at most 720 px wide; at this width a
  /// raster cover lands around 200–600 KB as PNG, sharp on a high-DPI phone
  /// without inflating the library directory.
  final double pixelWidth;

  /// Returns a PNG of page 1, or null when the page cannot be rendered.
  ///
  /// Null covers every reason the caller cannot use the result — no pages, an
  /// unparseable page, a degenerate page box — so the caller can fall back
  /// without distinguishing them.
  Future<Uint8List?> renderCoverPng(Uint8List bytes) async {
    ui.Image? image;
    try {
      final document = PdfDocument.open(bytes);
      if (document.pageCount == 0) {
        return null;
      }
      final page = document.page(0);
      final size = PdfPageRenderer.pageSize(page);
      if (size.isEmpty) {
        return null;
      }
      final ratio = (pixelWidth / size.width).clamp(0.2, 4.0).toDouble();
      image = await PdfPageRenderer.renderImage(
        page,
        pixelRatio: ratio,
        // A cover is page content, not the reader's marks: the document's own
        // annotations stay out, matching how the reader paints the page.
        annotations: false,
        rotation: null,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } on Object {
      return null;
    } finally {
      image?.dispose();
    }
  }
}
