import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/search/pdf_text_extractor.dart';
import '../../../core/search/search_indexer.dart';
import '../../../core/tasks/task_cancellation.dart';
import '../../../core/tasks/task_models.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/book_repository.dart';
import '../../../domain/ocr/ocr_jobs.dart';
import '../../../domain/ocr/ocr_models.dart';
import 'ocr_current_page_use_case.dart';
import 'ocr_providers.dart';

// The private fields are intentionally not constructed through public named
// initializing formals; callers outside this library could not name them.
// ignore_for_file: prefer_initializing_formals

final ocrJobControllerProvider = Provider<OcrJobController>((ref) {
  return OcrJobController(
    taskRepository: ref.watch(taskRepositoryProvider),
    jobRepository: ref.watch(ocrJobRepositoryProvider),
    bookRepository: ref.watch(bookRepositoryProvider),
    useCase: ref.watch(ocrCurrentPageUseCaseProvider),
    searchIndexer: ref.watch(searchIndexerProvider),
    cancellationRegistry: ref.watch(taskCancellationRegistryProvider),
    nativeTextExtractor: const PdfTextExtractorService(),
  );
});

/// Runs explicit OCR page ranges as durable, resumable tasks.
final class OcrJobController {
  OcrJobController({
    required TaskRepository taskRepository,
    required OcrJobRepository jobRepository,
    required BookRepository bookRepository,
    required OcrCurrentPageUseCase useCase,
    required SearchIndexer searchIndexer,
    required TaskCancellationRegistry cancellationRegistry,
    required PdfTextExtractorService nativeTextExtractor,
  }) : _taskRepository = taskRepository,
       _jobRepository = jobRepository,
       _bookRepository = bookRepository,
       _useCase = useCase,
       _searchIndexer = searchIndexer,
       _cancellationRegistry = cancellationRegistry,
       _nativeTextExtractor = nativeTextExtractor;

  final TaskRepository _taskRepository;
  final OcrJobRepository _jobRepository;
  final BookRepository _bookRepository;
  final OcrCurrentPageUseCase _useCase;
  final SearchIndexer _searchIndexer;
  final TaskCancellationRegistry _cancellationRegistry;
  final PdfTextExtractorService _nativeTextExtractor;
  final Set<String> _runningTaskIds = {};
  final Set<String> _pauseRequested = {};
  final Map<String, ({String jobId, Book book, TaskCancelToken token})>
  _pendingJobs = {};
  bool _workerRunning = false;

  bool get isRunning => _runningTaskIds.isNotEmpty || _pendingJobs.isNotEmpty;

  Future<void> recoverInterrupted(Set<String> liveTaskIds) {
    return _jobRepository.recoverInterrupted(liveTaskIds: liveTaskIds);
  }

  Future<OcrJob> start({
    required Book book,
    required List<int> pageNumbers,
    String? languageHint,
  }) async {
    if (book.format != BookFormat.pdf) {
      throw const OcrFailedException('仅支持 PDF 页面识别');
    }
    final pages = pageNumbers.toSet().toList(growable: false)..sort();
    if (pages.isEmpty) {
      throw const FormatException('请选择至少一页');
    }
    if (pages.length > OcrPageRange.maxPagesPerJob) {
      throw FormatException('单次最多识别 ${OcrPageRange.maxPagesPerJob} 页，请分批处理');
    }
    final sourceRevision = book.fileHash.trim().isEmpty
        ? book.id
        : book.fileHash;
    final signature = await _useCase.cacheSignatureFor(
      book,
      languageHint: languageHint,
    );
    final task = await _taskRepository.saveTask(
      type: PageSageTaskType.ocrPages,
      status: PageSageTaskStatus.queued,
      bookId: book.id,
      sourcePath: book.originalFilePath ?? book.libraryFilePath,
      message: '已加入识别队列 · ${pages.length} 页',
    );
    final job = await _jobRepository.createJob(
      taskId: task.id,
      bookId: book.id,
      sourceRevision: sourceRevision,
      config: OcrJobConfig(languageHint: languageHint, dpi: 200, maxEdge: 2200),
      pageNumbers: pages,
      expectedCacheSignature: signature,
    );
    _enqueue(job.id, task.id, book);
    return job;
  }

