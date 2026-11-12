import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/features/ocr/application/ocr_providers.dart';
import 'package:pagesage/features/reader/presentation/reader_desktop_toolbar.dart';
import 'package:pagesage/features/reader/presentation/reader_mobile_chrome.dart';
import 'package:pagesage/features/reader/presentation/reader_page.dart';
import 'package:pagesage/features/reader/presentation/reader_renderer_host.dart';
import 'package:pagesage/features/reader/presentation/reader_search_pane.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await database.bookDao.insertBook(
      BooksCompanion.insert(
        id: 'scanned',
        title: '扫描书',
        format: 'pdf',
        libraryFilePath: 'poc_pdf_canvas/samples/image-only.pdf',
        fileHash: 'scanned-revision',
        fileSize: 100,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        readerRendererHostProvider.overrideWithValue(
          (config) => _RecordingRenderer(config: config),
        ),
      ],
    );
    await container
        .read(settingsRepositoryProvider)
        .saveReaderSettings(const ReaderSettings(desktopTocOpen: false));
  });

  Future<void> indexOcr({bool geometry = true}) async {
    await container
        .read(ocrPageStoreProvider)
        .putPage(
          bookId: 'scanned',
          pageNumber: 1,
          result: OcrPageResult(
            text: '第四版前言，线性代数识别文本。',
            language: 'zh-Hans',
            engine: 'fixture',
            blocks: geometry
                ? const [
                    OcrTextBlock(
                      text: '第四版前言，线性代数识别文本。',
                      left: 0.1,
                      top: 0.2,
                      width: 0.7,
                      height: 0.1,
                    ),
                  ]
                : const [],
          ),
          sourceRevision: 'scanned-revision',
          cacheSignature: 'fixture-signature',
          textRevision: 'fixture-text',
        );
    final book = await container
        .read(bookRepositoryProvider)
        .getBook('scanned');
    await container.read(searchIndexerProvider).indexBook(book!);
  }

  ReaderRendererHostConfig config(WidgetTester tester) =>
      tester.widget<_RecordingRenderer>(find.byType(_RecordingRenderer)).config;

  void emitCapabilities(WidgetTester tester, {bool ocr = false}) {
    config(tester).onEvent(
      RendererCapabilityChanged(
        textSelection: ocr,
        search: false,
        nativeTextLayer: false,
        ocrTextLayer: ocr,
        reason: ocr ? null : '此 PDF 没有原生文本层',
      ),
    );
  }

  void entryTest(
    String description,
    Future<void> Function(WidgetTester) body, {
    Size size = const Size(1280, 900),
    bool recognized = true,
    bool geometry = true,
  }) {
    testWidgets(description, (tester) async {
      await tester.binding.setSurfaceSize(size);
      try {
        if (recognized) {
          await tester.runAsync(() => indexOcr(geometry: geometry));
        }
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: const MaterialApp(home: ReaderPage(bookId: 'scanned')),
            ),
          ),
        );
        await tester.runAsync(
          () => container.read(bookRepositoryProvider).getBook('scanned'),
        );
        await tester.pumpAndSettle();
        emitCapabilities(tester, ocr: recognized && geometry);
        await tester.pump();
        await body(tester);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
        await tester.runAsync(database.close);
        await tester.binding.setSurfaceSize(null);
      }
    });
  }

  Future<void> searchAndJump(WidgetTester tester) async {
    expect(find.byType(ReaderSearchPane), findsOneWidget);
    await tester.enterText(find.byType(TextField), '线性代数');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      await container
          .read(searchRepositoryProvider)
          .bookChunks(bookIds: const ['scanned']);
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('识别文本'), findsWidgets);
    expect(find.text('1/1'), findsOneWidget);
    final jumpToken = config(tester).jumpToken;
    await tester.tap(find.widgetWithText(FilledButton, '跳转'));
    await tester.pumpAndSettle();
    expect(config(tester).jumpToken, greaterThan(jumpToken));
    expect(config(tester).progress?.locator.page, 1);
  }

  Finder desktopSearch() => find.descendant(
    of: find.byType(ReaderDesktopToolbar),
    matching: find.byTooltip('搜索'),
  );

  entryTest('desktop search opens and locates persisted OCR text', (
    tester,
  ) async {
    await tester.tap(desktopSearch());
    await tester.pumpAndSettle();
    await searchAndJump(tester);
  });

  entryTest('Ctrl+F opens OCR search without native text', (tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await searchAndJump(tester);
  });

  entryTest('recognized page does not claim search is unavailable', (
    tester,
  ) async {
    expect(find.text('搜索不可用'), findsNothing);
  });

  entryTest(
    'text-only OCR remains searchable without a selectable overlay',
    (tester) async {
      await tester.tap(desktopSearch());
      await tester.pumpAndSettle();
      await searchAndJump(tester);
    },
    geometry: false,
  );

  entryTest('mobile search opens OCR results', (tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(MobileReaderBottomBar),
        matching: find.text('搜索'),
      ),
    );
    await tester.pumpAndSettle();
    await searchAndJump(tester);
  }, size: const Size(430, 900));

  entryTest('mobile more menu offers OCR search', (tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(MobileReaderBottomBar),
        matching: find.text('更多'),
      ),
    );
    await tester.pumpAndSettle();
    final searchItem = find.widgetWithText(ListTile, '书内搜索');
    await tester.ensureVisible(searchItem);
    await tester.tap(searchItem);
    await tester.pumpAndSettle();
    await searchAndJump(tester);
  }, size: const Size(430, 900));

  entryTest('native capability updates do not block newly indexed OCR', (
    tester,
  ) async {
    await tester.tap(desktopSearch());
    await tester.pumpAndSettle();
    expect(find.byType(ReaderSearchPane), findsOneWidget);
    await tester.enterText(find.byType(TextField), '线性代数');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      await container
          .read(searchRepositoryProvider)
          .bookChunks(bookIds: const ['scanned']);
    });
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配内容'), findsOneWidget);
    await tester.runAsync(indexOcr);
    emitCapabilities(tester);
    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();
    await tester.tap(desktopSearch());
    await tester.pumpAndSettle();
    await searchAndJump(tester);
  }, recognized: false);
}

final class _RecordingRenderer extends StatelessWidget {
  const _RecordingRenderer({required this.config});

  final ReaderRendererHostConfig config;

  @override
  Widget build(BuildContext context) => const Center(child: Text('扫描页面'));
}
