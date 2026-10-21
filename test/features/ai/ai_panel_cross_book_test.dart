import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ai/application/ai_context_range.dart';
import 'package:pagesage/features/ai/application/ai_context_source.dart';
import 'package:pagesage/features/ai/application/ai_providers.dart';
import 'package:pagesage/features/ai/application/retrieval_context_source.dart';
import 'package:pagesage/features/ai/presentation/ai_panel.dart';

/// Records where the panel asked to navigate.
final class _Sibling implements SearchRepository {
  @override
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async => [
    for (final id in bookIds.toSet())
      SearchBookChunks(
        bookId: id,
        chunks: [
          SearchChunk(
            id: '$id:pdf:42:0',
            bookId: id,
            title: '第 42 页',
            text: '共享的上下文词，出现在另一本书里。',
            sortOrder: 1,
            locator: ReadingLocator.pdf(page: 42),
          ),
        ],
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Book _book(String id, String title, String? categoryId) => Book(
  id: id,
  title: title,
  format: BookFormat.pdf,
  libraryFilePath: '/tmp/$id.pdf',
  fileHash: 'h$id',
  fileSize: 1,
  categoryId: categoryId,
  indexingStatus: 'done',
  createdAt: 1,
  updatedAt: 1,
);

final class _Library implements BookRepository {
  final current = _book('book-a', '甲书', 'folder-1');
  final sibling = _book('book-b', '乙书', 'folder-1');

  @override
  Future<Book?> getBook(String id) async =>
      [current, sibling].firstWhere((book) => book.id == id);

  @override
  Future<List<LibraryBook>> getLibrary() async => [
    LibraryBook(book: current),
    LibraryBook(book: sibling),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NoSource extends AiContextSource {
  @override
  Future<ContextSource?> load({
    required AiContextRange range,
    required String bookPath,
    required ReadingLocator? locator,
    required bool isEpub,
  }) async => null;
}

void main() {
  testWidgets('a folder passage opens its own book at the right page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final library = _Library();
    final panelKey = GlobalKey();
    final router = GoRouter(
      initialLocation: '/book/book-a/reader',
      routes: [
        GoRoute(
          path: '/book/:bookId/reader',
          builder: (context, state) {
            final label =
                'reader ${state.pathParameters['bookId']} '
                'page ${(state.extra as ReadingLocator?)?.page}';
            if (state.pathParameters['bookId'] == 'book-b') {
              return Scaffold(body: Center(child: Text(label)));
            }
            // The panel lives on the current book's page, with a Navigator
            // above it — the dropdown needs one to open.
            return Scaffold(
              body: Center(
                child: SizedBox(
                  width: 460,
                  height: 900,
                  child: AiPanel(
                    key: panelKey,
                    bookId: 'book-a',
                    locator: ReadingLocator.pdf(page: 1),
                    initialContext: '共享的上下文词',
                    onJumpTo: (locator) {},
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiContextSourceProvider.overrideWithValue(_NoSource()),
          retrievalContextSourceProvider.overrideWithValue(
            RetrievalContextSource(
              searchRepository: _Sibling(),
              bookRepository: library,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Pick the folder range: the passage comes from 乙书, not this book.
    await tester.tap(find.byType(DropdownButtonFormField<AiContextRange>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文件夹关联').last);
    await tester.pumpAndSettle();
    expect(find.text('乙书 · 第 42 页'), findsOneWidget);

    // The last row is the sibling book's passage; earlier rows belong to
    // this book and only scroll.
    await tester.tap(find.byTooltip('回到这段原文').last);
    await tester.pumpAndSettle();

    // The passage came from another book, so opening it is a navigation to
    // that book at that page, not a scroll inside this one.
    expect(find.text('reader book-b page 42'), findsOneWidget);
  });
}