  Future<void> pause(String taskId) async {
    final pending = _pendingJobs.remove(taskId);
    if (pending != null && !_runningTaskIds.contains(taskId)) {
      _pauseRequested.remove(taskId);
      pending.token.cancel();
      _cancellationRegistry.complete(taskId);
      final job = await _jobRepository.getJobByTaskId(taskId);
      if (job != null) {
        await _jobRepository.updateJob(
          id: job.id,
          status: OcrJobStatus.paused,
          reason: 'paused',
        );
      }
      await _taskRepository.updateStatus(
        id: taskId,
        status: PageSageTaskStatus.paused,
        message: '已暂停，可继续识别',
      );
      return;
    }
    final job = await _jobRepository.getJobByTaskId(taskId);
    if (job == null) return;
    _pauseRequested.add(taskId);
    _cancellationRegistry.cancel(taskId);
    await _taskRepository.updateStatus(
      id: taskId,
      status: PageSageTaskStatus.paused,
      message: '已暂停，可继续识别',
    );
  }

  Future<void> cancel(String taskId) async {
    _pendingJobs.remove(taskId);
    _pauseRequested.remove(taskId);
    final wasRunning = _runningTaskIds.contains(taskId);
    _cancellationRegistry.cancel(taskId);
    if (!wasRunning) {
      _cancellationRegistry.complete(taskId);
    }
    final job = await _jobRepository.getJobByTaskId(taskId);
    if (job != null) {
      final pages = await _jobRepository.getPages(job.id);
      for (final page in pages) {
        if (page.status == OcrPageJobStatus.pending ||
            page.status == OcrPageJobStatus.rendering ||
            page.status == OcrPageJobStatus.recognizing) {
          await _jobRepository.updatePage(
            id: page.id,
            status: OcrPageJobStatus.cancelled,
            attempt: page.attempt,
            clearError: true,
          );
        }
      }
      await _jobRepository.updateJob(
        id: job.id,
        status: OcrJobStatus.cancelled,
        reason: 'cancelled',
        clearReason: false,
      );
    }
    await _taskRepository.updateStatus(
      id: taskId,
      status: PageSageTaskStatus.cancelled,
      message: '已取消识别',
    );
  }

  Future<void> resume(PageSageTask task) async {
    await _resume(task);
  }

  /// Requeues only failed pages and leaves completed pages untouched.
  Future<int> retryFailedPages(PageSageTask task) async {
    return _resume(task);
  }

