import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/reader/application/reader_providers.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';

void main() {
  test('reader book provider loads books even when indexing failed', () async {
    const failedIndexedBook = Book(
      id: 'book-1',
      title: '索引失败的书',
      format: BookFormat.epub,
      libraryFilePath: 'library/book-1.epub',
      fileHash: 'hash-1',
      fileSize: 1024,
      indexingStatus: 'failed',
      createdAt: 1,
      updatedAt: 1,
    );

    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(
          _FakeBookRepository(failedIndexedBook),
        ),
      ],
    );
    addTearDown(container.dispose);

    final book = await container.read(readerBookProvider('book-1').future);

    expect(book, failedIndexedBook);
    expect(book?.indexingStatus, 'failed');
  });

  test(
    'session controller saves location and marks finished at full progress',
    () async {
      const book = Book(
        id: 'book-1',
        title: '测试书',
        format: BookFormat.pdf,
        libraryFilePath: 'library/book-1.pdf',
        fileHash: 'hash-1',
        fileSize: 1024,
        createdAt: 1,
        updatedAt: 1,
      );
      final repository = _FakeBookRepository(book);
      final controller = ReaderSessionController(
        bookId: book.id,
        repository: repository,
      );

      controller.handleEvent(
        RendererLocationChanged(
          locator: ReadingLocator.pdf(page: 10, progress: 1),
          progress: 1,
          pageNumber: 10,
        ),
      );
      await controller.flush();

      expect(repository.savedProgress, 1);
      expect(repository.savedLocator?.page, 10);
      expect(repository.readStatusUpdates, [ReadStatus.finished]);
    },
  );
}

final class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(this.book);

  final Book book;
  ReadingLocator? savedLocator;
  double? savedProgress;
  final readStatusUpdates = <ReadStatus>[];

  @override
  Future<Book?> getBook(String id) async => id == book.id ? book : null;

  @override
  Future<Book> createImportedBook(NewBookDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<Book?> findByHash(String fileHash) async => null;

  @override
  Future<List<LibraryBook>> getLibrary() async => const [];

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async => null;

  @override
  Future<void> markOpened(String bookId) async {}

  @override
  Future<void> saveProgress({
    required String bookId,
    required ReadingLocator locator,
    required double progress,
    String? chapterTitle,
    int? pageNumber,
  }) async {
    savedLocator = locator;
    savedProgress = progress;
  }

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
  Future<void> updateReadStatus(String bookId, ReadStatus readStatus) async {
    readStatusUpdates.add(readStatus);
  }

  @override
  Stream<List<LibraryBook>> watchLibrary() => Stream.value(const []);
}
