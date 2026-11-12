import 'dart:typed_data';

import '../../../core/ocr/ocr_cache_signature.dart';
import '../../../core/ocr/ocr_execution_gate.dart';
import '../../../core/ocr/ocr_timeline.dart';
import '../../../core/tasks/task_cancellation.dart';
import '../../../domain/books/book.dart';
import '../../../domain/ocr/ocr_capability.dart';
import '../../../domain/ocr/ocr_engine.dart';
import '../../../domain/ocr/ocr_models.dart';
import '../../../domain/ocr/pdf_page_rasterizer.dart';
import 'ocr_page_store.dart';
import 'ocr_session_cache.dart';

final class OcrCurrentPageUseCase {
  OcrCurrentPageUseCase({
    required this._rasterizer,
    required this._engine,
    required this._cache,
    OcrExecutionGate? executionGate,
    this._store,
    this._dpi = PdfPageRasterizer.defaultDpi,
    this._maxEdge = PdfPageRasterizer.defaultMaxEdge,
  }) : _executionGate = executionGate ?? OcrExecutionGate();

  final PdfPageRasterizer _rasterizer;
  final OcrEngine _engine;
  final OcrSessionCache _cache;
  final OcrExecutionGate _executionGate;
  final OcrPageStore? _store;
  final int _dpi;
  final int _maxEdge;

  /// Coalesce concurrent identical page requests (double-tap / rebuild).
  final Map<String, ({Future<OcrPageResult> future, TaskCancelToken? token})>
  _inFlight = {};

  Future<String> cacheSignatureFor(Book book, {String? languageHint}) async {
    final sourceRevision = book.fileHash.trim().isEmpty
        ? book.id
        : book.fileHash;
    final hint = (languageHint ?? book.language)?.trim();
    final requestedLanguage = (hint == null || hint.isEmpty) ? 'zh-Hans' : hint;
    return buildOcrCacheSignature(
      sourceRevision: sourceRevision,
      identity: await _cacheIdentity(requestedLanguage),
      dpi: _dpi,
      maxEdge: _maxEdge,
    );
  }

  /// Removes recognized pages from both process memory and durable storage.
  Future<void> discardCachedPages({
    required String bookId,
    required Iterable<int> pageNumbers,
  }) async {
    final pages = pageNumbers.toSet();
    if (pages.isEmpty) {
      return;
    }
    _cache.removePages(bookId, pages);
    await _store?.deletePages(bookId, pages);
  }

  /// Look up a previously recognized page without running OCR.
  Future<OcrPageResult?> peekCachedPage({
    required String bookId,
    required int pageNumber,
    String? cacheSignature,
  }) async {
    final memory = traceOcrSync(
      'ocr.cache.memory',
      () => _cache.get(bookId, pageNumber),
      arguments: {'page': pageNumber},
    );
    if (memory != null &&
        (cacheSignature == null ||
            memory.cacheSignature == cacheSignature ||
            memory.isLegacyOrUnverified)) {
      return memory;
    }
    final store = _store;
    if (store == null) {
      return null;
    }
    final disk = await traceOcrAsync(
      'ocr.cache.disk',
      () => store.getPage(bookId, pageNumber),
      arguments: {'page': pageNumber},
    );
    if (disk != null &&
        (cacheSignature == null ||
            disk.cacheSignature == cacheSignature ||
            disk.isLegacyOrUnverified)) {
      _cache.put(bookId, pageNumber, disk);
      return disk;
    }
    return null;
  }

  Future<OcrPageResult> recognizeCurrentPage({
    required Book book,
    required int pageNumber,
    String? languageHint,
    TaskCancelToken? cancelToken,
    bool forceRefresh = false,
    bool allowEmpty = false,
    bool requirePersistence = false,

    /// When set, OCR this display-space image instead of re-rendering the PDF
    /// natively. Geometry then matches the on-screen page box 1:1.
    Uint8List? displayImageBytes,
  }) {
    return traceOcrAsync(
      'ocr.page',
      () => _recognizeCurrentPage(
        book: book,
        pageNumber: pageNumber,
        languageHint: languageHint,
        cancelToken: cancelToken,
        forceRefresh: forceRefresh,
        allowEmpty: allowEmpty,
        requirePersistence: requirePersistence,
        displayImageBytes: displayImageBytes,
      ),
      arguments: {
        'page': pageNumber,
        'forceRefresh': forceRefresh,
        'hasDisplayImage': displayImageBytes?.isNotEmpty ?? false,
      },
    );
  }

