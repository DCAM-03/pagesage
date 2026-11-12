import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/ocr/ocr_engine.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/features/ocr/application/ocr_page_controller.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:pagesage/features/ocr/application/ocr_providers.dart';
import 'package:pagesage/features/reader/application/reader_ocr_coordinator.dart';

void main() {
  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'disposal' : 'cancel'} signals the engine and ignores its late result',
      () async {
        final engine = _PendingEngine();
        final store = MemoryOcrPageStore();
        final container = ProviderContainer(
          overrides: [
            ocrEngineProvider.overrideWithValue(engine),
            ocrPageStoreProvider.overrideWithValue(store),
          ],
        );
        final subscription = container.listen(
          ocrPageControllerProvider(_book.id),
          (_, next) {},
        );
        final controller = container.read(
          ocrPageControllerProvider(_book.id).notifier,
        );
        final pending = controller.recognize(
          book: _book,
          pageNumber: 1,
          displayImageBytes: Uint8List.fromList([1, 2, 3]),
        );
        final signal = await engine.started.future;
        expect(signal, isNotNull);
        if (dispose) {
          container.dispose();
        } else {
          controller.cancel();
        }
        await signal;
        engine.result.complete(
          const OcrPageResult(text: 'late', language: 'eng', engine: 'fake'),
        );
        expect(await pending, isNull);
        expect(await store.getPage(_book.id, 1), isNull);
        if (!dispose) {
          expect(
            container.read(ocrPageControllerProvider(_book.id)).phase,
            OcrPagePhase.idle,
          );
          subscription.close();
          container.dispose();
        }
      },
    );
  }

  test('releasing the reader coordinator cancels its active OCR', () async {
    final engine = _PendingEngine();
    final store = MemoryOcrPageStore();
    final container = ProviderContainer(
      overrides: [
        ocrEngineProvider.overrideWithValue(engine),
        ocrPageStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      readerOcrCoordinatorProvider(_book.id),
      (_, next) {},
    );
    final controller = container.read(
      ocrPageControllerProvider(_book.id).notifier,
    );
    final pending = controller.recognize(
      book: _book,
      pageNumber: 1,
      displayImageBytes: Uint8List.fromList([1, 2, 3]),
    );
    final signal = await engine.started.future;
    subscription.close();
    await container.pump();
    await signal;
    engine.result.complete(
      const OcrPageResult(text: 'late', language: 'eng', engine: 'fake'),
    );
    expect(await pending, isNull);
    expect(await store.getPage(_book.id, 1), isNull);
  });
}

const _book = Book(
  id: 'pending-ocr',
  title: 'Synthetic',
  format: BookFormat.pdf,
  libraryFilePath: '/unused.pdf',
  fileHash: 'synthetic',
  fileSize: 0,
  createdAt: 1,
  updatedAt: 1,
);

final class _PendingEngine implements OcrEngine {
  final started = Completer<Future<void>?>();
  final result = Completer<OcrPageResult>();

  @override
  String get id => 'fake';

  @override
  bool get supportsPdfPageOcr => false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<String>> supportedLanguages() async => ['eng'];

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  }) {
    started.complete(cancelled);
    return result.future;
  }

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) => throw UnimplementedError();
}
