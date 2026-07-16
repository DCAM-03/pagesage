import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_content_repositories.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/search/search_models.dart';

void main() {
  late AppDatabase database;
  late DriftSearchRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSearchRepository(database.searchDao);
    await _insertBook(
      database,
      id: 'book-epub',
      title: 'EPUB Book',
      format: BookFormat.epub,
      categoryId: 'cat-fiction',
    );
    await _insertBook(
      database,
      id: 'book-pdf',
      title: 'PDF Book',
      format: BookFormat.pdf,
      categoryId: 'cat-paper',
    );
    await database.tagDao.upsertTag(
      TagsCompanion.insert(
        id: 'tag-important',
        name: '重要',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await database.tagDao.setBookTags('book-epub', ['tag-important']);
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-epub:chapter-1',
      bookId: 'book-epub',
      title: '第一章',
      text: 'alpha shared term',
    );
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-pdf:page-1',
      bookId: 'book-pdf',
      title: '第一页',
      text: 'alpha shared term',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('filters FTS results by format, category, tag and book scope', () async {
    final epubResults = await repository.search(
      const SearchQuery(query: 'alpha', format: BookFormat.epub),
    );
    expect(epubResults.map((result) => result.bookId), ['book-epub']);

    final categoryResults = await repository.search(
      const SearchQuery(query: 'alpha', categoryId: 'cat-paper'),
    );
    expect(categoryResults.map((result) => result.bookId), ['book-pdf']);

    final tagResults = await repository.search(
      const SearchQuery(query: 'alpha', tagIds: {'tag-important'}),
    );
    expect(tagResults.map((result) => result.bookId), ['book-epub']);

    final scopedResults = await repository.search(
      const SearchQuery(query: 'alpha', bookId: 'book-pdf'),
    );
    expect(scopedResults.map((result) => result.bookId), ['book-pdf']);
  });

  test('separates book metadata results from content results', () async {
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-epub',
      bookId: 'book-epub',
      title: 'zeta metadata',
      text: 'zeta metadata',
    );
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-epub:content',
      bookId: 'book-epub',
      title: 'zeta content',
      text: 'zeta content',
    );

    final bookResults = await repository.search(
      const SearchQuery(query: 'zeta', typeFilters: {SearchResultType.book}),
    );
    final contentResults = await repository.search(
      const SearchQuery(query: 'zeta', typeFilters: {SearchResultType.content}),
    );

    expect(bookResults.map((result) => result.type), [SearchResultType.book]);
    expect(contentResults.map((result) => result.type), [
      SearchResultType.content,
    ]);
  });

  test('sorts by title hit, source weight and recent reading', () async {
    await _insertBook(
      database,
      id: 'book-old',
      title: 'Old Book',
      format: BookFormat.epub,
      categoryId: 'cat-fiction',
      lastOpenedAt: 10,
    );
    await _insertBook(
      database,
      id: 'book-new',
      title: 'New Book',
      format: BookFormat.epub,
      categoryId: 'cat-fiction',
      lastOpenedAt: 20,
    );
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-old:body',
      bookId: 'book-old',
      title: 'Body',
      text: 'gamma shared',
    );
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-new:body',
      bookId: 'book-new',
      title: 'Body',
      text: 'gamma shared',
    );

    final recentResults = await repository.search(
      const SearchQuery(query: 'gamma'),
    );
    expect(recentResults.map((result) => result.bookId), [
      'book-new',
      'book-old',
    ]);

    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-epub:title-hit',
      bookId: 'book-epub',
      title: 'delta title',
      text: 'body',
    );
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-pdf:body-hit',
      bookId: 'book-pdf',
      title: 'body',
      text: 'delta body',
    );

    final titleResults = await repository.search(
      const SearchQuery(query: 'delta'),
    );
    expect(titleResults.first.sourceId, 'book-epub:title-hit');

    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-epub:epsilon-content',
      bookId: 'book-epub',
      title: 'content',
      text: 'epsilon',
    );
    await repository.indexText(
      sourceType: 'note',
      sourceId: 'note-epsilon',
      bookId: 'book-epub',
      title: 'note',
      text: 'epsilon',
    );

    final weightedResults = await repository.search(
      const SearchQuery(query: 'epsilon'),
    );
    expect(weightedResults.first.type, SearchResultType.note);
  });
}

Future<void> _insertBook(
  AppDatabase database, {
  required String id,
  required String title,
  required BookFormat format,
  required String categoryId,
  int? lastOpenedAt,
}) {
  return database.bookDao.insertBook(
    BooksCompanion.insert(
      id: id,
      title: title,
      format: format.value,
      libraryFilePath: '/tmp/$id.${format.value}',
      fileHash: 'hash-$id',
      fileSize: 100,
      categoryId: Value(categoryId),
      createdAt: 1,
      updatedAt: 1,
      lastOpenedAt: Value(lastOpenedAt),
    ),
  );
}
