import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_content_repositories.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';

void main() {
  late AppDatabase database;
  late DriftBookmarkRepository repository;
  late DriftSearchRepository searchRepository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    searchRepository = DriftSearchRepository(database.searchDao);
    repository = DriftBookmarkRepository(
      database.bookmarkDao,
      searchRepository,
    );
    await database.bookDao.insertBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: '测试书',
        format: BookFormat.epub.value,
        libraryFilePath: '/tmp/book-1.epub',
        fileHash: 'hash-book-1',
        fileSize: 100,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('finds bookmark at equivalent locator', () async {
    final bookmark = await repository.saveBookmark(
      bookId: 'book-1',
      locator: ReadingLocator.epub(
        href: 'chapter.xhtml',
        chapterIndex: 1,
        progress: 0.2,
      ),
      title: '第一章',
      excerpt: '原文摘录',
    );

    final found = await repository.findAtLocator(
      'book-1',
      ReadingLocator.epub(
        href: 'chapter.xhtml',
        chapterIndex: 1,
        progress: 0.22,
      ),
    );

    expect(found?.id, bookmark.id);
  });

  test('updates note and search chunk when saving existing bookmark', () async {
    final bookmark = await repository.saveBookmark(
      bookId: 'book-1',
      locator: ReadingLocator.pdf(page: 3, scrollOffset: 100),
      title: '第 3 页',
      note: '旧备注',
      excerpt: '原文摘录',
    );

    await repository.saveBookmark(
      id: bookmark.id,
      bookId: bookmark.bookId,
      locator: bookmark.locator,
      title: bookmark.title,
      note: '新备注 searchable',
      excerpt: bookmark.excerpt,
    );

    final saved = await repository.findAtLocator(
      'book-1',
      ReadingLocator.pdf(page: 3, scrollOffset: 112),
    );
    final results = await searchRepository.search(
      const SearchQuery(
        query: 'searchable',
        typeFilters: {SearchResultType.bookmark},
      ),
    );

    expect(saved?.createdAt, bookmark.createdAt);
    expect(saved?.note, '新备注 searchable');
    expect(results.map((result) => result.sourceId), [bookmark.id]);
  });
}
