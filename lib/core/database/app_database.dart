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

  /// `text` or `image`. Every row written before schema v5 marks text, which
  /// is what it was.
  TextColumn get target => text().withDefault(const Constant('text'))();

  /// JSON for an [ImageAnchor]; null on text annotations.
  TextColumn get imageAnchor => text().nullable()();
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
  TextColumn get contextSnapshot => text().nullable()();
  TextColumn get profileId => text().nullable()();
  TextColumn get profileSnapshot => text().nullable()();
  TextColumn get answerMeta => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchChunkRow')
class SearchChunks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get locator => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().named('text')();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get generationId => text().nullable()();
  TextColumn get documentSourceId => text().nullable()();
  TextColumn get sourceRevision => text().nullable()();
  TextColumn get textRevision => text().nullable()();
  IntColumn get startOffset => integer().nullable()();
  IntColumn get endOffset => integer().nullable()();
  TextColumn get textOrigin => text().withDefault(const Constant('native'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchParentChunkRow')
class SearchParentChunks extends Table {
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
  TextColumn get generationId => text().nullable()();
  TextColumn get documentSourceId => text().nullable()();
  TextColumn get sourceRevision => text().nullable()();
  TextColumn get textRevision => text().nullable()();
  TextColumn get textOrigin => text().withDefault(const Constant('native'))();

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
  TextColumn get sourceRevision => text().nullable()();
  TextColumn get cacheSignature => text().nullable()();
  TextColumn get textRevision => text().nullable()();
  TextColumn get engineVersion => text().nullable()();
  TextColumn get pipelineVersion => text().nullable()();
  TextColumn get resultState => text().withDefault(const Constant('legacy'))();
  TextColumn get indexState =>
      text().withDefault(const Constant('notApplicable'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DocumentSourceRow')
class DocumentSources extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get kind => text()();
  TextColumn get address => text()();
  TextColumn get currentSourceRevision => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('present'))();
  IntColumn get observedSize => integer().nullable()();
  IntColumn get observedMtime => integer().nullable()();
  IntColumn get observedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchIndexUnitRow')
class SearchIndexUnits extends Table {
  TextColumn get id => text()();
  TextColumn get unitKey => text().unique()();
  TextColumn get bookId => text().nullable()();
  TextColumn get documentSourceId => text().nullable()();
  TextColumn get requestedInputRevision => text()();
  TextColumn get activeGenerationId => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchIndexGenerationRow')
class SearchIndexGenerations extends Table {
  TextColumn get id => text()();
  TextColumn get unitId => text()();
  TextColumn get inputRevision => text()();
  TextColumn get sourceRevision => text().nullable()();
  TextColumn get textRevision => text().nullable()();
  TextColumn get textOrigin => text().withDefault(const Constant('native'))();
  TextColumn get extractorVersion => text()();
  TextColumn get tokenizerVersion => text()();
  TextColumn get state => text().withDefault(const Constant('building'))();
  IntColumn get createdAt => integer()();
  IntColumn get publishedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AiProfileRow')
class AiProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get provider =>
      text().withDefault(const Constant('openai-compatible'))();
  TextColumn get baseUrl => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();
  RealColumn get temperature => real().withDefault(const Constant(0.2))();
  IntColumn get maxTokens => integer().withDefault(const Constant(1200))();
  BoolColumn get streaming => boolean().withDefault(const Constant(true))();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AiCredentialOperationRow')
class AiCredentialOperations extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get operation => text()();
  TextColumn get phase => text()();
  IntColumn get expectedRevision => integer()();
  TextColumn get ownerSessionId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchTermDocumentRow')
class SearchTermDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get chunkId => text().unique()();
  TextColumn get generationId => text().nullable()();
  TextColumn get titleNormalized => text()();
  TextColumn get textNormalized => text()();
  TextColumn get titleTerms => text()();
  TextColumn get textTerms => text()();
  TextColumn get normalizerVersion => text()();
  TextColumn get tokenizerVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OcrJobRow')
class OcrJobs extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().unique()();
  TextColumn get bookId => text()();
  TextColumn get sourceRevision => text()();
  TextColumn get configJson => text()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  TextColumn get reason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OcrJobPageRow')
class OcrJobPages extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  IntColumn get pageNumber => integer()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  TextColumn get ocrPageId => text().nullable()();
  TextColumn get expectedCacheSignature => text()();
  TextColumn get errorCode => text().nullable()();
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

final class BookSearchChunkRow {
  const BookSearchChunkRow({
    required this.chunk,
    this.parentTitle,
    this.parentText,
    this.parentLocator,
  });

  final SearchChunkRow chunk;
  final String? parentTitle;
  final String? parentText;
  final String? parentLocator;
}

final class SearchCandidateRow {
  const SearchCandidateRow({
    required this.chunk,
    required this.normalizedTitle,
    required this.normalizedText,
    required this.normalizedRank,
    required this.cjkRank,
    required this.hitSources,
    this.bookTitle,
  });

  final SearchChunkRow chunk;
  final String? bookTitle;
  final String normalizedTitle;
  final String normalizedText;
  final double normalizedRank;
  final double cjkRank;
  final int hitSources;
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

  Future<void> unlinkNote({required String annotationId}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(
      annotations,
    )..where((row) => row.id.equals(annotationId))).write(
      AnnotationsCompanion(
        noteId: const Value<String?>(null),
        updatedAt: Value(now),
      ),
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
    return (select(aiConversations)..orderBy([
          (row) => OrderingTerm.desc(row.createdAt),
          (row) => OrderingTerm.desc(row.rowId),
        ]))
        .watch();
  }

  Future<List<AiConversationRow>> getConversations() {
    return (select(aiConversations)..orderBy([
          (row) => OrderingTerm.desc(row.createdAt),
          (row) => OrderingTerm.desc(row.rowId),
        ]))
        .get();
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

@DriftAccessor(
  tables: [
    SearchChunks,
    SearchParentChunks,
    SearchTermDocuments,
    SearchIndexUnits,
    SearchIndexGenerations,
    Books,
    BookTags,
  ],
)
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.db);

  Future<List<SearchChunkRow>> chunksMissingTerms({
    required String normalizerVersion,
    required String tokenizerVersion,
  }) async {
    final rows = await customSelect(
      'SELECT c.* FROM search_chunks c '
      'LEFT JOIN search_term_documents t ON t.chunk_id = c.id '
      'WHERE (c.generation_id IS NULL OR c.generation_id IN '
      '(SELECT active_generation_id FROM search_index_units)) AND '
      '(t.id IS NULL OR t.normalizer_version != ? OR t.tokenizer_version != ?)',
      variables: [Variable(normalizerVersion), Variable(tokenizerVersion)],
      readsFrom: {searchChunks, searchTermDocuments},
    ).get();
    return rows
        .map((row) => searchChunks.map(row.data))
        .toList(growable: false);
  }

  Future<List<SearchCandidateRow>> searchCandidates({
    required String normalizedMatch,
    required String cjkMatch,
    required Set<String> sourceTypeClauses,
    required String? bookId,
    required String? categoryId,
    required Set<String> tagIds,
    required String? format,
    required int limit,
  }) async {
    if (sourceTypeClauses.isEmpty) return const [];
    final variables = <Variable<Object>>[
      Variable<String>(normalizedMatch),
      Variable<String>(cjkMatch),
    ];
    final filters = StringBuffer()
      ..write(' AND (')
      ..write(sourceTypeClauses.join(' OR '))
      ..write(')');
    void addScope(String? value, String sql) {
      if (value != null) {
        filters.write(' AND $sql');
        variables.add(Variable<String>(value));
      }
    }

    addScope(bookId, 'c.book_id = ?');
    if (categoryId == '__uncategorized__') {
      filters.write(' AND b.category_id IS NULL');
    } else {
      addScope(categoryId, 'b.category_id = ?');
    }
    addScope(format, 'b.format = ?');
    for (final tagId in tagIds) {
      filters.write(
        ' AND EXISTS (SELECT 1 FROM book_tags bt WHERE bt.book_id = c.book_id AND bt.tag_id = ?)',
      );
      variables.add(Variable<String>(tagId));
    }
    final query =
        '''
WITH normalized_hits AS (
  SELECT rowid AS chunk_rowid, bm25(search_normalized_fts) AS rank
  FROM search_normalized_fts
  WHERE search_normalized_fts MATCH ?
),
cjk_hits AS (
  SELECT rowid AS chunk_rowid, bm25(search_cjk_fts) AS rank
  FROM search_cjk_fts
  WHERE search_cjk_fts MATCH ?
),
candidates AS (
  SELECT chunk_rowid, rank, 0 AS source FROM normalized_hits
  UNION ALL
  SELECT chunk_rowid, rank, 1 AS source FROM cjk_hits
),
ranked AS MATERIALIZED (
SELECT c.id AS chunk_id, t.id AS term_id, c.sort_order,
       MIN(CASE WHEN h.source = 0 THEN h.rank ELSE NULL END) AS normalized_rank,
       MIN(CASE WHEN h.source = 1 THEN h.rank ELSE NULL END) AS cjk_rank,
       COUNT(DISTINCT h.source) AS hit_sources
FROM candidates h
JOIN search_term_documents t ON t.rowid = h.chunk_rowid
JOIN search_chunks c ON c.id = t.chunk_id
LEFT JOIN books b ON b.id = c.book_id
WHERE 1 = 1$filters
  AND (
    c.source_type != 'book'
    OR c.generation_id IS NULL
    OR c.generation_id = (
      SELECT u.active_generation_id
      FROM search_index_units u
      WHERE u.unit_key = 'book:' || c.book_id
    )
  )
GROUP BY c.id, t.id
ORDER BY hit_sources DESC,
         COALESCE(normalized_rank, 0) ASC,
         COALESCE(cjk_rank, 0) ASC,
         c.sort_order,
         c.id
LIMIT ?
)
SELECT c.*, b.title AS book_title, t.title_normalized, t.text_normalized,
       r.normalized_rank, r.cjk_rank, r.hit_sources
FROM ranked r
JOIN search_chunks c ON c.id = r.chunk_id
JOIN search_term_documents t ON t.id = r.term_id
LEFT JOIN books b ON b.id = c.book_id
ORDER BY r.hit_sources DESC, COALESCE(r.normalized_rank, 0),
         COALESCE(r.cjk_rank, 0), r.sort_order, r.chunk_id
''';
    variables.add(Variable<int>(limit));
    final rows = await customSelect(
      query,
      variables: variables,
      readsFrom: {searchChunks, searchTermDocuments, books, bookTags},
    ).get();
    return rows
        .map(
          (row) => SearchCandidateRow(
            chunk: SearchChunkRow(
              id: row.read<String>('id'),
              bookId: row.readNullable<String>('book_id'),
              parentId: row.readNullable<String>('parent_id'),
              sourceType: row.read<String>('source_type'),
              sourceId: row.readNullable<String>('source_id'),
              locator: row.readNullable<String>('locator'),
              title: row.readNullable<String>('title'),
              body: row.read<String>('text'),
              sortOrder: row.read<int>('sort_order'),
              createdAt: row.read<int>('created_at'),
              updatedAt: row.read<int>('updated_at'),
              generationId: row.readNullable<String>('generation_id'),
              documentSourceId: row.readNullable<String>('document_source_id'),
              sourceRevision: row.readNullable<String>('source_revision'),
              textRevision: row.readNullable<String>('text_revision'),
              startOffset: row.readNullable<int>('start_offset'),
              endOffset: row.readNullable<int>('end_offset'),
              textOrigin: row.readNullable<String>('text_origin') ?? 'native',
            ),
            bookTitle: row.readNullable<String>('book_title'),
            normalizedTitle: row.read<String>('title_normalized'),
            normalizedText: row.read<String>('text_normalized'),
            normalizedRank: row.readNullable<double>('normalized_rank') ?? 0,
            cjkRank: row.readNullable<double>('cjk_rank') ?? 0,
            hitSources: row.read<int>('hit_sources'),
          ),
        )
        .toList(growable: false);
  }

  Future<void> upsertTermDocuments(
    List<SearchTermDocumentsCompanion> rows,
  ) async {
    if (rows.isEmpty) return;
    await batch((batch) {
      batch.insertAllOnConflictUpdate(searchTermDocuments, rows);
    });
  }

  Future<void> upsertSearchUnit(SearchIndexUnitsCompanion unit) {
    return into(attachedDatabase.searchIndexUnits).insertOnConflictUpdate(unit);
  }

  Future<void> insertSearchGeneration(
    SearchIndexGenerationsCompanion generation,
  ) {
    return into(
      attachedDatabase.searchIndexGenerations,
    ).insertOnConflictUpdate(generation);
  }

  Future<void> publishSearchGeneration(String generationId) async {
    final rows = await customSelect(
      'SELECT g.unit_id, u.book_id '
      'FROM search_index_generations g '
      'JOIN search_index_units u ON u.id = g.unit_id '
      'WHERE g.id = ?',
      variables: [Variable<String>(generationId)],
      readsFrom: {
        attachedDatabase.searchIndexGenerations,
        attachedDatabase.searchIndexUnits,
      },
    ).get();
    if (rows.isEmpty) return;
    final unitId = rows.single.read<String>('unit_id');
    final bookId = rows.single.readNullable<String>('book_id');
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      if (bookId != null) {
        await customStatement(
          "DELETE FROM search_term_documents WHERE chunk_id IN ("
          "SELECT id FROM search_chunks WHERE source_type = 'book' "
          'AND book_id = ? AND (generation_id IS NULL OR generation_id != ?))',
          [bookId, generationId],
        );
        await customStatement(
          "DELETE FROM search_chunks WHERE source_type = 'book' "
          'AND book_id = ? AND (generation_id IS NULL OR generation_id != ?)',
          [bookId, generationId],
        );
        await customStatement(
          "DELETE FROM search_parent_chunks WHERE source_type = 'book' "
          'AND book_id = ? AND (generation_id IS NULL OR generation_id != ?)',
          [bookId, generationId],
        );
      }
      await customStatement(
        "UPDATE search_index_units SET active_generation_id = ?, "
        "state = 'ready', updated_at = ? WHERE id = ?",
        [generationId, now, unitId],
      );
      await customStatement(
        'DELETE FROM search_index_generations WHERE unit_id = ? AND id != ?',
        [unitId, generationId],
      );
    });
  }

  Future<void> discardSearchGeneration(String generationId) async {
    final rows = await customSelect(
      'SELECT g.unit_id '
      'FROM search_index_generations g '
      'WHERE g.id = ?',
      variables: [Variable<String>(generationId)],
      readsFrom: {attachedDatabase.searchIndexGenerations},
    ).get();
    if (rows.isEmpty) return;
    final unitId = rows.single.read<String>('unit_id');
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await customStatement(
        'DELETE FROM search_term_documents WHERE chunk_id IN ('
        'SELECT id FROM search_chunks WHERE generation_id = ?)',
        [generationId],
      );
      await customStatement(
        'DELETE FROM search_chunks WHERE generation_id = ?',
        [generationId],
      );
      await customStatement(
        'DELETE FROM search_parent_chunks WHERE generation_id = ?',
        [generationId],
      );
      await customStatement(
        'DELETE FROM search_index_generations WHERE id = ?',
        [generationId],
      );
      await customStatement(
        "UPDATE search_index_units SET state = "
        "CASE WHEN active_generation_id IS NULL THEN 'pending' ELSE 'ready' END, "
        'updated_at = ? WHERE id = ?',
        [now, unitId],
      );
    });
  }

  Future<void> upsertChunk(SearchChunksCompanion chunk) {
    return upsertChunks([chunk]);
  }

  /// Bulk upsert for book indexing. One SQLite batch keeps FTS triggers in-process
  /// without N separate Dart↔DB round-trips.
  Future<void> upsertChunks(List<SearchChunksCompanion> chunks) {
    if (chunks.isEmpty) {
      return Future<void>.value();
    }
    return transaction(() async {
      await batch((batch) {
        for (final chunk in chunks) {
          batch.deleteWhere(
            searchTermDocuments,
            (row) => row.chunkId.equals(chunk.id.value),
          );
        }
        batch.insertAllOnConflictUpdate(searchChunks, chunks);
      });
    });
  }

  Future<void> upsertParents(List<SearchParentChunksCompanion> parents) {
    if (parents.isEmpty) {
      return Future<void>.value();
    }
    return batch((batch) {
      batch.insertAllOnConflictUpdate(searchParentChunks, parents);
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

  Future<void> deleteByBook(String bookId) async {
    final chunkIds =
        await (selectOnly(searchChunks)
              ..addColumns([searchChunks.id])
              ..where(searchChunks.bookId.equals(bookId)))
            .map((row) => row.read<String>(searchChunks.id) ?? '')
            .get();
    await batch((batch) {
      if (chunkIds.isNotEmpty) {
        batch.deleteWhere(
          searchTermDocuments,
          (row) => row.chunkId.isIn(chunkIds),
        );
      }
      batch.deleteWhere(searchChunks, (row) => row.bookId.equals(bookId));
      batch.deleteWhere(searchParentChunks, (row) => row.bookId.equals(bookId));
    });
    await customStatement(
      'DELETE FROM search_index_generations WHERE unit_id IN '
      '(SELECT id FROM search_index_units WHERE book_id = ?)',
      [bookId],
    );
    await customStatement('DELETE FROM search_index_units WHERE book_id = ?', [
      bookId,
    ]);
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
              textOrigin: row.readNullable<String>('text_origin') ?? 'native',
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
              textOrigin: row.readNullable<String>('text_origin') ?? 'native',
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
  Future<List<BookSearchChunkRow>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async {
    final buffer = StringBuffer('''
SELECT c.*,
       p.title AS parent_title,
       p.text AS parent_text,
       p.locator AS parent_locator
FROM search_chunks c
LEFT JOIN search_parent_chunks p ON p.id = c.parent_id
LEFT JOIN books b ON b.id = c.book_id
WHERE c.source_type = 'book'
  AND (c.source_id IS NULL OR c.source_id != c.book_id)
  AND (
    c.generation_id IS NULL
    OR c.generation_id = (
      SELECT u.active_generation_id
      FROM search_index_units u
      WHERE u.unit_key = 'book:' || c.book_id
    )
  )
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
      readsFrom: {searchChunks, searchParentChunks, books},
    ).get();

    return rows
        .map(
          (row) => BookSearchChunkRow(
            chunk: SearchChunkRow(
              id: row.read<String>('id'),
              bookId: row.readNullable<String>('book_id'),
              parentId: row.readNullable<String>('parent_id'),
              sourceType: row.read<String>('source_type'),
              sourceId: row.readNullable<String>('source_id'),
              locator: row.readNullable<String>('locator'),
              title: row.readNullable<String>('title'),
              body: row.read<String>('text'),
              sortOrder: row.read<int>('sort_order'),
              createdAt: row.read<int>('created_at'),
              updatedAt: row.read<int>('updated_at'),
              textOrigin: row.readNullable<String>('text_origin') ?? 'native',
            ),
            parentTitle: row.readNullable<String>('parent_title'),
            parentText: row.readNullable<String>('parent_text'),
            parentLocator: row.readNullable<String>('parent_locator'),
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

@DriftAccessor(tables: [AiProfiles, AiCredentialOperations])
class AiProfileDao extends DatabaseAccessor<AppDatabase>
    with _$AiProfileDaoMixin {
  AiProfileDao(super.db);

  Future<List<AiProfileRow>> activeProfiles() =>
      (select(aiProfiles)..where((row) => row.deletedAt.isNull())).get();

  Future<AiProfileRow?> profileById(String id) =>
      (select(aiProfiles)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<void> insertProfile(AiProfilesCompanion profile) =>
      into(aiProfiles).insert(profile);

  Future<void> updateProfile(AiProfilesCompanion profile) => (update(
    aiProfiles,
  )..where((row) => row.id.equals(profile.id.value))).write(profile);

  Future<void> markDeleted(String id, int deletedAt) =>
      (update(aiProfiles)..where((row) => row.id.equals(id))).write(
        AiProfilesCompanion(deletedAt: Value(deletedAt)),
      );

  Future<void> openOperation(AiCredentialOperationsCompanion operation) =>
      into(aiCredentialOperations).insert(operation);

  Future<void> finishOperation(
    String id,
    int updatedAt, {
    String phase = 'done',
  }) =>
      (update(aiCredentialOperations)..where((row) => row.id.equals(id))).write(
        AiCredentialOperationsCompanion(
          phase: Value(phase),
          updatedAt: Value(updatedAt),
        ),
      );

  Future<bool> hasPendingOperation(String profileId) async {
    final rows =
        await (select(aiCredentialOperations)..where(
              (row) =>
                  row.profileId.equals(profileId) & row.phase.equals('pending'),
            ))
            .get();
    return rows.isNotEmpty;
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

  Future<List<OcrPageRow>> listByBook(String bookId) {
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

  Future<void> deletePages(String bookId, Iterable<int> pageNumbers) {
    final pages = pageNumbers.toSet().toList(growable: false);
    if (pages.isEmpty) {
      return Future<void>.value();
    }
    return (delete(ocrPages)..where(
          (row) => row.bookId.equals(bookId) & row.pageNumber.isIn(pages),
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
    SearchParentChunks,
    AppSettings,
    ImportTasks,
    OcrPages,
    DocumentSources,
    SearchIndexUnits,
    SearchIndexGenerations,
    AiProfiles,
    AiCredentialOperations,
    SearchTermDocuments,
    OcrJobs,
    OcrJobPages,
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
    AiProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 12;

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
      if (from < 5) {
        // Image annotations reuse the table: colours, notes, export and
        // jump-back are all shared with text highlights, and only the geometry
        // differs. Existing rows default to `text`, which is what they are.
        await migrator.addColumn(annotations, annotations.target);
        await migrator.addColumn(annotations, annotations.imageAnchor);
      }
      if (from < 6) {
        await migrator.createTable(searchParentChunks);
        if (!await _hasColumn('search_chunks', 'parent_id')) {
          await migrator.addColumn(searchChunks, searchChunks.parentId);
        }
      }
      if (from >= 2 && from < 7) {
        await migrator.addColumn(
          aiConversations,
          aiConversations.contextSnapshot,
        );
      }
      if (from < 8) {
        await migrator.createTable(documentSources);
        await migrator.createTable(searchIndexUnits);
        await migrator.createTable(searchIndexGenerations);
        await _addColumnIfMissing(migrator, searchChunks, 'generation_id');
        await _addColumnIfMissing(migrator, searchChunks, 'document_source_id');
        await _addColumnIfMissing(migrator, searchChunks, 'source_revision');
        await _addColumnIfMissing(migrator, searchChunks, 'text_revision');
        await _addColumnIfMissing(migrator, searchChunks, 'start_offset');
        await _addColumnIfMissing(migrator, searchChunks, 'end_offset');
        await _addColumnIfMissing(migrator, searchChunks, 'text_origin');
        await _addColumnIfMissing(
          migrator,
          searchParentChunks,
          'generation_id',
        );
        await _addColumnIfMissing(
          migrator,
          searchParentChunks,
          'document_source_id',
        );
        await _addColumnIfMissing(
          migrator,
          searchParentChunks,
          'source_revision',
        );
        await _addColumnIfMissing(
          migrator,
          searchParentChunks,
          'text_revision',
        );
        await _addColumnIfMissing(migrator, searchParentChunks, 'text_origin');
      }
      if (from < 9) {
        await migrator.createTable(aiProfiles);
        await migrator.createTable(aiCredentialOperations);
        await _addColumnIfMissing(migrator, aiConversations, 'profile_id');
        await _addColumnIfMissing(
          migrator,
          aiConversations,
          'profile_snapshot',
        );
      }
      if (from < 10) {
        await migrator.createTable(searchTermDocuments);
      }
      if (from < 11) {
        await _addColumnIfMissing(migrator, aiConversations, 'answer_meta');
      }
      if (from < 12) {
        await _addColumnIfMissing(migrator, ocrPages, 'source_revision');
        await _addColumnIfMissing(migrator, ocrPages, 'cache_signature');
        await _addColumnIfMissing(migrator, ocrPages, 'text_revision');
        await _addColumnIfMissing(migrator, ocrPages, 'engine_version');
        await _addColumnIfMissing(migrator, ocrPages, 'pipeline_version');
        await _addColumnIfMissing(migrator, ocrPages, 'result_state');
        await _addColumnIfMissing(migrator, ocrPages, 'index_state');
        await migrator.createTable(ocrJobs);
        await migrator.createTable(ocrJobPages);
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
      'CREATE INDEX IF NOT EXISTS idx_search_chunks_parent_id ON search_chunks(parent_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_parent_chunks_book_id ON search_parent_chunks(book_id)',
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
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS search_normalized_fts USING fts5(
  title_normalized,
  text_normalized,
  content='search_term_documents',
  content_rowid='rowid'
)
''');
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS search_cjk_fts USING fts5(
  title_terms,
  text_terms,
  content='search_term_documents',
  content_rowid='rowid'
)
''');
    for (final table in const ['search_normalized_fts', 'search_cjk_fts']) {
      final first = table == 'search_normalized_fts'
          ? 'title_normalized, text_normalized'
          : 'title_terms, text_terms';
      final second = table == 'search_normalized_fts'
          ? 'new.title_normalized, new.text_normalized'
          : 'new.title_terms, new.text_terms';
      final oldValues = table == 'search_normalized_fts'
          ? 'old.title_normalized, old.text_normalized'
          : 'old.title_terms, old.text_terms';
      await customStatement('''
CREATE TRIGGER IF NOT EXISTS ${table}_ai AFTER INSERT ON search_term_documents BEGIN
  INSERT INTO $table(rowid, $first) VALUES (new.rowid, $second);
END
''');
      await customStatement('''
CREATE TRIGGER IF NOT EXISTS ${table}_ad AFTER DELETE ON search_term_documents BEGIN
  INSERT INTO $table($table, rowid, $first)
  VALUES ('delete', old.rowid, $oldValues);
END
''');
      await customStatement('''
CREATE TRIGGER IF NOT EXISTS ${table}_au AFTER UPDATE ON search_term_documents BEGIN
  INSERT INTO $table($table, rowid, $first)
  VALUES ('delete', old.rowid, $oldValues);
  INSERT INTO $table(rowid, $first) VALUES (new.rowid, $second);
END
''');
    }
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_document_sources_active '
      'ON document_sources(book_id, address) WHERE state != \'missing\'',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_ocr_job_pages_job_page '
      'ON ocr_job_pages(job_id, page_number)',
    );
  }

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect("PRAGMA table_info('$table')").get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo<Table, Object> table,
    String columnName,
  ) async {
    if (await _hasColumn(table.actualTableName, columnName)) return;
    final column = table.$columns.firstWhere(
      (candidate) => candidate.name == columnName,
    );
    await migrator.addColumn(table, column);
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
