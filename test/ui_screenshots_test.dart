import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/platform/platform_providers.dart';
import 'package:pagesage/core/platform/window_drop_import_service.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/bookmark.dart';
import 'package:pagesage/domain/books/category.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/domain/books/tag.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/library/presentation/library_page.dart';
import 'package:pagesage/features/notes/presentation/notes_page.dart';
import 'package:pagesage/features/reader/presentation/reader_page.dart';
import 'package:pagesage/features/search/presentation/search_page.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';
import 'package:pagesage/features/tasks/presentation/task_center_page.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';

const _updateScreenshots = bool.fromEnvironment('UPDATE_PAGESAGE_SCREENSHOTS');
const _screenshotFilter = String.fromEnvironment('PAGESAGE_SCREENSHOT_FILTER');

void main() {
  testWidgets('captures controlled UI screenshots when explicitly requested', (
    tester,
  ) async {
    if (!_updateScreenshots) {
      return;
    }
    // ignore: avoid_print
    print('Screenshot run started. filter=$_screenshotFilter');

    final outputDir = Directory('.codex-run/ui-screenshots').absolute;
    outputDir.createSync(recursive: true);
    // ignore: avoid_print
    print('Output dir ready: ${outputDir.path}');

    final samplesDir = Directory('.codex-run/samples');
    final epubPath = '${samplesDir.path}${Platform.pathSeparator}standard.epub';
    final pdfPath =
        '${samplesDir.path}${Platform.pathSeparator}standard-text.pdf';
    if (!File(epubPath).existsSync() || !File(pdfPath).existsSync()) {
      throw StateError(
        '请先运行 dart run tool/generate_manual_samples.dart 生成 .codex-run/samples。',
      );
    }
    // ignore: avoid_print
    print('Samples ready');
    final books = _sampleBooks(epubPath: epubPath, pdfPath: pdfPath);
    final notes = _sampleNotes();
    final tasks = _sampleTasks();
    final data = _ScreenshotData(books: books, notes: notes, tasks: tasks);

    await _captureIfSelected(
      tester,
      fileName: 'desktop-1440-library.png',
      size: const Size(1440, 960),
      route: '/library',
      outputDir: outputDir,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'desktop-1024-search.png',
      size: const Size(1024, 760),
      route: '/search',
      outputDir: outputDir,
      data: data,
      afterPump: (tester) async {
        await tester.enterText(find.byType(SearchBar), 'PageSage local-first');
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
    await _captureIfSelected(
      tester,
      fileName: 'desktop-1024-notes.png',
      size: const Size(1024, 760),
      route: '/notes',
      outputDir: outputDir,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'desktop-768-settings.png',
      size: const Size(768, 760),
      route: '/settings',
      outputDir: outputDir,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'desktop-768-tasks.png',
      size: const Size(768, 760),
      route: '/tasks',
      outputDir: outputDir,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'desktop-600-library-large-text.png',
      size: const Size(600, 760),
      route: '/library',
      outputDir: outputDir,
      textScale: 1.25,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'mobile-360-library-large-text.png',
      size: const Size(360, 720),
      route: '/library',
      outputDir: outputDir,
      textScale: 1.35,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'mobile-360-notes-large-text.png',
      size: const Size(360, 720),
      route: '/notes',
      outputDir: outputDir,
      textScale: 1.35,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'mobile-412-library-large-text.png',
      size: const Size(412, 820),
      route: '/library',
      outputDir: outputDir,
      textScale: 1.25,
      data: data,
    );
    await _captureIfSelected(
      tester,
      fileName: 'theme-dark-library.png',
      size: const Size(1024, 760),
      route: '/library',
      outputDir: outputDir,
      data: data.copyWith(
        settings: const ReaderSettings(appThemeMode: ThemeMode.dark),
      ),
    );
    await _captureIfSelected(
      tester,
      fileName: 'theme-high-contrast-search.png',
      size: const Size(1024, 760),
      route: '/search',
      outputDir: outputDir,
      highContrast: true,
      data: data.copyWith(
        settings: const ReaderSettings(
          appThemeMode: ThemeMode.light,
          themePreset: ReaderThemePreset.contrast,
        ),
      ),
      afterPump: (tester) async {
        await tester.enterText(find.byType(SearchBar), 'PageSage');
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
    await _captureIfSelected(
      tester,
      fileName: 'reader-epub-desktop.png',
      size: const Size(1440, 960),
      route: '/book/book-epub/reader',
      outputDir: outputDir,
      data: data.copyWith(
        settings: const ReaderSettings(desktopContextOpen: true),
      ),
      settle: const Duration(seconds: 2),
    );
    await _captureIfSelected(
      tester,
      fileName: 'reader-pdf-desktop.png',
      size: const Size(1440, 960),
      route: '/book/book-pdf/reader',
      outputDir: outputDir,
      data: data.copyWith(
        settings: const ReaderSettings(desktopContextOpen: true),
      ),
      settle: const Duration(seconds: 2),
    );
    await _captureIfSelected(
      tester,
      fileName: 'mobile-360-reader-ai-large-text.png',
      size: const Size(360, 640),
      route: '/book/book-epub/reader',
      outputDir: outputDir,
      textScale: 1.5,
      data: data,
      settle: const Duration(milliseconds: 250),
      afterPump: (tester) async {
        await tester.tap(find.text('AI'));
        await tester.pumpAndSettle();
      },
    );
    await _captureIfSelected(
      tester,
      fileName: 'reader-theme-paper-epub.png',
      size: const Size(1024, 760),
      route: '/renderer/epub',
      outputDir: outputDir,
      data: data.copyWith(
        settings: const ReaderSettings(themePreset: ReaderThemePreset.paper),
      ),
      settle: const Duration(seconds: 2),
    );
    await _captureIfSelected(
      tester,
      fileName: 'reader-theme-green-epub.png',
      size: const Size(1024, 760),
      route: '/renderer/epub',
      outputDir: outputDir,
      data: data.copyWith(
        settings: const ReaderSettings(themePreset: ReaderThemePreset.green),
      ),
      settle: const Duration(seconds: 2),
    );
    await _captureIfSelected(
      tester,
      fileName: 'reader-theme-ink-epub.png',
      size: const Size(1024, 760),
      route: '/renderer/epub',
      outputDir: outputDir,
      data: data.copyWith(
        settings: const ReaderSettings(themePreset: ReaderThemePreset.ink),
      ),
      settle: const Duration(seconds: 2),
    );
    await _captureIfSelected(
      tester,
      fileName: 'reader-theme-contrast-epub.png',
      size: const Size(1024, 760),
      route: '/renderer/epub',
      outputDir: outputDir,
      highContrast: true,
      data: data.copyWith(
        settings: const ReaderSettings(themePreset: ReaderThemePreset.contrast),
      ),
      settle: const Duration(seconds: 2),
    );
  });
}

Future<void> _captureIfSelected(
  WidgetTester tester, {
  required String fileName,
  required Size size,
  required String route,
  required Directory outputDir,
  required _ScreenshotData data,
  double textScale = 1,
  bool highContrast = false,
  Duration settle = const Duration(milliseconds: 150),
  Future<void> Function(WidgetTester tester)? afterPump,
}) async {
  if (_screenshotFilter.isNotEmpty && !fileName.contains(_screenshotFilter)) {
    return;
  }
  // Keep this visible in explicit screenshot runs; it helps identify the page
  // that failed without affecting normal tests.
  // ignore: avoid_print
  print('Capturing $fileName');
  await _captureAppPage(
    tester,
    fileName: fileName,
    size: size,
    route: route,
    outputDir: outputDir,
    data: data,
    textScale: textScale,
    highContrast: highContrast,
    settle: settle,
    afterPump: afterPump,
  );
}

Future<void> _captureAppPage(
  WidgetTester tester, {
  required String fileName,
  required Size size,
  required String route,
  required Directory outputDir,
  required _ScreenshotData data,
  double textScale = 1,
  bool highContrast = false,
  Duration settle = const Duration(milliseconds: 150),
  Future<void> Function(WidgetTester tester)? afterPump,
}) async {
  await tester.binding.setSurfaceSize(size);
  final key = GlobalKey();
  // ignore: avoid_print
  print('Pump app $fileName');
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(data),
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          highContrast: highContrast,
        ),
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            title: 'PageSage',
            debugShowCheckedModeBanner: false,
            theme: highContrast ? AppTheme.highContrast() : AppTheme.light(),
            darkTheme: AppTheme.dark(),
            highContrastTheme: AppTheme.highContrast(),
            highContrastDarkTheme: AppTheme.highContrast(),
            themeMode: data.settings.appThemeMode,
            home: _pageForRoute(route, data),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(settle);
  if (route.startsWith('/book/') || route == '/renderer/epub') {
    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  if (afterPump != null) {
    // ignore: avoid_print
    print('After pump $fileName');
    await afterPump(tester);
    await tester.pump(settle);
  }

  expect(tester.takeException(), isNull);
  // ignore: avoid_print
  print('Write $fileName');
  await _writeBoundaryPng(key, File('${outputDir.path}/$fileName'));
  // ignore: avoid_print
  print('Done $fileName');
}

Widget _pageForRoute(String route, _ScreenshotData data) {
  return switch (route) {
    '/search' => const SearchPage(),
    '/notes' => const NotesPage(),
    '/tasks' => const TaskCenterPage(),
    '/settings' => const SettingsPage(),
    '/book/book-epub/reader' => const ReaderPage(bookId: 'book-epub'),
    '/book/book-pdf/reader' => const ReaderPage(bookId: 'book-pdf'),
    '/renderer/epub' => _ReaderThemeScreenshot(data: data),
    _ => const LibraryPage(),
  };
}

final class _ReaderThemeScreenshot extends StatelessWidget {
  const _ReaderThemeScreenshot({required this.data});

  final _ScreenshotData data;

  @override
  Widget build(BuildContext context) {
    final settings = data.settings;
    final preset = settings.themePreset;
    final highlight = preset == ReaderThemePreset.contrast
        ? const Color(0xFFFFFF00)
        : const Color(0xFFF2D96B);
    return Scaffold(
      backgroundColor: preset.background,
      body: SafeArea(
        child: ColoredBox(
          color: preset.background,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(settings.pageMargin + 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: preset.foreground,
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: preset.link, width: 1.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            preset.label,
                            style: TextStyle(
                              color: preset.link,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '本地优先阅读样章',
                        style: TextStyle(
                          color: preset.foreground,
                          fontSize: settings.fontSize + 10,
                          fontWeight: FontWeight.w700,
                          height: 1.24,
                        ),
                      ),
                      SizedBox(height: settings.paragraphSpacing + 4),
                      const Text(
                        'PageSage 的阅读器主题需要让正文、链接、搜索命中和标注同时保持清晰。这个受控样张用于截图回归，避免主题截图只停留在加载态。',
                      ),
                      SizedBox(height: settings.paragraphSpacing),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '用户选中的关键句会被保留为 '),
                            TextSpan(
                              text: '高亮标注',
                              style: TextStyle(
                                backgroundColor: highlight,
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '，同时链接颜色需要和正文有明确区分。'),
                          ],
                        ),
                      ),
                      SizedBox(height: settings.paragraphSpacing),
                      Text(
                        'pagesage.local/reader-theme',
                        style: TextStyle(
                          color: preset.link,
                          decoration: TextDecoration.underline,
                          decorationColor: preset.link,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _writeBoundaryPng(GlobalKey key, File file) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  file.writeAsBytesSync(bytes!.buffer.asUint8List(), flush: true);
}

// Riverpod 3 keeps Override internal while ProviderScope still requires it.
// Let the context infer the exact list type at the call site.
// ignore: strict_top_level_inference
_overrides(_ScreenshotData data) {
  return [
    bookRepositoryProvider.overrideWithValue(_FakeBookRepository(data.books)),
    settingsRepositoryProvider.overrideWithValue(
      _FakeSettingsRepository(data.settings),
    ),
    aiSettingsRepositoryProvider.overrideWithValue(
      const _FakeAiSettingsRepository(),
    ),
    taskRepositoryProvider.overrideWithValue(_FakeTaskRepository(data.tasks)),
    categoryRepositoryProvider.overrideWithValue(
      const _FakeCategoryRepository(),
    ),
    tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
    bookmarkRepositoryProvider.overrideWithValue(
      _FakeBookmarkRepository(_sampleBookmarks()),
    ),
    annotationRepositoryProvider.overrideWithValue(
      _FakeAnnotationRepository(_sampleAnnotations()),
    ),
    noteRepositoryProvider.overrideWithValue(_FakeNoteRepository(data.notes)),
    searchRepositoryProvider.overrideWithValue(const _FakeSearchRepository()),
    aiConversationRepositoryProvider.overrideWithValue(
      _FakeAiConversationRepository(_sampleConversations()),
    ),
    readerRendererHostProvider.overrideWithValue(
      (config) => _FakeReaderRendererHost(config: config),
    ),
    windowDropImportServiceProvider.overrideWithValue(
      WindowDropImportService(
        channel: const MethodChannel('pagesage/test_window_drop'),
      ),
    ),
  ];
}

final class _FakeReaderRendererHost extends StatefulWidget {
  const _FakeReaderRendererHost({required this.config});

  final ReaderRendererHostConfig config;

  @override
  State<_FakeReaderRendererHost> createState() =>
      _FakeReaderRendererHostState();
}

final class _FakeReaderRendererHostState
    extends State<_FakeReaderRendererHost> {
  bool _sent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sent) {
      return;
    }
    _sent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final book = widget.config.book;
      widget.config.onEvent(
        RendererLocationChanged(
          locator: book.format == BookFormat.pdf
              ? ReadingLocator.pdf(
                  page: 3,
                  progress: 0.58,
                  excerpt: 'PDF 页面片段用于验证 AI 上下文范围和搜索入口。',
                )
              : ReadingLocator.epub(
                  href: 'chapter2.xhtml',
                  chapterIndex: 1,
                  progress: 0.42,
                  excerpt: 'EPUB 片段用于验证移动端 AI 面板不会遮挡阅读主路径。',
                ),
          progress: book.format == BookFormat.pdf ? 0.58 : 0.42,
          chapterTitle: book.format == BookFormat.pdf
              ? null
              : '第二章 本地优先的阅读和知识沉淀',
          pageNumber: book.format == BookFormat.pdf ? 3 : null,
          totalPages: book.format == BookFormat.pdf ? 12 : null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.config.book.format == BookFormat.pdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.menu_book_outlined,
                  size: 40,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.config.book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.config.book.format == BookFormat.pdf
                      ? 'PDF 页面居中显示，页码、缩放和适宽操作集中在阅读器工具栏。'
                      : 'EPUB 正文区域保持阅读优先，目录、搜索、Notebook 和 AI 通过上下文面板进入。',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ScreenshotData {
  const _ScreenshotData({
    required this.books,
    required this.notes,
    required this.tasks,
    this.settings = const ReaderSettings(),
  });

  final List<LibraryBook> books;
  final List<Note> notes;
  final List<PageSageTask> tasks;
  final ReaderSettings settings;

  _ScreenshotData copyWith({ReaderSettings? settings}) {
    return _ScreenshotData(
      books: books,
      notes: notes,
      tasks: tasks,
      settings: settings ?? this.settings,
    );
  }
}

List<LibraryBook> _sampleBooks({
  required String epubPath,
  required String pdfPath,
}) {
  return [
    _libraryBook(
      id: 'book-epub',
      title: 'PageSage Standard EPUB With A Calm Modern Reading Workflow',
      author: 'PageSage Local Samples',
      path: epubPath,
      format: BookFormat.epub,
      progress: 0.36,
      categoryId: 'cat-reading',
      isFavorite: true,
    ),
    _libraryBook(
      id: 'book-pdf',
      title: 'PDF Reader Layout Validation Sample With Long Title',
      author: 'PageSage QA',
      path: pdfPath,
      format: BookFormat.pdf,
      progress: 0.72,
      indexingStatus: 'running',
      categoryId: 'cat-research',
    ),
    _libraryBook(
      id: 'book-failed',
      title: '一本标题非常非常长用于验证书库卡片列表和详情面板不会重叠的 EPUB 样本',
      author: 'PageSage UX Team With A Very Long Author Name',
      path: epubPath,
      format: BookFormat.epub,
      progress: 0.08,
      indexingStatus: 'failed',
    ),
  ];
}

LibraryBook _libraryBook({
  required String id,
  required String title,
  required String path,
  String? author,
  BookFormat format = BookFormat.epub,
  String indexingStatus = 'done',
  String? categoryId,
  bool isFavorite = false,
  double? progress,
}) {
  return LibraryBook(
    book: Book(
      id: id,
      title: title,
      author: author,
      format: format,
      libraryFilePath: path,
      fileHash: 'hash-$id',
      fileSize: 1024 * 42,
      indexingStatus: indexingStatus,
      categoryId: categoryId,
      isFavorite: isFavorite,
      createdAt: 1,
      updatedAt: 2,
    ),
    progress: progress == null
        ? null
        : ReadingProgressSnapshot(
            bookId: id,
            locator: format == BookFormat.pdf
                ? ReadingLocator.pdf(page: 2, progress: progress)
                : ReadingLocator.epub(
                    href: 'OEBPS/chapter1.xhtml',
                    chapterIndex: 0,
                    progress: progress,
                  ),
            progress: progress,
            chapterTitle: format == BookFormat.pdf ? null : '第一章 进入书库',
            pageNumber: format == BookFormat.pdf ? 2 : null,
            updatedAt: 2,
          ),
  );
}

List<Note> _sampleNotes() {
  return [
    Note(
      id: 'note-1',
      bookId: 'book-epub',
      title: '摘录：本地优先的阅读循环',
      content: '这条笔记用于检查 Notebook 卡片、详情预览、标签和跳转原文入口。',
      sourceText: 'PageSage 的本地验收样本用于检查导入、打开、目录跳转、书签、笔记和保存进度。',
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter1.xhtml',
        chapterIndex: 0,
        progress: 0.22,
      ),
      noteType: NoteType.excerpt,
      createdAt: 1,
      updatedAt: 2,
    ),
    Note(
      id: 'note-2',
      bookId: 'book-pdf',
      title: 'PDF 缩放和页码检查',
      content: '验证页码跳转、缩放、适宽、搜索和保存进度。',
      locator: ReadingLocator.pdf(page: 2, progress: 0.5),
      noteType: NoteType.text,
      createdAt: 3,
      updatedAt: 4,
    ),
  ];
}

List<Bookmark> _sampleBookmarks() {
  return [
    Bookmark(
      id: 'bookmark-1',
      bookId: 'book-epub',
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter1.xhtml',
        chapterIndex: 0,
        progress: 0.24,
      ),
      title: '第一章 进入书库',
      note: '检查书签视觉状态',
      createdAt: 1,
      updatedAt: 2,
    ),
  ];
}

List<Annotation> _sampleAnnotations() {
  return [
    Annotation(
      id: 'annotation-1',
      bookId: 'book-epub',
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter1.xhtml',
        chapterIndex: 0,
        progress: 0.24,
        excerpt: '本地验收样本',
      ),
      selectedText: '本地验收样本',
      color: AnnotationColor.yellow,
      style: AnnotationStyle.highlight,
      createdAt: 1,
      updatedAt: 2,
    ),
  ];
}

List<AiConversation> _sampleConversations() {
  return [
    AiConversation(
      id: 'ai-1',
      bookId: 'book-epub',
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter1.xhtml',
        chapterIndex: 0,
        progress: 0.26,
      ),
      provider: 'openai-compatible',
      model: 'local-validation',
      prompt: '总结当前选中文本',
      contextText: '明确的上下文范围：当前段落。',
      answer: '这段内容说明 PageSage 的导入、阅读、标注和进度恢复验收路径。',
      sourceText: '本地验收样本',
      createdAt: 5,
    ),
  ];
}

List<PageSageTask> _sampleTasks() {
  return const [
    PageSageTask(
      id: 'task-1',
      type: PageSageTaskType.importBook,
      status: PageSageTaskStatus.running,
      progress: 0.42,
      sourcePath: r'D:\Samples\PageSage\standard.epub',
      targetPath: r'D:\PageSage\library\standard.epub',
      message: '正在复制本地 EPUB 样本',
      createdAt: 1,
      updatedAt: 2,
    ),
    PageSageTask(
      id: 'task-2',
      type: PageSageTaskType.indexBook,
      status: PageSageTaskStatus.failed,
      progress: 0.68,
      sourcePath: r'D:\Samples\PageSage\broken.pdf',
      message: '无法解析损坏 PDF',
      error: 'PDF 文件结构不完整',
      createdAt: 3,
      updatedAt: 4,
    ),
  ];
}

final class _FakeBookRepository implements BookRepository {
  const _FakeBookRepository(this.books);

  final List<LibraryBook> books;

  @override
  Future<Book> createImportedBook(NewBookDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<Book?> findByHash(String fileHash) async => null;

  @override
  Future<Book?> getBook(String id) async {
    return books
        .where((item) => item.book.id == id)
        .map((item) => item.book)
        .firstOrNull;
  }

  @override
  Future<List<LibraryBook>> getLibrary() async => books;

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async {
    return books
        .where((item) => item.book.id == bookId)
        .map((item) => item.progress)
        .firstOrNull;
  }

  @override
  Future<void> markOpened(String bookId) async {}

  @override
  Future<void> saveProgress({
    required String bookId,
    required ReadingLocator locator,
    required double progress,
    String? chapterTitle,
    int? pageNumber,
  }) async {}

  @override
  Future<void> toggleFavorite(String bookId, bool isFavorite) async {}

  @override
  Future<void> updateCategory(String bookId, String? categoryId) async {}

  @override
  Future<void> updateIndexingStatus(
    String bookId,
    String indexingStatus,
  ) async {}

  @override
  Future<void> updateMetadata({
    required String bookId,
    String? title,
    String? author,
    String? description,
    String? coverPath,
  }) async {}

  @override
  Future<void> updateReadStatus(String bookId, ReadStatus readStatus) async {}

  @override
  Stream<List<LibraryBook>> watchLibrary() => Stream.value(books);
}

final class _FakeSettingsRepository implements SettingsRepository {
  const _FakeSettingsRepository(this.settings);

  final ReaderSettings settings;

  @override
  Future<ReaderSettings> getReaderSettings() async => settings;

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {}

  @override
  Stream<ReaderSettings> watchReaderSettings() => Stream.value(settings);
}

final class _FakeAiSettingsRepository implements AiSettingsRepository {
  const _FakeAiSettingsRepository();

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<AiSettings> getSettings() async => const AiSettings();

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Stream<AiSettings> watchSettings() => Stream.value(const AiSettings());
}

final class _FakeTaskRepository implements TaskRepository {
  const _FakeTaskRepository(this.tasks);

  final List<PageSageTask> tasks;

  @override
  Future<void> clearCompleted() async {}

  @override
  Future<List<PageSageTask>> getTasks() async => tasks;

  @override
  Future<PageSageTask> saveTask({
    String? id,
    required PageSageTaskType type,
    required PageSageTaskStatus status,
    String? sourcePath,
    String? targetPath,
    String? bookId,
    double progress = 0,
    String? message,
    String? error,
  }) async {
    return PageSageTask(
      id: id ?? 'task-new',
      type: type,
      status: status,
      progress: progress,
      sourcePath: sourcePath,
      targetPath: targetPath,
      bookId: bookId,
      message: message,
      error: error,
      createdAt: 1,
      updatedAt: 2,
    );
  }

  @override
  Future<void> updateStatus({
    required String id,
    required PageSageTaskStatus status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
  }) async {}

  @override
  Stream<List<PageSageTask>> watchTasks() => Stream.value(tasks);
}

final class _FakeCategoryRepository implements CategoryRepository {
  const _FakeCategoryRepository();

  @override
  Future<void> deleteCategory(
    String id, {
    String? moveBooksToCategoryId,
  }) async {}

  @override
  Future<List<BookCategory>> getCategories() async => const [
    BookCategory(
      id: 'cat-reading',
      name: '阅读中',
      sortOrder: 1,
      createdAt: 1,
      updatedAt: 2,
    ),
    BookCategory(
      id: 'cat-research',
      name: '研究资料',
      sortOrder: 2,
      createdAt: 1,
      updatedAt: 2,
    ),
  ];

  @override
  Future<BookCategory> saveCategory({
    String? id,
    String? parentId,
    required String name,
    int sortOrder = 0,
    String? icon,
  }) async {
    return BookCategory(
      id: id ?? 'category-new',
      parentId: parentId,
      name: name,
      sortOrder: sortOrder,
      icon: icon,
      createdAt: 1,
      updatedAt: 2,
    );
  }

  @override
  Stream<List<BookCategory>> watchCategories() async* {
    yield await getCategories();
  }
}

final class _FakeTagRepository implements TagRepository {
  const _FakeTagRepository();

  @override
  Future<void> deleteTag(String id) async {}

  @override
  Future<List<BookTag>> getTags() async => const [
    BookTag(id: 'tag-local', name: '本地优先', createdAt: 1, updatedAt: 2),
    BookTag(id: 'tag-layout', name: '长文本与窄屏验收', createdAt: 1, updatedAt: 2),
  ];

  @override
  Future<List<BookTag>> getTagsForBook(String bookId) async => getTags();

  @override
  Stream<Map<String, List<BookTag>>> watchTagsByBookId() async* {
    final tags = await getTags();
    yield {'book-long': tags, 'book-1': tags};
  }

  @override
  Future<Set<String>> getBookIdsWithTag(String tagId) async =>
      {'book-long', 'book-1'};

  @override
  Future<List<BookTag>> getTagsForNote(String noteId) async => getTags();

  @override
  Future<BookTag> saveTag({String? id, required String name, String? color}) {
    return Future.value(
      BookTag(
        id: id ?? 'tag-new',
        name: name,
        color: color,
        createdAt: 1,
        updatedAt: 2,
      ),
    );
  }

  @override
  Future<void> setBookTags(String bookId, Iterable<String> tagIds) async {}

  @override
  Future<void> setNoteTags(String noteId, Iterable<String> tagIds) async {}

  @override
  Stream<List<BookTag>> watchTags() async* {
    yield await getTags();
  }
}

final class _FakeBookmarkRepository implements BookmarkRepository {
  const _FakeBookmarkRepository(this.bookmarks);

  final List<Bookmark> bookmarks;

  @override
  Future<void> deleteBookmark(String id) async {}

  @override
  Future<Bookmark?> findAtLocator(String bookId, ReadingLocator locator) async {
    return bookmarks
        .where(
          (bookmark) =>
              bookmark.bookId == bookId && bookmark.locator.matches(locator),
        )
        .firstOrNull;
  }

  @override
  Future<List<Bookmark>> getAll() async => bookmarks;

  @override
  Future<Set<String>> getBookIdsWithBookmarks() async =>
      bookmarks.map((bookmark) => bookmark.bookId).toSet();

  @override
  Future<List<Bookmark>> getByBook(String bookId) async =>
      bookmarks.where((bookmark) => bookmark.bookId == bookId).toList();

  @override
  Future<Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  }) async {
    return Bookmark(
      id: id ?? 'bookmark-new',
      bookId: bookId,
      locator: locator,
      title: title,
      note: note,
      excerpt: excerpt,
      createdAt: 1,
      updatedAt: 2,
    );
  }

  @override
  Stream<List<Bookmark>> watchByBook(String bookId) async* {
    yield await getByBook(bookId);
  }
}

final class _FakeAnnotationRepository implements AnnotationRepository {
  const _FakeAnnotationRepository(this.annotations);

  final List<Annotation> annotations;

  @override
  Future<void> deleteAnnotation(String id) async {}

  @override
  Future<List<Annotation>> getAll() async => annotations;

  @override
  Future<List<Annotation>> getByBook(String bookId) async =>
      annotations.where((item) => item.bookId == bookId).toList();

  @override
  Future<void> linkNote({
    required String annotationId,
    required String noteId,
  }) async {}

  @override
  Future<Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    AnnotationColor color = AnnotationColor.yellow,
    AnnotationStyle style = AnnotationStyle.highlight,
  }) async {
    return Annotation(
      id: id ?? 'annotation-new',
      bookId: bookId,
      locator: locator,
      selectedText: selectedText,
      color: color,
      style: style,
      createdAt: 1,
      updatedAt: 2,
    );
  }

  @override
  Stream<List<Annotation>> watchByBook(String bookId) async* {
    yield await getByBook(bookId);
  }
}

final class _FakeNoteRepository implements NoteRepository {
  @override
  Future<Set<String>> getBookIdsWithNotes() async => <String>{};

  const _FakeNoteRepository(this.notes);

  final List<Note> notes;

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<List<Note>> getByBook(String bookId) async =>
      notes.where((note) => note.bookId == bookId).toList();

  @override
  Future<Note?> getNote(String id) async =>
      notes.where((note) => note.id == id).firstOrNull;

  @override
  Future<List<Note>> getNotes() async => notes;

  @override
  Future<Note> saveNote({
    String? id,
    String? bookId,
    String? annotationId,
    String? title,
    required String content,
    String? sourceText,
    ReadingLocator? locator,
    NoteType noteType = NoteType.text,
  }) async {
    return Note(
      id: id ?? 'note-new',
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: locator,
      noteType: noteType,
      createdAt: 1,
      updatedAt: 2,
    );
  }

  @override
  Stream<List<Note>> watchNotes() => Stream.value(notes);
}

final class _FakeSearchRepository implements SearchRepository {
  const _FakeSearchRepository();

  @override
  Future<void> deleteByBook(String bookId) async {}

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) async {}

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) async {}

  @override
  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  }) async {}

  @override
  Future<List<SearchResult>> search(SearchQuery query) async {
    if (query.query.trim().isEmpty) {
      return const [];
    }
    return [
      SearchResult(
        id: 'search-content',
        type: SearchResultType.content,
        title: 'PageSage Standard EPUB With A Calm Modern Reading Workflow',
        snippet: '<mark>PageSage</mark> 的本地验收样本用于检查导入、打开、目录跳转、书签、笔记和保存进度。',
        bookId: 'book-epub',
        sourceId: 'book-epub:epub:0:0',
        locator: ReadingLocator.epub(
          href: 'OEBPS/chapter1.xhtml',
          chapterIndex: 0,
          progress: 0.24,
        ),
      ),
      SearchResult(
        id: 'search-note',
        type: SearchResultType.note,
        title: '摘录：本地优先的阅读循环',
        snippet: 'Notebook 中保存的 <mark>PageSage</mark> 摘录和笔记。',
        bookId: 'book-epub',
        sourceId: 'note-1',
      ),
    ];
  }

  @override
  Future<void> indexTexts(List<SearchIndexEntry> entries) async {
    for (final entry in entries) {
      await indexText(
        sourceType: entry.sourceType,
        sourceId: entry.sourceId,
        bookId: entry.bookId,
        title: entry.title,
        text: entry.text,
        locator: entry.locator,
        sortOrder: entry.sortOrder,
      );
    }
  }

}

final class _FakeAiConversationRepository implements AiConversationRepository {
  const _FakeAiConversationRepository(this.conversations);

  final List<AiConversation> conversations;

  @override
  Future<void> clearAll() async {}

  @override
  Future<List<AiConversation>> getConversations() async => conversations;

  @override
  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) async {}

  @override
  Future<AiConversation> saveConversation({
    String? id,
    String? bookId,
    ReadingLocator? locator,
    required String provider,
    required String model,
    required String prompt,
    String? contextText,
    required String answer,
    String? sourceText,
  }) async {
    return AiConversation(
      id: id ?? 'ai-new',
      bookId: bookId,
      locator: locator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      createdAt: 1,
    );
  }

  @override
  Stream<List<AiConversation>> watchConversations() =>
      Stream.value(conversations);
}