  Future<OcrPageResult> _recognizeCurrentPage({
    required Book book,
    required int pageNumber,
    String? languageHint,
    TaskCancelToken? cancelToken,
    bool forceRefresh = false,
    bool allowEmpty = false,
    bool requirePersistence = false,
    Uint8List? displayImageBytes,
  }) async {
    cancelToken?.throwIfCancelled();
    if (book.format != BookFormat.pdf) {
      throw const OcrFailedException('仅支持 PDF 页面识别');
    }
    if (pageNumber < 1) {
      throw const OcrFailedException('页码无效');
    }
    if (requirePersistence && _store == null) {
      throw StateError('OCR 批处理需要可用的本地结果存储');
    }

    final sourceRevision = book.fileHash.trim().isEmpty
        ? book.id
        : book.fileHash;
    final hint = (languageHint ?? book.language)?.trim();
    final requestedLanguage = (hint == null || hint.isEmpty) ? 'zh-Hans' : hint;
    final identity = await _cacheIdentity(requestedLanguage);
    final cacheSignature = buildOcrCacheSignature(
      sourceRevision: sourceRevision,
      identity: identity,
      dpi: _dpi,
      maxEdge: _maxEdge,
    );

    if (!forceRefresh) {
      final cached = requirePersistence
          ? await _store!.getPage(book.id, pageNumber)
          : await peekCachedPage(
              bookId: book.id,
              pageNumber: pageNumber,
              cacheSignature: cacheSignature,
            );
      cancelToken?.throwIfCancelled();
      // Prefer continuous line-level geometry for selection. Old word-box
      // caches make temporary selection look like fragmented per-glyph islands.
      if (cached != null &&
          !_looksLikeFragmentedWordBoxes(cached) &&
          (allowEmpty || cached.hasText) &&
          _cacheIsUsable(
            cached,
            expectedSignature: cacheSignature,
            languageHint: languageHint,
          )) {
        return cached;
      }
    }

    final flightKey = '${book.id}:$pageNumber:${identity.resolvedLanguage}';
    final requestKey = '$flightKey:$allowEmpty:$requirePersistence';
    if (!forceRefresh) {
      final existing = _inFlight[requestKey];
      if (existing != null && !(existing.token?.isCancelled ?? false)) {
        cancelToken?.throwIfCancelled();
        if (cancelToken == null) return existing.future;
        return Future.any([
          existing.future,
          cancelToken.whenCancelled.then<OcrPageResult>((_) {
            throw const TaskCancelledException();
          }),
        ]);
      }
    }

    final future = _executionGate.run(
      cancelToken: cancelToken,
      operation: () => _recognizeUncached(
        book: book,
        pageNumber: pageNumber,
        languageHint: languageHint,
        cancelToken: cancelToken,
        displayImageBytes: displayImageBytes,
        sourceRevision: sourceRevision,
        cacheSignature: cacheSignature,
        identity: identity,
        allowEmpty: allowEmpty,
        requirePersistence: requirePersistence,
      ),
    );
    _inFlight[requestKey] = (future: future, token: cancelToken);
    try {
      return await future;
    } finally {
      if (identical(_inFlight[requestKey]?.future, future)) {
        _inFlight.remove(requestKey);
      }
    }
  }

