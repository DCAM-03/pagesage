import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import 'reader_notebook_providers.dart';

final readerAnnotationCommentServiceProvider =
    Provider<ReaderAnnotationCommentService>((ref) {
      return ReaderAnnotationCommentService(
        annotations: ref.watch(annotationRepositoryProvider),
        notes: ref.watch(noteRepositoryProvider),
        onChanged: (bookId) {
          if (ref.mounted) {
            ref.invalidate(notesByBookProvider(bookId));
          }
        },
      );
    });

final class ReaderAnnotationCommentService {
  const ReaderAnnotationCommentService({
    required AnnotationRepository annotations,
    required NoteRepository notes,
    required void Function(String bookId) onChanged,
  }) : this._(annotations, notes, onChanged);

  const ReaderAnnotationCommentService._(
    this._annotations,
    this._notes,
    this._onChanged,
  );

  final AnnotationRepository _annotations;
  final NoteRepository _notes;
  final void Function(String bookId) _onChanged;

  Future<Annotation> createWithComment({
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    required String comment,
    AnnotationColor color = AnnotationColor.yellow,
    AnnotationStyle style = AnnotationStyle.highlight,
  }) async {
    final text = comment.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(comment, 'comment', 'comment cannot be empty');
    }
    final annotation = await _annotations.saveAnnotation(
      bookId: bookId,
      locator: locator,
      selectedText: selectedText,
      color: color,
      style: style,
    );
    Note? note;
    try {
      note = await _notes.saveNote(
        bookId: bookId,
        annotationId: annotation.id,
        content: text,
        sourceText: selectedText,
        locator: locator,
        noteType: NoteType.comment,
      );
      await _annotations.linkNote(annotationId: annotation.id, noteId: note.id);
      _onChanged(bookId);
      return annotation;
    } on Object {
      if (note != null) {
        await _ignoreFailure(_notes.deleteNote(note.id));
      }
      await _ignoreFailure(_annotations.deleteAnnotation(annotation.id));
      rethrow;
    }
  }

  Future<Note> saveForAnnotation({
    required Annotation annotation,
    required String comment,
  }) async {
    final text = comment.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(comment, 'comment', 'comment cannot be empty');
    }
    final existing = await commentFor(annotation);
    if (existing != null) {
      final updated = await _notes.saveNote(
        id: existing.id,
        bookId: annotation.bookId,
        annotationId: annotation.id,
        title: existing.title,
        content: text,
        sourceText: existing.sourceText ?? annotation.selectedText,
        locator: existing.locator ?? annotation.locator,
        noteType: existing.noteType,
      );
      _onChanged(annotation.bookId);
      return updated;
    }
    final note = await _notes.saveNote(
      bookId: annotation.bookId,
      annotationId: annotation.id,
      content: text,
      sourceText: annotation.selectedText,
      locator: annotation.locator,
      noteType: NoteType.comment,
    );
    try {
      await _annotations.linkNote(annotationId: annotation.id, noteId: note.id);
    } on Object {
      await _ignoreFailure(_notes.deleteNote(note.id));
      rethrow;
    }
    _onChanged(annotation.bookId);
    return note;
  }

  Future<Note?> commentFor(Annotation annotation) async {
    final note = await linkedNoteFor(annotation);
    return note?.noteType == NoteType.comment ? note : null;
  }

  Future<Note?> linkedNoteFor(Annotation annotation) async {
    final noteId = annotation.noteId;
    if (noteId == null) {
      return null;
    }
    return _notes.getNote(noteId);
  }

  Future<void> deleteComment(Annotation annotation) async {
    final note = await commentFor(annotation);
    if (note == null) {
      return;
    }
    await _notes.deleteNote(note.id);
    await _ignoreFailure(_annotations.unlinkNote(annotationId: annotation.id));
    _onChanged(annotation.bookId);
  }

  Future<void> deleteAnnotation(Annotation annotation) async {
    final note = await commentFor(annotation);
    await _annotations.deleteAnnotation(annotation.id);
    if (note != null && note.noteType == NoteType.comment) {
      await _notes.deleteNote(note.id);
      _onChanged(annotation.bookId);
    }
  }
}

Future<void> _ignoreFailure(Future<void> future) async {
  try {
    await future;
  } on Object {
    return;
  }
}
