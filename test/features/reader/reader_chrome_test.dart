import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/features/reader/presentation/reader_chrome.dart';
import 'package:pagesage/features/reader/presentation/reader_desktop_toolbar.dart';
import 'package:pagesage/features/reader/presentation/reader_pdf_toolbar.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  setUpAll(() async {
    if (captureWorkbench) {
      await loadWorkbenchCaptureFonts();
    }
  });

  Future<void> pumpToolbar(
    WidgetTester tester, {
    double width = 1440,
    double textScale = 1,
    bool dark = false,
    VoidCallback? onAction,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final action = onAction ?? () {};
    final theme = dark ? AppTheme.dark() : AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: captureWorkbench
            ? theme.copyWith(
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                    fontFamily: 'Segoe UI',
                  ),
                ),
              )
            : theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: workbenchCaptureKey, child: child!),
        ),
        home: Scaffold(
          appBar: ReaderDesktopToolbar(
            title: '一本包含很长书名的阅读器工具栏布局验证样本 / Markdown、EPUB 与 PDF',
            tocOpen: true,
            activeContextTab: ReaderContextTab.notebook,
            bookmarked: true,
            onBack: action,
            onToc: action,
            onSearch: action,
            onBookmark: action,
            onNotebook: action,
            onAi: action,
            onSettings: action,
            onMore: (_) => action(),
            moreItems: (_) => const [
              PopupMenuItem(
                value: ReaderMoreAction.quickTheme,
                child: Text('阅读主题与界面颜色'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(Scaffold))).width,
      width,
    );
  }

  for (final scenario in [
    (width: 600.0, scale: 1.0, dark: false),
    (width: 900.0, scale: 1.0, dark: false),
    (width: 1024.0, scale: 1.5, dark: false),
    (width: 1440.0, scale: 1.0, dark: false),
    (width: 1440.0, scale: 2.0, dark: true),
  ]) {
    testWidgets('desktop toolbar fits $scenario and keeps every action', (
      tester,
    ) async {
      var actions = 0;
      await pumpToolbar(
        tester,
        width: scenario.width,
        textScale: scenario.scale,
        dark: scenario.dark,
        onAction: () => actions += 1,
      );
      expect(tester.takeException(), isNull);
      for (final label in ['返回书库', '收起目录', '搜索', '取消书签', '笔记', 'AI', '设置']) {
        await tester.tap(find.byTooltip(label));
        await tester.pump();
      }
      expect(actions, 7);
      await tester.tap(find.byTooltip('更多阅读操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('阅读主题与界面颜色'));
      await tester.pumpAndSettle();
      expect(actions, 8);
      final buttons = tester.widgetList<ReaderToolbarButton>(
        find.byType(ReaderToolbarButton),
      );
      expect(
        buttons
            .where((button) => button.selected)
            .map((button) => button.label),
        ['收起目录', '取消书签', '笔记'],
      );
      expect(buttons.map((button) => button.showLabel).toSet(), hasLength(1));
      if (scenario.width == 600) {
        expect(buttons.every((button) => !button.showLabel), isTrue);
      }
      if (scenario.width == 1440 && scenario.scale == 1) {
        expect(buttons.every((button) => button.showLabel), isTrue);
      }
      await captureWorkbenchWidget(
        tester,
        'reader-toolbar-${scenario.width.toInt()}-${scenario.scale}-${scenario.dark}',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('narrow PDF toolbar keeps collapse fixed and page tools usable', (
    tester,
  ) async {
    var collapsed = false;
    var fitPage = false;
    var ocr = false;
    var rangeOcr = false;
    var bookOcr = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: RepaintBoundary(key: workbenchCaptureKey, child: child!),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: PdfQuickToolbar(
                pageNumber: 38,
                totalPages: 206,
                settings: const ReaderSettings(),
                textLayerAvailable: false,
                searchAvailable: false,
                capabilityReason: '测试无文本层',
                onPageJump: () {},
                onZoomOut: () {},
                onZoomIn: () {},
                onFitWidth: () {},
                onFitPage: () => fitPage = true,
                onOcrPage: () => ocr = true,
                onOcrRange: () => rangeOcr = true,
                onOcrBook: () => bookOcr = true,
                onCollapse: () => collapsed = true,
              ),
            ),
          ),
        ),
      ),
    );
    final collapse = find.byIcon(Icons.keyboard_arrow_up);
    final collapsePosition = tester.getCenter(collapse);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing);
    await tester.ensureVisible(find.byIcon(Icons.fullscreen_outlined));
    await tester.tap(find.byIcon(Icons.fullscreen_outlined));
    await tester.ensureVisible(find.text('识别文字'));
    await tester.tap(find.text('识别文字'));
    expect(find.text('识别范围'), findsNothing);
    expect(find.text('识别整本'), findsNothing);
    await tester.tap(find.byTooltip('更多识别操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('识别范围'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多识别操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('识别整本'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(collapse), collapsePosition);
    await tester.tap(collapse);
    expect(fitPage, isTrue);
    expect(ocr, isTrue);
    expect(rangeOcr, isTrue);
    expect(bookOcr, isTrue);
    expect(collapsed, isTrue);
    await tester.pumpAndSettle();
    await captureWorkbenchWidget(tester, 'reader-toolbar-pdf-narrow');
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('wide PDF OCR uses one split control (dark=$dark)', (
      tester,
    ) async {
      var pages = 0;
      var ranges = 0;
      var books = 0;
      final menuStates = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) =>
              RepaintBoundary(key: workbenchCaptureKey, child: child!),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 760,
                child: PdfQuickToolbar(
                  pageNumber: 18,
                  totalPages: 410,
                  settings: const ReaderSettings(),
                  onPageJump: () {},
                  onZoomOut: () {},
                  onZoomIn: () {},
                  onFitWidth: () {},
                  onFitPage: () {},
                  onOcrPage: () => pages += 1,
                  onOcrRange: () => ranges += 1,
                  onOcrBook: () => books += 1,
                  onOcrMenuChanged: menuStates.add,
                  onCollapse: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('识别文字'), findsOneWidget);
      expect(find.text('识别范围'), findsNothing);
      expect(find.text('识别整本'), findsNothing);
      await captureWorkbenchWidget(tester, 'pdf-ocr-split-$dark');
      await tester.tap(find.text('识别文字'));
      expect(pages, 1);
      expect(menuStates, isEmpty);
      await tester.tap(find.byTooltip('更多识别操作'));
      await tester.pumpAndSettle();
      expect(menuStates, [true]);
      await captureWorkbenchWidget(tester, 'pdf-ocr-menu-$dark');
      await tester.tap(find.text('识别范围'));
      await tester.pumpAndSettle();
      expect(ranges, 1);
      expect(books, 0);
      expect(menuStates, [true, false]);
      await tester.tap(find.byTooltip('更多识别操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('识别整本'));
      await tester.pumpAndSettle();
      expect(books, 1);
      await tester.tap(find.byTooltip('更多识别操作'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(menuStates, [true, false, true, false, true, false]);
      expect(pages, 1);
      expect(ranges, 1);
      expect(books, 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('reader action snackbar is transient and compact', () {
    final desktopSnack = readerActionSnackBar(
      message: '已添加书签',
      actionLabel: '添加备注',
      onAction: () {},
      compact: false,
    );
    final compactSnack = readerActionSnackBar(
      message: '已添加书签',
      actionLabel: '添加备注',
      onAction: () {},
      compact: true,
    );

    expect(desktopSnack.persist, isFalse);
    expect(desktopSnack.duration, const Duration(seconds: 4));
    expect(desktopSnack.width, 420);
    expect(desktopSnack.margin, isNull);
    expect(compactSnack.persist, isFalse);
    expect(compactSnack.width, isNull);
    expect(compactSnack.margin, isNotNull);
  });

  test('reader snackbars use the quiet surface treatment', () {
    final theme = AppTheme.light();

    expect(
      theme.snackBarTheme.backgroundColor,
      theme.colorScheme.surface,
      reason: 'reader feedback should not be a full-width black inverse bar',
    );
    expect(
      theme.snackBarTheme.backgroundColor,
      isNot(theme.colorScheme.inverseSurface),
    );
    expect(theme.snackBarTheme.actionTextColor, theme.colorScheme.primary);
  });

  testWidgets('PDF toolbar exposes collapse and reveal actions', (
    tester,
  ) async {
    var collapsed = false;
    var revealed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PdfQuickToolbar(
                pageNumber: 38,
                totalPages: 206,
                settings: const ReaderSettings(),
                onPageJump: () {},
                onZoomOut: () {},
                onZoomIn: () {},
                onFitWidth: () {},
                onFitPage: () {},
                onCollapse: () => collapsed = true,
              ),
              PdfQuickToolbarReveal(
                pageNumber: 38,
                totalPages: 206,
                onReveal: () => revealed = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.tap(find.byType(PdfQuickToolbarReveal));

    expect(collapsed, isTrue);
    expect(revealed, isTrue);
    expect(find.text('38 / 206'), findsNWidgets(2));
  });
}
