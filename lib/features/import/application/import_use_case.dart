import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/files/app_paths.dart';
import '../../../core/files/format_detector.dart';
import '../../../core/files/hash_service.dart';
import '../../../core/files/metadata_extractor.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/search/search_indexer.dart';
import '../../../core/tasks/task_cancellation.dart';
import '../../../core/tasks/task_models.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/book_repository.dart';
import 'import_result.dart';

final class ImportUseCase {
  ImportUseCase({
    required FilePickerService filePickerService,
    required FormatDetector formatDetector,
    required HashService hashService,
    required MetadataExtractor metadataExtractor,
    required AppPaths appPaths,
    required BookRepository bookRepository,
    required SearchIndexer searchIndexer,
    required TaskRepository taskRepository,
    required TaskCancellationRegistry taskCancellationRegistry,
  }) : this._(
         filePickerService,
         formatDetector,
         hashService,
         metadataExtractor,
         appPaths,
         bookRepository,
         searchIndexer,
         taskRepository,
         taskCancellationRegistry,
       );

  const ImportUseCase._(
    this._filePickerService,
    this._formatDetector,
    this._hashService,
    this._metadataExtractor,
    this._appPaths,
    this._bookRepository,
    this._searchIndexer,
    this._taskRepository,
    this._taskCancellationRegistry,
  );

  final FilePickerService _filePickerService;
  final FormatDetector _formatDetector;
  final HashService _hashService;
  final MetadataExtractor _metadataExtractor;
  final AppPaths _appPaths;
  final BookRepository _bookRepository;
  final SearchIndexer _searchIndexer;
  final TaskRepository _taskRepository;
  final TaskCancellationRegistry _taskCancellationRegistry;

  Future<ImportBookResult> pickAndImport({bool allowDuplicate = false}) async {
    final pickedFile = await _filePickerService.pickBookFile();
    if (pickedFile == null) {
      return const ImportBookCancelled();
    }
    return importPath(pickedFile.path, allowDuplicate: allowDuplicate);
  }

  Future<ImportBooksResult> pickAndImportMany({
    bool allowDuplicate = false,
  }) async {
    final pickedFiles = await _filePickerService.pickBookFiles();
    if (pickedFiles.isEmpty) {
      return const ImportBooksResult(
        successes: [],
        duplicates: [],
        failures: [],
        cancelled: true,
      );
    }

    final successes = <Book>[];
    final duplicates = <ImportBookDuplicate>[];
    final failures = <ImportBookFailure>[];
    for (final file in pickedFiles) {
      final result = await importPath(
        file.path,
        allowDuplicate: allowDuplicate,
      );
      switch (result) {
        case ImportBookSuccess(:final book):
          successes.add(book);
        case ImportBookDuplicate():
          duplicates.add(result);
        case ImportBookFailure():
          failures.add(result);
        case ImportBookCancelled():
          break;
      }
    }
    return ImportBooksResult(
      successes: successes,
      duplicates: duplicates,
      failures: failures,
      cancelled: false,
    );
  }

  Future<ImportBooksResult> pickAndImportFolder({
    bool allowDuplicate = false,
  }) async {
    final folderPath = await _filePickerService.pickFolder();
    if (folderPath == null || folderPath.trim().isEmpty) {
      return const ImportBooksResult(
        successes: [],
        duplicates: [],
        failures: [],
        cancelled: true,
      );
    }
    return importFolder(folderPath, allowDuplicate: allowDuplicate);
  }

