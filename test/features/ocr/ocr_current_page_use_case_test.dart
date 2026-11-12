import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/ocr/ocr_capability.dart';
import 'package:pagesage/domain/ocr/ocr_engine.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/domain/ocr/pdf_page_rasterizer.dart';
import 'package:pagesage/features/ocr/application/ocr_current_page_use_case.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:pagesage/features/ocr/application/ocr_session_cache.dart';

void main() {
  test('recognizes page and caches result', () async {
    final rasterizer = _FakeRasterizer();
    final engine = _FakeEngine(text: '  Hello OCR  ');
    final cache = OcrSessionCache();
    final store = MemoryOcrPageStore();
    final useCase = OcrCurrentPageUseCase(
      rasterizer: rasterizer,
      engine: engine,
      cache: cache,
      store: store,
    );
    final book = _pdfBook();

    final first = await useCase.recognizeCurrentPage(book: book, pageNumber: 2);
    final second = await useCase.recognizeCurrentPage(
      book: book,
      pageNumber: 2,
    );

    expect(first.text, 'Hello OCR');
    expect(second.text, 'Hello OCR');
    expect(first.hasGeometry, isTrue);
    expect(rasterizer.calls, 0);
    expect(engine.pdfPageCalls, 1);
    expect(engine.imageCalls, 0);
    expect(cache.get(book.id, 2)?.text, 'Hello OCR');
    expect((await store.getPage(book.id, 2))?.text, 'Hello OCR');
  });

  test('restores page from disk store when session cache is cold', () async {
    final engine = _FakeEngine(text: 'From disk');
    final store = MemoryOcrPageStore();
    final book = _pdfBook();
    await store.putPage(
      bookId: book.id,
      pageNumber: 4,
      result: _result('From disk'),
    );
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: OcrSessionCache(),
      store: store,
    );

    final result = await useCase.recognizeCurrentPage(
      book: book,
      pageNumber: 4,
    );

    expect(result.text, 'From disk');
    expect(engine.pdfPageCalls, 0);
  });

  test('uses raster fallback when pdf-page OCR unsupported', () async {
    final rasterizer = _FakeRasterizer();
    final engine = _FakeEngine(text: 'Fallback', supportsPdf: false);
    final useCase = OcrCurrentPageUseCase(
      rasterizer: rasterizer,
      engine: engine,
      cache: OcrSessionCache(),
    );

    final result = await useCase.recognizeCurrentPage(
      book: _pdfBook(),
      pageNumber: 1,
    );

    expect(result.text, 'Fallback');
    expect(rasterizer.calls, 1);
    expect(engine.imageCalls, 1);
    expect(engine.pdfPageCalls, 0);
  });

  test('prefers the display image when one is provided', () async {
    final rasterizer = _FakeRasterizer();
    final engine = _FakeEngine(text: 'Visible page');
    final useCase = OcrCurrentPageUseCase(
      rasterizer: rasterizer,
      engine: engine,
      cache: OcrSessionCache(),
    );

    final result = await useCase.recognizeCurrentPage(
      book: _pdfBook(),
      pageNumber: 5,
      displayImageBytes: Uint8List.fromList(const [1, 2, 3, 4]),
    );

    expect(result.text, 'Visible page');
    expect(engine.imageCalls, 1);
    expect(engine.pdfPageCalls, 0);
    expect(rasterizer.calls, 0);
  });

  test('passes configured native raster settings to the engine', () async {
    final engine = _FakeEngine(text: 'Native settings');
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: OcrSessionCache(),
      dpi: 180,
      maxEdge: 1800,
    );

    await useCase.recognizeCurrentPage(book: _pdfBook(), pageNumber: 1);

    expect(engine.lastDpi, 180);
    expect(engine.lastMaxEdge, 1800);
  });

  test('dedupes concurrent requests for the same page', () async {
    final engine = _FakeEngine(
      text: 'Shared',
      delay: const Duration(milliseconds: 40),
    );
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: OcrSessionCache(),
    );
    final book = _pdfBook();

    final results = await Future.wait([
      useCase.recognizeCurrentPage(book: book, pageNumber: 3),
      useCase.recognizeCurrentPage(book: book, pageNumber: 3),
      useCase.recognizeCurrentPage(book: book, pageNumber: 3),
    ]);

    expect(results.map((r) => r.text), everyElement('Shared'));
    expect(engine.pdfPageCalls, 1);
  });

  test('serializes rasterization across different OCR pages', () async {
    final rasterizer = _BlockingRasterizer();
    final useCase = OcrCurrentPageUseCase(
      rasterizer: rasterizer,
      engine: _FakeEngine(text: 'Serialized', supportsPdf: false),
      cache: OcrSessionCache(),
    );
    final book = _pdfBook();

    final first = useCase.recognizeCurrentPage(book: book, pageNumber: 1);
    await rasterizer.firstStarted.future;
    final second = useCase.recognizeCurrentPage(book: book, pageNumber: 2);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(rasterizer.calls, 1);
    expect(rasterizer.maxActive, 1);

    rasterizer.releaseFirst.complete();
    await Future.wait([first, second]);

    expect(rasterizer.calls, 2);
    expect(rasterizer.maxActive, 1);
  });

  test('durable OCR does not report success when persistence fails', () async {
    final store = _FailingOcrPageStore();
    final cache = OcrSessionCache();
    final engine = _FakeEngine(text: 'Durable result');
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: cache,
      store: store,
    );
    final book = _pdfBook();

    await expectLater(
      useCase.recognizeCurrentPage(
        book: book,
        pageNumber: 8,
        requirePersistence: true,
      ),
      throwsStateError,
    );
    expect(cache.get(book.id, 8), isNull);

    store.failWrites = false;
    final retried = await useCase.recognizeCurrentPage(
      book: book,
      pageNumber: 8,
      requirePersistence: true,
    );

    expect(retried.text, 'Durable result');
    expect(engine.pdfPageCalls, 2);
    expect(await store.getPage(book.id, 8), isNotNull);
  });

  test('session cache is LRU and bounded', () {
    final cache = OcrSessionCache(maxEntries: 2);
    cache.put('a', 1, _result('1'));
    cache.put('a', 2, _result('2'));
    cache.put('a', 3, _result('3'));
    expect(cache.get('a', 1), isNull);
    expect(cache.get('a', 2)?.text, '2');
    // Touch 2 so 3 is older next eviction.
    cache.put('a', 4, _result('4'));
    expect(cache.get('a', 3), isNull);
    expect(cache.get('a', 2)?.text, '2');
    expect(cache.get('a', 4)?.text, '4');
  });

  test('throws when cancelled before work', () async {
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: 'x'),
      cache: OcrSessionCache(),
    );
    final token = TaskCancelToken()..cancel();

    await expectLater(
      useCase.recognizeCurrentPage(
        book: _pdfBook(),
        pageNumber: 1,
        cancelToken: token,
      ),
      throwsA(isA<TaskCancelledException>()),
    );
  });

  test('throws empty result when OCR text is blank', () async {
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: '   '),
      cache: OcrSessionCache(),
    );

    await expectLater(
      useCase.recognizeCurrentPage(book: _pdfBook(), pageNumber: 1),
      throwsA(isA<OcrEmptyResultException>()),
    );
  });

  test('throws when engine is unavailable', () async {
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: 'x', available: false),
      cache: OcrSessionCache(),
    );

    await expectLater(
      useCase.recognizeCurrentPage(book: _pdfBook(), pageNumber: 1),
      throwsA(isA<OcrUnavailableException>()),
    );
  });

  test('cancelled cached requests do not return a success', () async {
    final cache = OcrSessionCache()..put('book-ocr', 1, _result('old'));
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: 'new'),
      cache: cache,
    );
    await expectLater(
      useCase.recognizeCurrentPage(
        book: _pdfBook(),
        pageNumber: 1,
        cancelToken: TaskCancelToken()..cancel(),
      ),
      throwsA(isA<TaskCancelledException>()),
    );
  });

  test(
    'explicit language requests do not reuse an unversioned page cache',
    () async {
      final cache = OcrSessionCache()..put('book-ocr', 1, _result('old'));
      final engine = _FakeEngine(text: 'new');
      final useCase = OcrCurrentPageUseCase(
        rasterizer: _FakeRasterizer(),
        engine: engine,
        cache: cache,
      );
      final result = await useCase.recognizeCurrentPage(
        book: _pdfBook(),
        pageNumber: 1,
        languageHint: 'eng',
      );
      expect(result.text, 'new');
      expect(engine.pdfPageCalls, 1);
    },
  );

  test(
    'cancellation reaches the image engine and prevents cache or disk writes',
    () async {
      final started = Completer<Future<void>?>();
      final engine = _FakeEngine(
        text: 'late result',
        supportsPdf: false,
        delay: const Duration(milliseconds: 20),
        onImageStarted: started.complete,
      );
      final cache = OcrSessionCache();
      final store = MemoryOcrPageStore();
      final token = TaskCancelToken();
      final useCase = OcrCurrentPageUseCase(
        rasterizer: _FakeRasterizer(),
        engine: engine,
        cache: cache,
        store: store,
      );
      final assertion = expectLater(
        useCase.recognizeCurrentPage(
          book: _pdfBook(),
          pageNumber: 1,
          cancelToken: token,
        ),
        throwsA(isA<TaskCancelledException>()),
      );
      final signal = await started.future;
      expect(signal, isNotNull);
      token.cancel();
      await signal;
      await assertion;
      expect(cache.get('book-ocr', 1), isNull);
      expect(await store.getPage('book-ocr', 1), isNull);
    },
  );

  test(
    'a fresh request does not join the cancelled previous page request',
    () async {
      final started = Completer<void>();
      final engine = _FakeEngine(
        text: 'fresh',
        supportsPdf: false,
        delay: const Duration(milliseconds: 20),
        onImageStarted: (_) {
          if (!started.isCompleted) started.complete();
        },
      );
      final useCase = OcrCurrentPageUseCase(
        rasterizer: _FakeRasterizer(),
        engine: engine,
        cache: OcrSessionCache(),
      );
      final token = TaskCancelToken();
      final previous = expectLater(
        useCase.recognizeCurrentPage(
          book: _pdfBook(),
          pageNumber: 1,
          cancelToken: token,
        ),
        throwsA(isA<TaskCancelledException>()),
      );
      await started.future;
      token.cancel();
      final fresh = await useCase.recognizeCurrentPage(
        book: _pdfBook(),
        pageNumber: 1,
      );
      await previous;
      expect(fresh.text, 'fresh');
      expect(engine.imageCalls, 2);
    },
  );

  test(
    'capability failures preserve an actionable message and error code',
    () async {
      final useCase = OcrCurrentPageUseCase(
        rasterizer: _FakeRasterizer(),
        engine: _UnavailableCapabilityEngine(),
        cache: OcrSessionCache(),
      );
      await expectLater(
        useCase.recognizeCurrentPage(book: _pdfBook(), pageNumber: 1),
        throwsA(
          isA<OcrUnavailableException>()
              .having(
                (error) => error.message,
                'message',
                contains('configs/tsv'),
              )
              .having((error) => error.code, 'code', 'ocr_probe_failed'),
        ),
      );
    },
  );

  test('persists a signed, restorable recognition and reuses it', () async {
    final store = MemoryOcrPageStore();
    final engine = _FakeEngine(text: 'Signed result');
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: OcrSessionCache(),
      store: store,
    );
    final book = _pdfBook();

    final first = await useCase.recognizeCurrentPage(book: book, pageNumber: 2);
    expect(first.cacheSignature, isNotEmpty);
    expect(first.sourceRevision, 'hash');
    expect(first.textRevision, isNotEmpty);
    expect(first.resultState, 'recognized');
    expect(first.pipelineVersion, 'ocr-text-v1');

    final stored = await store.getPage(book.id, 2);
    expect(stored?.cacheSignature, first.cacheSignature);
    expect(stored?.sourceRevision, 'hash');
    expect(stored?.indexState, 'pending');

    final freshUseCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: 'Should not run'),
      cache: OcrSessionCache(),
      store: store,
    );
    final restored = await freshUseCase.recognizeCurrentPage(
      book: book,
      pageNumber: 2,
    );
    expect(restored.text, 'Signed result');
  });

  test('empty OCR is a cached completion when allowEmpty is set', () async {
    final store = MemoryOcrPageStore();
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: '   '),
      cache: OcrSessionCache(),
      store: store,
    );
    final book = _pdfBook();

    final result = await useCase.recognizeCurrentPage(
      book: book,
      pageNumber: 3,
      allowEmpty: true,
    );
    expect(result.text, isEmpty);
    expect(result.resultState, 'empty');
    expect(result.indexState, 'notApplicable');
    final stored = await store.getPage(book.id, 3);
    expect(stored?.resultState, 'empty');
  });

  test('a changed source revision invalidates a signed cache row', () async {
    final store = MemoryOcrPageStore();
    final useCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: _FakeEngine(text: 'old'),
      cache: OcrSessionCache(),
      store: store,
    );
    final book = _pdfBook();
    await useCase.recognizeCurrentPage(book: book, pageNumber: 1);

    final changedBook = Book(
      id: book.id,
      title: book.title,
      format: book.format,
      libraryFilePath: book.libraryFilePath,
      fileHash: 'hash-new',
      fileSize: book.fileSize,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
    );
    final engine = _FakeEngine(text: 'new');
    final freshUseCase = OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: OcrSessionCache(),
      store: store,
    );
    final result = await freshUseCase.recognizeCurrentPage(
      book: changedBook,
      pageNumber: 1,
    );
    expect(result.text, 'new');
    expect(engine.pdfPageCalls, 1);
  });
}

