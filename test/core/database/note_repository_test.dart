import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_content_repositories.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/domain/search/search_models.dart';

void main() {
  late AppDatabase database;
  late DriftNoteRepository repository;
  late DriftSearchRepository searchRepository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    searchRepository = DriftSearchRepository(database.searchDao);
    repository = DriftNoteRepository(database.noteDao, searchRepository);
    await database.bookDao.insertBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: '测试书',
        format: BookFormat.epub.value,
        libraryFilePath: '/tmp/book-1.epub',
        fileHash: 'hash-book-1',
        fileSize: 100,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('updates existing note and refreshes search chunk', () async {
    final note = await repository.saveNote(
      bookId: 'book-1',
      title: '摘录',
      content: '旧内容',
      sourceText: '原文',
      locator: ReadingLocator.epub(chapterIndex: 1),
      noteType: NoteType.excerpt,
    );

    final updated = await repository.saveNote(
      id: note.id,
      bookId: note.bookId,
      title: '摘录',
      content: '新内容 searchable',
      sourceText: note.sourceText,
      locator: note.locator,
      noteType: note.noteType,
    );
    final results = await searchRepository.search(
      const SearchQuery(
        query: 'searchable',
        typeFilters: {SearchResultType.note},
      ),
    );

    expect(updated.createdAt, note.createdAt);
    expect(updated.updatedAt, greaterThanOrEqualTo(note.updatedAt));
    expect(results.map((result) => result.sourceId), [note.id]);
  });
}
