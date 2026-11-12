import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/books/reading_position.dart';
import '../../domain/notes/note.dart' as domain;
import '../../domain/search/search_models.dart' as domain;
import '../../domain/books/locator_excerpt.dart';
import 'drift_locator_mapping.dart';
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftNoteRepository implements domain.NoteRepository {
  const DriftNoteRepository(this._dao, this._searchRepository);

  final db.NoteDao _dao;
  final domain.SearchRepository _searchRepository;

  @override
  Stream<List<domain.Note>> watchNotes() {
    return _dao.watchNotes().map(
      (rows) => rows.map(_mapNote).toList(growable: false),
    );
  }

  @override
  Future<List<domain.Note>> getNotes() async {
    final rows = await _dao.getNotes();
    return rows.map(_mapNote).toList(growable: false);
  }

  @override
  Future<List<domain.Note>> getByBook(String bookId) async {
    final rows = await _dao.getByBook(bookId);
    return rows.map(_mapNote).toList(growable: false);
  }

  @override
  Future<Set<String>> getBookIdsWithNotes() {
    return _dao.getBookIdsWithNotes();
  }

  @override
  Future<domain.Note?> getNote(String id) async {
    final row = await _dao.getNote(id);
    return row == null ? null : _mapNote(row);
  }

  @override
  Future<domain.Note> saveNote({
    String? id,
    String? bookId,
    String? annotationId,
    String? title,
    required String content,
    String? sourceText,
    ReadingLocator? locator,
    domain.NoteType noteType = domain.NoteType.text,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = id == null ? null : await _dao.getNote(id);
    final resolvedLocator = locator == null
        ? null
        : enrichLocatorForJump(locator, fallbackExcerpt: sourceText);
    final note = domain.Note(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: resolvedLocator,
      noteType: noteType,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertNote(
      db.NotesCompanion.insert(
        id: note.id,
        bookId: Value(note.bookId),
        annotationId: Value(note.annotationId),
        title: Value(note.title),
        content: note.content,
        sourceText: Value(note.sourceText),
        locator: Value(note.locator?.toJsonText()),
        noteType: note.noteType.value,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
    );
    await _searchRepository.indexText(
      sourceType: 'note',
      sourceId: note.id,
      bookId: note.bookId,
      title: note.title ?? '笔记',
      text: [note.sourceText, note.content].whereType<String>().join('\n'),
      locator: note.locator,
    );
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    await _dao.deleteNote(id);
    await _searchRepository.deleteBySource('note', id);
  }

  domain.Note _mapNote(db.NoteRow row) {
    return domain.Note(
      id: row.id,
      bookId: row.bookId,
      annotationId: row.annotationId,
      title: row.title,
      content: row.content,
      sourceText: row.sourceText,
      locator: row.locator == null
          ? null
          : locatorFromDatabaseText(row.locator!),
      noteType: domain.NoteType.fromValue(row.noteType),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
