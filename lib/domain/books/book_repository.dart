import 'book.dart';
import 'reading_position.dart';

abstract interface class BookRepository {
  Stream<List<LibraryBook>> watchLibrary();

  Future<List<LibraryBook>> getLibrary();

  Future<Book?> getBook(String id);

  Future<Book?> findByHash(String fileHash);

  Future<Book> createImportedBook(NewBookDraft draft);

  Future<ReadingProgressSnapshot?> getProgress(String bookId);

  Future<void> saveProgress({
    required String bookId,
    required ReadingLocator locator,
    required double progress,
    String? chapterTitle,
    int? pageNumber,
  });

  Future<void> markOpened(String bookId);

  Future<void> updateMetadata({
    required String bookId,
    String? title,
    String? author,
    String? description,
    String? coverPath,
  });

  Future<void> updateCategory(String bookId, String? categoryId);

  Future<void> toggleFavorite(String bookId, bool isFavorite);

  Future<void> updateReadStatus(String bookId, ReadStatus readStatus);

  Future<void> updateIndexingStatus(String bookId, String indexingStatus);

  Future<void> deleteBook(String bookId);
}
