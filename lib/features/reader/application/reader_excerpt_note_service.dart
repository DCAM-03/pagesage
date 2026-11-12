import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import '../../../domain/search/search_models.dart';
import 'reader_notebook_providers.dart';

final readerExcerptNoteServiceProvider = Provider<ReaderExcerptNoteService>((
  ref,
) {
  return ReaderExcerptNoteService(
    repository: ref.watch(noteRepositoryProvider),
    onSaved: (bookId) {
      if (ref.mounted) {
        ref.invalidate(notesByBookProvider(bookId));
      }
    },
  );
});

final class ReaderExcerptNoteService {
  const ReaderExcerptNoteService({
    required NoteRepository repository,
    required void Function(String bookId) onSaved,
  }) : this._(repository, onSaved);

  const ReaderExcerptNoteService._(this._repository, this._onSaved);

  final NoteRepository _repository;
  final void Function(String bookId) _onSaved;

  Future<Note?> saveResult({
    required String bookId,
    required SearchResult result,
  }) {
    final text = plainSearchSnippet(result.snippet);
    return saveExcerpt(
      bookId: bookId,
      title: result.title,
      content: text,
      sourceText: text,
      locator: result.locator,
    );
  }

  Future<Note?> saveExcerpt({
    required String bookId,
    required String content,
    String? title,
    String? sourceText,
    ReadingLocator? locator,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) return null;
    final note = await _repository.saveNote(
      bookId: bookId,
      title: title,
      content: trimmedContent,
      sourceText: sourceText,
      locator: locator,
      noteType: NoteType.excerpt,
    );
    _onSaved(bookId);
    return note;
  }
}

String plainSearchSnippet(String value) {
  return value.replaceAll(RegExp('<[^>]+>'), '').trim();
}
