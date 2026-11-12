import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/search/presentation/search_page.dart';

void main() {
  testWidgets('new input invalidates pending responses before debounce', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repository = _ControlledSearch();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        searchRepositoryProvider.overrideWithValue(repository),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SearchPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), '旧查询');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(repository.requests, hasLength(1));
      await tester.enterText(find.byType(SearchBar), '新查询');
      repository.requests.first.complete([_hit('旧结果')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('旧结果'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(repository.requests, hasLength(2));
      repository.requests.last.complete([_hit('新结果')]);
      await tester.pumpAndSettle();
      expect(find.text('新结果'), findsOneWidget);
      expect(find.text('旧结果'), findsNothing);
      await tester.enterText(find.byType(SearchBar), '');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('新结果'), findsNothing);
      expect(repository.requests, hasLength(2));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(database.close);
    }
  });

  testWidgets(
    'opening a Chinese match keeps file and exact focus coordinates',
    (tester) async {
      final database = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final repository = _ControlledSearch();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          searchRepositoryProvider.overrideWithValue(repository),
        ],
      );
      ReadingLocator? opened;
      String? openedBook;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SearchPage()),
          GoRoute(
            path: '/reader/:bookId',
            name: 'reader',
            builder: (_, state) {
              openedBook = state.pathParameters['bookId'];
              opened = state.extra as ReadingLocator;
              return const Scaffold(body: Text('阅读正文'));
            },
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(SearchBar), '知识管理');
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        repository.requests.single.complete([_hit('定位结果')]);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('更多搜索结果操作'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('打开来源'));
        await tester.pumpAndSettle();
        expect(openedBook, 'book');
        expect(opened?.href, 'nested/chapter.md');
        expect(opened?.chapterOffset, 42);
        expect(opened?.chapterEndOffset, 46);
        expect(opened?.excerpt, '知识管理');
        expect(opened?.folderFileLocal, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        await tester.runAsync(database.close);
      }
    },
  );
}

SearchResult _hit(String title) => SearchResult(
  id: title,
  type: SearchResultType.content,
  bookId: 'book',
  title: title,
  snippet: '<mark>知识管理</mark>正文',
  locator: ReadingLocator.markdown(
    href: 'nested/chapter.md',
    chapterIndex: 0,
    chapterOffset: 42,
    chapterEndOffset: 46,
    excerpt: '知识管理',
    folderFileLocal: true,
  ),
);

class _ControlledSearch implements SearchRepository {
  final requests = <Completer<List<SearchResult>>>[];

  @override
  Future<List<SearchResult>> search(SearchQuery query) {
    final request = Completer<List<SearchResult>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
