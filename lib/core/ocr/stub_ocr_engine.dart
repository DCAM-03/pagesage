import 'dart:typed_data';

import '../../domain/ocr/ocr_engine.dart';
import '../../domain/ocr/ocr_models.dart';

final class StubOcrEngine implements OcrEngine {
  const StubOcrEngine();

  @override
  String get id => 'stub';

  @override
  bool get supportsPdfPageOcr => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<String>> supportedLanguages() async => const [];

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  }) async {
    throw const OcrUnavailableException();
  }

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) {
    throw const OcrUnavailableException();
  }
}
