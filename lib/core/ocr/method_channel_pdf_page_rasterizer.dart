import 'package:flutter/services.dart';

import '../../domain/ocr/ocr_models.dart';
import '../../domain/ocr/pdf_page_rasterizer.dart';

final class MethodChannelPdfPageRasterizer implements PdfPageRasterizer {
  MethodChannelPdfPageRasterizer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pagesage/pdf_raster');

  final MethodChannel _channel;

  @override
  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
    int maxPixels = 5000000,
  }) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('renderPage', {
        'path': filePath,
        'pageNumber': pageNumber,
        'dpi': dpi,
        'maxEdge': maxEdge,
        'maxPixels': maxPixels,
        // JPEG is ~5–15× smaller than PNG for scan pages → faster channel + decode.
        'format': 'jpeg',
        'quality': 85,
      });
      if (result is! Map) {
        throw const OcrFailedException('页面渲染返回格式无效');
      }
      final map = Map<Object?, Object?>.from(result);
      final bytesValue = map['bytes'];
      final Uint8List bytes;
      if (bytesValue is Uint8List) {
        bytes = bytesValue;
      } else if (bytesValue is List<int>) {
        bytes = Uint8List.fromList(bytesValue);
      } else if (bytesValue is List) {
        bytes = Uint8List.fromList(bytesValue.cast<int>());
      } else {
        throw const OcrFailedException('页面渲染未返回图像数据');
      }
      final width = (map['width'] as num?)?.toInt() ?? 0;
      final height = (map['height'] as num?)?.toInt() ?? 0;
      if (bytes.isEmpty || width <= 0 || height <= 0) {
        throw const OcrFailedException('页面渲染结果为空');
      }
      return PdfPageImage(
        bytes: bytes,
        width: width,
        height: height,
        pageNumber: pageNumber,
        dpi: dpi,
      );
    } on PlatformException catch (error) {
      throw OcrFailedException(_mapRasterError(error));
    }
  }

  String _mapRasterError(PlatformException error) {
    return switch (error.code) {
      'file_not_found' => '找不到 PDF 文件',
      'page_out_of_range' => '页码超出范围',
      'render_failed' =>
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : '页面渲染失败',
      _ =>
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : '页面渲染失败',
    };
  }
}
