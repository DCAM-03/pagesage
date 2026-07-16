final class BookTag {
  const BookTag({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.color,
  });

  final String id;
  final String name;
  final String? color;
  final int createdAt;
  final int updatedAt;
}

abstract interface class TagRepository {
  Stream<List<BookTag>> watchTags();

  Future<List<BookTag>> getTags();

  Future<List<BookTag>> getTagsForBook(String bookId);

  /// Live map of bookId → tags for library rendering without per-row queries.
  Stream<Map<String, List<BookTag>>> watchTagsByBookId();

  Future<Set<String>> getBookIdsWithTag(String tagId);

  Future<List<BookTag>> getTagsForNote(String noteId);

  Future<BookTag> saveTag({String? id, required String name, String? color});

  Future<void> setBookTags(String bookId, Iterable<String> tagIds);

  Future<void> setNoteTags(String noteId, Iterable<String> tagIds);

  Future<void> deleteTag(String id);
}
