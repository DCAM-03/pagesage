import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/ocr/method_channel_ocr_engine.dart';
import 'package:pagesage/core/ocr/method_channel_pdf_page_rasterizer.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_view.dart';

import '../tool/generate_manual_samples.dart';
import 'support/reader_harness.dart';

/// Run on an isolated Android target; no production library or AI requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File pdf;

  setUpAll(() async {
    if (!Platform.isAndroid) throw StateError('Android target required');
    directory = await Directory.systemTemp.createTemp('pagesage-platform-');
    pdf = await File('${directory.path}/中文 空格.pdf').writeAsBytes(
      buildTextPdf(['PageSage platform test', 'Second page', 'Third page']),
    );
  });
  tearDownAll(() async => directory.delete(recursive: true));

  testWidgets('native PDF raster and ML Kit OCR round trip', (tester) async {
    final rasterizer = MethodChannelPdfPageRasterizer();
    final image = await rasterizer.renderPage(
      filePath: pdf.path,
      pageNumber: 1,
      maxEdge: 1600,
      maxPixels: 2000000,
    );
    expect(image.width, inInclusiveRange(1, 1600));
    expect(image.height, inInclusiveRange(1, 1600));
    expect(image.width * image.height, lessThanOrEqualTo(2000000));
    expect(image.bytes.take(2), [0xff, 0xd8]);
    await expectLater(
      rasterizer.renderPage(filePath: pdf.path, pageNumber: 9999),
      throwsA(isA<OcrFailedException>()),
    );
    final engine = MethodChannelOcrEngine(id: 'mlkit');
    expect(await engine.isAvailable(), isTrue);
    expect(await engine.supportedLanguages(), containsAll(['zh-Hans', 'en']));
    for (final result in [
      await engine.recognize(imageBytes: image.bytes, languageHint: 'en'),
      await engine.recognizePdfPage(
        filePath: pdf.path,
        pageNumber: 1,
        languageHint: 'en',
      ),
    ]) {
      expect(result.text, contains('PageSage'));
      expect(result.engine, 'mlkit');
      expect(result.blocks, isNotEmpty);
      for (final block in result.blocks) {
        expect(block.left, inInclusiveRange(0, 1));
        expect(block.top, inInclusiveRange(0, 1));
        expect(block.width, inInclusiveRange(0, 1));
        expect(block.height, inInclusiveRange(0, 1));
      }
    }
    // A subsequent native request must survive the earlier page-range error.
    expect(
      (await rasterizer.renderPage(filePath: pdf.path, pageNumber: 2)).bytes,
      isNotEmpty,
    );
  });

  testWidgets('Android secure storage writes reads and deletes a test key', (
    tester,
  ) async {
    final storage = SecureStore();
    final key =
        'pagesage.platform-test.${DateTime.now().microsecondsSinceEpoch}';
    try {
      await storage.write(key, 'synthetic-test-value');
      expect(await storage.read(key), 'synthetic-test-value');
    } finally {
      await storage.delete(key);
    }
    expect(await storage.hasValue(key), isFalse);
  });

  testWidgets('Android SQLite FTS5 persists through a file reopen', (
    tester,
  ) async {
    final file = File('${directory.path}/platform.sqlite');
    var database = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await database.customStatement(
        'CREATE VIRTUAL TABLE platform_fts USING fts5(content)',
      );
      await database.customStatement(
        "INSERT INTO platform_fts VALUES ('PageSage offline reader')",
      );
    } finally {
      await database.close();
    }
    database = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final rows = await database
          .customSelect(
            "SELECT content FROM platform_fts WHERE platform_fts MATCH 'offline'",
          )
          .get();
      expect(rows.single.read<String>('content'), 'PageSage offline reader');
    } finally {
      await database.close();
    }
  });

  testWidgets(
    'Android export rejects a missing source without opening a picker',
    (tester) async {
      await expectLater(
        const MethodChannel(
          'pagesage/files',
        ).invokeMethod<String>('saveExport', {
          'sourcePath': '${directory.path}/missing.md',
          'name': 'test.md',
          'mimeType': 'text/markdown',
        }),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'file_not_found',
          ),
        ),
      );
    },
  );

  testWidgets(
    'Android PDF navigation saves progress and reopens the saved page',
    (tester) async {
      final harness = await ReaderHarness.create(
        books: [
          Book(
            id: 'android-pdf',
            title: 'Android platform sample',
            format: BookFormat.pdf,
            libraryFilePath: pdf.path,
            fileHash: 'platform-pdf',
            fileSize: await pdf.length(),
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
      );
      try {
        await harness.pumpReader(
          tester,
          'android-pdf',
          settings: const ReaderSettings(readerMode: ReaderMode.paged),
        );
        expect(find.byType(PdfCanvasView), findsOneWidget);
        expect(
          tester
              .widget<PdfCanvasView>(find.byType(PdfCanvasView))
              .settings
              .readerMode,
          ReaderMode.paged,
        );
        final width = tester.getSize(find.byType(PdfCanvasView)).width;
        await tester.drag(find.byType(PdfCanvasView), Offset(-width * 0.8, 0));
        await harness.settle(tester);
        await harness.closeReader(tester);
        await harness.settle(tester);
        final saved = await harness.database.progressDao.getProgress(
          'android-pdf',
        );
        expect(saved?.pageNumber, 2);
        await harness.pumpReader(tester, 'android-pdf');
        expect(find.byType(PdfCanvasView), findsOneWidget);
        expect(tester.takeException(), isNull);
        // The resumed renderer must emit its restored page into the same store.
        await harness.settle(tester);
        final restored = await harness.database.progressDao.getProgress(
          'android-pdf',
        );
        expect(restored?.pageNumber, 2);
      } finally {
        await harness.closeReader(tester);
        await harness.settle(tester);
        await harness.dispose();
      }
    },
  );
}
