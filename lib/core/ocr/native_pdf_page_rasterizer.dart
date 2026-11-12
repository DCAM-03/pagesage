import 'dart:io';

import 'package:pdf_document/pdf_document.dart';

import '../../domain/ocr/pdf_page_rasterizer.dart';
import '../../renderers/pdf/pdf_canvas_renderer.dart';

final class NativePdfPageRasterizer implements PdfPageRasterizer {
  _PdfRenderSession? _session;

  @override
  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
    int maxPixels = 5000000,
  }) async {
    if (pageNumber < 1 || dpi <= 0 || maxEdge <= 0 || maxPixels <= 0) {
      throw ArgumentError.value(pageNumber, 'pageNumber', '页码或渲染预算无效');
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('PDF 文件不存在');
    }
    final stat = await file.stat();
    final path = file.absolute.path;
    var session = _session;
    if (session == null ||
        session.path != path ||
        session.modified != stat.modified ||
        session.length != stat.size) {
      session?.renderer.dispose();
      _session = null;
      final bytes = await file.readAsBytes();
      final document = PdfDocument.open(bytes);
      PdfCanvasRenderer? renderer;
      try {
        renderer = PdfCanvasRenderer(document, sourceBytes: bytes);
        session = _PdfRenderSession(
          path: path,
          modified: stat.modified,
          length: stat.size,
          renderer: renderer,
        );
        _session = session;
      } catch (_) {
        renderer?.dispose();
        rethrow;
      }
    }
    final renderer = session.renderer;
    if (pageNumber > renderer.pageCount) {
      throw RangeError.range(pageNumber, 1, renderer.pageCount);
    }
    final imageBytes = await renderer.exportPageImage(
      pageNumber - 1,
      targetWidth: dpi * 8.0,
      maxEdge: maxEdge,
      maxPixels: maxPixels,
    );
    if (imageBytes == null || imageBytes.isEmpty) {
      throw StateError('页面光栅化失败');
    }
    final size = renderer.displaySizeOf(pageNumber - 1);
    return PdfPageImage(
      bytes: imageBytes,
      width: size.width.round(),
      height: size.height.round(),
      pageNumber: pageNumber,
      dpi: dpi,
    );
  }

  void dispose() {
    _session?.renderer.dispose();
    _session = null;
  }
}

final class _PdfRenderSession {
  const _PdfRenderSession({
    required this.path,
    required this.modified,
    required this.length,
    required this.renderer,
  });

  final String path;
  final DateTime modified;
  final int length;
  final PdfCanvasRenderer renderer;
}
