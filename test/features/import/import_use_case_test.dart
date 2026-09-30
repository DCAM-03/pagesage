import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_book_repository.dart';
import 'package:pagesage/core/database/drift_content_repositories.dart';
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
import 'package:pagesage/features/import/application/import_result.dart';
import 'package:pagesage/features/import/application/import_use_case.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../tool/generate_manual_samples.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pagesage_import_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('discoverBookPaths finds nested epub and pdf files', () async {
    final nested = Directory(p.join(tempDir.path, 'lib', 'sub'));
    await nested.create(recursive: true);
    await File(p.join(nested.path, 'a.epub')).writeAsString('epub');
    await File(p.join(nested.path, 'b.PDF')).writeAsString('%PDF-');
    await File(p.join(nested.path, 'c.txt')).writeAsString('nope');
    final paths = await ImportUseCase.discoverBookPaths(tempDir.path);
    expect(paths.map(p.basename).toSet(), {'a.epub', 'b.PDF'});
  });

  test('returns imported book before background indexing completes', () async {
    final source = File(p.join(tempDir.path, 'book.pdf'));
    await source.writeAsString('%PDF-');
    final bookRepository = _BlockingIndexBookRepository();
    final taskRepository = _MemoryTaskRepository();
    final useCase = ImportUseCase(
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
      taskRepository: taskRepository,
      taskCancellationRegistry: TaskCancellationRegistry(),
    );

    final result = await useCase
        .importPath(source.path)
        .timeout(const Duration(seconds: 1));

    expect(result, isA<ImportBookSuccess>());
    expect(taskRepository.tasks.single.status, PageSageTaskStatus.indexing);
    expect(taskRepository.tasks.single.bookId, isNotNull);
    expect(
      await File(taskRepository.tasks.single.targetPath!).exists(),
      isTrue,
    );
    await bookRepository.backgroundIndexStarted.future.timeout(
      const Duration(seconds: 1),
    );
  });

  test(
    'imports generated EPUB and PDF samples and restores saved progress after database reopen',
    () async {
      await generateManualSamples(outputPath: p.join(tempDir.path, 'samples'));
      final databaseFile = File(p.join(tempDir.path, 'pagesage.sqlite'));

      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      addTearDown(firstDatabase.close);
      final firstHarness = _RealImportHarness(firstDatabase);

      final epubSource = File(p.join(tempDir.path, 'samples', 'standard.epub'));
      final pdfSource = File(
        p.join(tempDir.path, 'samples', 'standard-text.pdf'),
      );
      final epubResult = await firstHarness.useCase.importPath(
        epubSource.path,
        taskId: 'import-epub',
      );
      final pdfResult = await firstHarness.useCase.importPath(
        pdfSource.path,
        taskId: 'import-pdf',
      );

      expect(epubResult, isA<ImportBookSuccess>());
      expect(pdfResult, isA<ImportBookSuccess>());

      final epubBook = (epubResult as ImportBookSuccess).book;
      final pdfBook = (pdfResult as ImportBookSuccess).book;
      expect(epubBook.format, BookFormat.epub);
      expect(pdfBook.format, BookFormat.pdf);
      expect(epubBook.originalFilePath, epubSource.path);
      expect(pdfBook.originalFilePath, pdfSource.path);
      expect(await epubSource.exists(), isTrue);
      expect(await pdfSource.exists(), isTrue);
      expect(await File(epubBook.libraryFilePath).exists(), isTrue);
      expect(await File(pdfBook.libraryFilePath).exists(), isTrue);
      expect(epubBook.libraryFilePath, isNot(epubSource.path));
      expect(pdfBook.libraryFilePath, isNot(pdfSource.path));
      expect(
        p.isWithin(
          p.join(tempDir.path, 'PageSageData', 'library'),
          epubBook.libraryFilePath,
        ),
        isTrue,
      );
      expect(
        p.isWithin(
          p.join(tempDir.path, 'PageSageData', 'library'),
          pdfBook.libraryFilePath,
        ),
        isTrue,
      );

      await _waitForTaskDone(firstHarness.taskRepository, 'import-epub');
      await _waitForTaskDone(firstHarness.taskRepository, 'import-pdf');

      final epubLocator = ReadingLocator.epub(
        href: 'chapter2.xhtml',
        chapterIndex: 1,
        chapterOffset: 24,
        chapterEndOffset: 96,
        progress: 0.62,
        excerpt: '关闭应用后重新打开',
      );
      final pdfLocator = ReadingLocator.pdf(
        page: 3,
        scrollOffset: 420,
        zoom: 1.35,
        progress: 0.86,
        excerpt: 'restore progress here',
      );
      await firstHarness.bookRepository.saveProgress(
        bookId: epubBook.id,
        locator: epubLocator,
        progress: 0.62,
        chapterTitle: '第二章 阅读循环',
      );
      await firstHarness.bookRepository.saveProgress(
        bookId: pdfBook.id,
        locator: pdfLocator,
        progress: 0.86,
        pageNumber: 3,
      );
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      addTearDown(reopenedDatabase.close);
      final reopenedRepository = DriftBookRepository(
        bookDao: reopenedDatabase.bookDao,
        progressDao: reopenedDatabase.progressDao,
      );

      final reopenedEpub = await reopenedRepository.getBook(epubBook.id);
      final reopenedPdf = await reopenedRepository.getBook(pdfBook.id);
      final reopenedEpubProgress = await reopenedRepository.getProgress(
        epubBook.id,
      );
      final reopenedPdfProgress = await reopenedRepository.getProgress(
        pdfBook.id,
      );

      expect(reopenedEpub?.libraryFilePath, epubBook.libraryFilePath);
      expect(reopenedPdf?.libraryFilePath, pdfBook.libraryFilePath);
      expect(reopenedEpubProgress?.locator.matches(epubLocator), isTrue);
      expect(reopenedEpubProgress?.progress, 0.62);
      expect(reopenedEpubProgress?.chapterTitle, '第二章 阅读循环');
      expect(reopenedPdfProgress?.locator.matches(pdfLocator), isTrue);
      expect(reopenedPdfProgress?.progress, 0.86);
      expect(reopenedPdfProgress?.pageNumber, 3);
    },
  );
}