  Future<ImportBooksResult> importFolder(
    String folderPath, {
    bool allowDuplicate = false,
  }) async {
    final paths = await discoverBookPaths(folderPath);
    if (paths.isEmpty) {
      return const ImportBooksResult(
        successes: [],
        duplicates: [],
        failures: [],
        cancelled: false,
      );
    }

    final successes = <Book>[];
    final duplicates = <ImportBookDuplicate>[];
    final failures = <ImportBookFailure>[];
    for (final path in paths) {
      final result = await importPath(path, allowDuplicate: allowDuplicate);
      switch (result) {
        case ImportBookSuccess(:final book):
          successes.add(book);
        case ImportBookDuplicate():
          duplicates.add(result);
        case ImportBookFailure():
          failures.add(result);
        case ImportBookCancelled():
          break;
      }
    }
    return ImportBooksResult(
      successes: successes,
      duplicates: duplicates,
      failures: failures,
      cancelled: false,
    );
  }

  /// Recursively finds `.epub` / `.pdf` under [folderPath].
  static Future<List<String>> discoverBookPaths(String folderPath) async {
    final root = Directory(folderPath);
    if (!await root.exists()) {
      return const [];
    }
    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.epub' || ext == '.pdf') {
        paths.add(entity.path);
      }
    }
    paths.sort();
    return paths;
  }

  Future<ImportBookResult> importPath(
    String sourcePath, {
    bool allowDuplicate = false,
    String? taskId,
  }) async {
    File? copiedFile;
    PageSageTask? task;
    TaskCancelToken? cancelToken;

    try {
      task = await _taskRepository.saveTask(
        id: taskId,
        type: PageSageTaskType.importBook,
        status: PageSageTaskStatus.running,
        sourcePath: sourcePath,
        progress: 0.05,
        message: '正在导入',
      );
      cancelToken = _taskCancellationRegistry.register(task.id);
      cancelToken.throwIfCancelled();
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        await _failTask(task, '文件不可访问');
        return const ImportBookFailure('文件不可访问');
      }

      final format = await _formatDetector.detect(sourceFile);
      cancelToken.throwIfCancelled();
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.running,
        progress: 0.2,
        message: '正在计算文件指纹',
      );
      final fileHash = await _hashService.sha256File(
        sourceFile,
        cancelToken: cancelToken,
      );
      cancelToken.throwIfCancelled();
      final existingBook = await _bookRepository.findByHash(fileHash);
      if (existingBook != null && !allowDuplicate) {
        await _taskRepository.updateStatus(
          id: task.id,
          status: PageSageTaskStatus.cancelled,
          progress: 1,
          message: '发现重复文件',
        );
        _taskCancellationRegistry.complete(task.id);
        return ImportBookDuplicate(
          existingBook: existingBook,
          sourcePath: sourcePath,
        );
      }

      final bookId = const Uuid().v4();
      final libraryPath = await _appPaths.libraryBookPath(
        bookId: bookId,
        fileHash: fileHash,
        format: format,
      );
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.running,
        progress: 0.55,
        targetPath: libraryPath,
        message: '正在复制到书库',
      );
      copiedFile = await _copyWithCancellation(
        sourceFile,
        File(libraryPath),
        cancelToken,
      );
      final sourceLength = await sourceFile.length();
      final copiedLength = await copiedFile.length();
      if (copiedLength != sourceLength) {
        throw const FileSystemException('复制后的文件大小不一致');
      }

      final metadata = await _metadataExtractor.extract(
        file: copiedFile,
        format: format,
        bookId: bookId,
        cancelToken: cancelToken,
      );
      cancelToken.throwIfCancelled();

      final now = DateTime.now().millisecondsSinceEpoch;
      final fallbackTitle = p.basenameWithoutExtension(sourcePath).trim();
      final title = metadata.title?.trim().isNotEmpty == true
          ? metadata.title!.trim()
          : fallbackTitle;
      final draft = NewBookDraft(
        id: bookId,
        title: title.isEmpty ? '未命名书籍' : title,
        originalTitle: title.isEmpty ? null : title,
        format: format,
        originalFilePath: sourcePath,
        libraryFilePath: copiedFile.path,
        author: metadata.author,
        language: metadata.language,
        description: metadata.description,
        coverPath: metadata.coverPath,
        fileHash: fileHash,
        fileSize: sourceLength,
        createdAt: now,
      );

      final book = await _bookRepository.createImportedBook(draft);
      cancelToken.throwIfCancelled();
      await _taskRepository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.indexing,
        progress: 0.82,
        bookId: book.id,
        targetPath: book.libraryFilePath,
        message: '正在建立索引',
      );
      unawaited(
        _completeImportIndexing(
          taskId: task.id,
          book: book,
          cancelToken: cancelToken,
        ),
      );
      return ImportBookSuccess(book);
    } on TaskCancelledException {
      if (copiedFile != null && await copiedFile.exists()) {
        await copiedFile.delete();
      }
      await _cancelTask(task);
      return const ImportBookCancelled();
    } on UnsupportedBookFormatException {
      await _failTask(task, '当前版本仅支持 EPUB 和 PDF 文件');
      return const ImportBookFailure('当前版本仅支持 EPUB 和 PDF 文件');
    } on FileSystemException catch (error) {
      if (copiedFile != null && await copiedFile.exists()) {
        await copiedFile.delete();
      }
      await _failTask(task, '导入失败，请检查文件权限或磁盘空间', error);
      return ImportBookFailure('导入失败，请检查文件权限或磁盘空间', details: error);
    } catch (error) {
      if (copiedFile != null && await copiedFile.exists()) {
        await copiedFile.delete();
      }
      await _failTask(task, '导入失败', error);
      return ImportBookFailure('导入失败', details: error);
    }
  }

  Future<void> _failTask(
    PageSageTask? task,
    String message, [
    Object? error,
  ]) async {
    if (task == null) {
      return;
    }
    await _taskRepository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.failed,
      progress: 1,
      message: message,
      error: error?.toString(),
    );
    _taskCancellationRegistry.complete(task.id);
  }

  Future<void> _cancelTask(PageSageTask? task) async {
    if (task == null) {
      return;
    }
    await _taskRepository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.cancelled,
      progress: task.progress,
      message: '已取消',
    );
    _taskCancellationRegistry.complete(task.id);
  }

  Future<File> _copyWithCancellation(
    File source,
    File target,
    TaskCancelToken cancelToken,
  ) async {
    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    try {
      await for (final chunk in source.openRead()) {
        cancelToken.throwIfCancelled();
        sink.add(chunk);
      }
      cancelToken.throwIfCancelled();
      await sink.flush();
      await sink.close();
      return target;
    } on Object {
      await sink.close();
      if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    }
  }

  Future<void> _completeImportIndexing({
    required String taskId,
    required Book book,
    required TaskCancelToken cancelToken,
  }) async {
    var doneMessage = '导入完成';
    String? errorMessage;
    try {
      await _searchIndexer.indexBook(book, cancelToken: cancelToken);
    } on TaskCancelledException {
      await _taskRepository.updateStatus(
        id: taskId,
        status: PageSageTaskStatus.cancelled,
        progress: 0.82,
        bookId: book.id,
        targetPath: book.libraryFilePath,
        message: '已取消索引',
      );
      _taskCancellationRegistry.complete(taskId);
      return;
    } on Object catch (error) {
      doneMessage = '导入完成，索引失败，可稍后重建';
      errorMessage = error.toString();
    }
    if (cancelToken.isCancelled) {
      await _taskRepository.updateStatus(
        id: taskId,
        status: PageSageTaskStatus.cancelled,
        progress: 0.82,
        bookId: book.id,
        targetPath: book.libraryFilePath,
        message: '已取消索引',
      );
      _taskCancellationRegistry.complete(taskId);
      return;
    }
    await _taskRepository.updateStatus(
      id: taskId,
      status: PageSageTaskStatus.done,
      progress: 1,
      bookId: book.id,
      targetPath: book.libraryFilePath,
      message: doneMessage,
      error: errorMessage,
    );
    _taskCancellationRegistry.complete(taskId);
  }
}
