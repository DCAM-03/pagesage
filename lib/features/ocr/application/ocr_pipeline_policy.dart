import '../../../domain/ocr/pdf_page_rasterizer.dart';

/// Tunable OCR path settings used by the P0 benchmark and later defaults.
final class OcrPipelinePolicy {
  const OcrPipelinePolicy({
    this.preferNativePdfPage = false,
    this.dpi = PdfPageRasterizer.defaultDpi,
    this.maxEdge = PdfPageRasterizer.defaultMaxEdge,
  });

  /// Skips the Flutter display-image export and lets the native engine render
  /// the PDF page directly. Default stays off until both paths are measured.
  final bool preferNativePdfPage;

  final int dpi;
  final int maxEdge;
}

const _benchmarkPreferNative = bool.fromEnvironment(
  'PAGESAGE_OCR_NATIVE_FAST_PATH',
);
const _benchmarkDpi = int.fromEnvironment(
  'PAGESAGE_OCR_DPI',
  defaultValue: PdfPageRasterizer.defaultDpi,
);
const _benchmarkMaxEdge = int.fromEnvironment(
  'PAGESAGE_OCR_MAX_EDGE',
  defaultValue: PdfPageRasterizer.defaultMaxEdge,
);

const defaultOcrPipelinePolicy = OcrPipelinePolicy(
  preferNativePdfPage: _benchmarkPreferNative,
  dpi: _benchmarkDpi,
  maxEdge: _benchmarkMaxEdge,
);
