import 'dart:typed_data';

import 'ocr_models.dart';

/// Local OCR backend (ML Kit / WinRT / stub / fake).
abstract interface class OcrEngine {
  /// Stable id for diagnostics and result metadata (`mlkit`, `winrt`, …).
  String get id;

  Future<bool> isAvailable();

  Future<List<String>> supportedLanguages();

  /// Prefer [recognizePdfPage] when available — avoids PNG channel round-trips.
  bool get supportsPdfPageOcr => false;

  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  });

  /// One-shot: open PDF page on native side, OCR, return text only.
  ///
  /// Default throws; platform engines override for the fast path.
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) {
    throw UnsupportedError('recognizePdfPage is not supported by $id');
  }
}
