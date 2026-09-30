import 'dart:typed_data';

import '../../../core/tasks/task_cancellation.dart';
import '../../../domain/books/book.dart';
import '../../../domain/ocr/ocr_engine.dart';
import '../../../domain/ocr/ocr_models.dart';
import '../../../domain/ocr/pdf_page_rasterizer.dart';
import 'ocr_page_store.dart';
import 'ocr_session_cache.dart';

final class OcrCurrentPageUseCase {
  OcrCurrentPageUseCase({
    required PdfPageRasterizer rasterizer,
    required OcrEngine engine,
    required OcrSessionCache cache,
    OcrPageStore? store,
  }) : _rasterizer = rasterizer,
       _engine = engine,
       _cache = cache,
       _store = store;

  final PdfPageRasterizer _rasterizer;
  final OcrEngine _engine;
  final OcrSessionCache _cache;
  final OcrPageStore? _store;

  /// Coalesce concurrent identical page requests (double-tap / rebuild).
  final Map<String, Future<OcrPageResult>> _inFlight = {};

  /// Look up a previously recognized page without running OCR.
  Future<OcrPageResult?> peekCachedPage({
    required String bookId,
    required int pageNumber,
  }) async {
    final memory = _cache.get(bookId, pageNumber);
    if (memory != null) {
      return memory;
    }
    final store = _store;
    if (store == null) {
      return null;
    }
    final disk = await store.getPage(bookId, pageNumber);
    if (disk != null) {
      _cache.put(bookId, pageNumber, disk);
    }
    return disk;
  }

  Future<OcrPageResult> recognizeCurrentPage({
    required Book book,
    required int pageNumber,
    String? languageHint,
    TaskCancelToken? cancelToken,
    bool forceRefresh = false,

    /// When set, OCR this display-space image instead of re-rendering the PDF
    /// natively. Geometry then matches the on-screen page box 1:1.
    Uint8List? displayImageBytes,
  }) async {
    if (book.format != BookFormat.pdf) {
      throw const OcrFailedException('仅支持 PDF 页面识别');
    }
    if (pageNumber < 1) {
      throw const OcrFailedException('页码无效');
    }

    if (!forceRefresh) {
      final cached = await peekCachedPage(
        bookId: book.id,
        pageNumber: pageNumber,
      );
      // Prefer continuous line-level geometry for selection. Old word-box
      // caches make temporary selection look like per-glyph islands — re-OCR.
      if (cached != null && !_looksLikeFragmentedWordBoxes(cached)) {
        return cached;
      }
    }

    final flightKey = '${book.id}:$pageNumber';
    if (!forceRefresh) {
      final existing = _inFlight[flightKey];
      if (existing != null) {
        cancelToken?.throwIfCancelled();
        return existing;
      }
    }

    final future = _recognizeUncached(
      book: book,
      pageNumber: pageNumber,
      languageHint: languageHint,
      cancelToken: cancelToken,
      displayImageBytes: displayImageBytes,
    );
    _inFlight[flightKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[flightKey], future)) {
        _inFlight.remove(flightKey);
      }
    }
  }

  Future<OcrPageResult> _recognizeUncached({
    required Book book,
    required int pageNumber,
    String? languageHint,
    TaskCancelToken? cancelToken,
    Uint8List? displayImageBytes,
  }) async {
    cancelToken?.throwIfCancelled();
    final available = await _engine.isAvailable();
    cancelToken?.throwIfCancelled();
    if (!available) {
      throw const OcrUnavailableException();
    }

    final hint = (languageHint ?? book.language)?.trim();
    final language = (hint == null || hint.isEmpty) ? 'zh-Hans' : hint;

    late final OcrPageResult result;
    final displayBytes = displayImageBytes;
    if (displayBytes != null && displayBytes.isNotEmpty) {
      // Preferred: OCR the exact pixels the user sees.
      result = await _engine.recognize(
        imageBytes: displayBytes,
        languageHint: language,
      );
    } else if (_engine.supportsPdfPageOcr) {
      // Fallback: native PDF re-render (may disagree with PDF.js layout).
      result = await _engine.recognizePdfPage(
        filePath: book.libraryFilePath,
        pageNumber: pageNumber,
        languageHint: language,
        dpi: PdfPageRasterizer.defaultDpi,
        maxEdge: PdfPageRasterizer.defaultMaxEdge,
      );
    } else {
      final image = await _rasterizer.renderPage(
        filePath: book.libraryFilePath,
        pageNumber: pageNumber,
        dpi: PdfPageRasterizer.defaultDpi,
      );
      cancelToken?.throwIfCancelled();
      result = await _engine.recognize(
        imageBytes: image.bytes,
        languageHint: language,
      );
    }
    cancelToken?.throwIfCancelled();

    final normalized = result.text.trim();
    if (normalized.isEmpty) {
      throw const OcrEmptyResultException();
    }

    final stored = OcrPageResult(
      text: normalized,
      language: result.language.isEmpty ? language : result.language,
      engine: result.engine.isEmpty ? _engine.id : result.engine,
      confidence: result.confidence,
      blocks: result.blocks,
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
    );
    _cache.put(book.id, pageNumber, stored);
    final store = _store;
    if (store != null) {
      try {
        await store.putPage(
          bookId: book.id,
          pageNumber: pageNumber,
          result: stored,
        );
      } on Object {
        // Persistence must never block reading; session cache still works.
      }
    }
    return stored;
  }

  /// Old word-level OCR caches make selection look fragmented; re-run OCR.
  bool _looksLikeFragmentedWordBoxes(OcrPageResult result) {
    final boxes = result.blocks
        .where((b) => b.hasGeometry)
        .toList(growable: false);
    if (boxes.length < 8) {
      return false;
    }
    var short = 0;
    for (final box in boxes) {
      final text = box.text.trim();
      final width = box.width ?? 0;
      if (text.length <= 4 || width < 0.12) {
        short += 1;
      }
    }
    return short / boxes.length >= 0.7;
  }
}
