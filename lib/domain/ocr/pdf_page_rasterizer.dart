import 'dart:typed_data';

/// Rasterized PDF page ready for OCR (encoded image bytes).
final class PdfPageImage {
  const PdfPageImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.pageNumber,
    required this.dpi,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// 1-based page number.
  final int pageNumber;
  final int dpi;
}

/// Renders a PDF page to a bitmap without going through the WebView.
///
/// Prefer [OcrEngine.recognizePdfPage] for interactive OCR — it skips
/// encode/decode and large MethodChannel payloads.
abstract interface class PdfPageRasterizer {
  /// Default tuned for OCR speed/quality balance (not print fidelity).
  static const int defaultDpi = 200;
  static const int defaultMaxEdge = 2200;

  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = defaultDpi,
  });
}
