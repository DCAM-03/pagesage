import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/books/tag.dart' as domain;
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftTagRepository implements domain.TagRepository {
  const DriftTagRepository(this._dao);

  final db.TagDao _dao;

  @override
  Stream<List<domain.BookTag>> watchTags() {
    return _dao.watchTags().map(
      (rows) => rows.map(_mapTag).toList(growable: false),
    );
  }

  @override
  Future<List<domain.BookTag>> getTags() async {
    final rows = await _dao.getTags();
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Future<List<domain.BookTag>> getTagsForBook(String bookId) async {
    final rows = await _dao.getTagsForBook(bookId);
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Stream<Map<String, List<domain.BookTag>>> watchTagsByBookId() {
    return _dao.watchTagsByBookId().map((raw) {
      return {
        for (final entry in raw.entries)
          entry.key: entry.value.map(_mapTag).toList(growable: false),
      };
    });
  }

  @override
  Future<Set<String>> getBookIdsWithTag(String tagId) {
    return _dao.getBookIdsWithTag(tagId);
  }

  @override
  Future<List<domain.BookTag>> getTagsForNote(String noteId) async {
    final rows = await _dao.getTagsForNote(noteId);
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Future<domain.BookTag> saveTag({
    String? id,
    required String name,
    String? color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('标签名称不能为空');
    }
    final existing = await getTags();
    if (existing.any((tag) => tag.id != id && tag.name == trimmedName)) {
      throw const FormatException('标签名称已存在');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    domain.BookTag? previous;
    for (final tag in existing) {
      if (tag.id == id) {
        previous = tag;
        break;
      }
    }
    final tag = domain.BookTag(
      id: id ?? _uuid.v4(),
      name: trimmedName,
      color: color,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertTag(
      db.TagsCompanion.insert(
        id: tag.id,
        name: tag.name,
        color: Value(tag.color),
        createdAt: tag.createdAt,
        updatedAt: tag.updatedAt,
      ),
    );
    return tag;
  }

  @override
  Future<void> setBookTags(String bookId, Iterable<String> tagIds) {
    return _dao.setBookTags(bookId, tagIds);
  }

  @override
  Future<void> setNoteTags(String noteId, Iterable<String> tagIds) {
    return _dao.setNoteTags(noteId, tagIds);
  }

  @override
  Future<void> deleteTag(String id) {
    return _dao.deleteTag(id);
  }

  domain.BookTag _mapTag(db.TagRow row) {
    return domain.BookTag(
      id: row.id,
      name: row.name,
      color: row.color,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