  Future<int> _resume(PageSageTask task) async {
    if (task.type != PageSageTaskType.ocrPages) return 0;
    if (_runningTaskIds.contains(task.id) ||
        _pendingJobs.containsKey(task.id)) {
      throw StateError('识别任务正在运行或排队');
    }
    final bookId = task.bookId;
    if (bookId == null || bookId.isEmpty) {
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.failed,
        message: '缺少书籍 ID，无法继续识别',
        error: '缺少书籍 ID',
      );
      return 0;
    }
    final book = await _bookRepository.getBook(bookId);
    if (book == null) {
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.failed,
        message: '书籍已不存在，无法继续识别',
        error: '书籍已不存在',
      );
      return 0;
    }
    final job =
        await _jobRepository.getJobByTaskId(task.id) ??
        await _jobRepository.getLatestResumable(bookId);
    if (job == null) {
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.failed,
        message: '找不到可继续的识别任务',
        error: '找不到 OCR 任务记录',
      );
      return 0;
    }
    final pages = await _jobRepository.getPages(job.id);
    var retried = 0;
    for (final page in pages) {
      if (page.status == OcrPageJobStatus.failed) {
        retried += 1;
        await _jobRepository.updatePage(
          id: page.id,
          status: OcrPageJobStatus.pending,
          attempt: page.attempt,
          clearError: true,
        );
      }
    }
    _pauseRequested.remove(task.id);
    _enqueue(job.id, task.id, book);
    return retried;
  }

  /// Deletes this task's OCR text, page checkpoints, session cache and search
  /// entries. The book and native PDF text are not touched.
  Future<void> clearResults(PageSageTask task) async {
    if (task.type != PageSageTaskType.ocrPages) {
      throw ArgumentError.value(task.type, 'task.type', '不是 OCR 任务');
    }
    if (_runningTaskIds.contains(task.id)) {
      throw StateError('请先暂停或取消正在运行的识别任务');
    }
    _pendingJobs.remove(task.id);
    _cancellationRegistry.complete(task.id);
    final bookId = task.bookId?.trim() ?? '';
    if (bookId.isEmpty) {
      throw StateError('任务缺少书籍 ID');
    }
    final job = await _jobRepository.getJobByTaskId(task.id);
    if (job == null) {
      throw StateError('找不到 OCR 任务记录');
    }
    final pages = await _jobRepository.getPages(job.id);
    final pageNumbers = pages
        .map((page) => page.pageNumber)
        .toList(growable: false);
    _pauseRequested.remove(task.id);
    await _useCase.discardCachedPages(bookId: bookId, pageNumbers: pageNumbers);
    await _jobRepository.deleteJob(job.id);

    final book = await _bookRepository.getBook(bookId);
    if (book != null) {
      await _searchIndexer.indexBook(book);
    }
    await _taskRepository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.cancelled,
      progress: task.progress,
      message: '已清除 ${pageNumbers.length} 页 OCR 文字与搜索索引',
      clearError: true,
    );
  }

  void _enqueue(String jobId, String taskId, Book book) {
    if (_runningTaskIds.contains(taskId) || _pendingJobs.containsKey(taskId)) {
      return;
    }
    final token = _cancellationRegistry.register(taskId);
    _pendingJobs[taskId] = (jobId: jobId, book: book, token: token);
    unawaited(_drainWorker());
  }

  Future<void> _drainWorker() async {
    if (_workerRunning) return;
    _workerRunning = true;
    try {
      while (_pendingJobs.isNotEmpty) {
        final entry = _pendingJobs.entries.first;
        _pendingJobs.remove(entry.key);
        await _runExclusive(
          entry.value.jobId,
          entry.key,
          entry.value.book,
          entry.value.token,
        );
      }
    } finally {
      _workerRunning = false;
    }
  }

  Future<void> _runExclusive(
    String jobId,
    String taskId,
    Book book,
    TaskCancelToken token,
  ) async {
    if (!_runningTaskIds.add(taskId)) return;
    try {
      token.throwIfCancelled();
      final job = await _jobRepository.getJob(jobId);
      if (job == null) return;
      final pages = await _jobRepository.getPages(jobId);
      if (pages.isEmpty) {
        await _finish(taskId, jobId, OcrJobStatus.failed, '识别任务没有页面');
        return;
      }
      if (job.sourceRevision !=
          (book.fileHash.trim().isEmpty ? book.id : book.fileHash)) {
        await _jobRepository.updateJob(
          id: jobId,
          status: OcrJobStatus.paused,
          reason: 'sourceChanged',
        );
        await _taskRepository.updateStatus(
          id: taskId,
          status: PageSageTaskStatus.paused,
          message: 'PDF 文件已变化，请重新创建识别任务',
        );
        return;
      }

      await _jobRepository.updateJob(
        id: jobId,
        status: OcrJobStatus.running,
        clearReason: true,
      );
      await _taskRepository.updateStatus(
        id: taskId,
        status: PageSageTaskStatus.running,
        progress: 0,
        message: '准备识别 ${pages.length} 页',
      );

      final nativePages = await _nativePages(book);
      var recognized = 0;
      var cached = 0;
      var skippedNative = 0;
      var empty = 0;
      var failed = 0;
      var incomplete = 0;

      for (final page in pages) {
        token.throwIfCancelled();
        if (page.status.isTerminal ||
            page.status == OcrPageJobStatus.recognized ||
            page.status == OcrPageJobStatus.indexing) {
          if (page.status == OcrPageJobStatus.skippedNative) skippedNative += 1;
          if (page.status == OcrPageJobStatus.empty) empty += 1;
          if (page.status == OcrPageJobStatus.failed) failed += 1;
          if (page.status == OcrPageJobStatus.recognized) recognized += 1;
          continue;
        }
        if (nativePages.contains(page.pageNumber)) {
          skippedNative += 1;
          await _jobRepository.updatePage(
            id: page.id,
            status: OcrPageJobStatus.skippedNative,
            attempt: page.attempt,
            clearError: true,
          );
          await _reportProgress(
            taskId,
            jobId,
            pages.length,
            recognized: recognized,
            cached: cached,
            skippedNative: skippedNative,
            empty: empty,
            failed: failed,
          );
          continue;
        }

        final existing = await _useCase.peekCachedPage(
          bookId: book.id,
          pageNumber: page.pageNumber,
          cacheSignature: page.expectedCacheSignature,
        );
        if (existing != null &&
            (existing.hasText || existing.resultState == 'empty')) {
          if (existing.hasText) {
            cached += 1;
          } else {
            empty += 1;
          }
          await _jobRepository.updatePage(
            id: page.id,
            status: existing.hasText
                ? OcrPageJobStatus.recognized
                : OcrPageJobStatus.empty,
            attempt: page.attempt,
            clearError: true,
          );
          await _reportProgress(
            taskId,
            jobId,
            pages.length,
            recognized: recognized,
            cached: cached,
            skippedNative: skippedNative,
            empty: empty,
            failed: failed,
          );
          continue;
        }

        await _jobRepository.updatePage(
          id: page.id,
          status: OcrPageJobStatus.recognizing,
          attempt: page.attempt + 1,
          clearError: true,
        );
        await _reportProgress(
          taskId,
          jobId,
          pages.length,
          recognized: recognized,
          cached: cached,
          skippedNative: skippedNative,
          empty: empty,
          failed: failed,
          currentPageNumber: page.pageNumber,
        );
        try {
          final result = await _useCase.recognizeCurrentPage(
            book: book,
            pageNumber: page.pageNumber,
            languageHint: job.config.languageHint,
            cancelToken: token,
            allowEmpty: true,
            requirePersistence: true,
          );
          if (result.hasText) {
            recognized += 1;
            await _jobRepository.updatePage(
              id: page.id,
              status: OcrPageJobStatus.recognized,
              attempt: page.attempt + 1,
              clearError: true,
            );
          } else {
            empty += 1;
            await _jobRepository.updatePage(
              id: page.id,
              status: OcrPageJobStatus.empty,
              attempt: page.attempt + 1,
              clearError: true,
            );
          }
        } on TaskCancelledException {
          rethrow;
        } on OcrEmptyResultException {
          empty += 1;
          await _jobRepository.updatePage(
            id: page.id,
            status: OcrPageJobStatus.empty,
            attempt: page.attempt + 1,
            clearError: true,
          );
        } on Object catch (error) {
          failed += 1;
          await _jobRepository.updatePage(
            id: page.id,
            status: OcrPageJobStatus.failed,
            attempt: page.attempt + 1,
            errorCode: _errorCode(error),
          );
        }
        await _reportProgress(
          taskId,
          jobId,
          pages.length,
          recognized: recognized,
          cached: cached,
          skippedNative: skippedNative,
          empty: empty,
          failed: failed,
        );
      }

      token.throwIfCancelled();
      final refreshed = await _jobRepository.getPages(jobId);
      final toIndex = refreshed
          .where(
            (page) =>
                page.status == OcrPageJobStatus.recognized ||
                page.status == OcrPageJobStatus.indexing,
          )
          .toList(growable: false);
      if (toIndex.isNotEmpty || empty > 0) {
        for (final page in toIndex) {
          if (page.status != OcrPageJobStatus.indexing) {
            await _jobRepository.updatePage(
              id: page.id,
              status: OcrPageJobStatus.indexing,
              attempt: page.attempt,
            );
          }
        }
        await _taskRepository.updateStatus(
          id: taskId,
          status: PageSageTaskStatus.indexing,
          message: '正在更新搜索索引',
        );
        await _searchIndexer.indexBook(
          book,
          cancelToken: token,
          onProgress: (progress, {message}) {
            unawaited(
              _taskRepository.updateStatus(
                id: taskId,
                status: PageSageTaskStatus.indexing,
                progress: progress.clamp(0.85, 0.99),
                message: message ?? '正在更新搜索索引',
              ),
            );
          },
        );
        for (final page in toIndex) {
          await _jobRepository.updatePage(
            id: page.id,
            status: OcrPageJobStatus.done,
            attempt: page.attempt,
          );
        }
      }

      final completedPages = await _jobRepository.getPages(jobId);
      incomplete = completedPages
          .where(
            (page) =>
                !page.status.isTerminal &&
                page.status != OcrPageJobStatus.recognized,
          )
          .length;
      final status = failed > 0 || incomplete > 0
          ? OcrJobStatus.partial
          : OcrJobStatus.done;
      await _finish(
        taskId,
        jobId,
        status,
        null,
        progress: 1,
        message:
            '完成 ${completedPages.length} 页 · 新识别 $recognized · 缓存 $cached · '
            '原生跳过 $skippedNative · 空页 $empty · 失败 $failed',
      );
    } on TaskCancelledException {
      final job = await _jobRepository.getJob(jobId);
      final paused = _pauseRequested.remove(taskId);
      if (job != null) {
        await _jobRepository.updateJob(
          id: jobId,
          status: paused ? OcrJobStatus.paused : OcrJobStatus.cancelled,
          reason: paused ? 'paused' : 'cancelled',
        );
      }
      await _taskRepository.updateStatus(
        id: taskId,
        status: paused
            ? PageSageTaskStatus.paused
            : PageSageTaskStatus.cancelled,
        message: paused ? '已暂停，可继续识别' : '已取消识别',
      );
    } on Object catch (error) {
      await _finish(
        taskId,
        jobId,
        OcrJobStatus.failed,
        _errorCode(error),
        message: '识别任务失败',
      );
    } finally {
      _runningTaskIds.remove(taskId);
      _cancellationRegistry.complete(taskId);
    }
  }

  Future<Set<int>> _nativePages(Book book) async {
    try {
      final document = await _nativeTextExtractor.extract(book.libraryFilePath);
      return {
        for (final page in document.pages)
          if (page.text.trim().isNotEmpty) page.pageNumber,
      };
    } on Object {
      return const {};
    }
  }

  Future<void> _reportProgress(
    String taskId,
    String jobId,
    int totalPages, {
    required int recognized,
    required int cached,
    required int skippedNative,
    required int empty,
    required int failed,
    int? currentPageNumber,
  }) async {
    final pages = await _jobRepository.getPages(jobId);
    final processed = pages
        .where(
          (page) =>
              page.status == OcrPageJobStatus.done ||
              page.status == OcrPageJobStatus.empty ||
              page.status == OcrPageJobStatus.skippedNative ||
              page.status == OcrPageJobStatus.failed ||
              page.status == OcrPageJobStatus.recognized ||
              page.status == OcrPageJobStatus.cancelled,
        )
        .length;
    await _taskRepository.updateStatus(
      id: taskId,
      status: PageSageTaskStatus.running,
      progress: totalPages == 0 ? 0 : processed / totalPages,
      message:
          '${currentPageNumber == null ? '已处理' : '正在识别第 $currentPageNumber 页'} '
          '$processed/$totalPages；新识别 $recognized；缓存 $cached；'
          '原生跳过 $skippedNative；空页 $empty；失败 $failed',
    );
  }

  Future<void> _finish(
    String taskId,
    String jobId,
    OcrJobStatus jobStatus,
    String? reason, {
    double progress = 1,
    String? message,
  }) async {
    await _jobRepository.updateJob(
      id: jobId,
      status: jobStatus,
      reason: reason,
      clearReason: reason == null,
    );
    await _taskRepository.updateStatus(
      id: taskId,
      status: switch (jobStatus) {
        OcrJobStatus.partial => PageSageTaskStatus.partial,
        OcrJobStatus.done => PageSageTaskStatus.done,
        OcrJobStatus.failed => PageSageTaskStatus.failed,
        OcrJobStatus.paused => PageSageTaskStatus.paused,
        OcrJobStatus.cancelled => PageSageTaskStatus.cancelled,
        OcrJobStatus.queued ||
        OcrJobStatus.running => PageSageTaskStatus.running,
      },
      progress: progress,
      message: message,
      error: jobStatus == OcrJobStatus.failed ? reason : null,
      clearError: jobStatus != OcrJobStatus.failed,
    );
  }

  String _errorCode(Object error) {
    if (error is OcrUnavailableException) return error.code;
    if (error is OcrFailedException) return error.code;
    return 'ocr_failed';
  }
}
