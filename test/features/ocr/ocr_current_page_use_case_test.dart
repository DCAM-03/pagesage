import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/domain/books/book.dart';
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

final class _FakeEngine implements OcrEngine {
  _FakeEngine({
    required this.text,
    this.available = true,
    this.supportsPdf = true,
    this.delay = Duration.zero,
  });

  final String text;
  final bool available;
  final bool supportsPdf;
  final Duration delay;
  int pdfPageCalls = 0;
  int imageCalls = 0;

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
  }) async {
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
