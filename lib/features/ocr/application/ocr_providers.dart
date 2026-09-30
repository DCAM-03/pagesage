import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/ocr/method_channel_ocr_engine.dart';
import '../../../core/ocr/method_channel_pdf_page_rasterizer.dart';
import '../../../core/ocr/stub_ocr_engine.dart';
import '../../../core/ocr/stub_pdf_page_rasterizer.dart';
import '../../../domain/ocr/ocr_engine.dart';
import '../../../domain/ocr/pdf_page_rasterizer.dart';
import '../../../renderers/pdf/pdf_renderer_controller.dart';
import 'ocr_current_page_use_case.dart';
import 'ocr_page_store.dart';
import 'ocr_session_cache.dart';

final ocrSessionCacheProvider = Provider<OcrSessionCache>((ref) {
  return OcrSessionCache();
});

final ocrPageStoreProvider = Provider<OcrPageStore>((ref) {
  return DriftOcrPageStore(ref.watch(ocrPageDaoProvider));
});

/// Active PDF renderer controller for display-space OCR export.
///
/// Set by [PdfRendererView] while mounted; prefer this over native PDF
/// re-render so OCR geometry matches the on-screen page box.
final activePdfRendererControllerProvider =
    StateProvider<PdfRendererController?>((ref) => null);

final pdfPageRasterizerProvider = Provider<PdfPageRasterizer>((ref) {
  if (Platform.isAndroid || Platform.isWindows) {
    return MethodChannelPdfPageRasterizer();
  }
  return const StubPdfPageRasterizer();
});

final ocrEngineProvider = Provider<OcrEngine>((ref) {
  if (Platform.isAndroid) {
    return MethodChannelOcrEngine(id: 'mlkit');
  }
  if (Platform.isWindows) {
    return MethodChannelOcrEngine(id: 'winrt');
  }
  return const StubOcrEngine();
});

final ocrCurrentPageUseCaseProvider = Provider<OcrCurrentPageUseCase>((ref) {
  return OcrCurrentPageUseCase(
    rasterizer: ref.watch(pdfPageRasterizerProvider),
    engine: ref.watch(ocrEngineProvider),
    cache: ref.watch(ocrSessionCacheProvider),
    store: ref.watch(ocrPageStoreProvider),
  );
});