  Future<OcrPageResult> _recognizeUncached({
    required Book book,
    required int pageNumber,
    String? languageHint,
    TaskCancelToken? cancelToken,
    Uint8List? displayImageBytes,
    required String sourceRevision,
    required String cacheSignature,
    required OcrCacheIdentity identity,
    required bool allowEmpty,
    required bool requirePersistence,
  }) async {
    cancelToken?.throwIfCancelled();
    final available = await traceOcrAsync('ocr.engine.available', () async {
      if (_engine case OcrCapabilitySource source) {
        final capability = await source.capability();
        if (!capability.isAvailable) {
          final code = switch (capability.status) {
            OcrCapabilityStatus.engineMissing => 'ocr_engine_missing',
            OcrCapabilityStatus.languageMissing => 'ocr_language_missing',
            OcrCapabilityStatus.unsupportedVersion => 'ocr_unsupported_version',
            _ => 'ocr_probe_failed',
          };
          throw OcrUnavailableException(capability.message, code);
        }
        return true;
      }
      return _engine.isAvailable();
    }, arguments: {'engine': _engine.id});
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
      result = await traceOcrAsync(
        'ocr.engine.image',
        () => _engine.recognize(
          imageBytes: displayBytes,
          languageHint: language,
          cancelled: cancelToken?.whenCancelled,
        ),
        arguments: {'source': 'display', 'bytes': displayBytes.length},
      );
    } else if (_engine.supportsPdfPageOcr) {
      // Fallback: native PDF re-render (may disagree with PDF.js layout).
      result = await traceOcrAsync(
        'ocr.engine.nativePdfPage',
        () => _engine.recognizePdfPage(
          filePath: book.libraryFilePath,
          pageNumber: pageNumber,
          languageHint: language,
          dpi: _dpi,
          maxEdge: _maxEdge,
        ),
        arguments: {'page': pageNumber, 'dpi': _dpi, 'maxEdge': _maxEdge},
      );
    } else {
      final image = await traceOcrAsync(
        'ocr.rasterize',
        () => _rasterizer.renderPage(
          filePath: book.libraryFilePath,
          pageNumber: pageNumber,
          dpi: _dpi,
          maxEdge: _maxEdge,
        ),
        arguments: {'page': pageNumber, 'dpi': _dpi},
      );
      cancelToken?.throwIfCancelled();
      result = await traceOcrAsync(
        'ocr.engine.image',
        () => _engine.recognize(
          imageBytes: image.bytes,
          languageHint: language,
          cancelled: cancelToken?.whenCancelled,
        ),
        arguments: {
          'source': 'raster',
          'bytes': image.bytes.length,
          'width': image.width,
          'height': image.height,
        },
      );
    }
    cancelToken?.throwIfCancelled();

    final normalized = result.text.trim();

    final stored = OcrPageResult(
      text: normalized,
      language: result.language.isEmpty ? language : result.language,
      engine: result.engine.isEmpty ? _engine.id : result.engine,
      confidence: result.confidence,
      blocks: result.blocks,
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
      sourceRevision: sourceRevision,
      cacheSignature: cacheSignature,
      textRevision: buildOcrTextRevision(
        sourceRevision: sourceRevision,
        text: normalized,
      ),
      engineVersion: identity.engineVersion,
      pipelineVersion: ocrTextPipelineVersion,
      resultState: normalized.isEmpty ? 'empty' : 'recognized',
      indexState: normalized.isEmpty ? 'notApplicable' : 'pending',
    );
    final store = _store;
    var persisted = false;
    if (store != null) {
      try {
        await traceOcrAsync(
          'ocr.persist',
          () => store.putPage(
            bookId: book.id,
            pageNumber: pageNumber,
            result: stored,
            sourceRevision: stored.sourceRevision,
            cacheSignature: stored.cacheSignature,
            textRevision: stored.textRevision,
            engineVersion: stored.engineVersion,
            pipelineVersion: stored.pipelineVersion ?? ocrTextPipelineVersion,
            resultState: stored.resultState,
            indexState: stored.indexState,
          ),
          arguments: {'page': pageNumber},
        );
        persisted = true;
      } on Object catch (error, stackTrace) {
        if (requirePersistence) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    }
    if (requirePersistence && !persisted) {
      throw StateError('OCR 结果未能写入本地存储');
    }
    if (normalized.isNotEmpty) {
      _cache.put(book.id, pageNumber, stored);
    }
    if (normalized.isEmpty && !allowEmpty) {
      throw const OcrEmptyResultException();
    }
    return stored;
  }

  Future<OcrCacheIdentity> _cacheIdentity(String languageHint) async {
    final engine = _engine;
    if (engine is OcrCacheIdentitySource) {
      return (engine as OcrCacheIdentitySource).cacheIdentity(
        languageHint: languageHint,
      );
    }
    return OcrCacheIdentity(
      engineId: engine.id,
      resolvedLanguage: languageHint,
    );
  }

  bool _cacheIsUsable(
    OcrPageResult cached, {
    required String expectedSignature,
    required String? languageHint,
  }) {
    if (cached.cacheSignature == expectedSignature &&
        cached.resultState != 'legacy') {
      return true;
    }
    // Keep old rows useful for the reading overlay. They are never consumed by
    // search unless a new signed recognition has replaced them, and an
    // explicit language request must not silently reuse a different model.
    return cached.isLegacyOrUnverified && languageHint == null;
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
