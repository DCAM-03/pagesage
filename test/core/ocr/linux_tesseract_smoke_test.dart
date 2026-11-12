import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/ocr/linux_tesseract_ocr_engine.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/features/ocr/application/ocr_page_controller.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:pagesage/features/ocr/application/ocr_providers.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_renderer.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  final imagePath = Platform.environment['PAGESAGE_OCR_SMOKE_IMAGE'];
  final chinesePath = Platform.environment['PAGESAGE_OCR_SMOKE_CHINESE_IMAGE'];
  final pdfPath = Platform.environment['PAGESAGE_OCR_SMOKE_PDF'];
  final enabled = Platform.isLinux && imagePath != null;
  test(
    'real Linux current-page controller recognizes and restores persisted line geometry',
    () async {
      final image = await File(imagePath!).readAsBytes();
      final directory = await Directory.systemTemp.createTemp(
        'pagesage_smoke_db_',
      );
      final file = File('${directory.path}/ocr.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      await database.bookDao.insertBook(
        BooksCompanion.insert(
          id: _book.id,
          title: _book.title,
          format: 'pdf',
          libraryFilePath: _book.libraryFilePath,
          fileHash: _book.fileHash,
          fileSize: 0,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      final store = DriftOcrPageStore(database.ocrPageDao);
      final container = ProviderContainer(
        overrides: [ocrPageStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        ocrPageControllerProvider(_book.id),
        (_, next) {},
      );
      addTearDown(subscription.close);
      final engine = container.read(ocrEngineProvider);
      expect(engine, isA<LinuxTesseractOcrEngine>());
      expect(await engine.isAvailable(), isTrue);
      expect(
        await engine.supportedLanguages(),
        containsAll(['eng', 'chi_sim']),
      );
      final recognized = await container
          .read(ocrPageControllerProvider(_book.id).notifier)
          .recognize(book: _book, pageNumber: 1, displayImageBytes: image);
      expect(recognized, isNotNull);
      final result = recognized!;
      expect(result.text, contains('PageSage'));
      expect(result.text, contains('Local reading'));
      expect(result.hasGeometry, isTrue);
      expect(
        result.blocks.every(
          (block) =>
              block.left! >= 0 &&
              block.top! >= 0 &&
              block.left! + block.width! <= 1 &&
              block.top! + block.height! <= 1,
        ),
        isTrue,
      );
      expect(
        container.read(ocrPageControllerProvider(_book.id)).phase,
        OcrPagePhase.success,
      );
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      final restored = await DriftOcrPageStore(
        database.ocrPageDao,
      ).getPage(_book.id, 1);
      expect(restored?.text, result.text);
      expect(restored?.language, 'eng');
      expect(restored?.imageWidth, result.imageWidth);
      expect(
        restored?.blocks.map((block) => block.toJson()),
        result.blocks.map((block) => block.toJson()),
      );
    },
    skip: !enabled,
  );

  test(
    'real Chinese image recognition returns Chinese text with line geometry',
    () async {
      final engine = LinuxTesseractOcrEngine();
      final result = await engine.recognize(
        imageBytes: await File(chinesePath!).readAsBytes(),
        languageHint: 'zh-Hans',
      );
      expect(result.text, contains('中文内容'));
      expect(result.language, 'chi_sim+eng');
      expect(result.hasGeometry, isTrue);
    },
    skip: !enabled || chinesePath == null,
  );

  test(
    'real PDF canvas export feeds the Linux current-page controller',
    () async {
      final renderer = PdfCanvasRenderer(
        PdfDocument.open(await File(pdfPath!).readAsBytes()),
      );
      addTearDown(renderer.dispose);
      expect(await renderer.hasTextLayerAsync(), isFalse);
      final container = ProviderContainer(
        overrides: [
          ocrPageStoreProvider.overrideWithValue(MemoryOcrPageStore()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        ocrPageControllerProvider(_book.id),
        (_, next) {},
      );
      addTearDown(subscription.close);
      final results = await container
          .read(ocrPageControllerProvider(_book.id).notifier)
          .recognizePages(
            book: _book,
            pageNumbers: [1],
            exportPage: (page) async {
              final bytes = await renderer.exportPageImage(page - 1);
              if (bytes != null) {
                await File(
                  '${File(imagePath!).parent.path}/pdf-export.png',
                ).writeAsBytes(bytes);
              }
              return bytes;
            },
          );
      expect(
        results,
        hasLength(1),
        reason: container
            .read(ocrPageControllerProvider(_book.id))
            .errorMessage,
      );
      expect(results.single.result.text, contains('PageSage'));
      expect(results.single.result.hasGeometry, isTrue);
    },
    skip: !enabled || pdfPath == null,
  );
}

const _book = Book(
  id: 'synthetic-ocr',
  title: 'Synthetic OCR',
  format: BookFormat.pdf,
  libraryFilePath: '/unused/synthetic.pdf',
  fileHash: 'synthetic',
  fileSize: 0,
  language: 'en',
  createdAt: 1,
  updatedAt: 1,
);
