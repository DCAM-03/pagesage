import '../../domain/ocr/ocr_models.dart';
import '../../domain/ocr/pdf_page_rasterizer.dart';

final class StubPdfPageRasterizer implements PdfPageRasterizer {
  const StubPdfPageRasterizer();

  @override
  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
    int maxPixels = 5000000,
  }) async {
    throw const OcrFailedException('当前平台暂不支持 PDF 页渲染');
  }
}
