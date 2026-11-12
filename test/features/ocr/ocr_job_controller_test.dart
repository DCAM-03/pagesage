import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_book_repository.dart';
import 'package:pagesage/core/database/drift_ocr_job_repository.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/database/drift_task_repository.dart';
import 'package:pagesage/core/search/pdf_text_extractor.dart';
import 'package:pagesage/core/search/search_indexer.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/ocr/ocr_engine.dart';
import 'package:pagesage/domain/ocr/ocr_jobs.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/domain/ocr/pdf_page_rasterizer.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ocr/application/ocr_current_page_use_case.dart';
import 'package:pagesage/features/ocr/application/ocr_job_controller.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:pagesage/features/ocr/application/ocr_session_cache.dart';
import 'package:pagesage/features/ocr/application/stored_ocr_search_source.dart';

void main() {
  late AppDatabase database;
  late DriftBookRepository bookRepository;
  late DriftTaskRepository taskRepository;
  late DriftOcrJobRepository jobRepository;
  late DriftOcrPageStore pageStore;
  late DriftSearchRepository searchRepository;
  late Directory tempDirectory;
  late Book book;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    jobRepository = DriftOcrJobRepository(database);
    bookRepository = DriftBookRepository(
      bookDao: database.bookDao,
      progressDao: database.progressDao,
      searchDao: database.searchDao,
      ocrPageDao: database.ocrPageDao,
      ocrJobRepository: jobRepository,
    );
    taskRepository = DriftTaskRepository(database.taskDao);
    pageStore = DriftOcrPageStore(database.ocrPageDao);
    searchRepository = DriftSearchRepository(database.searchDao);
    tempDirectory = await Directory.systemTemp.createTemp('pagesage_ocr_job_');
    final pdf = File('${tempDirectory.path}/scan.pdf');
    final bytes = _buildEmptyPdf();
    await pdf.writeAsBytes(bytes);
    book = await bookRepository.createImportedBook(
      NewBookDraft(
        id: 'book-ocr-job',
        title: '扫描书',
        format: BookFormat.pdf,
        originalFilePath: pdf.path,
        libraryFilePath: pdf.path,
        fileHash: 'hash-ocr-job',
        fileSize: bytes.length,
        createdAt: 1,
      ),
    );
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('runs all pages, persists signed text, and refreshes search', () async {
    final engine = _ControllableOcrEngine();
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );

    final job = await controller.start(book: book, pageNumbers: [2, 1]);
    final task = await _waitForTask(
      taskRepository,
      job.taskId,
      PageSageTaskStatus.done,
    );

    expect(task.progress, 1);
    expect(task.message, contains('新识别 2'));
    final pages = await jobRepository.getPages(job.id);
    expect(pages.map((page) => page.pageNumber), [1, 2]);
    expect(
      pages.map((page) => page.status),
      everyElement(OcrPageJobStatus.done),
    );
    final stored = await pageStore.listPages(book.id);
    expect(stored, hasLength(2));
    expect(
      stored.every(
        (page) =>
            page.result.resultState == 'recognized' &&
            page.result.cacheSignature != null &&
            page.result.textRevision != null,
      ),
      isTrue,
    );

    final results = await searchRepository.search(
      const SearchQuery(query: '扫描识别文本'),
    );
    final ocrResult = results.firstWhere(
      (result) => result.sourceId?.contains(':ocr:') == true,
    );
    expect(ocrResult.precision, SearchMatchPrecision.pageOnly);
    expect(ocrResult.textOrigin, 'ocr');
    expect(ocrResult.locator?.page, anyOf(1, 2));
  });

  test('pause cancels the current page and resume finishes the job', () async {
    final engine = _ControllableOcrEngine(blockFirstUntilCancelled: true);
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );

    final job = await controller.start(book: book, pageNumbers: [1]);
    await engine.firstStarted.future;
    await controller.pause(job.taskId);
    final paused = await _waitForTask(
      taskRepository,
      job.taskId,
      PageSageTaskStatus.paused,
    );
    expect(engine.calls, 1);
    expect((await jobRepository.getJob(job.id))?.status, OcrJobStatus.paused);
    expect(await pageStore.getPage(book.id, 1), isNull);

    await controller.resume(paused);
    final done = await _waitForTask(
      taskRepository,
      job.taskId,
      PageSageTaskStatus.done,
    );

    expect(done.progress, 1);
    expect(engine.calls, 2);
    expect((await jobRepository.getJob(job.id))?.status, OcrJobStatus.done);
    final pages = await jobRepository.getPages(job.id);
    expect(pages.single.status, OcrPageJobStatus.done);
    expect((await pageStore.getPage(book.id, 1))?.text, '扫描识别文本');
  });

  test('an empty OCR replacement removes stale search hits', () async {
    await pageStore.putPage(
      bookId: book.id,
      pageNumber: 1,
      result: const OcrPageResult(
        text: '旧识别正文',
        language: 'zh-Hans',
        engine: 'old',
      ),
      sourceRevision: book.fileHash,
      cacheSignature: 'old-signature',
      textRevision: 'old-text-revision',
      resultState: 'recognized',
    );
    final oldIndexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      ocrSearchSource: StoredOcrSearchSource(pageStore),
    );
    await oldIndexer.indexBook(book);
    expect(
      await searchRepository.search(const SearchQuery(query: '旧识别正文')),
      isNotEmpty,
    );

    final engine = _ControllableOcrEngine(text: '');
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );

    final job = await controller.start(book: book, pageNumbers: [1]);
    await _waitForTask(taskRepository, job.taskId, PageSageTaskStatus.done);

    expect((await pageStore.getPage(book.id, 1))?.resultState, 'empty');
    expect(
      await searchRepository.search(const SearchQuery(query: '旧识别正文')),
      isEmpty,
    );
  });

  test(
    'resume retries failed pages without rerunning completed ones',
    () async {
      final engine = _ControllableOcrEngine(failFirst: true);
      final controller = _controller(
        engine: engine,
        pageStore: pageStore,
        searchRepository: searchRepository,
        bookRepository: bookRepository,
        taskRepository: taskRepository,
        jobRepository: jobRepository,
      );

      final job = await controller.start(book: book, pageNumbers: [1]);
      final partial = await _waitForTask(
        taskRepository,
        job.taskId,
        PageSageTaskStatus.partial,
      );
      expect(engine.calls, 1);
      expect(
        (await jobRepository.getJob(job.id))?.status,
        OcrJobStatus.partial,
      );
      expect(
        (await jobRepository.getPages(job.id)).single.status,
        OcrPageJobStatus.failed,
      );

      await controller.resume(partial);
      await _waitForTask(taskRepository, job.taskId, PageSageTaskStatus.done);

      expect(engine.calls, 2);
      expect((await jobRepository.getJob(job.id))?.status, OcrJobStatus.done);
      expect(
        (await jobRepository.getPages(job.id)).single.status,
        OcrPageJobStatus.done,
      );
    },
  );

  test('retryFailedPages requeues only the failed page', () async {
    final engine = _ControllableOcrEngine(failFirst: true);
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );

    final job = await controller.start(book: book, pageNumbers: [1, 2]);
    final partial = await _waitForTask(
      taskRepository,
      job.taskId,
      PageSageTaskStatus.partial,
    );
    expect(engine.calls, 2);
    expect((await jobRepository.getPages(job.id)).map((page) => page.status), [
      OcrPageJobStatus.failed,
      OcrPageJobStatus.done,
    ]);

    final retried = await controller.retryFailedPages(partial);
    expect(retried, 1);
    await _waitForTask(taskRepository, job.taskId, PageSageTaskStatus.done);

    expect(engine.calls, 3);
    expect(
      (await jobRepository.getPages(job.id)).map((page) => page.status),
      everyElement(OcrPageJobStatus.done),
    );
  });

  test('clearResults removes OCR text, job records and search hits', () async {
    final engine = _ControllableOcrEngine();
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );

    final job = await controller.start(book: book, pageNumbers: [1]);
    final done = await _waitForTask(
      taskRepository,
      job.taskId,
      PageSageTaskStatus.done,
    );
    expect(await pageStore.getPage(book.id, 1), isNotNull);
    expect(
      await searchRepository.search(const SearchQuery(query: '扫描识别文本')),
      isNotEmpty,
    );

    await controller.clearResults(done);

    expect(await pageStore.getPage(book.id, 1), isNull);
    expect(await jobRepository.getJob(job.id), isNull);
    expect(await jobRepository.getPages(job.id), isEmpty);
    expect(
      await searchRepository.search(const SearchQuery(query: '扫描识别文本')),
      isEmpty,
    );
    final cleared = (await taskRepository.getTasks()).single;
    expect(cleared.status, PageSageTaskStatus.cancelled);
    expect(cleared.message, contains('已清除 1 页'));

    final rerun = await controller.start(book: book, pageNumbers: [1]);
    await _waitForTask(taskRepository, rerun.taskId, PageSageTaskStatus.done);
    expect(engine.calls, 2);
  });

  test('runs OCR jobs through one FIFO worker', () async {
    final engine = _ControllableOcrEngine(holdFirst: true);
    final cancellationRegistry = TaskCancellationRegistry();
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
      cancellationRegistry: cancellationRegistry,
    );
    addTearDown(() {
      if (!engine.releaseFirst.isCompleted) {
        engine.releaseFirst.complete();
      }
    });

    final first = await controller.start(book: book, pageNumbers: [1]);
    await engine.firstStarted.future;
    final second = await controller.start(book: book, pageNumbers: [2]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final queued = (await taskRepository.getTasks()).firstWhere(
      (task) => task.id == second.taskId,
    );
    expect(queued.status, PageSageTaskStatus.queued);
    expect(cancellationRegistry.isLive(second.taskId), isTrue);
    expect(engine.calls, 1);
    expect(engine.maxActiveRecognitions, 1);

    engine.releaseFirst.complete();
    await _waitForTask(taskRepository, first.taskId, PageSageTaskStatus.done);
    await _waitForTask(taskRepository, second.taskId, PageSageTaskStatus.done);

    expect(engine.calls, 2);
    expect(engine.maxActiveRecognitions, 1);
  });

  test('pausing a queued OCR job prevents it from starting', () async {
    final engine = _ControllableOcrEngine(holdFirst: true);
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );
    addTearDown(() {
      if (!engine.releaseFirst.isCompleted) {
        engine.releaseFirst.complete();
      }
    });

    final first = await controller.start(book: book, pageNumbers: [1]);
    await engine.firstStarted.future;
    final second = await controller.start(book: book, pageNumbers: [2]);

    await controller.pause(second.taskId);
    final paused = await _waitForTask(
      taskRepository,
      second.taskId,
      PageSageTaskStatus.paused,
    );
    expect(
      (await jobRepository.getJob(second.id))?.status,
      OcrJobStatus.paused,
    );

    engine.releaseFirst.complete();
    await _waitForTask(taskRepository, first.taskId, PageSageTaskStatus.done);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(engine.calls, 1);
    expect(
      (await taskRepository.getTasks())
          .firstWhere((task) => task.id == second.taskId)
          .status,
      PageSageTaskStatus.paused,
    );

    await controller.resume(paused);
    await _waitForTask(taskRepository, second.taskId, PageSageTaskStatus.done);

    expect(engine.calls, 2);
    expect(engine.maxActiveRecognitions, 1);
  });

  test(
    'cancelling a queued OCR job removes it from the worker queue',
    () async {
      final engine = _ControllableOcrEngine(holdFirst: true);
      final controller = _controller(
        engine: engine,
        pageStore: pageStore,
        searchRepository: searchRepository,
        bookRepository: bookRepository,
        taskRepository: taskRepository,
        jobRepository: jobRepository,
      );
      addTearDown(() {
        if (!engine.releaseFirst.isCompleted) {
          engine.releaseFirst.complete();
        }
      });

      final first = await controller.start(book: book, pageNumbers: [1]);
      await engine.firstStarted.future;
      final second = await controller.start(book: book, pageNumbers: [2]);

      await controller.cancel(second.taskId);
      await _waitForTask(
        taskRepository,
        second.taskId,
        PageSageTaskStatus.cancelled,
      );

      engine.releaseFirst.complete();
      await _waitForTask(taskRepository, first.taskId, PageSageTaskStatus.done);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.calls, 1);
      expect(
        (await jobRepository.getJob(second.id))?.status,
        OcrJobStatus.cancelled,
      );
      expect(
        (await jobRepository.getPages(second.id)).single.status,
        OcrPageJobStatus.cancelled,
      );
    },
  );

  test('cancel marks every unfinished page as cancelled', () async {
    final engine = _ControllableOcrEngine(blockFirstUntilCancelled: true);
    final controller = _controller(
      engine: engine,
      pageStore: pageStore,
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      taskRepository: taskRepository,
      jobRepository: jobRepository,
    );

    final job = await controller.start(book: book, pageNumbers: [1, 2]);
    await engine.firstStarted.future;
    await controller.cancel(job.taskId);
    await _waitForTask(
      taskRepository,
      job.taskId,
      PageSageTaskStatus.cancelled,
    );

    expect(
      (await jobRepository.getJob(job.id))?.status,
      OcrJobStatus.cancelled,
    );
    expect(
      (await jobRepository.getPages(job.id)).map((page) => page.status),
      everyElement(OcrPageJobStatus.cancelled),
    );
  });
}

