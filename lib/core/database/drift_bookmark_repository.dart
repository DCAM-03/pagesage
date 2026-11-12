import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/books/bookmark.dart' as domain;
import '../../domain/books/reading_position.dart';
import '../../domain/search/search_models.dart' as domain;
import '../../domain/books/locator_excerpt.dart';
import 'drift_locator_mapping.dart';
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftBookmarkRepository implements domain.BookmarkRepository {
  const DriftBookmarkRepository(this._dao, this._searchRepository);

  final db.BookmarkDao _dao;
  final domain.SearchRepository _searchRepository;

  @override
  Stream<List<domain.Bookmark>> watchByBook(String bookId) {
    return _dao
        .watchByBook(bookId)
        .map((rows) => rows.map(_mapBookmark).toList(growable: false));
  }

  @override
  Future<List<domain.Bookmark>> getByBook(String bookId) async {
    final rows = await _dao.getByBook(bookId);
    return rows.map(_mapBookmark).toList(growable: false);
  }

  @override
  Future<List<domain.Bookmark>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_mapBookmark).toList(growable: false);
  }

  @override
  Future<Set<String>> getBookIdsWithBookmarks() {
    return _dao.getBookIdsWithBookmarks();
  }

  @override
  Future<domain.Bookmark?> findAtLocator(
    String bookId,
    ReadingLocator locator,
  ) async {
    final bookmarks = await getByBook(bookId);
    for (final bookmark in bookmarks) {
      if (bookmark.locator.matches(locator)) {
        return bookmark;
      }
    }
    return null;
  }

  @override
  Future<domain.Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = id == null ? null : await _dao.getBookmark(id);
    final resolvedExcerpt = compactLocatorExcerpt(
      excerpt ?? locator.excerpt ?? note,
    );
    final resolvedLocator = enrichLocatorForJump(
      locator,
      fallbackExcerpt: resolvedExcerpt,
    );
    final bookmark = domain.Bookmark(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      locator: resolvedLocator,
      title: title,
      note: note,
      excerpt: resolvedExcerpt,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertBookmark(
      db.BookmarksCompanion.insert(
        id: bookmark.id,
        bookId: bookmark.bookId,
        locator: bookmark.locator.toJsonText(),
        title: Value(bookmark.title),
        note: Value(bookmark.note),
        excerpt: Value(bookmark.excerpt),
        createdAt: bookmark.createdAt,
        updatedAt: bookmark.updatedAt,
      ),
    );
    await _searchRepository.indexText(
      sourceType: 'bookmark',
      sourceId: bookmark.id,
      bookId: bookId,
      title: title ?? resolvedLocator.displayLabel,
      text: [note, resolvedExcerpt].whereType<String>().join('\n'),
      locator: resolvedLocator,
    );
    return bookmark;
  }

  @override
  Future<void> deleteBookmark(String id) async {
    await _dao.deleteBookmark(id);
    await _searchRepository.deleteBySource('bookmark', id);
  }

  domain.Bookmark _mapBookmark(db.BookmarkRow row) {
    return domain.Bookmark(
      id: row.id,
      bookId: row.bookId,
      locator: locatorFromDatabaseText(row.locator),
      title: row.title,
      note: row.note,
      excerpt: row.excerpt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
