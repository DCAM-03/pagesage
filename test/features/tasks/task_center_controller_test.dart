import 'dart:io';

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
}

TaskCenterController _controller(
  _MemoryTaskRepository repository, {
  TaskCancellationRegistry? cancellationRegistry,
}) {
  final bookRepository = _FakeBookRepository();
  final registry = cancellationRegistry ?? TaskCancellationRegistry();
  return TaskCenterController(
    taskRepository: repository,
    importUseCase: ImportUseCase(
      filePickerService: FilePickerService(),
      formatDetector: FormatDetector(),
      hashService: HashService(),
      metadataExtractor: MetadataExtractor(appPaths: AppPaths()),
      appPaths: AppPaths(),
      bookRepository: bookRepository,
      searchIndexer: SearchIndexer(
        searchRepository: _NoopSearchRepository(),
        bookRepository: bookRepository,
      ),
      taskRepository: repository,
      taskCancellationRegistry: registry,
    ),
    bookRepository: bookRepository,
    searchIndexer: SearchIndexer(
      searchRepository: _NoopSearchRepository(),
      bookRepository: bookRepository,
    ),
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
  @override
  Future<Book?> findByHash(String fileHash) async => null;

  @override
  Future<Book?> getBook(String id) async => null;

  @override
  Future<List<LibraryBook>> getLibrary() async => const [];

  @override
  Stream<List<LibraryBook>> watchLibrary() => const Stream.empty();

  @override
  Future<Book> createImportedBook(NewBookDraft draft) async {
    return Book(
      id: draft.id,
      title: draft.title,
      format: draft.format,
      libraryFilePath: draft.libraryFilePath,
      fileHash: draft.fileHash,
      fileSize: draft.fileSize,
      createdAt: draft.createdAt,
      updatedAt: draft.createdAt,
    );
  }

  @override
  Future<void> deleteBook(String bookId) async {}

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
  Future<List<SearchResult>> search(SearchQuery query) async => const [];
}
