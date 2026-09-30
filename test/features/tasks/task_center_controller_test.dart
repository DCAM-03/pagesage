import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/format_detector.dart';
import 'package:pagesage/core/files/hash_service.dart';
import 'package:pagesage/core/files/metadata_extractor.dart';
import 'package:pagesage/core/platform/file_picker_service.dart';
import 'package:pagesage/core/search/search_indexer.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/import/application/import_use_case.dart';
import 'package:pagesage/features/tasks/application/task_center_controller.dart';

void main() {
  test(
    'recovers interrupted active tasks as failed with sanitized error',
    () async {
      final repository = _MemoryTaskRepository();
      final task = await repository.saveTask(
        type: PageSageTaskType.importBook,
        status: PageSageTaskStatus.running,
        sourcePath: r'C:\Users\Chaos\secret\book.epub',
        progress: 0.4,
        message: '正在导入',
      );
      final controller = _controller(repository);

      await controller.recoverInterruptedTasks();

      final saved = await repository.getTasks();
      expect(saved.single.id, task.id);
      expect(saved.single.status, PageSageTaskStatus.failed);
      expect(saved.single.message, '上次运行中断，可重试');
      expect(saved.single.error, isNot(contains(r'C:\Users\Chaos')));
    },
  );

  test(
    'cancel task deletes partial target when no book id is linked',
    () async {
      final repository = _MemoryTaskRepository();
      final tempDir = await Directory.systemTemp.createTemp('pagesage_task_');
      addTearDown(() => tempDir.delete(recursive: true));
      final partial = File('${tempDir.path}/partial.epub')
        ..writeAsStringSync('partial');
      final task = await repository.saveTask(
        type: PageSageTaskType.importBook,
        status: PageSageTaskStatus.running,
        targetPath: partial.path,
        progress: 0.5,
      );
      final controller = _controller(repository);

      await controller.cancelTask(task);

      expect(await partial.exists(), isFalse);
      expect(
        (await repository.getTasks()).single.status,
        PageSageTaskStatus.cancelled,
      );
    },
  );

  test('cancel task notifies active cancellation token', () async {
    final repository = _MemoryTaskRepository();
    final registry = TaskCancellationRegistry();
    final task = await repository.saveTask(
      type: PageSageTaskType.importBook,
      status: PageSageTaskStatus.running,
      progress: 0.3,
    );
    final token = registry.register(task.id);
    final controller = _controller(repository, cancellationRegistry: registry);

    await controller.cancelTask(task);

    expect(token.isCancelled, isTrue);
    expect(
      (await repository.getTasks()).single.status,
      PageSageTaskStatus.cancelled,
    );
  });

  test('sanitizeTaskError hides API keys and local paths', () {
    final sanitized = sanitizeTaskError(
      r'failed with sk-testsecret123456789 at C:\Users\Chaos\book.epub',
    );

    expect(sanitized, isNot(contains('sk-testsecret')));
    expect(sanitized, isNot(contains(r'C:\Users\Chaos')));
    expect(sanitized, contains('[已隐藏密钥]'));
    expect(sanitized, contains('[本地路径]'));
  });

  test(
    'retry import task with existing bookId re-indexes without creating a second book',
    () async {
      final repository = _MemoryTaskRepository();
      final tempDir = await Directory.systemTemp.createTemp('pagesage_retry_');
      addTearDown(() => tempDir.delete(recursive: true));
      final pdfPath = '${tempDir.path}/book-1.pdf';
      // Minimal empty-text PDF (same structure as indexer tests).
      await File(pdfPath).writeAsBytes(_minimalEmptyPdf());
      final bookRepository = _FakeBookRepository(
        books: {
          'book-1': Book(
            id: 'book-1',
            title: 'Already Imported',
            format: BookFormat.pdf,
            libraryFilePath: pdfPath,
            fileHash: 'same-hash',
            fileSize: 10,
            createdAt: 1,
            updatedAt: 1,
          ),
        },
      );
      final searchRepository = _RecordingSearchRepository();
      final controller = _controller(
        repository,
        bookRepository: bookRepository,
        searchRepository: searchRepository,
      );
      final task = await repository.saveTask(
        type: PageSageTaskType.importBook,
        status: PageSageTaskStatus.failed,
        sourcePath: r'C:\Users\Chaos\secret\scan.pdf',
        bookId: 'book-1',
        targetPath: pdfPath,
        progress: 0.82,
        message: '导入完成，索引失败，可重试索引',
      );

      await controller.retryTask(task);

      final saved = (await repository.getTasks()).single;
      expect(saved.status, PageSageTaskStatus.done);
      expect(saved.message, '索引已重建');
      expect(bookRepository.createCalls, 0);
      expect(searchRepository.indexedBookIds, ['book-1']);
    },
  );
}

TaskCenterController _controller(
  _MemoryTaskRepository repository, {
  TaskCancellationRegistry? cancellationRegistry,
  BookRepository? bookRepository,
  SearchRepository? searchRepository,
}) {
  final books = bookRepository ?? _FakeBookRepository();
  final search = searchRepository ?? _NoopSearchRepository();
  final registry = cancellationRegistry ?? TaskCancellationRegistry();
  final indexer = SearchIndexer(
    searchRepository: search,
    bookRepository: books,
  );
  return TaskCenterController(
    taskRepository: repository,
    importUseCase: ImportUseCase(
      filePickerService: FilePickerService(),
      formatDetector: FormatDetector(),
      hashService: HashService(),
      metadataExtractor: MetadataExtractor(appPaths: AppPaths()),
      appPaths: AppPaths(),
      bookRepository: books,
      searchIndexer: indexer,
      taskRepository: repository,
      taskCancellationRegistry: registry,
    ),
    bookRepository: books,
    searchIndexer: indexer,
    taskCancellationRegistry: registry,
  );
}

