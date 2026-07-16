import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/library/application/library_controller.dart';
import 'package:pagesage/features/library/application/library_providers.dart';

void main() {
  test('library controller updates view state and clears filters', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(libraryControllerProvider.notifier);

    controller.setSort(LibrarySort.title);
    controller.setViewMode(LibraryViewMode.grid);
    controller.setGridSize(LibraryGridSize.large);
    controller.setSystemFilter(LibrarySystemFilter.favorite);
    controller.setFormat(BookFormat.pdf);
    controller.setCategory('cat-1');
    controller.setTag('tag-1');
    controller.setHasNotesOnly(true);
    controller.setHasBookmarksOnly(true);
    controller.selectBook('book-1');

    var state = container.read(libraryControllerProvider);
    expect(state.sort, LibrarySort.title);
    expect(state.viewMode, LibraryViewMode.grid);
    expect(state.gridSize, LibraryGridSize.large);
    expect(state.systemFilter, LibrarySystemFilter.favorite);
    expect(state.format, BookFormat.pdf);
    expect(state.categoryId, 'cat-1');
    expect(state.tagId, 'tag-1');
    expect(state.hasNotesOnly, isTrue);
    expect(state.hasBookmarksOnly, isTrue);
    expect(state.selectedBookId, 'book-1');

    controller.clearFilters();

    state = container.read(libraryControllerProvider);
    expect(state.sort, LibrarySort.title);
    expect(state.viewMode, LibraryViewMode.grid);
    expect(state.gridSize, LibraryGridSize.large);
    expect(state.systemFilter, LibrarySystemFilter.all);
    expect(state.format, isNull);
    expect(state.categoryId, isNull);
    expect(state.tagId, isNull);
    expect(state.hasNotesOnly, isFalse);
    expect(state.hasBookmarksOnly, isFalse);
    expect(state.selectedBookId, 'book-1');
  });

  test('setGridSize switches view mode back to grid', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(libraryControllerProvider.notifier);

    controller.setViewMode(LibraryViewMode.list);
    controller.setGridSize(LibraryGridSize.small);

    final state = container.read(libraryControllerProvider);
    expect(state.viewMode, LibraryViewMode.grid);
    expect(state.gridSize, LibraryGridSize.small);
    expect(state.gridSize.minTileWidth, 112);
  });

  test('filters library books by system filters and category', () {
    final books = [
      _item(
        id: 'a',
        title: 'A',
        isFavorite: true,
        readStatus: ReadStatus.unread,
      ),
      _item(
        id: 'b',
        title: 'B',
        categoryId: 'cat-1',
        readStatus: ReadStatus.finished,
        lastOpenedAt: 10,
      ),
      _item(
        id: 'c',
        title: 'C',
        format: BookFormat.pdf,
        categoryId: 'cat-2',
        readStatus: ReadStatus.reading,
      ),
    ];

    expect(
      filterLibraryBooks(
        books,
        systemFilter: LibrarySystemFilter.favorite,
      ).map((item) => item.book.id),
      ['a'],
    );
    expect(
      filterLibraryBooks(
        books,
        systemFilter: LibrarySystemFilter.recent,
      ).map((item) => item.book.id),
      ['b'],
    );
    expect(
      filterLibraryBooks(
        books,
        categoryId: 'cat-1',
      ).map((item) => item.book.id),
      ['b'],
    );
    expect(
      filterLibraryBooks(
        books,
        categoryId: '__uncategorized__',
      ).map((item) => item.book.id),
      ['a'],
    );
    expect(
      filterLibraryBooks(
        books,
        format: BookFormat.pdf,
      ).map((item) => item.book.id),
      ['c'],
    );
  });

  test('sorts library books by metadata, progress, size and format', () {
    final books = [
      _item(id: 'a', title: 'Zoo', author: 'Beta', fileSize: 30, progress: 0.2),
      _item(
        id: 'b',
        title: 'Alpha',
        author: 'Alpha',
        fileSize: 10,
        progress: 0.7,
      ),
      _item(
        id: 'c',
        title: 'Mid',
        author: 'Gamma',
        format: BookFormat.pdf,
        fileSize: 20,
        progress: 0.4,
      ),
    ];

    expect(sortLibraryBooks(books, LibrarySort.title).map(_id), [
      'b',
      'c',
      'a',
    ]);
    expect(sortLibraryBooks(books, LibrarySort.author).map(_id), [
      'b',
      'a',
      'c',
    ]);
    expect(sortLibraryBooks(books, LibrarySort.progress).map(_id), [
      'b',
      'c',
      'a',
    ]);
    expect(sortLibraryBooks(books, LibrarySort.fileSize).map(_id), [
      'a',
      'c',
      'b',
    ]);
    expect(sortLibraryBooks(books, LibrarySort.format).map(_id), [
      'a',
      'b',
      'c',
    ]);
  });
}

String _id(LibraryBook item) => item.book.id;

LibraryBook _item({
  required String id,
  required String title,
  String? author,
  BookFormat format = BookFormat.epub,
  String? categoryId,
  bool isFavorite = false,
  ReadStatus readStatus = ReadStatus.unread,
  int? lastOpenedAt,
  int fileSize = 1,
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
      fileSize: fileSize,
      categoryId: categoryId,
      isFavorite: isFavorite,
      readStatus: readStatus,
      createdAt: 1,
      updatedAt: 1,
      lastOpenedAt: lastOpenedAt,
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
