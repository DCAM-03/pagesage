import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/ocr/ocr_engine.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:pagesage/features/ocr/application/ocr_pipeline_policy.dart';
import 'package:pagesage/features/ocr/application/ocr_providers.dart';
import 'package:pagesage/features/reader/application/reader_ocr_coordinator.dart';
import 'package:pagesage/renderers/pdf/pdf_page_image_source.dart';

void main() {
  test(
    'visible pages fall back when the renderer cannot report them',
    () async {
      final coordinator = _coordinator();

      expect(
        await coordinator.visiblePages(
          fallbackPage: 7,
          pageSource: _FakePageSource(visible: const [3, 3, 4, 0]),
        ),
        [3, 4],
      );
      expect(
        await coordinator.visiblePages(
          fallbackPage: 7,
          pageSource: _FakePageSource(visible: const []),
        ),
        [7],
      );
      expect(
        await coordinator.visiblePages(
          fallbackPage: 7,
          pageSource: _FakePageSource(failVisible: true),
        ),
        [7],
      );
      expect(await coordinator.visiblePages(fallbackPage: 7), [7]);
    },
  );

  test('recognizes visible pages and retries an empty export', () async {
    final source = _FakePageSource(
      visible: const [3, 4],
      exports: {
        3: [
          null,
          Uint8List.fromList([3]),
        ],
        4: [
          Uint8List.fromList([4]),
        ],
      },
    );
    final coordinator = _coordinator(
      recognizePages:
          ({
            required Book book,
            required List<int> pageNumbers,
            String? languageHint,
            bool forceRefresh = false,
            Future<Uint8List?> Function(int pageNumber)? exportPage,
          }) async {
            expect(forceRefresh, isFalse);
            return [
              for (final page in pageNumbers)
                if (await exportPage!(page) case final bytes?)
                  (
                    page: page,
                    result: OcrPageResult(
                      text: 'page $page: ${bytes.single}',
                      language: 'en',
                      engine: 'fake',
                    ),
                  ),
            ];
          },
    );

    final results = await coordinator.recognizePages(
      book: _pdfBook(),
      pageNumbers: const [3, 4],
      pageSource: source,
    );

    expect(source.exportCalls, [3, 3, 4]);
    expect(results.map((result) => result.page), [3, 4]);
    expect(results.map((result) => result.result.text), [
      'page 3: 3',
      'page 4: 4',
    ]);
  });

  test('passes no export callback without a page source', () async {
    var exportPageWasNull = false;
    final coordinator = _coordinator(
      recognizePages:
          ({
            required Book book,
            required List<int> pageNumbers,
            String? languageHint,
            bool forceRefresh = false,
            Future<Uint8List?> Function(int pageNumber)? exportPage,
          }) async {
            exportPageWasNull = exportPage == null;
            return const [];
          },
    );

    await coordinator.recognizePages(book: _pdfBook(), pageNumbers: const [1]);

    expect(exportPageWasNull, isTrue);
  });

  test('restores only unseen pages with complete geometry', () async {
    final coordinator = _coordinator(
      peekPage: ({required pageNumber}) async {
        return switch (pageNumber) {
          1 => _result('one', blocks: [_block('one')]),
          2 => _result('two', blocks: [_block('two')]),
          3 => _result('three'),
          _ => null,
        };
      },
    );

    final overlays = await coordinator.restoreOverlays(
      fallbackPage: 2,
      pageSource: _FakePageSource(visible: const [1, 2, 3]),
      isRestored: (page) => page == 1,
    );

    expect(overlays, hasLength(1));
    expect(overlays.single.page, 2);
    expect(overlays.single.blocks.single.text, 'two');
  });

  test('stops restoring when the reader has moved on', () async {
    var cacheReads = 0;
    final coordinator = _coordinator(
      peekPage: ({required pageNumber}) async {
        cacheReads += 1;
        return _result('$pageNumber', blocks: [_block('$pageNumber')]);
      },
    );

    final overlays = await coordinator.restoreOverlays(
      fallbackPage: 1,
      pageSource: _FakePageSource(visible: const [1, 2]),
      isRestored: (_) => false,
      isCurrent: () => cacheReads == 0,
    );

    expect(overlays, isEmpty);
    expect(cacheReads, 1);
  });

  test('provider wires the coordinator to the book OCR controller', () async {
    final container = ProviderContainer(
      overrides: [
        ocrEngineProvider.overrideWithValue(_FakeOcrEngine()),
        ocrPageStoreProvider.overrideWithValue(MemoryOcrPageStore()),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      readerOcrCoordinatorProvider('book-ocr'),
      (_, next) {},
    );
    addTearDown(subscription.close);
    final coordinator = subscription.read();
    final results = await coordinator.recognizePages(
      book: _pdfBook(),
      pageNumbers: const [1],
    );

    expect(results.single.page, 1);
    expect(results.single.result.text, 'provider text');
  });

  test('native benchmark policy skips the display export', () async {
    final engine = _FakeOcrEngine();
    final source = _FakePageSource(visible: const [1]);
    final container = ProviderContainer(
      overrides: [
        ocrEngineProvider.overrideWithValue(engine),
        ocrPageStoreProvider.overrideWithValue(MemoryOcrPageStore()),
        ocrPipelinePolicyProvider.overrideWithValue(
          const OcrPipelinePolicy(preferNativePdfPage: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      readerOcrCoordinatorProvider('book-ocr'),
      (_, next) {},
    );
    addTearDown(subscription.close);
    final coordinator = subscription.read();
    await coordinator.recognizePages(
      book: _pdfBook(),
      pageNumbers: const [1],
      pageSource: source,
    );

    expect(source.exportCalls, isEmpty);
    expect(engine.pdfPageCalls, 1);
    expect(engine.imageCalls, 0);
  });
}

ReaderOcrCoordinator _coordinator({
  ReaderOcrRecognizePages? recognizePages,
  ReaderOcrPeekPage? peekPage,
}) {
  return ReaderOcrCoordinator(
    recognizePageBatch:
        recognizePages ??
        ({
          required Book book,
          required List<int> pageNumbers,
          String? languageHint,
          bool forceRefresh = false,
          Future<Uint8List?> Function(int pageNumber)? exportPage,
        }) async => const [],
    peekPage: peekPage ?? ({required pageNumber}) async => null,
  );
}

Book _pdfBook() {
  return const Book(
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

OcrPageResult _result(String text, {List<OcrTextBlock> blocks = const []}) {
  return OcrPageResult(
    text: text,
    language: 'en',
    engine: 'fake',
    blocks: blocks,
  );
}

OcrTextBlock _block(String text) {
  return OcrTextBlock(
    text: text,
    left: 0.1,
    top: 0.1,
    width: 0.2,
    height: 0.05,
  );
}

final class _FakePageSource implements PdfPageImageSource {
  _FakePageSource({
    this.visible = const [1],
    this.failVisible = false,
    Map<int, List<Uint8List?>>? exports,
  }) : exports = exports ?? {};

  final List<int> visible;
  final bool failVisible;
  final Map<int, List<Uint8List?>> exports;
  final List<int> exportCalls = [];

  @override
  Future<Uint8List?> exportPageImage({
    required int pageNumber,
    double quality = 0.86,
  }) async {
    exportCalls.add(pageNumber);
    final queued = exports[pageNumber];
    if (queued == null || queued.isEmpty) {
      return Uint8List.fromList([pageNumber]);
    }
    return queued.removeAt(0);
  }

  @override
  Future<Uint8List?> exportPageRegion({
    required int pageNumber,
    required ReaderRect rect,
  }) async => null;

  @override
  Future<List<int>> getVisiblePages({int? fallbackPage}) async {
    if (failVisible) {
      throw StateError('renderer unavailable');
    }
    return visible;
  }
}

final class _FakeOcrEngine implements OcrEngine {
  int pdfPageCalls = 0;
  int imageCalls = 0;

  @override
  String get id => 'fake-provider';

  @override
  bool get supportsPdfPageOcr => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<String>> supportedLanguages() async => const ['en'];

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  }) async {
    imageCalls += 1;
    return _result('provider text');
  }

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) async {
    pdfPageCalls += 1;
    return _result('provider text');
  }
}
