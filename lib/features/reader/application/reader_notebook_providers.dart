import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/books/bookmark.dart';
import '../../../domain/notes/note.dart';

final bookmarksByBookProvider = StreamProvider.family<List<Bookmark>, String>((
  ref,
  bookId,
) {
  return ref.watch(bookmarkRepositoryProvider).watchByBook(bookId);
});

final notesByBookProvider = FutureProvider.family<List<Note>, String>((
  ref,
  bookId,
) {
  return ref.watch(noteRepositoryProvider).getByBook(bookId);
});

final annotationsByBookProvider =
    StreamProvider.family<List<Annotation>, String>((ref, bookId) {
      return ref.watch(annotationRepositoryProvider).watchByBook(bookId);
    });
