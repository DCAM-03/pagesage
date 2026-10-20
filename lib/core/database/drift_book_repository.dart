import 'dart:async';
import 'package:drift/drift.dart';

import '../../domain/books/book.dart' as domain;
import '../../domain/books/book_repository.dart';
import '../../domain/books/reading_position.dart';
import 'app_database.dart' as db;

final class DriftBookRepository implements BookRepository {
  DriftBookRepository({
    required db.BookDao bookDao,
    required db.ProgressDao progressDao,
    db.BookmarkDao? bookmarkDao,
    db.AnnotationDao? annotationDao,
    db.NoteDao? noteDao,
    db.AiConversationDao? aiConversationDao,
    db.SearchDao? searchDao,
    db.OcrPageDao? ocrPageDao,
  }) : this._(
         bookDao,
         progressDao,
         bookmarkDao,
         annotationDao,
         noteDao,
         aiConversationDao,
         searchDao,
         ocrPageDao,
       );

  const DriftBookRepository._(
    this._bookDao,
    this._progressDao,
    this._bookmarkDao,
    this._annotationDao,
    this._noteDao,
    this._aiConversationDao,
    this._searchDao,
    this._ocrPageDao,
  );

  final db.BookDao _bookDao;
  final db.ProgressDao _progressDao;
  final db.BookmarkDao? _bookmarkDao;
  final db.AnnotationDao? _annotationDao;
  final db.NoteDao? _noteDao;
  final db.AiConversationDao? _aiConversationDao;
  final db.SearchDao? _searchDao;
  final db.OcrPageDao? _ocrPageDao;

