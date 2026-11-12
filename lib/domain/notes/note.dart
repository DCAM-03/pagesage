import '../books/reading_position.dart';

enum NoteType {
  text('text'),
  excerpt('excerpt'),
  comment('comment'),
  ai('ai'),
  question('question');

  const NoteType(this.value);

  final String value;

  static NoteType fromValue(String value) {
    return values.firstWhere(
      (type) => type.value == value,
      orElse: () => NoteType.text,
    );
  }
}

final class Note {
  const Note({
    required this.id,
    required this.content,
    required this.noteType,
    required this.createdAt,
    required this.updatedAt,
    this.bookId,
    this.annotationId,
    this.title,
    this.sourceText,
    this.locator,
  });

  final String id;
  final String? bookId;
  final String? annotationId;
  final String? title;
  final String content;
  final String? sourceText;
  final ReadingLocator? locator;
  final NoteType noteType;
  final int createdAt;
  final int updatedAt;
}

abstract interface class NoteRepository {
  Stream<List<Note>> watchNotes();

  Future<List<Note>> getNotes();

  Future<List<Note>> getByBook(String bookId);

  Future<Set<String>> getBookIdsWithNotes();

  Future<Note?> getNote(String id);

  Future<Note> saveNote({
    String? id,
    String? bookId,
    String? annotationId,
    String? title,
    required String content,
    String? sourceText,
    ReadingLocator? locator,
    NoteType noteType,
  });

  Future<void> deleteNote(String id);
}