final class _RealImportHarness {
  _RealImportHarness(this.database)
    : bookRepository = DriftBookRepository(
        bookDao: database.bookDao,
        progressDao: database.progressDao,
        bookmarkDao: database.bookmarkDao,
        annotationDao: database.annotationDao,
        noteDao: database.noteDao,
        aiConversationDao: database.aiConversationDao,
        searchDao: database.searchDao,
      ),
      searchRepository = DriftSearchRepository(database.searchDao),
      taskRepository = DriftTaskRepository(database.taskDao) {
    useCase = ImportUseCase(
      filePickerService: FilePickerService(),
      formatDetector: FormatDetector(),
      hashService: HashService(),
      metadataExtractor: MetadataExtractor(appPaths: AppPaths()),
      appPaths: AppPaths(),
      bookRepository: bookRepository,
      searchIndexer: SearchIndexer(
        searchRepository: searchRepository,
        bookRepository: bookRepository,
      ),
      taskRepository: taskRepository,
      taskCancellationRegistry: TaskCancellationRegistry(),
    );
  }

  final AppDatabase database;
  final DriftBookRepository bookRepository;
  final DriftSearchRepository searchRepository;
  final DriftTaskRepository taskRepository;
  late final ImportUseCase useCase;
}

Future<void> _waitForTaskDone(
  TaskRepository taskRepository,
  String taskId,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final tasks = await taskRepository.getTasks();
    final task = tasks.where((candidate) => candidate.id == taskId).first;
    if (task.status == PageSageTaskStatus.done) {
      return;
    }
    if (task.status == PageSageTaskStatus.failed ||
        task.status == PageSageTaskStatus.cancelled) {
      fail('Task $taskId ended with ${task.status.value}: ${task.error}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for task $taskId to finish.');
}

final class _BlockingIndexBookRepository implements BookRepository {
  final Completer<void> backgroundIndexStarted = Completer<void>();
  final Completer<void> _neverComplete = Completer<void>();
  Book? _book;

  @override
  Future<Book> createImportedBook(NewBookDraft draft) async {
    final book = Book(
      id: draft.id,
      title: draft.title,
      originalTitle: draft.originalTitle,
      author: draft.author,
      format: draft.format,
      originalFormat: draft.format.value,
      originalFilePath: draft.originalFilePath,
      libraryFilePath: draft.libraryFilePath,
      coverPath: draft.coverPath,
      fileHash: draft.fileHash,
      fileSize: draft.fileSize,
      language: draft.language,
      description: draft.description,
      createdAt: draft.createdAt,
      updatedAt: draft.createdAt,
    );
    _book = book;
    return book;
  }

  @override
  Future<void> updateIndexingStatus(String bookId, String indexingStatus) {
    if (!backgroundIndexStarted.isCompleted) {
      backgroundIndexStarted.complete();
    }
    return _neverComplete.future;
  }

  @override
  Future<Book?> findByHash(String fileHash) async => null;

  @override
  Future<Book?> getBook(String id) async => _book?.id == id ? _book : null;

  @override
  Future<List<LibraryBook>> getLibrary() async => const [];

  @override
  Stream<List<LibraryBook>> watchLibrary() => const Stream.empty();

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

final class _MemoryTaskRepository implements TaskRepository {
  final List<PageSageTask> tasks = [];

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
      id: id ?? 'task-${tasks.length + 1}',
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
    tasks.add(task);
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
    final index = tasks.indexWhere((task) => task.id == id);
    final previous = tasks[index];
    tasks[index] = PageSageTask(
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
  Future<void> clearCompleted() async {}

  @override
  Future<List<PageSageTask>> getTasks() async => tasks;

  @override
  Stream<List<PageSageTask>> watchTasks() => Stream.value(tasks);
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

final class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}