Book _pdfBook() {
  return Book(
    id: 'book-ocr',
    title: 'Scan',
    format: BookFormat.pdf,
    libraryFilePath: r'C:\tmp\scan.pdf',
    fileHash: 'hash',
    fileSize: 10,
    createdAt: 1,
    updatedAt: 1,
  );
}

OcrPageResult _result(String text) {
  return OcrPageResult(text: text, language: 'zh-Hans', engine: 'fake');
}

final class _FakeRasterizer implements PdfPageRasterizer {
  int calls = 0;

  @override
  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
    int maxPixels = 5000000,
  }) async {
    calls += 1;
    return PdfPageImage(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      width: 10,
      height: 10,
      pageNumber: pageNumber,
      dpi: dpi,
    );
  }
}

final class _BlockingRasterizer implements PdfPageRasterizer {
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  var calls = 0;
  var active = 0;
  var maxActive = 0;

  @override
  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
    int maxPixels = 5000000,
  }) async {
    calls += 1;
    active += 1;
    if (active > maxActive) maxActive = active;
    try {
      if (calls == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      return PdfPageImage(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        width: 10,
        height: 10,
        pageNumber: pageNumber,
        dpi: dpi,
      );
    } finally {
      active -= 1;
    }
  }
}

final class _FailingOcrPageStore implements OcrPageStore {
  final Map<int, OcrPageResult> pages = {};
  bool failWrites = true;

