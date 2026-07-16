import 'reading_position.dart';

final class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.locator,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.note,
    this.excerpt,
  });

  final String id;
  final String bookId;
  final ReadingLocator locator;
  final String? title;
  final String? note;
  final String? excerpt;
  final int createdAt;
  final int updatedAt;
}

abstract interface class BookmarkRepository {
  Stream<List<Bookmark>> watchByBook(String bookId);

  Future<List<Bookmark>> getByBook(String bookId);

  Future<List<Bookmark>> getAll();

  Future<Set<String>> getBookIdsWithBookmarks();

  Future<Bookmark?> findAtLocator(String bookId, ReadingLocator locator);

  Future<Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  });

  Future<void> deleteBookmark(String id);
}
