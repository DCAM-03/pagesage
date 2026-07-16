import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/logging/privacy_sanitizer.dart';
import '../../../core/search/search_indexer.dart';
import '../../../core/tasks/task_cancellation.dart';
import '../../../core/tasks/task_models.dart';
import '../../../domain/books/book_repository.dart';
import '../../import/application/import_providers.dart';
import '../../import/application/import_use_case.dart';

final taskListProvider = StreamProvider<List<PageSageTask>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTasks();
});

final taskCenterControllerProvider = Provider<TaskCenterController>((ref) {
  return TaskCenterController(
    taskRepository: ref.watch(taskRepositoryProvider),
    importUseCase: ref.watch(importUseCaseProvider),
    bookRepository: ref.watch(bookRepositoryProvider),
    searchIndexer: ref.watch(searchIndexerProvider),
    taskCancellationRegistry: ref.watch(taskCancellationRegistryProvider),
  );
});

final class TaskCenterController {
  const TaskCenterController({
    required TaskRepository taskRepository,
    required ImportUseCase importUseCase,
    required BookRepository bookRepository,
    required SearchIndexer searchIndexer,
    required TaskCancellationRegistry taskCancellationRegistry,
  }) : this._(
         taskRepository,
         importUseCase,
         bookRepository,
         searchIndexer,
         taskCancellationRegistry,
       );

  const TaskCenterController._(
    this._taskRepository,
    this._importUseCase,
    this._bookRepository,
    this._searchIndexer,
    this._taskCancellationRegistry,
  );

  final TaskRepository _taskRepository;
  final ImportUseCase _importUseCase;
  final BookRepository _bookRepository;
  final SearchIndexer _searchIndexer;
  final TaskCancellationRegistry _taskCancellationRegistry;

  Future<void> recoverInterruptedTasks() async {
    final tasks = await _taskRepository.getTasks();
    for (final task in tasks) {
      if (!_isActive(task.status)) {
        continue;
      }
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.failed,
        progress: task.progress,
        message: '上次运行中断，可重试',
        error: sanitizeTaskError('任务在应用关闭或重启时中断'),
      );
    }
  }

  Future<void> cancelTask(PageSageTask task) async {
    final hasActiveToken = _taskCancellationRegistry.cancel(task.id);
    await _deleteIfPartialTarget(task);
    await _taskRepository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.cancelled,
      progress: task.progress,
      message: '已取消',
    );
    if (!hasActiveToken) {
      _taskCancellationRegistry.complete(task.id);
    }
  }

  Future<void> retryTask(PageSageTask task) async {
    switch (task.type) {
      case PageSageTaskType.importBook:
        final sourcePath = task.sourcePath;
        if (sourcePath == null || sourcePath.isEmpty) {
          await _markRetryFailed(task, '缺少源文件路径，无法重试');
          return;
        }
        await _importUseCase.importPath(
          sourcePath,
          allowDuplicate: true,
          taskId: task.id,
        );
      case PageSageTaskType.indexBook:
      case PageSageTaskType.rebuildIndex:
        await _retryIndex(task);
      case PageSageTaskType.metadata:
      case PageSageTaskType.exportNotes:
      case PageSageTaskType.backup:
      case PageSageTaskType.restore:
        await _markRetryFailed(task, '这个任务类型暂不支持自动重试');
    }
  }

  Future<void> clearCompleted() {
    return _taskRepository.clearCompleted();
  }

  Future<void> _retryIndex(PageSageTask task) async {
    final bookId = task.bookId;
    if (bookId == null || bookId.isEmpty) {
      await _markRetryFailed(task, '缺少书籍 ID，无法重试索引');
      return;
    }
    final book = await _bookRepository.getBook(bookId);
    if (book == null) {
      await _markRetryFailed(task, '书籍已不存在，无法重试索引');
      return;
    }
    await _taskRepository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.indexing,
      progress: 0.1,
      message: '正在重建索引',
    );
    final cancelToken = _taskCancellationRegistry.register(task.id);
    try {
      await _searchIndexer.indexBook(book, cancelToken: cancelToken);
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.done,
        progress: 1,
        message: '索引已重建',
      );
      _taskCancellationRegistry.complete(task.id);
    } on TaskCancelledException {
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.cancelled,
        progress: task.progress,
        message: '已取消索引',
      );
      _taskCancellationRegistry.complete(task.id);
    } on Object catch (error) {
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.failed,
        progress: 1,
        message: '索引重建失败',
        error: sanitizeTaskError(error),
      );
      _taskCancellationRegistry.complete(task.id);
    }
  }

  Future<void> _markRetryFailed(PageSageTask task, String message) {
    return _taskRepository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.failed,
      progress: task.progress,
      message: message,
      error: sanitizeTaskError(message),
    );
  }

  Future<void> _deleteIfPartialTarget(PageSageTask task) async {
    final path = task.targetPath;
    if (path == null || path.isEmpty) {
      return;
    }
    if (task.bookId != null && task.bookId!.isNotEmpty) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  bool _isActive(PageSageTaskStatus status) {
    return switch (status) {
      PageSageTaskStatus.queued ||
      PageSageTaskStatus.running ||
      PageSageTaskStatus.indexing => true,
      PageSageTaskStatus.done ||
      PageSageTaskStatus.failed ||
      PageSageTaskStatus.cancelled => false,
    };
  }
}

String sanitizeTaskError(Object? error) {
  return const PrivacySanitizer().sanitize(error);
}