  @override
  Stream<List<LibraryBook>> watchLibrary() {
    // Split books vs progress watches:
    // - import / metadata / favorite / open → books stream
    // - reading locator ticks → progress stream only
    // Distinct fingerprint so sub-1% progress noise does not rebuild the shelf.
    final controller = StreamController<List<LibraryBook>>();
    var books = <db.BookRow>[];
    var progressById = <String, db.ReadingProgressRow>{};
    var booksReady = false;
    var progressReady = false;
    String? lastFingerprint;

    void emit() {
      if (controller.isClosed || !booksReady || !progressReady) {
        return;
      }
      final merged = books
          .map(
            (row) => LibraryBook(
              book: _mapBook(row),
              progress: progressById[row.id] == null
                  ? null
                  : _mapProgress(progressById[row.id]!),
            ),
          )
          .toList(growable: false);
      final fingerprint = _libraryFingerprint(merged);
      if (fingerprint == lastFingerprint) {
        return;
      }
      lastFingerprint = fingerprint;
      controller.add(merged);
    }

    final booksSub = _bookDao.watchBooks().listen((rows) {
      books = rows;
      booksReady = true;
      emit();
    }, onError: controller.addError);
    final progressSub = _progressDao.watchAllProgress().listen((rows) {
      progressById = {for (final row in rows) row.bookId: row};
      progressReady = true;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await booksSub.cancel();
      await progressSub.cancel();
    };
    return controller.stream;
  }

  @override
  Future<List<LibraryBook>> getLibrary() async {
    final bookRows = await _bookDao.getBooks();
    final progressRows = await _progressDao.getAllProgress();
    final progressById = {for (final row in progressRows) row.bookId: row};
    return bookRows
        .map(
          (row) => LibraryBook(
            book: _mapBook(row),
            progress: progressById[row.id] == null
                ? null
                : _mapProgress(progressById[row.id]!),
          ),
        )
        .toList(growable: false);
  }

  /// Visual identity for the shelf: ignore sub-percent progress jitter and
  /// locator JSON churn while reading.
  String _libraryFingerprint(List<LibraryBook> books) {
    final buffer = StringBuffer();
    for (final item in books) {
      final book = item.book;
      final progressPct = ((item.progress?.progress ?? 0) * 100).round();
      buffer
        ..write(book.id)
        ..write(':')
        ..write(book.updatedAt)
        ..write(':')
        ..write(book.lastOpenedAt ?? 0)
        ..write(':')
        ..write(book.readStatus.value)
        ..write(':')
        ..write(book.isFavorite ? 1 : 0)
        ..write(':')
        ..write(book.indexingStatus)
        ..write(':')
        ..write(book.categoryId ?? '')
        ..write(':')
        ..write(progressPct)
        ..write('|');
    }
    return buffer.toString();
  }

  @override
  Future<domain.Book?> getBook(String id) async {
    final row = await _bookDao.getBook(id);
    return row == null ? null : _mapBook(row);
  }

  @override
  Future<domain.Book?> findByHash(String fileHash) async {
    final row = await _bookDao.findByHash(fileHash);
    return row == null ? null : _mapBook(row);
  }

  @override
  Future<domain.Book> createImportedBook(domain.NewBookDraft draft) async {
    // Last line of defense against double-import races / retry bugs.
    final existing = await findByHash(draft.fileHash);
    if (existing != null) {
      return existing;
    }
    final updatedAt = draft.createdAt;
    await _bookDao.insertBook(
      db.BooksCompanion.insert(
        id: draft.id,
        title: draft.title,
        originalTitle: Value(draft.originalTitle),
        author: Value(draft.author),
        format: draft.format.value,
        originalFormat: Value(draft.format.value),
        originalFilePath: Value(draft.originalFilePath),
        libraryFilePath: draft.libraryFilePath,
        coverPath: Value(draft.coverPath),
        fileHash: draft.fileHash,
        fileSize: draft.fileSize,
        language: Value(draft.language),
        description: Value(draft.description),
        createdAt: draft.createdAt,
        updatedAt: updatedAt,
      ),
    );
    final created = await _bookDao.getBook(draft.id);
    return _mapBook(created!);
  }

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async {
    final row = await _progressDao.getProgress(bookId);
    return row == null ? null : _mapProgress(row);
  }

  @override
  Future<void> saveProgress({
    required String bookId,
    required ReadingLocator locator,
    required double progress,
    String? chapterTitle,
    int? pageNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _progressDao.saveProgress(
      db.ReadingProgressCompanion.insert(
        bookId: bookId,
        locator: locator.toJsonText(),
        progress: Value(progress.clamp(0, 1).toDouble()),
        chapterTitle: Value(chapterTitle),
        pageNumber: Value(pageNumber),
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> markOpened(String bookId) {
    return _bookDao.markOpened(bookId, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> updateMetadata({
    required String bookId,
    String? title,
    String? author,
    String? description,
    String? coverPath,
  }) {
    return _bookDao.updateMetadata(
      id: bookId,
      title: title,
      author: author,
      description: description,
      coverPath: coverPath,
    );
  }

  @override
  Future<void> updateCategory(String bookId, String? categoryId) {
    return _bookDao.updateCategory(bookId, categoryId);
  }

  @override
  Future<void> toggleFavorite(String bookId, bool isFavorite) {
    return _bookDao.toggleFavorite(bookId, isFavorite);
  }

  @override
  Future<void> updateReadStatus(String bookId, domain.ReadStatus readStatus) {
    return _bookDao.updateReadStatus(bookId, readStatus.value);
  }

  @override
  Future<void> updateIndexingStatus(String bookId, String indexingStatus) {
    return _bookDao.updateIndexingStatus(bookId, indexingStatus);
  }

  @override
  Future<void> deleteBook(String bookId) async {
    await _progressDao.deleteProgress(bookId);
    await _bookmarkDao?.deleteByBook(bookId);
    await _annotationDao?.deleteByBook(bookId);
    await _noteDao?.deleteByBook(bookId);
    await _aiConversationDao?.deleteByBook(bookId);
    await _searchDao?.deleteByBook(bookId);
    await _ocrPageDao?.deleteByBook(bookId);
    await _bookDao.deleteBook(bookId);
  }

  domain.Book _mapBook(db.BookRow row) {
    return domain.Book(
      id: row.id,
      title: row.title,
      originalTitle: row.originalTitle,
      author: row.author,
      format: domain.BookFormat.fromValue(row.format) ?? domain.BookFormat.epub,
      originalFormat: row.originalFormat,
      originalFilePath: row.originalFilePath,
      libraryFilePath: row.libraryFilePath,
      coverPath: row.coverPath,
      fileHash: row.fileHash,
      fileSize: row.fileSize,
      language: row.language,
      description: row.description,
      categoryId: row.categoryId,
      isFavorite: row.isFavorite,
      readStatus: domain.ReadStatus.fromValue(row.readStatus),
      indexingStatus: row.indexingStatus,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastOpenedAt: row.lastOpenedAt,
    );
  }

  ReadingProgressSnapshot _mapProgress(db.ReadingProgressRow row) {
    return ReadingProgressSnapshot(
      bookId: row.bookId,
      locator: ReadingLocator.fromJsonText(row.locator),
      progress: row.progress,
      chapterTitle: row.chapterTitle,
      pageNumber: row.pageNumber,
      updatedAt: row.updatedAt,
    );
  }
}