OcrJobController _controller({
  required OcrEngine engine,
  required OcrPageStore pageStore,
  required DriftSearchRepository searchRepository,
  required DriftBookRepository bookRepository,
  required DriftTaskRepository taskRepository,
  required DriftOcrJobRepository jobRepository,
  TaskCancellationRegistry? cancellationRegistry,
}) {
  return OcrJobController(
    taskRepository: taskRepository,
    jobRepository: jobRepository,
    bookRepository: bookRepository,
    useCase: OcrCurrentPageUseCase(
      rasterizer: _FakeRasterizer(),
      engine: engine,
      cache: OcrSessionCache(),
      store: pageStore,
    ),
    searchIndexer: SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      ocrSearchSource: StoredOcrSearchSource(pageStore),
    ),
    cancellationRegistry: cancellationRegistry ?? TaskCancellationRegistry(),
    nativeTextExtractor: const PdfTextExtractorService(),
  );
}

Future<PageSageTask> _waitForTask(
  DriftTaskRepository repository,
  String taskId,
  PageSageTaskStatus status,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final task = (await repository.getTasks())
        .where((item) => item.id == taskId)
        .firstOrNull;
    if (task?.status == status) {
      return task!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final tasks = await repository.getTasks();
  fail(
    'task $taskId did not reach ${status.value}; '
    'current=${tasks.where((task) => task.id == taskId).firstOrNull?.status}',
  );
}

final class _ControllableOcrEngine implements OcrEngine {
  _ControllableOcrEngine({
    this.blockFirstUntilCancelled = false,
    this.holdFirst = false,
    this.failFirst = false,
    this.text = '扫描识别文本',
  });

  final bool blockFirstUntilCancelled;
  final bool holdFirst;
  final bool failFirst;
  final String text;
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  var calls = 0;
  var activeRecognitions = 0;
  var maxActiveRecognitions = 0;

  @override
  String get id => 'fake-ocr-job';

  @override
  bool get supportsPdfPageOcr => false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<String>> supportedLanguages() async => const ['zh-Hans'];

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  }) async {
    activeRecognitions += 1;
    if (activeRecognitions > maxActiveRecognitions) {
      maxActiveRecognitions = activeRecognitions;
    }
    try {
      calls += 1;
      if (calls == 1 && failFirst) {
        throw const OcrFailedException('temporary failure');
      }
      if (calls == 1 && holdFirst) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      if (calls == 1 && blockFirstUntilCancelled) {
        firstStarted.complete();
        if (cancelled != null) {
          await cancelled;
        }
        throw const TaskCancelledException();
      }
      return OcrPageResult(
        text: text,
        language: languageHint,
        engine: id,
        blocks: text.isEmpty
            ? const []
            : const [
                OcrTextBlock(
                  text: '扫描识别文本',
                  left: 0.1,
                  top: 0.1,
                  width: 0.5,
                  height: 0.05,
                ),
              ],
        imageWidth: 1000,
        imageHeight: 1400,
      );
    } finally {
      activeRecognitions -= 1;
    }
  }

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) {
    throw UnsupportedError('native PDF OCR is not used by this fake');
  }
}

final class _FakeRasterizer implements PdfPageRasterizer {
  @override
  Future<PdfPageImage> renderPage({
    required String filePath,
    required int pageNumber,
    int dpi = PdfPageRasterizer.defaultDpi,
    int maxEdge = PdfPageRasterizer.defaultMaxEdge,
    int maxPixels = 5000000,
  }) async {
    return PdfPageImage(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      width: 1000,
      height: 1400,
      pageNumber: pageNumber,
      dpi: dpi,
    );
  }
}

Uint8List _buildEmptyPdf() {
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
  for (var index = 0; index < objects.length; index += 1) {
    offsets.add(buffer.length);
    buffer.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
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
