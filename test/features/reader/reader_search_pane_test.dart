import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/reader/application/reader_notebook_providers.dart';
import 'package:pagesage/features/reader/presentation/reader_context_pane.dart';
import 'package:pagesage/features/reader/presentation/reader_notebook.dart';
import 'package:pagesage/features/reader/presentation/reader_search_pane.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late _SearchRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    for (final id in ['book-a', 'book-b']) {
      await database.bookDao.insertBook(
        BooksCompanion.insert(
          id: id,
          title: id,
          format: 'epub',
          libraryFilePath: '/library/$id.epub',
          fileHash: 'hash-$id',
          fileSize: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
    }
    repository = _SearchRepository(DriftSearchRepository(database.searchDao));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        searchRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  void searchTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
        await tester.runAsync(database.close);
      }
    });
  }

  searchTest('input debounces and clear cancels the pending search', (
    tester,
  ) async {
    final queries = <String>[];
    var cleared = 0;
    await tester.pumpWidget(
      _app(
        container,
        _pane(onQueryChanged: queries.add, onClear: () => cleared++),
      ),
    );
    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(repository.queries.single.query, 'beta');
    expect(repository.queries.single.bookId, 'book-a');
    expect(repository.queries.single.typeFilters, {SearchResultType.content});
    expect(queries, ['alpha', 'beta']);

    await tester.enterText(find.byType(TextField), 'cancelled');
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.queries, hasLength(1));
    expect(find.text('输入关键词搜索当前书籍'), findsOneWidget);
    expect(cleared, 1);
  });

  searchTest(
    'navigation previews exact locators and AI keeps a plain snippet',
    (tester) async {
      final first = _result('first', chapter: 0);
      final second = _result('second', chapter: 2);
      repository.handler = (_) async => [first, second];
      final selected = <ReadingLocator>[];
      final actions = <InBookSearchAction>[];
      await tester.pumpWidget(
        _app(
          container,
          _pane(
            initialQuery: 'query',
            currentLocator: ReadingLocator.epub(chapterIndex: 1),
            onPreviewResult: selected.add,
            onAction: actions.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      await tester.tap(find.text('跳转'));
      expect(selected.single.toJsonText(), second.locator!.toJsonText());
      await tester.tap(find.byTooltip('下一条'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(selected.last.toJsonText(), first.locator!.toJsonText());
      await tester.tap(find.byTooltip('上一条'));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      await tester.tap(find.byTooltip('对搜索结果片段提问').last);
      expect(actions.single.intent, InBookSearchIntent.askAi);
      expect(actions.single.sourceText, 'second plain snippet');
      expect(actions.single.locator.toJsonText(), second.locator!.toJsonText());
    },
  );

  searchTest('failed searches retry the same query without becoming empty', (
    tester,
  ) async {
    var attempts = 0;
    repository.handler = (_) async {
      if (attempts++ == 0) {
        throw StateError('fixture failure');
      }
      return [_result('recovered')];
    };
    await tester.pumpWidget(
      _app(container, _pane(initialQuery: 'retry query')),
    );
    await tester.pumpAndSettle();
    expect(find.text('搜索失败'), findsOneWidget);
    expect(find.text('没有找到匹配内容'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('recovered'), findsOneWidget);
    expect(repository.queries.map((query) => query.query), [
      'retry query',
      'retry query',
    ]);
  });

  searchTest('changing books replaces the pending search and query state', (
    tester,
  ) async {
    final pending = Completer<List<SearchResult>>();
    repository.handler = (query) => query.bookId == 'book-a'
        ? pending.future
        : Future.value([_result('new-book', bookId: 'book-b')]);
    await tester.pumpWidget(
      _app(container, _pane(initialQuery: 'first query')),
    );
    await tester.pump();
    expect(repository.queries.single.bookId, 'book-a');
    await tester.pumpWidget(
      _app(container, _pane(bookId: 'book-b', initialQuery: 'second query')),
    );
    await tester.pump();
    pending.complete([_result('old-book')]);
    await tester.pumpAndSettle();
    expect(repository.queries.last.bookId, 'book-b');
    expect(repository.queries.last.query, 'second query');
    expect(find.text('new-book'), findsOneWidget);
    expect(find.text('old-book'), findsNothing);
  });

  searchTest('an external empty query clears the visible results', (
    tester,
  ) async {
    repository.handler = (_) async => [_result('old-result')];
    await tester.pumpWidget(
      _app(container, _pane(initialQuery: 'first query')),
    );
    await tester.pumpAndSettle();
    expect(find.text('old-result'), findsOneWidget);
    await tester.pumpWidget(_app(container, _pane(initialQuery: '')));
    await tester.pumpAndSettle();
    expect(find.text('old-result'), findsNothing);
    expect(find.text('输入关键词搜索当前书籍'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  searchTest('unmounting a pending search ignores its late completion', (
    tester,
  ) async {
    final pending = Completer<List<SearchResult>>();
    repository.handler = (_) => pending.future;
    await tester.pumpWidget(_app(container, _pane(initialQuery: 'pending')));
    await tester.pump();
    await tester.pumpWidget(_app(container, const Text('Closed')));
    pending.complete([_result('late')]);
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('late'), findsNothing);
  });

  searchTest('saving a result persists its snippet, locator and note type', (
    tester,
  ) async {
    repository.handler = (_) async => [_result('saved')];
    await tester.runAsync(
      () => container.read(notesByBookProvider('book-a').future),
    );
    await tester.pumpWidget(_app(container, _pane(initialQuery: 'saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存搜索结果为笔记'));
    await tester.pumpAndSettle();
    final notes = await tester.runAsync(
      () => container.read(notesByBookProvider('book-a').future),
    );
    expect(notes, hasLength(1));
    expect(notes!.single.bookId, 'book-a');
    expect(notes.single.title, 'saved');
    expect(notes.single.content, 'saved plain snippet');
    expect(notes.single.sourceText, 'saved plain snippet');
    expect(notes.single.locator!.chapterIndex, 0);
    expect(notes.single.locator!.chapterOffset, 40);
    expect(notes.single.noteType, NoteType.excerpt);
  });

  for (final switchesBook in [false, true]) {
    searchTest(
      'saving refreshes its original book after ${switchesBook ? 'switching books' : 'closing'}',
      (tester) async {
        repository.handler = (_) async => [_result('saving')];
        final gate = Completer<void>();
        final indexStarted = Completer<void>();
        final indexFinished = Completer<void>();
        repository.beforeNoteIndex = () async {
          indexStarted.complete();
          await gate.future;
        };
        repository.afterNoteIndex = indexFinished.complete;
        await tester.runAsync(
          () => container.read(notesByBookProvider('book-a').future),
        );
        await tester.pumpWidget(_app(container, _pane(initialQuery: 'saving')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('保存搜索结果为笔记'));
        await tester.runAsync(() => indexStarted.future);
        await tester.pumpWidget(
          _app(
            container,
            switchesBook ? _pane(bookId: 'book-b') : const Text('Closed'),
          ),
        );
        await tester.runAsync(() async {
          gate.complete();
          await indexFinished.future;
        });
        await tester.pumpAndSettle();
        final notes = await tester.runAsync(
          () => container.read(notesByBookProvider('book-a').future),
        );
        expect(notes, hasLength(1));
        expect(notes!.single.content, 'saving plain snippet');
        expect(find.text('已保存为笔记'), findsNothing);
      },
    );
  }

  searchTest('Escape closes embedded search through its callbacks once', (
    tester,
  ) async {
    var cleared = 0;
    var closed = 0;
    await tester.pumpWidget(
      _app(container, _pane(onClear: () => cleared++, onClose: () => closed++)),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(closed, 1);
  });

  searchTest('mobile search returns the original AI source and dismisses', (
    tester,
  ) async {
    repository.handler = (_) async => [_result('mobile')];
    InBookSearchAction? returned;
    await tester.pumpWidget(
      _app(
        container,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await showModalBottomSheet<InBookSearchAction>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _pane(initialQuery: 'mobile', embedded: false),
              );
            },
            child: const Text('Open search'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('对搜索结果片段提问'));
    await tester.pumpAndSettle();
    expect(returned!.intent, InBookSearchIntent.askAi);
    expect(returned!.sourceText, 'mobile plain snippet');
    expect(returned!.locator.chapterOffset, 40);
    expect(find.byType(ReaderSearchPane), findsNothing);
  });

  searchTest('context tabs delegate selection and retain Notebook navigation', (
    tester,
  ) async {
    await tester.runAsync(
      () => container
          .read(bookmarkRepositoryProvider)
          .saveBookmark(
            bookId: 'book-a',
            locator: ReadingLocator.epub(chapterIndex: 3),
            title: 'Notebook bookmark',
          ),
    );
    final selected = <ReadingLocator>[];
    final tabs = <ReaderContextTab>[];
    var closed = 0;
    Widget pane(ReaderContextTab tab) => ReaderContextPane(
      bookId: 'book-a',
      format: BookFormat.epub,
      activeTab: tab,
      searchQuery: null,
      currentLocator: null,
      selectedText: null,
      selectedLocator: null,
      onQueryChanged: (_) {},
      onPreviewResult: selected.add,
      onClear: () {},
      onClose: () => closed++,
      onTabChanged: tabs.add,
      onAction: (_) {},
    );
    await tester.pumpWidget(_app(container, pane(ReaderContextTab.search)));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderSearchPane), findsOneWidget);
    await tester.tap(find.text('笔记'));
    expect(tabs, [ReaderContextTab.notebook]);
    await tester.pumpWidget(_app(container, pane(ReaderContextTab.notebook)));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderNotebookPane), findsOneWidget);
    await tester.tap(find.text('Notebook bookmark'));
    expect(selected.single.chapterIndex, 3);
    await tester.tap(find.text('AI'));
    expect(tabs.last, ReaderContextTab.ai);
    await tester.tap(find.byTooltip('收起侧栏'));
    expect(closed, 1);
  });
}

Widget _app(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );

ReaderSearchPane _pane({
  String bookId = 'book-a',
  String? initialQuery,
  ReadingLocator? currentLocator,
  ValueChanged<String>? onQueryChanged,
  ValueChanged<ReadingLocator>? onPreviewResult,
  VoidCallback? onClear,
  VoidCallback? onClose,
  ValueChanged<InBookSearchAction>? onAction,
  bool embedded = true,
}) => ReaderSearchPane(
  bookId: bookId,
  initialQuery: initialQuery,
  currentLocator: currentLocator,
  onQueryChanged: onQueryChanged ?? (_) {},
  onPreviewResult: onPreviewResult ?? (_) {},
  onClear: onClear ?? () {},
  onClose: onClose,
  onAction: onAction,
  embedded: embedded,
);

SearchResult _result(String id, {int chapter = 0, String bookId = 'book-a'}) =>
    SearchResult(
      id: id,
      type: SearchResultType.content,
      title: id,
      snippet: '<mark>$id</mark> plain snippet',
      bookId: bookId,
      locator: ReadingLocator.epub(chapterIndex: chapter, chapterOffset: 40),
    );

final class _SearchRepository implements SearchRepository {
  _SearchRepository(this.storage);

  final SearchRepository storage;
  final queries = <SearchQuery>[];
  Future<List<SearchResult>> Function(SearchQuery) handler = (_) async =>
      const [];
  Future<void> Function()? beforeNoteIndex;
  void Function()? afterNoteIndex;

  @override
  Future<List<SearchResult>> search(SearchQuery query) {
    queries.add(query);
    return handler(query);
  }

  @override
  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  }) async {
    if (sourceType == 'note') {
      await beforeNoteIndex?.call();
    }
    await storage.indexText(
      sourceType: sourceType,
      sourceId: sourceId,
      bookId: bookId,
      title: title,
      text: text,
      locator: locator,
      sortOrder: sortOrder,
    );
    if (sourceType == 'note') {
      afterNoteIndex?.call();
    }
  }

  @override
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) => storage.bookChunks(bookIds: bookIds, categoryId: categoryId);

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) => storage.indexBookMetadata(
    bookId: bookId,
    title: title,
    author: author,
    description: description,
  );

  @override
  Future<void> indexTexts(List<SearchIndexEntry> entries) =>
      storage.indexTexts(entries);

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) =>
      storage.deleteBySource(sourceType, sourceId);

  @override
  Future<void> deleteByBook(String bookId) => storage.deleteByBook(bookId);
}
