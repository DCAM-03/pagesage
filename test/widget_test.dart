import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pagesage/app/pagesage_app.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/platform/file_picker_service.dart';
import 'package:pagesage/core/platform/platform_providers.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/books/bookmark.dart';
import 'package:pagesage/domain/books/category.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/domain/books/tag.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ai/application/ai_context_range.dart';
import 'package:pagesage/features/reader/presentation/reader_page.dart';
import 'package:pagesage/features/library/presentation/library_page.dart';
import 'package:pagesage/features/search/presentation/search_page.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';

void main() {
  testWidgets('shows the empty library screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
        ],
        child: const PageSageApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('书库'), findsWidgets);
    expect(find.text('还没有书籍'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsWidgets);
    expect(find.byKey(const ValueKey('import-books-button')), findsOneWidget);
  });

  testWidgets(
    'desktop search page does not duplicate the global search action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
            searchRepositoryProvider.overrideWithValue(
              const _FakeSearchRepository(),
            ),
          ],
          child: const PageSageApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(OutlinedButton, '搜索'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search_outlined).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, '搜索'), findsNothing);
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.text('搜索本地书库、正文、Notebook 和 AI 历史'), findsOneWidget);
    },
  );

  testWidgets('desktop import command and Ctrl+O open the book picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final adapter = _RecordingFilePickerAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          filePickerServiceProvider.overrideWithValue(
            FilePickerService(adapter: adapter),
          ),
        ],
        child: const PageSageApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.upload_file).first);
    await tester.pump();
    expect(adapter.pickRequests, hasLength(1));
    expect(adapter.pickRequests.single.allowMultiple, isTrue);
    expect(adapter.pickRequests.single.allowedExtensions, ['epub', 'pdf']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(adapter.pickRequests, hasLength(2));
    expect(adapter.pickRequests.last.dialogTitle, '导入 EPUB/PDF');
  });

  testWidgets(
    'navigating back to 书库 after an import does not reopen the picker',
    (tester) async {
      // The import intent lives in a provider that outlives the library page;
      // `ShellRoute` remounts the page on every navigation. A page-local
      // "handled" counter reset to 0 on remount and replayed the last request,
      // so clicking 书库 opened the file picker long after the import was done.
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final adapter = _RecordingFilePickerAdapter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
            filePickerServiceProvider.overrideWithValue(
              FilePickerService(adapter: adapter),
            ),
          ],
          child: const PageSageApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // One intentional import, cancelled in the picker.
      await tester.tap(
        find.byKey(const ValueKey('header-import-books-button')),
      );
      await tester.pumpAndSettle();
      expect(adapter.pickRequests, hasLength(1));

      // Leave the library, then come back through the navigation button.
      await tester.tap(find.text('搜索').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('书库').first);
      await tester.pumpAndSettle();

      expect(
        adapter.pickRequests,
        hasLength(1),
        reason: 'the completed intent must not replay on remount',
      );
    },
  );

  testWidgets('mobile library creates a category from the filter sheet', (
    tester,
  ) async {
    final categoryRepository = _MutableCategoryRepository();
    addTearDown(categoryRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(id: 'book-category-create', title: '分类创建入口验证'),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(categoryRepository),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(360, 720)),
            child: LibraryPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('分类创建入口验证'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '筛选'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '新建书架文件夹'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '新建书架文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '技术');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(categoryRepository.savedNames, ['技术']);
    expect(find.text('技术'), findsWidgets);
    expect(find.text('已创建书架文件夹“技术”'), findsOneWidget);
  });

  testWidgets('shows long library titles on narrow large-text screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'book-long',
                  title: '一本标题非常非常长用于验证移动端网格卡片不会横向溢出或遮挡操作按钮的 EPUB 样本',
                  author: 'PageSage UX Team With A Very Long Author Name',
                  progress: 0.42,
                  indexingStatus: 'failed',
                ),
                _libraryBook(
                  id: 'book-pdf',
                  title: 'PDF Reader Layout Smoke Test',
                  author: 'PageSage',
                  format: BookFormat.pdf,
                  progress: 0.76,
                  indexingStatus: 'running',
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(1.4),
          ),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('书库'), findsWidgets);
    expect(find.textContaining('一本标题非常非常长'), findsOneWidget);
    expect(find.text('PDF'), findsWidgets);
  });

  testWidgets(
    'mobile library avoids bottom overflow on short large-text windows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(
              _FakeBookRepository(
                books: [
                  _libraryBook(
                    id: 'book-short-window',
                    title: '一本标题很长用于验证短窗口底部不会溢出的 EPUB 样本',
                    author: 'PageSage UX Team With A Long Name',
                    progress: 0.58,
                    indexingStatus: 'running',
                  ),
                ],
              ),
            ),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
          ],
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: PageSageApp(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('书库'), findsWidgets);
      expect(find.textContaining('一本标题很长'), findsOneWidget);
      expect(find.text('任务'), findsWidgets);
    },
  );

  testWidgets(
    'shows long search queries and results on narrow large-text screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(
              _FakeBookRepository(
                books: [
                  _libraryBook(
                    id: 'book-long',
                    title: '一本标题非常非常长用于验证搜索结果不会横向溢出或遮挡菜单按钮',
                    author: 'PageSage UX Team',
                    progress: 0.42,
                  ),
                ],
              ),
            ),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
            noteRepositoryProvider.overrideWithValue(
              const _FakeNoteRepository(),
            ),
            searchRepositoryProvider.overrideWithValue(
              const _FakeSearchRepository(),
            ),
          ],
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 720),
              textScaler: TextScaler.linear(1.4),
            ),
            child: PageSageApp(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pumpAndSettle();

      const longQuery = '这是一个非常非常长的搜索词用于验证搜索框结果列表和筛选控件不会发生横向溢出';
      await tester.enterText(find.byType(SearchBar), longQuery);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('搜索'), findsWidgets);
      expect(find.textContaining('搜索结果标题非常非常长'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('命中片段包含非常非常长的连续文本'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('search result actions fit short large-text mobile windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'book-long',
                  title: '一本标题非常非常长用于验证搜索操作弹窗不会在短窗口溢出',
                  author: 'PageSage UX Team',
                  progress: 0.42,
                  indexingStatus: 'failed',
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), '布局');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('索引状态'), findsOneWidget);
    expect(find.text('重建待处理'), findsOneWidget);
    expect(find.textContaining('搜索结果标题非常非常长'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('对搜索片段提问').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('对搜索片段提问').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('对片段提问'), findsWidgets);
    expect(find.text('上下文范围：当前搜索结果片段'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
  });

  testWidgets('global search result saves snippet as excerpt note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notes = _RecordingNoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'book-long',
                  title: '全局搜索保存笔记验证样本',
                  author: 'PageSage UX Team',
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(notes),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(SearchBar), '命中片段');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('搜索结果标题非常非常长'), findsOneWidget);

    await tester.tap(find.byTooltip('保存搜索片段为笔记').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(notes.saved, hasLength(1));
    final note = notes.saved.single;
    expect(note.bookId, 'book-long');
    expect(note.noteType, NoteType.excerpt);
    expect(note.title, contains('搜索结果标题'));
    expect(note.content, contains('命中片段包含非常非常长的连续文本'));
    expect(note.content, isNot(contains('<mark>')));
    expect(note.sourceText, note.content);
    expect(note.locator?.href, 'chapter.xhtml');
    expect(find.text('已保存为笔记'), findsOneWidget);
  });

  testWidgets('shows long notes on narrow large-text screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'book-long',
                  title: '一本标题非常非常长用于验证笔记筛选里的书籍范围标签不会横向溢出',
                  author: 'PageSage UX Team',
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(
            _FakeNoteRepository(
              notes: [
                Note(
                  id: 'note-long',
                  bookId: 'book-long',
                  title: '一条标题非常非常长的摘录笔记用于验证移动端笔记卡片标题不会撑破布局',
                  content: '笔记内容非常非常长，用于验证摘要在三行内省略，且不会遮挡尾部类型标签或浮动新建按钮。',
                  sourceText: '原文摘录也非常非常长，用于验证摘要合并原文和内容时仍然保持卡片稳定。',
                  locator: ReadingLocator.epub(href: 'chapter.xhtml'),
                  noteType: NoteType.excerpt,
                  createdAt: 1,
                  updatedAt: 2,
                ),
              ],
            ),
          ),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(1.4),
          ),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('管理书签、摘录、手写笔记和 AI 记录'), findsOneWidget);
    expect(find.textContaining('一条标题非常非常长的摘录笔记'), findsOneWidget);
    expect(find.text('摘录'), findsWidgets);
  });

  testWidgets('note editor fits short large-text mobile windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('新建笔记'), findsWidgets);
    expect(find.text('内容'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('shows mobile settings sections with modern page headers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(1.4),
          ),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('返回设置'), findsOneWidget);
    expect(find.text('默认阅读模式、字体、排版和主题'), findsWidgets);
    expect(find.text('默认字号'), findsOneWidget);
  });

  testWidgets(
    'mobile settings AI and tag dialogs fit short large-text windows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            aiSettingsRepositoryProvider.overrideWithValue(
              const _FakeAiSettingsRepository(),
            ),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
            annotationRepositoryProvider.overrideWithValue(
              const _FakeAnnotationRepository(),
            ),
            noteRepositoryProvider.overrideWithValue(
              const _FakeNoteRepository(),
            ),
            searchRepositoryProvider.overrideWithValue(
              const _FakeSearchRepository(),
            ),
          ],
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: PageSageApp(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('连接测试'), findsOneWidget);
      expect(find.text('保存 AI 设置'), findsOneWidget);

      await tester.tap(find.byTooltip('返回设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('分类与标签').first);
      await tester.tap(find.text('分类与标签').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建标签'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('新建标签'), findsWidgets);
      expect(find.text('标签名称'), findsOneWidget);
      expect(find.text('#1F6F64'), findsOneWidget);
      expect(find.text('保存'), findsWidgets);
    },
  );

  testWidgets('settings exposes privacy and license notices', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(size: Size(360, 720)),
          child: PageSageApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于').first);
    await tester.pumpAndSettle();

    expect(find.text('版本、隐私说明和开源许可'), findsWidgets);
    expect(find.text('隐私说明'), findsOneWidget);
    expect(find.text('开源许可说明'), findsOneWidget);

    await tester.tap(find.text('隐私说明'));
    await tester.pumpAndSettle();
    expect(find.text('PageSage 隐私说明'), findsOneWidget);
    expect(find.textContaining('默认不会自动上传整本书'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开源许可说明'));
    await tester.pumpAndSettle();
    expect(find.text('PageSage 开源许可说明'), findsOneWidget);
    expect(find.textContaining('pubspec.lock'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('acting on a selection keeps its highlight painted', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var latest = ValueNotifier<ReaderRendererHostConfig?>(null);
    addTearDown(latest.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'reader-keep-selection',
                  title: '保留选区验证样本',
                  progress: 0.2,
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          aiConversationRepositoryProvider.overrideWithValue(
            const _FakeAiConversationRepository(),
          ),
          readerRendererHostProvider.overrideWithValue(
            (config) => _FakeRendererHost(
              config: config,
              // Reports the selection after the menu has had time to open.
              event: RendererLocationChanged(
                locator: ReadingLocator.epub(
                  href: 'chapter.xhtml',
                  chapterIndex: 0,
                  progress: 0.2,
                  excerpt: '选中的一段话',
                ),
                progress: 0.2,
                chapterTitle: '第一章',
              ),
              exportConfig: (config) => latest.value = config,
            ),
          ),
        ],
        // A wide window: the desktop selection menu, not the bottom sheet.
        child: const MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: MaterialApp(home: ReaderPage(bookId: 'reader-keep-selection')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final before = latest.value!.clearSelectionVersion;

    // A selection arrives; the action menu opens over it.
    final host = tester.widget<_FakeRendererHost>(
      find.byType(_FakeRendererHost),
    );
    host.config.onEvent(
      RendererTextSelected(
        text: '选中的一段话',
        locator: ReadingLocator.epub(
          href: 'chapter.xhtml',
          chapterIndex: 0,
          progress: 0.2,
          excerpt: '选中的一段话',
        ),
        // Where the selection sits, so the floating menu lands inside the
        // window instead of below it.
        sourceRect: const ReaderRect(
          page: 1,
          x: 120,
          y: 120,
          width: 200,
          height: 24,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('复制').first);
    await tester.pump(const Duration(milliseconds: 250));

    // Acting on a selection is not the same as being done with it: the paint
    // has to outlive the menu, or the reader loses track of which passage the
    // answer is about.
    expect(
      latest.value!.clearSelectionVersion,
      before,
      reason: 'running an action must not clear the selection paint',
    );

    // The mobile chrome auto-hide timer is still armed; let it fire before the
    // tree goes away.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('reader shows PDF no-text-layer capability notice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'pdf-no-text',
                  title: '无文本层 PDF',
                  format: BookFormat.pdf,
                  progress: 0.1,
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          readerRendererHostProvider.overrideWithValue(
            (config) => _FakeRendererHost(
              config: config,
              event: const RendererCapabilityChanged(
                textSelection: false,
                search: false,
                reason: '此 PDF 没有文本层，划词、高亮与搜索不可用。可使用「识别本页」提取文字。',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ReaderPage(bookId: 'pdf-no-text')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Quiet status in the PDF toolbar (not a floating toast).
    expect(find.textContaining('无文本层'), findsWidgets);
  });

  testWidgets('reader shows renderer error panel and retry action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'pdf-broken',
                  title: '损坏 PDF',
                  format: BookFormat.pdf,
                  progress: 0.1,
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          readerRendererHostProvider.overrideWithValue(
            (config) => _FakeRendererHost(
              config: config,
              event: const RendererFailed('PDF 文件结构不完整'),
            ),
          ),
        ],
        child: const MaterialApp(home: ReaderPage(bookId: 'pdf-broken')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('无法渲染书籍'), findsOneWidget);
    expect(find.text('PDF 文件结构不完整'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(find.text('正在重新打开'), findsOneWidget);
  });

  testWidgets('mobile reader controls fit short large-text windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'reader-short-window',
                  title: '一本标题非常非常长用于验证移动阅读器底部控制和抽屉不会溢出的 EPUB 样本',
                  author: 'PageSage UX Team',
                  progress: 0.42,
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          aiConversationRepositoryProvider.overrideWithValue(
            const _FakeAiConversationRepository(),
          ),
          readerRendererHostProvider.overrideWithValue(
            (config) => _FakeRendererHost(
              config: config,
              event: RendererLocationChanged(
                locator: ReadingLocator.epub(
                  href: 'chapter.xhtml',
                  chapterIndex: 2,
                  progress: 0.42,
                  excerpt: '用于验证 AI 面板上下文摘要的选中文本片段',
                ),
                progress: 0.42,
                chapterTitle: '一个非常长的章节标题用于验证状态区域可以换行而不是溢出',
              ),
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(home: ReaderPage(bookId: 'reader-short-window')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The short window keeps four primary actions; notes and AI live one level
    // down in the more sheet, and the point of this test is that neither level
    // overflows at 1.5x text.
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('笔记与标注'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('这本书还没有 Notebook 条目'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭 Notebook'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 助手'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('上下文范围'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);

    // The reader hands the panel its book file, so the ranges that read a
    // page or chapter are available. Before the wiring they were offered but
    // silently sent the selection instead.
    await tester.tap(find.byTooltip('上下文范围'));
    await tester.pumpAndSettle();
    final ranges = tester
        .widgetList<PopupMenuItem<AiContextRange>>(
          find.byType(PopupMenuItem<AiContextRange>),
        )
        .toList(growable: false);
    expect(ranges, isNotEmpty);
    expect(
      ranges.every((item) => item.enabled),
      isTrue,
      reason: 'a book with a library path can supply every range',
    );
  });

  testWidgets('desktop reader keyboard shortcuts open panels and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bookmarks = _RecordingBookmarkRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'reader-keyboard-pdf',
                  title: 'PDF 快捷键验证样本',
                  format: BookFormat.pdf,
                  progress: 0.25,
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(bookmarks),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(const _FakeNoteRepository()),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          aiConversationRepositoryProvider.overrideWithValue(
            const _FakeAiConversationRepository(),
          ),
          readerRendererHostProvider.overrideWithValue(
            (config) => _FakeRendererHost(
              config: config,
              event: RendererLocationChanged(
                locator: ReadingLocator.pdf(
                  page: 3,
                  progress: 0.25,
                  excerpt: 'PDF 快捷键测试片段',
                ),
                progress: 0.25,
                pageNumber: 3,
                totalPages: 12,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: ReaderPage(bookId: 'reader-keyboard-pdf'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.textContaining('Fake renderer'));
    await tester.pump();

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('本书搜索'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('本书搜索'), findsNothing);

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();

    expect(bookmarks.saved, hasLength(1));
    expect(bookmarks.saved.single.bookId, 'reader-keyboard-pdf');
    expect(bookmarks.saved.single.locator.page, 3);
    expect(find.text('已添加书签'), findsOneWidget);

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyG);
    await tester.pumpAndSettle();

    expect(find.text('跳转页码'), findsOneWidget);
    expect(find.text('页码'), findsOneWidget);
  });

  testWidgets(
    'desktop reader keyboard shortcuts navigate search and zoom PDF',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = _RecordingSettingsRepository(
        const ReaderSettings(pdfScale: 1.2, pdfZoomMode: PdfZoomMode.custom),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const ReaderPage(bookId: 'reader-zoom-pdf'),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(
              _FakeBookRepository(
                books: [
                  _libraryBook(
                    id: 'reader-zoom-pdf',
                    title: 'PDF 缩放快捷键验证样本',
                    format: BookFormat.pdf,
                    progress: 0.25,
                  ),
                ],
              ),
            ),
            settingsRepositoryProvider.overrideWithValue(settings),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
            annotationRepositoryProvider.overrideWithValue(
              const _FakeAnnotationRepository(),
            ),
            noteRepositoryProvider.overrideWithValue(
              const _FakeNoteRepository(),
            ),
            searchRepositoryProvider.overrideWithValue(
              const _FakeSearchRepository(),
            ),
            aiSettingsRepositoryProvider.overrideWithValue(
              const _FakeAiSettingsRepository(),
            ),
            aiConversationRepositoryProvider.overrideWithValue(
              const _FakeAiConversationRepository(),
            ),
            readerRendererHostProvider.overrideWithValue(
              (config) => _FakeRendererHost(
                config: config,
                event: RendererLocationChanged(
                  locator: ReadingLocator.pdf(page: 2, progress: 0.25),
                  progress: 0.25,
                  pageNumber: 2,
                  totalPages: 12,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.textContaining('Fake renderer'));
      await tester.pump();

      await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/search');
      expect(find.text('搜索'), findsWidgets);
      expect(find.byType(SearchPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWithValue(
              _FakeBookRepository(
                books: [
                  _libraryBook(
                    id: 'reader-zoom-pdf',
                    title: 'PDF 缩放快捷键验证样本',
                    format: BookFormat.pdf,
                    progress: 0.25,
                  ),
                ],
              ),
            ),
            settingsRepositoryProvider.overrideWithValue(settings),
            taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
            categoryRepositoryProvider.overrideWithValue(
              const _FakeCategoryRepository(),
            ),
            tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
            bookmarkRepositoryProvider.overrideWithValue(
              const _FakeBookmarkRepository(),
            ),
            annotationRepositoryProvider.overrideWithValue(
              const _FakeAnnotationRepository(),
            ),
            noteRepositoryProvider.overrideWithValue(
              const _FakeNoteRepository(),
            ),
            searchRepositoryProvider.overrideWithValue(
              const _FakeSearchRepository(),
            ),
            aiSettingsRepositoryProvider.overrideWithValue(
              const _FakeAiSettingsRepository(),
            ),
            aiConversationRepositoryProvider.overrideWithValue(
              const _FakeAiConversationRepository(),
            ),
            readerRendererHostProvider.overrideWithValue(
              (config) => _FakeRendererHost(
                config: config,
                event: RendererLocationChanged(
                  locator: ReadingLocator.pdf(page: 2, progress: 0.25),
                  progress: 0.25,
                  pageNumber: 2,
                  totalPages: 12,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: ReaderPage(bookId: 'reader-zoom-pdf')),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.textContaining('Fake renderer'));
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.equal);
      await tester.pump(const Duration(milliseconds: 150));

      expect(settings.saved.last.pdfScale, closeTo(1.3, 0.001));
      expect(settings.saved.last.pdfZoomMode, PdfZoomMode.custom);
      expect(find.text('缩放 130%'), findsOneWidget);

      await _sendControlShortcut(tester, LogicalKeyboardKey.minus);
      await tester.pump(const Duration(milliseconds: 150));

      expect(settings.saved.last.pdfScale, closeTo(1.2, 0.001));
      expect(settings.saved.last.pdfZoomMode, PdfZoomMode.custom);
      expect(find.text('缩放 120%'), findsOneWidget);

      await _sendControlShortcut(tester, LogicalKeyboardKey.digit0);
      await tester.pump(const Duration(milliseconds: 150));

      expect(settings.saved.last.pdfScale, 1);
      expect(settings.saved.last.pdfZoomMode, PdfZoomMode.actual);
      expect(find.text('已恢复默认阅读比例'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('reader in-book search result saves as excerpt note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notes = _RecordingNoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(
            _FakeBookRepository(
              books: [
                _libraryBook(
                  id: 'reader-search-epub',
                  title: 'EPUB 本书搜索验证样本',
                  format: BookFormat.epub,
                  progress: 0.2,
                ),
              ],
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository()),
          categoryRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(),
          ),
          tagRepositoryProvider.overrideWithValue(const _FakeTagRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            const _FakeBookmarkRepository(),
          ),
          annotationRepositoryProvider.overrideWithValue(
            const _FakeAnnotationRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(notes),
          searchRepositoryProvider.overrideWithValue(
            const _FakeSearchRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
          aiConversationRepositoryProvider.overrideWithValue(
            const _FakeAiConversationRepository(),
          ),
          readerRendererHostProvider.overrideWithValue(
            (config) => _FakeRendererHost(
              config: config,
              event: RendererLocationChanged(
                locator: ReadingLocator.epub(
                  href: 'chapter.xhtml',
                  chapterIndex: 0,
                  chapterOffset: 10,
                  progress: 0.2,
                  excerpt: '当前章节片段',
                ),
                progress: 0.2,
                chapterTitle: '第一章',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: ReaderPage(bookId: 'reader-search-epub'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _sendControlShortcut(tester, LogicalKeyboardKey.keyF);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(SearchBar).last, '命中片段');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('本书搜索'), findsOneWidget);
    expect(find.byTooltip('保存搜索结果为笔记'), findsOneWidget);

    await tester.tap(find.byTooltip('保存搜索结果为笔记'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(notes.saved, hasLength(1));
    final note = notes.saved.single;
    expect(note.bookId, 'reader-search-epub');
    expect(note.noteType, NoteType.excerpt);
    expect(note.title, contains('搜索结果标题'));
    expect(note.content, contains('命中片段包含非常非常长的连续文本'));
    expect(note.content, isNot(contains('<mark>')));
    expect(note.sourceText, note.content);
    expect(note.locator?.href, 'chapter.xhtml');
    expect(find.text('已保存为笔记'), findsOneWidget);
  });
}

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _sendControlShiftShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(
    key,
    character: key == LogicalKeyboardKey.keyF ? 'F' : null,
  );
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

final class _FakeRendererHost extends StatefulWidget {
  const _FakeRendererHost({
    required this.config,
    required this.event,
    this.exportConfig,
  });

  final ReaderRendererHostConfig config;
  final RendererEvent event;

  /// Receives the latest config, so a test can read the selection token the
  /// host passes down.
  final void Function(ReaderRendererHostConfig config)? exportConfig;

  @override
  State<_FakeRendererHost> createState() => _FakeRendererHostState();
}

final class _FakeRendererHostState extends State<_FakeRendererHost> {
  bool _sent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sent) {
      return;
    }
    _sent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.config.onEvent(widget.event);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Every rebuild, since the host passes a fresh config down each time.
    widget.exportConfig?.call(widget.config);
    return Center(child: Text('Fake renderer ${widget.config.book.title}'));
  }
}

final class _RecordingFilePickerAdapter implements FilePickerAdapter {
  @override
  Future<String?> pickDirectory({required String dialogTitle}) async => null;

  final pickRequests = <FilePickerRequest>[];

  @override
  Future<List<PickedPlatformFile>> pickFiles(FilePickerRequest request) async {
    pickRequests.add(request);
    return const [];
  }

  @override
  Future<String?> saveFile(FileSaveRequest request) async => null;
}

final class _FakeBookRepository implements BookRepository {
  const _FakeBookRepository({this.books = const []});

  final List<LibraryBook> books;

  @override
  Future<Book> createImportedBook(NewBookDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<Book?> findByHash(String fileHash) async => null;

  @override
  Future<Book?> getBook(String id) async {
    for (final item in books) {
      if (item.book.id == id) {
        return item.book;
      }
    }
    return null;
  }

  @override
  Future<List<LibraryBook>> getLibrary() async => books;

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async {
    for (final item in books) {
      if (item.book.id == bookId) {
        return item.progress;
      }
    }
    return null;
  }

  @override
  Future<void> markOpened(String bookId) async {}

  @override
  Future<void> deleteBook(String bookId) async {}

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
  @override
  Future<ReaderSettings> getReaderSettings() async => const ReaderSettings();

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {}

  @override
  Stream<ReaderSettings> watchReaderSettings() {
    return Stream.value(const ReaderSettings());
  }
}

final class _RecordingSettingsRepository implements SettingsRepository {
  _RecordingSettingsRepository(ReaderSettings initialSettings)
    : _settings = initialSettings;

  ReaderSettings _settings;
  final saved = <ReaderSettings>[];
  final _controller = StreamController<ReaderSettings>.broadcast();

  @override
  Future<ReaderSettings> getReaderSettings() async => _settings;

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {
    _settings = settings;
    saved.add(settings);
    _controller.add(settings);
  }

  @override
  Stream<ReaderSettings> watchReaderSettings() async* {
    yield _settings;
    yield* _controller.stream;
  }
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

final class _FakeAiConversationRepository implements AiConversationRepository {
  const _FakeAiConversationRepository();

  @override
  Future<void> clearAll() async {}

  @override
  Future<List<AiConversation>> getConversations() async => const [];

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
    String? threadId,
  }) async {
    return AiConversation(
      id: id ?? 'ai-test',
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
  Stream<List<AiConversation>> watchConversations() => Stream.value(const []);
}

final class _FakeTaskRepository implements TaskRepository {
  @override
  Future<void> clearCompleted() async {}

  @override
  Future<List<PageSageTask>> getTasks() async => const [];

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
    final now = DateTime.now().millisecondsSinceEpoch;
    return PageSageTask(
      id: id ?? 'task-test',
      type: type,
      status: status,
      progress: progress,
      createdAt: now,
      updatedAt: now,
      sourcePath: sourcePath,
      targetPath: targetPath,
      bookId: bookId,
      message: message,
      error: error,
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
    bool clearError = false,
  }) async {}

  @override
  Stream<List<PageSageTask>> watchTasks() => Stream.value(const []);
}

final class _FakeCategoryRepository implements CategoryRepository {
  const _FakeCategoryRepository();

  @override
  Future<void> deleteCategory(
    String id, {
    String? moveBooksToCategoryId,
  }) async {}

  @override
  Future<List<BookCategory>> getCategories() async => const [];

  @override
  Future<BookCategory> saveCategory({
    String? id,
    String? parentId,
    required String name,
    int sortOrder = 0,
    String? icon,
  }) async {
    return BookCategory(
      id: id ?? 'category-test',
      parentId: parentId,
      name: name,
      sortOrder: sortOrder,
      icon: icon,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Stream<List<BookCategory>> watchCategories() => Stream.value(const []);
}

final class _MutableCategoryRepository implements CategoryRepository {
  final _controller = StreamController<List<BookCategory>>.broadcast();
  final _categories = <BookCategory>[];
  final savedNames = <String>[];

  void dispose() {
    _controller.close();
  }

  @override
  Future<void> deleteCategory(
    String id, {
    String? moveBooksToCategoryId,
  }) async {
    _categories.removeWhere((category) => category.id == id);
    _emit();
  }

  @override
  Future<List<BookCategory>> getCategories() async =>
      List.unmodifiable(_categories);

  @override
  Future<BookCategory> saveCategory({
    String? id,
    String? parentId,
    required String name,
    int sortOrder = 0,
    String? icon,
  }) async {
    final category = BookCategory(
      id: id ?? 'category-${_categories.length + 1}',
      parentId: parentId,
      name: name,
      sortOrder: sortOrder == 0 ? (_categories.length + 1) * 1024 : sortOrder,
      icon: icon,
      createdAt: 1,
      updatedAt: 1,
    );
    savedNames.add(name);
    _categories
      ..removeWhere((item) => item.id == category.id)
      ..add(category);
    _emit();
    return category;
  }

  @override
  Stream<List<BookCategory>> watchCategories() async* {
    yield List.unmodifiable(_categories);
    yield* _controller.stream;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_categories));
    }
  }
}

final class _FakeTagRepository implements TagRepository {
  const _FakeTagRepository();

  @override
  Future<void> deleteTag(String id) async {}

  @override
  Future<List<BookTag>> getTags() async => const [
    BookTag(
      id: 'tag-long',
      name: '一个非常长的标签用于验证筛选芯片换行',
      createdAt: 1,
      updatedAt: 1,
    ),
  ];

  @override
  Future<List<BookTag>> getTagsForBook(String bookId) async => getTags();

  @override
  Stream<Map<String, List<BookTag>>> watchTagsByBookId() async* {
    final tags = await getTags();
    yield {'book-long': tags, 'book-1': tags};
  }

  @override
  Future<Set<String>> getBookIdsWithTag(String tagId) async => {
    'book-long',
    'book-1',
  };

  @override
  Future<List<BookTag>> getTagsForNote(String noteId) async => const [];

  @override
  Future<BookTag> saveTag({String? id, required String name, String? color}) {
    return Future.value(
      BookTag(
        id: id ?? 'tag-test',
        name: name,
        color: color,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  }

  @override
  Future<void> setBookTags(String bookId, Iterable<String> tagIds) async {}

  @override
  Future<void> setNoteTags(String noteId, Iterable<String> tagIds) async {}

  @override
  Stream<List<BookTag>> watchTags() => Stream.value(const [
    BookTag(
      id: 'tag-long',
      name: '一个非常长的标签用于验证筛选芯片换行',
      createdAt: 1,
      updatedAt: 1,
    ),
  ]);
}

final class _FakeBookmarkRepository implements BookmarkRepository {
  const _FakeBookmarkRepository();

  @override
  Future<Bookmark?> findAtLocator(String bookId, ReadingLocator locator) async {
    return null;
  }

  @override
  Future<List<Bookmark>> getAll() async => const [];

  @override
  Future<List<Bookmark>> getByBook(String bookId) async => const [];

  @override
  Future<Set<String>> getBookIdsWithBookmarks() async => <String>{};

  @override
  Future<Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBookmark(String id) async {}

  @override
  Stream<List<Bookmark>> watchByBook(String bookId) => Stream.value(const []);
}

final class _RecordingBookmarkRepository implements BookmarkRepository {
  final saved = <Bookmark>[];

  @override
  Future<Set<String>> getBookIdsWithBookmarks() async =>
      saved.map((bookmark) => bookmark.bookId).toSet();

  @override
  Future<Bookmark?> findAtLocator(String bookId, ReadingLocator locator) async {
    for (final bookmark in saved) {
      if (bookmark.bookId == bookId && bookmark.locator.matches(locator)) {
        return bookmark;
      }
    }
    return null;
  }

  @override
  Future<List<Bookmark>> getAll() async => saved;

  @override
  Future<List<Bookmark>> getByBook(String bookId) async =>
      saved.where((bookmark) => bookmark.bookId == bookId).toList();

  @override
  Future<Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  }) async {
    final bookmark = Bookmark(
      id: id ?? 'bookmark-${saved.length + 1}',
      bookId: bookId,
      locator: locator,
      title: title,
      note: note,
      excerpt: excerpt,
      createdAt: 1,
      updatedAt: 1,
    );
    saved.add(bookmark);
    return bookmark;
  }

  @override
  Future<void> deleteBookmark(String id) async {
    saved.removeWhere((bookmark) => bookmark.id == id);
  }

  @override
  Stream<List<Bookmark>> watchByBook(String bookId) => Stream.value(
    saved.where((bookmark) => bookmark.bookId == bookId).toList(),
  );
}

final class _FakeAnnotationRepository implements AnnotationRepository {
  const _FakeAnnotationRepository();

  @override
  Future<void> deleteAnnotation(String id) async {}

  @override
  Future<List<Annotation>> getAll() async => const [];

  @override
  Future<List<Annotation>> getByBook(String bookId) async => const [];

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
      id: id ?? 'annotation-test',
      bookId: bookId,
      locator: locator,
      selectedText: selectedText,
      color: color,
      style: style,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Stream<List<Annotation>> watchByBook(String bookId) => Stream.value(const []);
}

final class _FakeNoteRepository implements NoteRepository {
  const _FakeNoteRepository({this.notes = const []});

  final List<Note> notes;

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<Note?> getNote(String id) async {
    for (final note in notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<List<Note>> getByBook(String bookId) async =>
      notes.where((note) => note.bookId == bookId).toList(growable: false);

  @override
  Future<Set<String>> getBookIdsWithNotes() async => {
    for (final note in notes)
      if (note.bookId != null) note.bookId!,
  };

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
      id: id ?? 'note-test',
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: locator,
      noteType: noteType,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Stream<List<Note>> watchNotes() => Stream.value(notes);
}

final class _RecordingNoteRepository implements NoteRepository {
  final saved = <Note>[];

  @override
  Future<Set<String>> getBookIdsWithNotes() async => {
    for (final note in saved)
      if (note.bookId != null) note.bookId!,
  };

  @override
  Future<void> deleteNote(String id) async {
    saved.removeWhere((note) => note.id == id);
  }

  @override
  Future<Note?> getNote(String id) async {
    for (final note in saved) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<List<Note>> getByBook(String bookId) async =>
      saved.where((note) => note.bookId == bookId).toList(growable: false);

  @override
  Future<List<Note>> getNotes() async => saved;

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
    final note = Note(
      id: id ?? 'note-${saved.length + 1}',
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: locator,
      noteType: noteType,
      createdAt: 1,
      updatedAt: 1,
    );
    saved.add(note);
    return note;
  }

  @override
  Stream<List<Note>> watchNotes() => Stream.value(saved);
}

final class _FakeSearchRepository implements SearchRepository {
  const _FakeSearchRepository();

  @override
  Future<void> deleteByBook(String bookId) async {}

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) async {}

  @override
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async => const [];

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
    return [
      SearchResult(
        id: 'result-long',
        type: SearchResultType.content,
        title: '搜索结果标题非常非常长用于验证窄屏大字体时标题不会挤压右侧菜单按钮或横向溢出',
        snippet:
            '<mark>命中片段包含非常非常长的连续文本</mark>，用于验证 RichText 在窄屏、大字体和高亮 mark 下仍然会省略并保持卡片布局稳定。',
        bookId: 'book-long',
        sourceId: 'chunk-long',
        locator: ReadingLocator.epub(href: 'chapter.xhtml', progress: 0.42),
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

LibraryBook _libraryBook({
  required String id,
  required String title,
  String? author,
  BookFormat format = BookFormat.epub,
  String indexingStatus = 'done',
  double? progress,
}) {
  return LibraryBook(
    book: Book(
      id: id,
      title: title,
      author: author,
      format: format,
      libraryFilePath: '$id.${format.value}',
      fileHash: 'hash-$id',
      fileSize: 1,
      indexingStatus: indexingStatus,
      createdAt: 1,
      updatedAt: 1,
    ),
    progress: progress == null
        ? null
        : ReadingProgressSnapshot(
            bookId: id,
            locator: format == BookFormat.pdf
                ? ReadingLocator.pdf(page: 1, progress: progress)
                : ReadingLocator.epub(progress: progress),
            progress: progress,
            updatedAt: 1,
          ),
  );
}
