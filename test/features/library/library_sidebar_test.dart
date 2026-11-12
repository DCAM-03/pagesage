import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/pagesage_app.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/category.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/library/application/library_controller.dart';
import 'package:pagesage/features/library/application/library_providers.dart';
import 'package:pagesage/features/library/presentation/library_page.dart';
import 'package:pagesage/features/settings/application/settings_providers.dart';
import 'package:pagesage/features/tasks/application/task_center_controller.dart';

void main() {
  Future<ProviderContainer> pumpLibrary(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 960);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryBooksProvider.overrideWith((ref) => Stream.value(_books)),
          categoriesProvider.overrideWith((ref) => Stream.value(_categories)),
          tagsProvider.overrideWith((ref) => Stream.value([])),
          readerSettingsProvider.overrideWith(
            (ref) => Stream.value(const ReaderSettings()),
          ),
          taskListProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const RepaintBoundary(
          key: ValueKey('library-sidebar-capture'),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(LibraryPage));
    expect(MediaQuery.sizeOf(element).width, 1440);
    expect(find.byTooltip('收起书库分类'), findsOneWidget);
    return ProviderScope.containerOf(element);
  }

  testWidgets('folding releases width and preserves expanded directories', (
    tester,
  ) async {
    final container = await pumpLibrary(tester);
    final sidebar = find.byKey(const ValueKey('library-category-sidebar'));
    final gridWidth = tester.getSize(find.byType(GridView)).width;

    await tester.tap(
      find.descendant(of: sidebar, matching: find.byTooltip('展开文件夹')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sidebar, matching: find.text('Dart 学习')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('收起书库分类'));
    await tester.pumpAndSettle();

    expect(sidebar, findsNothing);
    expect(
      container.read(libraryControllerProvider).categorySidebarOpen,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(GridView)).width,
      closeTo(gridWidth + 249, 1),
    );
    await tester.tap(find.byTooltip('展开书库分类'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sidebar, matching: find.text('Dart 学习')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sidebar, matching: find.byTooltip('折叠文件夹')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed filters stay usable after an empty result', (
    tester,
  ) async {
    final container = await pumpLibrary(tester);
    await tester.tap(find.byTooltip('收起书库分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('阅读状态：全部'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<LibrarySystemFilter>, '未读'),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(libraryControllerProvider).systemFilter,
      LibrarySystemFilter.unread,
    );
    expect(find.byTooltip('阅读状态：未读'), findsOneWidget);
    await tester.tap(find.byTooltip('书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dart 学习').last);
    await tester.pumpAndSettle();
    expect(container.read(libraryControllerProvider).categoryId, 'dart');
    expect(find.byTooltip('Dart 学习'), findsOneWidget);

    await tester.tap(find.byTooltip('阅读状态：未读'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<LibrarySystemFilter>, '已读'),
    );
    await tester.pumpAndSettle();
    expect(find.text('没有符合筛选条件的书籍'), findsOneWidget);
    expect(find.byTooltip('展开书库分类'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    final state = container.read(libraryControllerProvider);
    expect(state.systemFilter, LibrarySystemFilter.all);
    expect(state.categoryId, isNull);
    expect(state.categorySidebarOpen, isFalse);
    expect(find.text('没有符合筛选条件的书籍'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing preserves the desktop fold choice', (tester) async {
    final container = await pumpLibrary(tester);
    await tester.tap(find.byTooltip('收起书库分类'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(800, 900);
    await tester.pumpAndSettle();
    expect(find.byTooltip('展开书库分类'), findsNothing);
    expect(find.text('全部'), findsWidgets);
    expect(
      container.read(libraryControllerProvider).categorySidebarOpen,
      isFalse,
    );

    tester.view.physicalSize = const Size(1024, 760);
    await tester.pumpAndSettle();
    expect(find.byTooltip('展开书库分类'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-category-sidebar')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('展开书库分类'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('收起书库分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures sidebar layouts when requested', (tester) async {
    if (!const bool.fromEnvironment('UPDATE_PAGESAGE_SCREENSHOTS')) {
      return;
    }
    final fontFile = File(
      '/usr/share/fonts/google-noto-sans-cjk-vf-fonts/NotoSansCJK-VF.ttc',
    );
    final artifacts = Directory(
      Platform.resolvedExecutable,
    ).parent.parent.parent;
    final iconFile = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    );
    for (final entry in {
      'Roboto': fontFile,
      'MaterialIcons': iconFile,
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(ByteData.sublistView(entry.value.readAsBytesSync())),
          ))
          .load();
    }
    await pumpLibrary(tester);
    for (final width in [1440.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      await _capture(tester, 'library-sidebar-${width.toInt()}-expanded');
      await tester.tap(find.byTooltip('收起书库分类'));
      await tester.pumpAndSettle();
      await _capture(tester, 'library-sidebar-${width.toInt()}-collapsed');
      if (width == 1024) {
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await _capture(tester, 'library-sidebar-1024-large-text');
      } else {
        await tester.tap(find.byTooltip('展开书库分类'));
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('library-sidebar-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('.codex-run/ui-screenshots/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

const _categories = [
  BookCategory(
    id: 'programming',
    name: '编程',
    sortOrder: 0,
    createdAt: 1,
    updatedAt: 1,
  ),
  BookCategory(
    id: 'dart',
    parentId: 'programming',
    name: 'Dart 学习',
    sortOrder: 1,
    createdAt: 1,
    updatedAt: 1,
  ),
];

const _books = [
  LibraryBook(
    book: Book(
      id: 'guide',
      title: 'Dart 阅读指南',
      format: BookFormat.markdown,
      libraryFilePath: '/fixtures/guide.md',
      fileHash: 'guide-hash',
      fileSize: 100,
      categoryId: 'dart',
      createdAt: 1,
      updatedAt: 1,
    ),
  ),
  LibraryBook(
    book: Book(
      id: 'notes',
      title: '阅读与记录',
      format: BookFormat.markdown,
      libraryFilePath: '/fixtures/notes.md',
      fileHash: 'notes-hash',
      fileSize: 100,
      readStatus: ReadStatus.finished,
      createdAt: 1,
      updatedAt: 1,
    ),
  ),
];
