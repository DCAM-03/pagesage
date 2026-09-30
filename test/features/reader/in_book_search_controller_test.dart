import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/reader/application/in_book_search_controller.dart';

void main() {
  test('debounces query changes and searches current book content', () async {
    final repository = _FakeSearchRepository([
      SearchResult(
        id: 'result-1',
        type: SearchResultType.content,
        title: '第一章',
        snippet: 'alpha snippet',
        bookId: 'book-1',
        locator: ReadingLocator.epub(chapterIndex: 0, progress: 0.1),
      ),
    ]);
    final controller = InBookSearchController(
      bookId: 'book-1',
      repository: repository,
      debounceDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.updateQuery('alpha');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(repository.queries.single.query, 'alpha');
    expect(repository.queries.single.bookId, 'book-1');
    expect(repository.queries.single.typeFilters, {SearchResultType.content});
    expect(controller.state.results, hasLength(1));
    expect(controller.state.selectedIndex, 0);
  });

  test('selects next and previous result cyclically', () async {
    final repository = _FakeSearchRepository([
      SearchResult(
        id: 'result-1',
        type: SearchResultType.content,
        title: '第一章',
        snippet: 'first',
        locator: ReadingLocator.epub(chapterIndex: 0),
      ),
      SearchResult(
        id: 'result-2',
        type: SearchResultType.content,
        title: '第二章',
        snippet: 'second',
        locator: ReadingLocator.epub(chapterIndex: 1),
      ),
    ]);
    final controller = InBookSearchController(
      bookId: 'book-1',
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.searchNow('alpha');
    controller.selectNext();
    expect(controller.state.selectedResult?.id, 'result-2');
    controller.selectNext();
    expect(controller.state.selectedResult?.id, 'result-1');
    controller.selectPrevious();
    expect(controller.state.selectedResult?.id, 'result-2');
  });

  test('selects result nearest after current locator', () async {
    final repository = _FakeSearchRepository([
      SearchResult(
        id: 'early',
        type: SearchResultType.content,
        title: '第一章',
        snippet: 'early',
        locator: ReadingLocator.epub(chapterIndex: 0, chapterOffset: 20),
      ),
      SearchResult(
        id: 'near',
        type: SearchResultType.content,
        title: '第二章',
        snippet: 'near',
        locator: ReadingLocator.epub(chapterIndex: 1, chapterOffset: 140),
      ),
      SearchResult(
        id: 'late',
        type: SearchResultType.content,
        title: '第二章',
        snippet: 'late',
        locator: ReadingLocator.epub(chapterIndex: 1, chapterOffset: 500),
      ),
    ]);
    final controller = InBookSearchController(
      bookId: 'book-1',
      repository: repository,
      currentLocator: ReadingLocator.epub(chapterIndex: 1, chapterOffset: 120),
    );
    addTearDown(controller.dispose);

    await controller.searchNow('alpha');

    expect(controller.state.selectedResult?.id, 'near');
  });

  test('keeps query and exposes retry after search failure', () async {
    final repository = _FakeSearchRepository(
      const [],
      error: StateError('failed'),
    );
    final controller = InBookSearchController(
      bookId: 'book-1',
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.searchNow('alpha');

    expect(controller.state.query, 'alpha');
    expect(controller.state.error, '搜索失败');
    expect(controller.state.results, isEmpty);
  });
}

final class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository(this.results, {this.error});

  final List<SearchResult> results;
  final Object? error;
  final queries = <SearchQuery>[];

  @override
  Future<List<SearchResult>> search(SearchQuery query) async {
    queries.add(query);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return results;
  }

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
