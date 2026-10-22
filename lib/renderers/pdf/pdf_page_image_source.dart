import 'dart:typed_data';

import '../../domain/books/reading_position.dart';

/// A renderer that can hand out a page as an image, for OCR.
///
/// OCR runs on a bitmap of the page, and the geometry it reports is relative to
/// that bitmap, so the bitmap must be the page as the reader sees it — same
/// /Rotate, same crop box. Both renderers can produce that: the WebView
/// captures its own canvas, the canvas renderer paints the page again.
///
/// The interface exists so the reader depends on the capability rather than on
/// one implementation. It replaces a control path that only the WebView could
/// serve, which meant "识别本页" was dead on the canvas renderer.
abstract interface class PdfPageImageSource {
  /// Renders [pageNumber] (1-based) to an encoded image, or null when the page
  /// cannot be produced.
  ///
  /// [quality] is a hint for lossy encoders; a renderer that encodes PNG
  /// ignores it rather than degrading the text OCR has to read.
  Future<Uint8List?> exportPageImage({required int pageNumber, double quality});

  /// Renders one region of [pageNumber] (1-based) as an encoded image.
  ///
  /// [rect] is a fraction of the displayed page box — the same basis image
  /// annotations store — so a saved picture is exactly the box the reader
  /// circled, at whatever rotation the page carries. Returns null when the
  /// region cannot be produced; callers must not write an empty file.
  Future<Uint8List?> exportPageRegion({
    required int pageNumber,
    required ReaderRect rect,
  });

  /// Pages currently visible to the reader, 1-based, in reading order.
  ///
  /// A double-page spread returns both pages, so OCR covers what is on screen.
  /// [fallbackPage] is returned when the renderer cannot tell.
  Future<List<int>> getVisiblePages({int? fallbackPage});
}
