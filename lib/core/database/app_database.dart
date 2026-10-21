import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('BookRow')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get originalTitle => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get format => text()();
  TextColumn get originalFormat => text().nullable()();
  TextColumn get originalFilePath => text().nullable()();
  TextColumn get libraryFilePath => text()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get fileHash => text()();
  IntColumn get fileSize => integer()();
  TextColumn get language => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get readStatus => text().withDefault(const Constant('unread'))();
  TextColumn get indexingStatus =>
      text().withDefault(const Constant('pending'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get lastOpenedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get icon => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BookTagRow')
class BookTags extends Table {
  TextColumn get bookId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {bookId, tagId};
}

@DataClassName('ReadingProgressRow')
class ReadingProgress extends Table {
  TextColumn get bookId => text()();
  TextColumn get locator => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get chapterTitle => text().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {bookId};
}

@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get locator => text()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get excerpt => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnnotationRow')
class Annotations extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get locator => text()();
  TextColumn get selectedText => text()();
  TextColumn get color => text()();
  TextColumn get style => text()();
  TextColumn get noteId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().nullable()();
  TextColumn get annotationId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get sourceText => text().nullable()();
  TextColumn get locator => text().nullable()();
  TextColumn get noteType => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('NoteTagRow')
class NoteTags extends Table {
  TextColumn get noteId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

@DataClassName('AiConversationRow')
class AiConversations extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().nullable()();
  TextColumn get locator => text().nullable()();
  TextColumn get provider => text()();
  TextColumn get model => text()();
  TextColumn get prompt => text()();
  TextColumn get contextText => text().nullable()();
  TextColumn get answer => text()();
  TextColumn get sourceText => text().nullable()();
  TextColumn get noteId => text().nullable()();
  IntColumn get createdAt => integer()();

  /// Groups consecutive turns asked against the same context.
  ///
  /// Null on rows written before this column existed: they are single turns,
  /// and the history view shows them as such rather than inventing a thread.
  /// Their `id` is a usable thread key of its own if it is ever needed.
  TextColumn get threadId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchChunkRow')
class SearchChunks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get locator => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().named('text')();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ImportTaskRow')
class ImportTasks extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get status => text()();
  TextColumn get sourcePath => text().nullable()();
  TextColumn get targetPath => text().nullable()();
  TextColumn get bookId => text().nullable()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get message => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Persisted OCR text + geometry for a single PDF page (local-only).
@DataClassName('OcrPageRow')
class OcrPages extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get pageNumber => integer()();
  TextColumn get body => text().named('text')();
  TextColumn get language => text().nullable()();
  TextColumn get engine => text().nullable()();
  RealColumn get confidence => real().nullable()();

  /// JSON list of {text,left,top,width,height} normalized boxes.
  TextColumn get blocksJson => text()();
  IntColumn get imageWidth => integer().nullable()();
  IntColumn get imageHeight => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

final class BookWithProgressRow {
  const BookWithProgressRow({required this.book, this.progress});

  final BookRow book;
  final ReadingProgressRow? progress;
}

final class SearchMatchRow {
  const SearchMatchRow({required this.chunk, required this.snippet});

  final SearchChunkRow chunk;
  final String snippet;
}

@DriftAccessor(tables: [Books, ReadingProgress])
class BookDao extends DatabaseAccessor<AppDatabase> with _$BookDaoMixin {
  BookDao(super.db);

  /// Books only — progress is watched separately so reading saves do not
  /// re-query/re-join the entire library on every locator tick.
  Stream<List<BookRow>> watchBooks() {
    return (select(books)..orderBy([
          (book) => OrderingTerm.desc(book.lastOpenedAt),
          (book) => OrderingTerm.desc(book.createdAt),
        ]))
        .watch();
  }

  Future<List<BookRow>> getBooks() {
    return (select(books)..orderBy([
          (book) => OrderingTerm.desc(book.lastOpenedAt),
          (book) => OrderingTerm.desc(book.createdAt),
        ]))
        .get();
  }

  Stream<List<BookWithProgressRow>> watchLibrary() =>
      _libraryQuery().watch().map(
        (rows) => rows
            .map(
              (row) => BookWithProgressRow(
                book: row.readTable(books),
                progress: row.readTableOrNull(readingProgress),
              ),
            )
            .toList(growable: false),
      );

  Future<List<BookWithProgressRow>> getLibrary() async {
    final rows = await _libraryQuery().get();
    return rows
        .map(
          (row) => BookWithProgressRow(
            book: row.readTable(books),
            progress: row.readTableOrNull(readingProgress),
          ),
        )
        .toList(growable: false);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _libraryQuery() {
    return select(books).join([
      leftOuterJoin(
        readingProgress,
        readingProgress.bookId.equalsExp(books.id),
      ),
    ])..orderBy([
      OrderingTerm.desc(books.lastOpenedAt),
      OrderingTerm.desc(books.createdAt),
    ]);
  }

  Future<BookRow?> getBook(String id) {
    return (select(
      books,
    )..where((book) => book.id.equals(id))).getSingleOrNull();
  }

  Future<BookRow?> findByHash(String fileHash) {
    return (select(
      books,
    )..where((book) => book.fileHash.equals(fileHash))).getSingleOrNull();
  }

  Future<void> insertBook(BooksCompanion book) {
    return into(books).insert(book);
  }

  Future<void> markOpened(String id, int openedAt) {
    return (update(books)..where((book) => book.id.equals(id))).write(
      BooksCompanion(
        readStatus: const Value('reading'),
        lastOpenedAt: Value(openedAt),
        updatedAt: Value(openedAt),
      ),
    );
  }

  Future<void> updateMetadata({
    required String id,
    String? title,
    String? author,
    String? description,
    String? coverPath,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(books)..where((book) => book.id.equals(id))).write(
      BooksCompanion(
        title: title == null ? const Value.absent() : Value(title),
        author: author == null ? const Value.absent() : Value(author),
        description: description == null
            ? const Value.absent()
            : Value(description),
        coverPath: coverPath == null ? const Value.absent() : Value(coverPath),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateCategory(String id, String? categoryId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(books)..where((book) => book.id.equals(id))).write(
      BooksCompanion(categoryId: Value(categoryId), updatedAt: Value(now)),
    );
  }

  Future<void> toggleFavorite(String id, bool isFavorite) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(books)..where((book) => book.id.equals(id))).write(
      BooksCompanion(isFavorite: Value(isFavorite), updatedAt: Value(now)),
    );
  }

  Future<void> updateReadStatus(String id, String readStatus) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(books)..where((book) => book.id.equals(id))).write(
      BooksCompanion(readStatus: Value(readStatus), updatedAt: Value(now)),
    );
  }

  Future<void> updateIndexingStatus(String id, String indexingStatus) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(books)..where((book) => book.id.equals(id))).write(
      BooksCompanion(
        indexingStatus: Value(indexingStatus),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteBook(String id) {
    return (delete(books)..where((book) => book.id.equals(id))).go();
  }
}

@DriftAccessor(tables: [ReadingProgress])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Future<ReadingProgressRow?> getProgress(String bookId) {
    return (select(
      readingProgress,
    )..where((row) => row.bookId.equals(bookId))).getSingleOrNull();
  }

  Stream<List<ReadingProgressRow>> watchAllProgress() {
    return select(readingProgress).watch();
  }

  Future<List<ReadingProgressRow>> getAllProgress() {
    return select(readingProgress).get();
  }

  Future<void> saveProgress(ReadingProgressCompanion progress) {
    return into(readingProgress).insertOnConflictUpdate(progress);
  }

  Future<void> deleteProgress(String bookId) {
    return (delete(
      readingProgress,
    )..where((row) => row.bookId.equals(bookId))).go();
  }
}

@DriftAccessor(tables: [Categories, Books])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<CategoryRow>> watchCategories() {
    return (select(categories)..orderBy([
          (row) => OrderingTerm.asc(row.sortOrder),
          (row) => OrderingTerm.asc(row.name),
        ]))
        .watch();
  }

  Future<List<CategoryRow>> getCategories() {
    return (select(categories)..orderBy([
          (row) => OrderingTerm.asc(row.sortOrder),
          (row) => OrderingTerm.asc(row.name),
        ]))
        .get();
  }

  Future<void> upsertCategory(CategoriesCompanion category) {
    return into(categories).insertOnConflictUpdate(category);
  }

  Future<void> deleteCategory(String id, {String? moveBooksToCategoryId}) {
    return transaction(() async {
      await (update(books)..where((book) => book.categoryId.equals(id))).write(
        BooksCompanion(categoryId: Value(moveBooksToCategoryId)),
      );
      await (update(categories)..where((row) => row.parentId.equals(id))).write(
        const CategoriesCompanion(parentId: Value(null)),
      );
      await (delete(categories)..where((row) => row.id.equals(id))).go();
    });
  }
}

@DriftAccessor(tables: [Tags, BookTags, NoteTags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Stream<List<TagRow>> watchTags() {
    return (select(
      tags,
    )..orderBy([(row) => OrderingTerm.asc(row.name)])).watch();
  }

  Future<List<TagRow>> getTags() {
    return (select(tags)..orderBy([(row) => OrderingTerm.asc(row.name)])).get();
  }

  Future<List<TagRow>> getTagsForBook(String bookId) async {
    final query = select(tags).join([
      innerJoin(bookTags, bookTags.tagId.equalsExp(tags.id)),
    ])..where(bookTags.bookId.equals(bookId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList(growable: false);
  }

  /// All book→tags assignments for library list/filter without N+1 queries.
  Stream<Map<String, List<TagRow>>> watchTagsByBookId() {
    final query = select(
      bookTags,
    ).join([innerJoin(tags, tags.id.equalsExp(bookTags.tagId))]);
    return query.watch().map((rows) {
      final map = <String, List<TagRow>>{};
      for (final row in rows) {
        final bookId = row.readTable(bookTags).bookId;
        final tag = row.readTable(tags);
        map.putIfAbsent(bookId, () => <TagRow>[]).add(tag);
      }
      for (final entry in map.entries) {
        entry.value.sort((a, b) => a.name.compareTo(b.name));
      }
      return map;
    });
  }

  Future<Set<String>> getBookIdsWithTag(String tagId) async {
    final rows = await (select(
      bookTags,
    )..where((row) => row.tagId.equals(tagId))).get();
    return rows.map((row) => row.bookId).toSet();
  }

  Future<List<TagRow>> getTagsForNote(String noteId) async {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])..where(noteTags.noteId.equals(noteId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList(growable: false);
  }

  Future<void> upsertTag(TagsCompanion tag) {
    return into(tags).insertOnConflictUpdate(tag);
  }

  Future<void> setBookTags(String bookId, Iterable<String> tagIds) {
    return transaction(() async {
      await (delete(bookTags)..where((row) => row.bookId.equals(bookId))).go();
      await batch((batch) {
        batch.insertAll(
          bookTags,
          tagIds.map(
            (tagId) => BookTagsCompanion.insert(bookId: bookId, tagId: tagId),
          ),
        );
      });
    });
  }

  Future<void> setNoteTags(String noteId, Iterable<String> tagIds) {
    return transaction(() async {
      await (delete(noteTags)..where((row) => row.noteId.equals(noteId))).go();
      await batch((batch) {
        batch.insertAll(
          noteTags,
          tagIds.map(
            (tagId) => NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
          ),
        );
      });
    });
  }

  Future<void> deleteTag(String id) {
    return transaction(() async {
      await (delete(bookTags)..where((row) => row.tagId.equals(id))).go();
      await (delete(noteTags)..where((row) => row.tagId.equals(id))).go();
      await (delete(tags)..where((row) => row.id.equals(id))).go();
    });
  }
}

@DriftAccessor(tables: [Bookmarks])
class BookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  Stream<List<BookmarkRow>> watchByBook(String bookId) {
    return (select(bookmarks)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<List<BookmarkRow>> getByBook(String bookId) {
    return (select(bookmarks)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .get();
  }

  Future<List<BookmarkRow>> getAll() {
    return (select(
      bookmarks,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
  }

  Future<Set<String>> getBookIdsWithBookmarks() async {
    final query = selectOnly(bookmarks, distinct: true)
      ..addColumns([bookmarks.bookId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(bookmarks.bookId) != null) row.read(bookmarks.bookId)!,
    };
  }

  Future<BookmarkRow?> getBookmark(String id) {
    return (select(
      bookmarks,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertBookmark(BookmarksCompanion bookmark) {
    return into(bookmarks).insertOnConflictUpdate(bookmark);
  }

  Future<void> deleteBookmark(String id) {
    return (delete(bookmarks)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteByBook(String bookId) {
    return (delete(bookmarks)..where((row) => row.bookId.equals(bookId))).go();
  }
}

@DriftAccessor(tables: [Annotations])
class AnnotationDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationDaoMixin {
  AnnotationDao(super.db);

  Stream<List<AnnotationRow>> watchByBook(String bookId) {
    return (select(annotations)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .watch();
  }

  Future<List<AnnotationRow>> getByBook(String bookId) {
    return (select(annotations)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
  }

  Future<List<AnnotationRow>> getAll() {
    return (select(annotations)..orderBy([
          (row) => OrderingTerm.asc(row.bookId),
          (row) => OrderingTerm.asc(row.createdAt),
        ]))
        .get();
  }

  Future<AnnotationRow?> getAnnotation(String id) {
    return (select(
      annotations,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertAnnotation(AnnotationsCompanion annotation) {
    return into(annotations).insertOnConflictUpdate(annotation);
  }

  Future<void> linkNote({
    required String annotationId,
    required String noteId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(
      annotations,
    )..where((row) => row.id.equals(annotationId))).write(
      AnnotationsCompanion(noteId: Value(noteId), updatedAt: Value(now)),
    );
  }

  Future<void> deleteAnnotation(String id) {
    return (delete(annotations)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteByBook(String bookId) {
    return (delete(
      annotations,
    )..where((row) => row.bookId.equals(bookId))).go();
  }
}

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Stream<List<NoteRow>> watchNotes() {
    return (select(
      notes,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).watch();
  }

  Future<List<NoteRow>> getNotes() {
    return (select(
      notes,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
  }

  Future<List<NoteRow>> getByBook(String bookId) {
    return (select(notes)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
        .get();
  }

  Future<Set<String>> getBookIdsWithNotes() async {
    final query = selectOnly(notes, distinct: true)
      ..addColumns([notes.bookId])
      ..where(notes.bookId.isNotNull());
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(notes.bookId) != null) row.read(notes.bookId)!,
    };
  }

  Future<NoteRow?> getNote(String id) {
    return (select(notes)..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertNote(NotesCompanion note) {
    return into(notes).insertOnConflictUpdate(note);
  }

  Future<void> deleteNote(String id) {
    return (delete(notes)..where((row) => row.id.equals(id))).go();
  }

  Future<void> deleteByBook(String bookId) {
    return (delete(notes)..where((row) => row.bookId.equals(bookId))).go();
  }
}

@DriftAccessor(tables: [AiConversations])
class AiConversationDao extends DatabaseAccessor<AppDatabase>
    with _$AiConversationDaoMixin {
  AiConversationDao(super.db);

  Stream<List<AiConversationRow>> watchConversations() {
    return (select(
      aiConversations,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();
  }

  Future<List<AiConversationRow>> getConversations() {
    return (select(
      aiConversations,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
  }

  Future<void> insertConversation(AiConversationsCompanion conversation) {
    return into(aiConversations).insert(conversation);
  }

  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) {
    return (update(aiConversations)
          ..where((row) => row.id.equals(conversationId)))
        .write(AiConversationsCompanion(noteId: Value(noteId)));
  }

  Future<void> clearAll() {
    return delete(aiConversations).go();
  }

  Future<void> deleteByBook(String bookId) {
    return (delete(
      aiConversations,
    )..where((row) => row.bookId.equals(bookId))).go();
  }
}

@DriftAccessor(tables: [SearchChunks, Books, BookTags])
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.db);

  Future<void> upsertChunk(SearchChunksCompanion chunk) {
    return into(searchChunks).insertOnConflictUpdate(chunk);
  }

  /// Bulk upsert for book indexing. One SQLite batch keeps FTS triggers in-process
  /// without N separate Dart↔DB round-trips.
  Future<void> upsertChunks(List<SearchChunksCompanion> chunks) {
    if (chunks.isEmpty) {
      return Future<void>.value();
    }
    return batch((batch) {
      batch.insertAllOnConflictUpdate(searchChunks, chunks);
    });
  }

  Future<void> deleteBySource(String sourceType, String? sourceId) {
    if (sourceId == null) {
      return (delete(
        searchChunks,
      )..where((row) => row.sourceType.equals(sourceType))).go();
    }
    return (delete(searchChunks)..where(
          (row) =>
              row.sourceType.equals(sourceType) & row.sourceId.equals(sourceId),
        ))
        .go();
  }

  Future<void> deleteByBook(String bookId) {
    return (delete(
      searchChunks,
    )..where((row) => row.bookId.equals(bookId))).go();
  }

  Future<List<SearchMatchRow>> search(
    String query, {
    bool includeBookResults = true,
    bool includeContentResults = true,
    bool includeNoteResults = true,
    bool includeBookmarkResults = true,
    bool includeAiResults = true,
    String rawQuery = '',
    String? bookId,
    String? categoryId,
    Set<String> tagIds = const {},
    String? format,
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final variables = <Variable<Object>>[Variable<String>(trimmed)];
    final buffer = StringBuffer('''
SELECT c.*, snippet(search_chunks_fts, 1, '<mark>', '</mark>', '...', 12) AS snippet
FROM search_chunks_fts
JOIN search_chunks c ON c.rowid = search_chunks_fts.rowid
LEFT JOIN books b ON b.id = c.book_id
WHERE search_chunks_fts MATCH ?
''');

    if (!includeBookResults ||
        !includeContentResults ||
        !includeNoteResults ||
        !includeBookmarkResults ||
        !includeAiResults) {
      final clauses = <String>[];
      if (includeBookResults) {
        clauses.add("(c.source_type = 'book' AND c.source_id = c.book_id)");
      }
      if (includeContentResults) {
        clauses.add(
          "(c.source_type = 'book' AND (c.source_id IS NULL OR c.source_id != c.book_id))",
        );
      }
      if (includeNoteResults) {
        clauses.add("c.source_type = 'note'");
      }
      if (includeBookmarkResults) {
        clauses.add("c.source_type = 'bookmark'");
      }
      if (includeAiResults) {
        clauses.add("c.source_type = 'ai'");
      }
      if (clauses.isEmpty) {
        return const [];
      }
      buffer.write(' AND (');
      buffer.write(clauses.join(' OR '));
      buffer.write(')');
    }

    if (bookId != null) {
      buffer.write(' AND c.book_id = ?');
      variables.add(Variable<String>(bookId));
    }

    if (categoryId != null) {
      if (categoryId == '__uncategorized__') {
        buffer.write(' AND b.category_id IS NULL');
      } else {
        buffer.write(' AND b.category_id = ?');
        variables.add(Variable<String>(categoryId));
      }
    }

    if (format != null) {
      buffer.write(' AND b.format = ?');
      variables.add(Variable<String>(format));
    }

    if (tagIds.isNotEmpty) {
      for (final tagId in tagIds) {
        buffer.write(
          ' AND EXISTS (SELECT 1 FROM book_tags bt WHERE bt.book_id = c.book_id AND bt.tag_id = ?)',
        );
        variables.add(Variable<String>(tagId));
      }
    }

    final titlePattern = '%${rawQuery.trim().toLowerCase()}%';
    buffer.write('''
 ORDER BY
  CASE
    WHEN lower(COALESCE(c.title, '')) LIKE ? THEN 0
    WHEN lower(COALESCE(b.title, '')) LIKE ? THEN 0
    ELSE 1
  END,
  CASE
    WHEN c.source_type = 'book' AND c.source_id = c.book_id THEN 0
    WHEN c.source_type = 'note' THEN 1
    WHEN c.source_type = 'bookmark' THEN 2
    WHEN c.source_type = 'book' THEN 3
    WHEN c.source_type = 'ai' THEN 4
    ELSE 5
  END,
  bm25(search_chunks_fts),
  COALESCE(b.last_opened_at, 0) DESC,
  c.sort_order
 LIMIT ?
''');
    variables
      ..add(Variable<String>(titlePattern))
      ..add(Variable<String>(titlePattern));
    variables.add(Variable<int>(limit));

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {searchChunks, books, bookTags},
    ).get();

    return rows
        .map(
          (row) => SearchMatchRow(
            chunk: SearchChunkRow(
              id: row.read<String>('id'),
              bookId: row.readNullable<String>('book_id'),
              sourceType: row.read<String>('source_type'),
              sourceId: row.readNullable<String>('source_id'),
              locator: row.readNullable<String>('locator'),
              title: row.readNullable<String>('title'),
              body: row.read<String>('text'),
              sortOrder: row.read<int>('sort_order'),
              createdAt: row.read<int>('created_at'),
              updatedAt: row.read<int>('updated_at'),
            ),
            snippet: row.read<String>('snippet'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<SearchMatchRow>> searchLikeFallback({
    required String rawQuery,
    bool includeBookResults = true,
    bool includeContentResults = true,
    bool includeNoteResults = true,
    bool includeBookmarkResults = true,
    bool includeAiResults = true,
    String? bookId,
    String? categoryId,
    Set<String> tagIds = const {},
    String? format,
    int limit = 50,
  }) async {
    final trimmed = rawQuery.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return const [];
    }

    final variables = <Variable<Object>>[
      Variable<String>('%$trimmed%'),
      Variable<String>('%$trimmed%'),
    ];
    final buffer = StringBuffer('''
SELECT c.*, c.text AS snippet
FROM search_chunks c
LEFT JOIN books b ON b.id = c.book_id
WHERE (lower(COALESCE(c.title, '')) LIKE ? OR lower(c.text) LIKE ?)
''');

    if (!includeBookResults ||
        !includeContentResults ||
        !includeNoteResults ||
        !includeBookmarkResults ||
        !includeAiResults) {
      final clauses = <String>[];
      if (includeBookResults) {
        clauses.add("(c.source_type = 'book' AND c.source_id = c.book_id)");
      }
      if (includeContentResults) {
        clauses.add(
          "(c.source_type = 'book' AND (c.source_id IS NULL OR c.source_id != c.book_id))",
        );
      }
      if (includeNoteResults) {
        clauses.add("c.source_type = 'note'");
      }
      if (includeBookmarkResults) {
        clauses.add("c.source_type = 'bookmark'");
      }
      if (includeAiResults) {
        clauses.add("c.source_type = 'ai'");
      }
      if (clauses.isEmpty) {
        return const [];
      }
      buffer.write(' AND (');
      buffer.write(clauses.join(' OR '));
      buffer.write(')');
    }

    if (bookId != null) {
      buffer.write(' AND c.book_id = ?');
      variables.add(Variable<String>(bookId));
    }

    if (categoryId != null) {
      if (categoryId == '__uncategorized__') {
        buffer.write(' AND b.category_id IS NULL');
      } else {
        buffer.write(' AND b.category_id = ?');
        variables.add(Variable<String>(categoryId));
      }
    }

    if (format != null) {
      buffer.write(' AND b.format = ?');
      variables.add(Variable<String>(format));
    }

    if (tagIds.isNotEmpty) {
      for (final tagId in tagIds) {
        buffer.write(
          ' AND EXISTS (SELECT 1 FROM book_tags bt WHERE bt.book_id = c.book_id AND bt.tag_id = ?)',
        );
        variables.add(Variable<String>(tagId));
      }
    }

    final titlePattern = '%$trimmed%';
    buffer.write('''
 ORDER BY
  CASE
    WHEN lower(COALESCE(c.title, '')) LIKE ? THEN 0
    WHEN lower(COALESCE(b.title, '')) LIKE ? THEN 0
    ELSE 1
  END,
  CASE
    WHEN c.source_type = 'book' AND c.source_id = c.book_id THEN 0
    WHEN c.source_type = 'note' THEN 1
    WHEN c.source_type = 'bookmark' THEN 2
    WHEN c.source_type = 'book' THEN 3
    WHEN c.source_type = 'ai' THEN 4
    ELSE 5
  END,
  c.sort_order,
  c.updated_at DESC
 LIMIT ?
''');
    variables
      ..add(Variable<String>(titlePattern))
      ..add(Variable<String>(titlePattern))
      ..add(Variable<int>(limit));

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {searchChunks, books, bookTags},
    ).get();

    return rows
        .map(
          (row) => SearchMatchRow(
            chunk: SearchChunkRow(
              id: row.read<String>('id'),
              bookId: row.readNullable<String>('book_id'),
              sourceType: row.read<String>('source_type'),
              sourceId: row.readNullable<String>('source_id'),
              locator: row.readNullable<String>('locator'),
              title: row.readNullable<String>('title'),
              body: row.read<String>('text'),
              sortOrder: row.read<int>('sort_order'),
              createdAt: row.read<int>('created_at'),
              updatedAt: row.read<int>('updated_at'),
            ),
            snippet: _likeSnippet(row.read<String>('snippet'), trimmed),
          ),
        )
        .toList(growable: false);
  }

  String _likeSnippet(String text, String query) {
    final lower = text.toLowerCase();
    final index = lower.indexOf(query);
    if (index < 0) {
      return text.length <= 180 ? text : '${text.substring(0, 180)}...';
    }
    final start = (index - 48).clamp(0, text.length).toInt();
    final end = (index + query.length + 72).clamp(0, text.length).toInt();
    return text.substring(start, end);
  }

  /// Body chunks of the selected books, in reading order.
  ///
  /// Only rows whose `source_id` is not the book's own id: that row is the
  /// book's title/author metadata, and a question about a topic must not match
  /// a book just because its name contains the topic.
  Future<List<SearchChunkRow>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async {
    final buffer = StringBuffer('''
SELECT c.*
FROM search_chunks c
LEFT JOIN books b ON b.id = c.book_id
WHERE c.source_type = 'book'
  AND (c.source_id IS NULL OR c.source_id != c.book_id)
''');
    final variables = <Variable<Object>>[];

    final ids = bookIds.toList(growable: false);
    if (ids.isNotEmpty) {
      buffer.write(' AND c.book_id IN (');
      buffer.write(List.filled(ids.length, '?').join(', '));
      buffer.write(')');
      variables.addAll(ids.map((id) => Variable<String>(id)));
    }

    if (categoryId != null) {
      if (categoryId == '__uncategorized__') {
        buffer.write(' AND b.category_id IS NULL');
      } else {
        buffer.write(' AND b.category_id = ?');
        variables.add(Variable<String>(categoryId));
      }
    }

    buffer.write(' ORDER BY c.book_id, c.sort_order');

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {searchChunks, books},
    ).get();

    return rows
        .map(
          (row) => SearchChunkRow(
            id: row.read<String>('id'),
            bookId: row.readNullable<String>('book_id'),
            sourceType: row.read<String>('source_type'),
            sourceId: row.readNullable<String>('source_id'),
            locator: row.readNullable<String>('locator'),
            title: row.readNullable<String>('title'),
            body: row.read<String>('text'),
            sortOrder: row.read<int>('sort_order'),
            createdAt: row.read<int>('created_at'),
            updatedAt: row.read<int>('updated_at'),
          ),
        )
        .toList(growable: false);
  }
}

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Stream<List<AppSettingRow>> watchSettings() {
    return select(appSettings).watch();
  }

  Future<String?> getValue(String key) async {
    final row = await (select(
      appSettings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value, int updatedAt) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value, updatedAt: updatedAt),
    );
  }
}

@DriftAccessor(tables: [OcrPages])
class OcrPageDao extends DatabaseAccessor<AppDatabase> with _$OcrPageDaoMixin {
  OcrPageDao(super.db);

  Future<OcrPageRow?> getPage(String bookId, int pageNumber) {
    return (select(ocrPages)..where(
          (row) =>
              row.bookId.equals(bookId) & row.pageNumber.equals(pageNumber),
        ))
        .getSingleOrNull();
  }

  Future<List<OcrPageRow>> getPagesForBook(String bookId) {
    return (select(ocrPages)
          ..where((row) => row.bookId.equals(bookId))
          ..orderBy([(row) => OrderingTerm.asc(row.pageNumber)]))
        .get();
  }

  Future<void> upsertPage(OcrPagesCompanion page) {
    return into(ocrPages).insertOnConflictUpdate(page);
  }

  Future<void> deleteByBook(String bookId) {
    return (delete(ocrPages)..where((row) => row.bookId.equals(bookId))).go();
  }

  Future<void> deletePage(String bookId, int pageNumber) {
    return (delete(ocrPages)..where(
          (row) =>
              row.bookId.equals(bookId) & row.pageNumber.equals(pageNumber),
        ))
        .go();
  }
}

@DriftAccessor(tables: [ImportTasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  Stream<List<ImportTaskRow>> watchTasks() {
    return (select(
      importTasks,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();
  }

  Future<List<ImportTaskRow>> getTasks() {
    return (select(
      importTasks,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
  }

  Future<void> upsertTask(ImportTasksCompanion task) {
    return into(importTasks).insertOnConflictUpdate(task);
  }

  Future<void> updateStatus({
    required String id,
    required String status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
    bool clearError = false,
  }) {
    return (update(importTasks)..where((row) => row.id.equals(id))).write(
      ImportTasksCompanion(
        status: Value(status),
        progress: progress == null ? const Value.absent() : Value(progress),
        targetPath: targetPath == null
            ? const Value.absent()
            : Value(targetPath),
        bookId: bookId == null ? const Value.absent() : Value(bookId),
        message: message == null ? const Value.absent() : Value(message),
        // Passing no error keeps the stored one; a retry that succeeds has to
        // remove it explicitly, or the details sheet keeps showing the failure
        // that was already recovered from.
        error: error != null
            ? Value(error)
            : clearError
            ? const Value(null)
            : const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> clearCompleted() {
    return (delete(importTasks)..where(
          (row) =>
              row.status.equals('done') |
              row.status.equals('failed') |
              row.status.equals('cancelled'),
        ))
        .go();
  }
}

@DriftDatabase(
  tables: [
    Books,
    Categories,
    Tags,
    BookTags,
    ReadingProgress,
    Bookmarks,
    Annotations,
    Notes,
    NoteTags,
    AiConversations,
    SearchChunks,
    AppSettings,
    ImportTasks,
    OcrPages,
  ],
  daos: [
    BookDao,
    ProgressDao,
    CategoryDao,
    TagDao,
    BookmarkDao,
    AnnotationDao,
    NoteDao,
    AiConversationDao,
    SearchDao,
    SettingsDao,
    TaskDao,
    OcrPageDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexesAndFts();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(categories);
        await migrator.createTable(tags);
        await migrator.createTable(bookTags);
        await migrator.createTable(bookmarks);
        await migrator.createTable(annotations);
        await migrator.createTable(notes);
        await migrator.createTable(noteTags);
        await migrator.createTable(aiConversations);
        await migrator.createTable(searchChunks);
        await migrator.createTable(importTasks);
      }
      if (from < 3) {
        await migrator.createTable(ocrPages);
      }
      if (from < 4) {
        // Follow-up turns need to be grouped. Existing rows stay single-turn:
        // grouping them after the fact would guess at which ones belong
        // together, and a wrong guess is worse than an ungrouped history.
        await migrator.addColumn(aiConversations, aiConversations.threadId);
      }
      await _createIndexesAndFts();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createIndexesAndFts();
    },
  );

  Future<void> _createIndexesAndFts() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_books_file_hash ON books(file_hash)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_books_category_id ON books(category_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_books_last_opened_at ON books(last_opened_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_books_format ON books(format)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_book_tags_tag_id ON book_tags(tag_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON bookmarks(created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_annotations_book_id ON annotations(book_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_annotations_note_id ON annotations(note_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_book_id ON notes(book_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_annotation_id ON notes(annotation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_conversations_book_id ON ai_conversations(book_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_conversations_created_at ON ai_conversations(created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_chunks_book_id ON search_chunks(book_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_chunks_source_type ON search_chunks(source_type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_chunks_source_id ON search_chunks(source_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ocr_pages_book_id ON ocr_pages(book_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_ocr_pages_book_page ON ocr_pages(book_id, page_number)',
    );
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS search_chunks_fts USING fts5(
  title,
  text,
  content='search_chunks',
  content_rowid='rowid'
)
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS search_chunks_ai AFTER INSERT ON search_chunks BEGIN
  INSERT INTO search_chunks_fts(rowid, title, text)
  VALUES (new.rowid, new.title, new.text);
END
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS search_chunks_ad AFTER DELETE ON search_chunks BEGIN
  INSERT INTO search_chunks_fts(search_chunks_fts, rowid, title, text)
  VALUES ('delete', old.rowid, old.title, old.text);
END
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS search_chunks_au AFTER UPDATE ON search_chunks BEGIN
  INSERT INTO search_chunks_fts(search_chunks_fts, rowid, title, text)
  VALUES ('delete', old.rowid, old.title, old.text);
  INSERT INTO search_chunks_fts(rowid, title, text)
  VALUES (new.rowid, new.title, new.text);
END
''');
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(
      p.join(appSupportDir.path, 'PageSageData', 'database'),
    );
    await dbDir.create(recursive: true);
    final dbFile = File(p.join(dbDir.path, 'pagesage.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}
