import 'package:flutter/services.dart';

import '../../domain/ocr/ocr_engine.dart';
import '../../domain/ocr/ocr_models.dart';
import '../../domain/ocr/pdf_page_rasterizer.dart';

final class MethodChannelOcrEngine implements OcrEngine {
  MethodChannelOcrEngine({MethodChannel? channel, this._id = 'platform'})
    : _channel = channel ?? const MethodChannel('pagesage/ocr');

  final MethodChannel _channel;
  final String _id;

  bool? _availableCache;

  @override
  String get id => _id;

  @override
  bool get supportsPdfPageOcr => true;

  @override
  Future<bool> isAvailable() async {
    final cached = _availableCache;
    if (cached != null) {
      return cached;
    }
    try {
      final value = await _channel.invokeMethod<bool>('isAvailable');
      return _availableCache = value ?? false;
    } on PlatformException {
      return _availableCache = false;
    } on MissingPluginException {
      return _availableCache = false;
    }
  }

  @override
  Future<List<String>> supportedLanguages() async {
    try {
      final value = await _channel.invokeMethod<List<dynamic>>(
        'supportedLanguages',
      );
      if (value == null) {
        return const [];
      }
      return value.whereType<String>().toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
  }) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('recognizePdfPage', {
        'path': filePath,
        'pageNumber': pageNumber,
        'languageHint': languageHint,
        'dpi': dpi,
        'maxEdge': maxEdge,
      });
      return _parseResult(result, languageHint);
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on MissingPluginException {
      throw const OcrUnavailableException();
    }
  }

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
  }) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('recognize', {
        'imageBytes': imageBytes,
        'languageHint': languageHint,
      });
      return _parseResult(result, languageHint);
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on MissingPluginException {
      throw const OcrUnavailableException();
    }
  }

  OcrPageResult _parseResult(Object? result, String languageHint) {
    if (result is! Map) {
      throw const OcrFailedException('识别返回格式无效');
    }
    final map = Map<Object?, Object?>.from(result);
    final text = (map['text'] as String?)?.trim() ?? '';
    final engine = (map['engine'] as String?)?.trim();
    final language = (map['language'] as String?)?.trim();
    final confidence = (map['confidence'] as num?)?.toDouble();
    final imageWidth = (map['imageWidth'] as num?)?.toInt();
    final imageHeight = (map['imageHeight'] as num?)?.toInt();
    final blocks = _parseBlocks(map['blocks']);
    return OcrPageResult(
      text: text,
      language: (language == null || language.isEmpty)
          ? languageHint
          : language,
      engine: (engine == null || engine.isEmpty) ? id : engine,
      confidence: confidence,
      blocks: blocks,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  List<OcrTextBlock> _parseBlocks(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final blocks = <OcrTextBlock>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<Object?, Object?>.from(item);
      final text = (map['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      blocks.add(
        OcrTextBlock(
          text: text,
          left: (map['left'] as num?)?.toDouble(),
          top: (map['top'] as num?)?.toDouble(),
          width: (map['width'] as num?)?.toDouble(),
          height: (map['height'] as num?)?.toDouble(),
        ),
      );
    }
    return List.unmodifiable(blocks);
  }

  Never _mapPlatformException(PlatformException error) {
    if (error.code == 'ocr_unavailable') {
      throw OcrUnavailableException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : '当前平台暂不支持本地识别',
      );
    }
    if (error.code == 'file_not_found') {
      throw const OcrFailedException('找不到 PDF 文件');
    }
    if (error.code == 'page_out_of_range') {
      throw const OcrFailedException('页码超出范围');
    }
    throw OcrFailedException(
      error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : '文本识别失败',
    );
  }
}