final class _MemoryTaskRepository implements TaskRepository {
  final List<PageSageTask> _tasks = [];

  @override
  Future<PageSageTask> saveTask({
    String? id,
    required PageSageTaskType type,
    required PageSageTaskStatus status,
    String? sourcePath,
    String? targetPath,
    String? bookId,
    double progress = 0,
    String? message,
    String? error,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = PageSageTask(
      id: id ?? 'task-${_tasks.length + 1}',
      type: type,
      status: status,
      sourcePath: sourcePath,
      targetPath: targetPath,
      bookId: bookId,
      progress: progress,
      message: message,
      error: error,
      createdAt: now,
      updatedAt: now,
    );
    final existing = _tasks.indexWhere((item) => item.id == task.id);
    if (existing == -1) {
      _tasks.add(task);
    } else {
      _tasks[existing] = task;
    }
    return task;
  }

  @override
  Future<void> updateStatus({
    required String id,
    required PageSageTaskStatus status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    final previous = _tasks[index];
    _tasks[index] = PageSageTask(
      id: previous.id,
      type: previous.type,
      status: status,
      sourcePath: previous.sourcePath,
      targetPath: targetPath ?? previous.targetPath,
      bookId: bookId ?? previous.bookId,
      progress: progress ?? previous.progress,
      message: message ?? previous.message,
      error: error ?? previous.error,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> clearCompleted() async {
    _tasks.removeWhere(
      (task) =>
          task.status == PageSageTaskStatus.done ||
          task.status == PageSageTaskStatus.failed ||
          task.status == PageSageTaskStatus.cancelled,
    );
  }

  @override
  Future<List<PageSageTask>> getTasks() async => List.unmodifiable(_tasks);

  @override
  Stream<List<PageSageTask>> watchTasks() => Stream.value(_tasks);
}

final class _FakeBookRepository implements BookRepository {
  _FakeBookRepository({Map<String, Book>? books}) : _books = {...?books};

  final Map<String, Book> _books;
  int createCalls = 0;

  @override
  Future<Book?> findByHash(String fileHash) async {
    for (final book in _books.values) {
      if (book.fileHash == fileHash) {
        return book;
      }
    }
    return null;
  }

  @override
  Future<Book?> getBook(String id) async => _books[id];

  @override
  Future<List<LibraryBook>> getLibrary() async =>
      _books.values.map((book) => LibraryBook(book: book)).toList();

  @override
  Stream<List<LibraryBook>> watchLibrary() => Stream.value(
    _books.values.map((book) => LibraryBook(book: book)).toList(),
  );

  @override
  Future<Book> createImportedBook(NewBookDraft draft) async {
    createCalls += 1;
    final book = Book(
      id: draft.id,
      title: draft.title,
      format: draft.format,
      libraryFilePath: draft.libraryFilePath,
      fileHash: draft.fileHash,
      fileSize: draft.fileSize,
      createdAt: draft.createdAt,
      updatedAt: draft.createdAt,
    );
    _books[book.id] = book;
    return book;
  }

  @override
  Future<void> deleteBook(String bookId) async {
    _books.remove(bookId);
  }

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async => null;

  @override
  Future<void> markOpened(String bookId) async {}

  @override
  Future<void> saveProgress({
    required String bookId,
    required ReadingLocator locator,
    required double progress,
    String? chapterTitle,
    int? pageNumber,
  }) async {}

  @override
  Future<void> toggleFavorite(String bookId, bool isFavorite) async {}

  @override
  Future<void> updateCategory(String bookId, String? categoryId) async {}

  @override
  Future<void> updateIndexingStatus(
    String bookId,
    String indexingStatus,
  ) async {}

  @override
  Future<void> updateMetadata({
    required String bookId,
    String? title,
    String? author,
    String? description,
    String? coverPath,
  }) async {}

  @override
  Future<void> updateReadStatus(String bookId, ReadStatus readStatus) async {}
}

final class _NoopSearchRepository implements SearchRepository {
  @override
  Future<void> deleteByBook(String bookId) async {}

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) async {}

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) async {}

  @override
  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  }) async {}

  @override
  Future<void> indexTexts(List<SearchIndexEntry> entries) async {
    for (final entry in entries) {
      await indexText(
        sourceType: entry.sourceType,
        sourceId: entry.sourceId,
        bookId: entry.bookId,
        title: entry.title,
        text: entry.text,
        locator: entry.locator,
        sortOrder: entry.sortOrder,
      );
    }
  }

  @override
  Future<List<SearchResult>> search(SearchQuery query) async => const [];
}

final class _RecordingSearchRepository extends _NoopSearchRepository {
  final indexedBookIds = <String>[];

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) async {
    indexedBookIds.add(bookId);
  }
}

Uint8List _minimalEmptyPdf() {
  const operations = 'q Q';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R '
        '/Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${operations.length} >>\nstream\n$operations\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i += 1) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xrefOffset = buffer.length;
  buffer
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}