  @override
  Future<OcrPageResult?> getPage(String bookId, int pageNumber) async {
    return pages[pageNumber];
  }

  @override
  Future<List<OcrStoredPage>> listPages(String bookId) async => [
    for (final entry in pages.entries)
      OcrStoredPage(pageNumber: entry.key, result: entry.value),
  ];

  @override
  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
    String? sourceRevision,
    String? cacheSignature,
    String? textRevision,
    String? engineVersion,
    String pipelineVersion = 'ocr-text-v1',
    String resultState = 'recognized',
    String indexState = 'pending',
  }) async {
    if (failWrites) throw StateError('disk write failed');
    pages[pageNumber] = result;
  }

  @override
  Future<void> deleteBook(String bookId) async => pages.clear();

  @override
  Future<void> deletePages(String bookId, Iterable<int> pageNumbers) async {
    for (final pageNumber in pageNumbers) {
      pages.remove(pageNumber);
    }
  }
}

class _FakeEngine implements OcrEngine {
  _FakeEngine({
    required this.text,
    this.available = true,
    this.supportsPdf = true,
    this.delay = Duration.zero,
    this.onImageStarted,
  });

  final String text;
  final bool available;
  final bool supportsPdf;
  final Duration delay;
  final void Function(Future<void>?)? onImageStarted;
  int pdfPageCalls = 0;
  int imageCalls = 0;
  int? lastDpi;
  int? lastMaxEdge;

  @override
  String get id => 'fake';

  @override
  bool get supportsPdfPageOcr => supportsPdf;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<String>> supportedLanguages() async => const ['zh-Hans'];

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  }) async {
    onImageStarted?.call(cancelled);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    imageCalls += 1;
    return OcrPageResult(text: text, language: languageHint, engine: id);
  }

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) async {
    lastDpi = dpi;
    lastMaxEdge = maxEdge;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    pdfPageCalls += 1;
    return OcrPageResult(
      text: text,
      language: languageHint,
      engine: id,
      blocks: [
        const OcrTextBlock(
          text: 'Hello',
          left: 0.1,
          top: 0.1,
          width: 0.3,
          height: 0.05,
        ),
      ],
      imageWidth: 1000,
      imageHeight: 1400,
    );
  }
}

final class _UnavailableCapabilityEngine extends _FakeEngine
    implements OcrCapabilitySource {
  _UnavailableCapabilityEngine() : super(text: 'unused');

  @override
  Future<OcrCapability> capability({bool refresh = false}) async =>
      OcrCapability(
        status: OcrCapabilityStatus.probeFailed,
        message: '缺少 configs/tsv 输出配置',
      );
}
