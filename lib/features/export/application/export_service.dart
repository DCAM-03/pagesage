import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/files/app_paths.dart';
import '../../../core/files/image_cache_store.dart';
import '../../../core/tasks/task_cancellation.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/annotations/image_anchor.dart';
import '../../../domain/books/bookmark.dart';
import '../../../domain/books/book_repository.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import 'restore_database_preparation.dart';

final class RestoreBackupResult {
  const RestoreBackupResult({
    required this.databasePath,
    required this.rollbackPath,
  });

  final String databasePath;
  final String rollbackPath;
}

/// What an image-annotation export produced.
///
/// The Markdown file and the picture folder are two things on disk, so the
/// result names both: the caller has to be able to say where the pictures
/// went, otherwise a reader who moved the Markdown loses them silently.
final class ImageAnnotationExportResult {
  const ImageAnnotationExportResult({
    required this.markdownFile,
    required this.imageDirectory,
    required this.imageCount,
    required this.missingCount,
  });

  /// The Markdown file that references the pictures.
  final File markdownFile;

  /// The folder holding the copied pictures.
  final Directory imageDirectory;

  /// How many pictures were written.
  final int imageCount;

  /// How many image annotations had no cached picture to copy.
  ///
  /// Non-zero means the export is incomplete, and the caller should say so
  /// rather than let the reader believe every picture made it.
  final int missingCount;
}

final class _NotebookExportEntry {
  const _NotebookExportEntry({
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.bookId,
    this.locator,
  });

  final String type;
  final String title;
  final String body;
  final String? bookId;
  final ReadingLocator? locator;
  final int timestamp;
}

final class _ImageExportSection {
  const _ImageExportSection({
    required this.annotation,
    required this.bookTitle,
    this.imagePath,
  });

  final Annotation annotation;
  final String bookTitle;

  /// Path of the picture relative to the Markdown file, or null when the
  /// picture was never cached.
  final String? imagePath;
}

final class ExportService {
  const ExportService({
    required AppPaths appPaths,
    required NoteRepository noteRepository,
    required BookmarkRepository bookmarkRepository,
    required AnnotationRepository annotationRepository,
    required AiConversationRepository aiConversationRepository,
    required AppDatabase database,
    required CachedImageStore imageCacheStore,
    required BookRepository bookRepository,
  }) : this._(
         appPaths,
         noteRepository,
         bookmarkRepository,
         annotationRepository,
         aiConversationRepository,
         database,
         imageCacheStore,
         bookRepository,
       );

  const ExportService._(
    this._appPaths,
    this._noteRepository,
    this._bookmarkRepository,
    this._annotationRepository,
    this._aiConversationRepository,
    this._database,
    this._imageCacheStore,
    this._bookRepository,
  );

  final AppPaths _appPaths;
  final NoteRepository _noteRepository;
  final BookmarkRepository _bookmarkRepository;
  final AnnotationRepository _annotationRepository;
  final AiConversationRepository _aiConversationRepository;
  final AppDatabase _database;

  /// Where the cut-out pictures live.
  final CachedImageStore _imageCacheStore;

  /// Needed to put a book title on each exported picture.
  final BookRepository _bookRepository;

  Future<File> exportAllNotesMarkdown({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    final notes = await _noteRepository.getNotes();
    cancelToken?.throwIfCancelled();
    final file = await _targetFile(
      targetPath,
      prefix: 'pagesage-notes',
      extension: 'md',
    );
    return _writeTextAtomically(
      file,
      _renderNotes(notes),
      cancelToken: cancelToken,
    );
  }

  Future<File> exportBookmarksCsv({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    final bookmarks = await _bookmarkRepository.getAll();
    cancelToken?.throwIfCancelled();
    final file = await _targetFile(
      targetPath,
      prefix: 'pagesage-bookmarks',
      extension: 'csv',
    );
    return _writeTextAtomically(
      file,
      _renderBookmarksCsv(bookmarks),
      cancelToken: cancelToken,
    );
  }

  Future<File> exportAnnotationsJson({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    final annotations = await _annotationRepository.getAll();
    cancelToken?.throwIfCancelled();
    final file = await _targetFile(
      targetPath,
      prefix: 'pagesage-annotations',
      extension: 'json',
    );
    return _writeTextAtomically(
      file,
      _renderAnnotationsJson(annotations),
      cancelToken: cancelToken,
    );
  }

  Future<File> exportNotebookMarkdown({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    final notes = await _noteRepository.getNotes();
    cancelToken?.throwIfCancelled();
    final bookmarks = await _bookmarkRepository.getAll();
    cancelToken?.throwIfCancelled();
    final annotations = await _annotationRepository.getAll();
    cancelToken?.throwIfCancelled();
    final conversations = await _aiConversationRepository.getConversations();
    cancelToken?.throwIfCancelled();
    final file = await _targetFile(
      targetPath,
      prefix: 'pagesage-notebook',
      extension: 'md',
    );
    return _writeTextAtomically(
      file,
      _renderNotebookMarkdown(notes, bookmarks, annotations, conversations),
      cancelToken: cancelToken,
    );
  }

  Future<File> exportAiConversationsMarkdown({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    final conversations = await _aiConversationRepository.getConversations();
    cancelToken?.throwIfCancelled();
    final file = await _targetFile(
      targetPath,
      prefix: 'pagesage-ai',
      extension: 'md',
    );
    return _writeTextAtomically(
      file,
      _renderAiConversations(conversations),
      cancelToken: cancelToken,
    );
  }

  /// Export the image annotations as a Markdown file plus a folder of pictures.
  ///
  /// The pictures come from the app's cache: they were cut out of the pages
  /// when the reader marked them, and they are copied next to the Markdown so
  /// the export is a self-contained folder that any editor can open.
  ///
  /// An image annotation whose picture was never cached is still listed in the
  /// Markdown, with its comment and its place in the book, but without a
  /// picture. Dropping the entry instead would lose the comment, which is the
  /// part the reader actually wrote.
  Future<ImageAnnotationExportResult> exportImageAnnotations({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final annotations = await _annotationRepository.getAll();
    cancelToken?.throwIfCancelled();
    final imageAnnotations = annotations
        .where(
          (annotation) =>
              annotation.target == AnnotationTarget.image &&
              annotation.imageAnchor != null,
        )
        .toList();

    final file = await _targetFile(
      targetPath,
      prefix: 'pagesage-images',
      extension: 'md',
    );
    final imageDirectory = Directory(
      p.join(
        p.dirname(file.path),
        '${p.basenameWithoutExtension(file.path)}_images_${const Uuid().v4()}',
      ),
    );

    final bookIds = <String>{
      for (final annotation in imageAnnotations) annotation.bookId,
    };
    final titles = <String, String>{};
    for (final bookId in bookIds) {
      cancelToken?.throwIfCancelled();
      final book = await _bookRepository.getBook(bookId);
      titles[bookId] = book?.title ?? '未知书籍';
    }

    var imageCount = 0;
    var missingCount = 0;
    final sections = <_ImageExportSection>[];
    var published = false;
    try {
      for (final annotation in imageAnnotations) {
        cancelToken?.throwIfCancelled();
        final anchor = annotation.imageAnchor!;
        final cached = await _imageCacheStore.get(
          bookId: annotation.bookId,
          anchor: anchor,
        );
        String? relativePath;
        if (cached == null) {
          missingCount++;
        } else {
          await imageDirectory.create(recursive: true);
          final name =
              '${const Uuid().v5(Namespace.url.value, annotation.bookId)}_'
              '${CachedImageStore.fileNameFor(anchor)}.png';
          final destination = File(p.join(imageDirectory.path, name));
          await destination.writeAsBytes(
            await cached.readAsBytes(),
            flush: true,
          );
          relativePath = p.posix.join(p.basename(imageDirectory.path), name);
          imageCount++;
        }
        sections.add(
          _ImageExportSection(
            annotation: annotation,
            bookTitle: titles[annotation.bookId] ?? '未知书籍',
            imagePath: relativePath,
          ),
        );
      }

      cancelToken?.throwIfCancelled();
      final markdown = _renderImageAnnotations(sections);
      await _writeTextAtomically(file, markdown, cancelToken: cancelToken);
      published = true;
      return ImageAnnotationExportResult(
        markdownFile: file,
        imageDirectory: imageDirectory,
        imageCount: imageCount,
        missingCount: missingCount,
      );
    } finally {
      if (!published && await imageDirectory.exists()) {
        await imageDirectory.delete(recursive: true);
      }
    }
  }

  Future<File> packageImageAnnotations(
    ImageAnnotationExportResult result, {
    TaskCancelToken? cancelToken,
  }) async {
    final file = File('${result.markdownFile.path}.zip');
    final temporary = File('${file.path}.${const Uuid().v4()}.part');
    final encoder = ZipFileEncoder();
    try {
      cancelToken?.throwIfCancelled();
      encoder.create(temporary.path);
      try {
        await encoder.addFile(
          result.markdownFile,
          p.basename(result.markdownFile.path),
        );
        if (await result.imageDirectory.exists()) {
          await for (final entity in result.imageDirectory.list(
            followLinks: false,
          )) {
            cancelToken?.throwIfCancelled();
            if (entity is File) {
              await encoder.addFile(
                entity,
                p.posix.join(
                  p.basename(result.imageDirectory.path),
                  p.basename(entity.path),
                ),
              );
            }
          }
        }
      } finally {
        await encoder.close();
      }
      cancelToken?.throwIfCancelled();
      return await temporary.rename(file.path);
    } on Object {
      await _deleteIfExists(temporary);
      rethrow;
    }
  }

  Future<File> backupDatabaseZip({
    String? targetPath,
    TaskCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final database = await _appPaths.databaseFile();
    final date = DateTime.now();
    final zipFile = await _targetFile(
      targetPath,
      prefix: 'pagesage-backup',
      extension: 'zip',
    );
    await zipFile.parent.create(recursive: true);
    final tempFile = File('${zipFile.path}.${const Uuid().v4()}.part');
    final snapshot = File('${tempFile.path}.sqlite');
    final encoder = ZipFileEncoder();
    try {
      final sourcePath = database.path;
      final snapshotPath = snapshot.path;
      await Isolate.run(() {
        final source = sqlite.sqlite3.open(
          sourcePath,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          source.execute('PRAGMA busy_timeout = 5000');
          source.execute('VACUUM INTO ?', [snapshotPath]);
        } finally {
          source.close();
        }
      });
      cancelToken?.throwIfCancelled();
      encoder.create(tempFile.path);
      final covers = await _appPaths.coversDirectory();
      cancelToken?.throwIfCancelled();
      encoder.addArchiveFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'app': 'PageSage',
            'version': 1,
            'createdAt': date.toIso8601String(),
            'contents': ['database/pagesage.sqlite', 'covers/'],
          }),
        ),
      );
      cancelToken?.throwIfCancelled();
      await encoder.addFile(snapshot, 'database/pagesage.sqlite');
      cancelToken?.throwIfCancelled();
      if (await covers.exists()) {
        await encoder.addDirectory(covers, includeDirName: true, level: 6);
      }
      cancelToken?.throwIfCancelled();
      await encoder.close();
      cancelToken?.throwIfCancelled();
      await tempFile.rename(zipFile.path);
      return zipFile;
    } on Object {
      try {
        await encoder.close();
      } on Object {
        // The archive may already be closed or not fully initialized.
      }
      await _deleteIfExists(tempFile);
      rethrow;
    } finally {
      await _deleteIfExists(snapshot);
    }
  }

  Future<RestoreBackupResult> restoreDatabaseBackup(
    File zipFile, {
    TaskCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    if (!await zipFile.exists()) {
      throw const FileSystemException('备份文件不存在');
    }

    final archive = ZipDecoder().decodeBytes(
      await zipFile.readAsBytes(),
      verify: true,
    );
    cancelToken?.throwIfCancelled();
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const FormatException('备份中缺少 manifest.json');
    }
    final manifest = jsonDecode(utf8.decode(manifestEntry.content));
    if (manifest is! Map<String, dynamic> ||
        manifest['app'] != 'PageSage' ||
        manifest['version'] != 1 ||
        manifest['contents'] is! List ||
        !(manifest['contents'] as List).contains('database/pagesage.sqlite')) {
      throw const FormatException('备份清单无效或版本不受支持');
    }
    final databaseEntry = archive.findFile('database/pagesage.sqlite');
    if (databaseEntry == null || !databaseEntry.isFile) {
      throw const FormatException('备份中缺少 database/pagesage.sqlite');
    }

    final databaseBytes = databaseEntry.content;
    if (!_looksLikeSqlite(databaseBytes)) {
      throw const FormatException('备份数据库文件格式无效');
    }
    cancelToken?.throwIfCancelled();

    final database = await _appPaths.databaseFile();
    await database.parent.create(recursive: true);
    final stagedDatabase = File(
      p.join(
        database.parent.path,
        '.${p.basename(database.path)}.${DateTime.now().microsecondsSinceEpoch}.restore',
      ),
    );
    final stagedCovers = Directory('${stagedDatabase.path}.covers');
    final covers = await _appPaths.coversDirectory();
    try {
      await stagedDatabase.writeAsBytes(databaseBytes, flush: true);
      await _validateBackupDatabase(stagedDatabase);
      await stagedCovers.create();
      for (final entry in archive.files) {
        if (!entry.isFile || !entry.name.startsWith('covers/')) continue;
        final name = entry.name.substring('covers/'.length);
        if (name.isEmpty ||
            name.contains('\\') ||
            p.posix.isAbsolute(name) ||
            name.split('/').contains('..') ||
            entry.isSymbolicLink) {
          throw const FormatException('备份封面路径无效');
        }
        final destination = File(p.join(stagedCovers.path, name));
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(entry.content, flush: true);
      }
      cancelToken?.throwIfCancelled();
    } on Object {
      await _deleteIfExists(stagedDatabase);
      if (await stagedCovers.exists()) {
        await stagedCovers.delete(recursive: true);
      }
      rethrow;
    }

    var stagedInstalled = false;
    try {
      cancelToken?.throwIfCancelled();
      await _database.close();
      final rollback = await _rollbackFileFor(database);
      final rollbackCovers = Directory('${rollback.path}.covers');
      if (await database.exists()) {
        await database.copy(rollback.path);
      } else {
        await rollback.writeAsBytes(const []);
      }

      var coversMoved = false;
      var coversInstalled = false;
      try {
        await covers.rename(rollbackCovers.path);
        coversMoved = true;
        await stagedCovers.rename(covers.path);
        coversInstalled = true;
        await _deleteIfExists(File('${database.path}-wal'));
        await _deleteIfExists(File('${database.path}-shm'));
        await stagedDatabase.rename(database.path);
        stagedInstalled = true;
      } on Object {
        if (coversInstalled) await covers.delete(recursive: true);
        if (coversMoved) await rollbackCovers.rename(covers.path);
        if (await rollback.exists()) {
          await rollback.copy(database.path);
        }
        rethrow;
      }

      return RestoreBackupResult(
        databasePath: database.path,
        rollbackPath: rollback.path,
      );
    } finally {
      if (!stagedInstalled) {
        await _deleteIfExists(stagedDatabase);
        if (await stagedCovers.exists()) {
          await stagedCovers.delete(recursive: true);
        }
      }
    }
  }

  String _renderImageAnnotations(List<_ImageExportSection> sections) {
    final buffer = StringBuffer()
      ..writeln('# PageSage 图片批注导出')
      ..writeln()
      ..writeln('导出时间：${DateTime.now().toIso8601String()}')
      ..writeln();

    if (sections.isEmpty) {
      buffer.writeln('暂无图片批注。');
      return buffer.toString();
    }

    for (final section in sections) {
      final annotation = section.annotation;
      final anchor = annotation.imageAnchor!;
      final page = anchor is PdfImageAnchor ? anchor.page : null;
      buffer
        ..writeln('## ${section.bookTitle}')
        ..writeln()
        ..writeln(
          '- 位置：${page != null ? '第 $page 页' : annotation.locator.displayLabel}',
        )
        ..writeln('- 颜色：${annotation.color.value}');
      final caption = annotation.selectedText.trim();
      buffer.writeln('- 图注：${caption.isEmpty ? '未标注' : caption}');
      final comment = annotation.noteId;
      if (comment != null) {
        buffer.writeln('- 关联笔记 ID：`$comment`');
      }
      buffer.writeln();
      if (section.imagePath != null) {
        buffer
          ..writeln(
            '![${_escapeHeading(caption.isEmpty ? '图片' : caption)}](${section.imagePath})',
          )
          ..writeln();
      } else {
        // The picture is not in the cache — it was never cut out, or the cache
        // was cleared. Saying so beats an empty image box in the reader's
        // exported document.
        buffer
          ..writeln('> 图片未缓存，未能导出。')
          ..writeln();
      }
    }
    return buffer.toString();
  }

  String _renderNotes(List<Note> notes) {
    final buffer = StringBuffer()
      ..writeln('# PageSage 笔记导出')
      ..writeln()
      ..writeln('导出时间：${DateTime.now().toIso8601String()}')
      ..writeln();

    if (notes.isEmpty) {
      buffer.writeln('暂无笔记。');
      return buffer.toString();
    }

    for (final note in notes) {
      buffer
        ..writeln('## ${_escapeHeading(note.title ?? '无标题笔记')}')
        ..writeln()
        ..writeln('- 类型：${note.noteType.value}')
        ..writeln(
          '- 创建时间：${DateTime.fromMillisecondsSinceEpoch(note.createdAt).toIso8601String()}',
        )
        ..writeln(
          '- 更新时间：${DateTime.fromMillisecondsSinceEpoch(note.updatedAt).toIso8601String()}',
        );
      if (note.bookId != null) {
        buffer.writeln('- 书籍 ID：`${note.bookId}`');
      }
      if (note.locator != null) {
        buffer.writeln('- 位置：`${note.locator!.toJsonText()}`');
      }
      if (note.sourceText?.isNotEmpty == true) {
        buffer
          ..writeln()
          ..writeln('> ${note.sourceText!.replaceAll('\n', '\n> ')}');
      }
      buffer
        ..writeln()
        ..writeln(note.content)
        ..writeln();
    }
    return buffer.toString();
  }

  String _escapeHeading(String value) {
    return value.replaceAll('\n', ' ').trim();
  }

  String _renderBookmarksCsv(List<Bookmark> bookmarks) {
    final buffer = StringBuffer()
      ..writeln('book_id,location,title,note,excerpt,created_at');
    for (final bookmark in bookmarks) {
      buffer.writeln(
        [
          bookmark.bookId,
          bookmark.locator.toJsonText(),
          bookmark.title ?? '',
          bookmark.note ?? '',
          bookmark.excerpt ?? '',
          DateTime.fromMillisecondsSinceEpoch(
            bookmark.createdAt,
          ).toIso8601String(),
        ].map(_csv).join(','),
      );
    }
    return buffer.toString();
  }

  String _renderAnnotationsJson(List<Annotation> annotations) {
    final payload = {
      'app': 'PageSage',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'annotations': [
        for (final annotation in annotations)
          {
            'id': annotation.id,
            'bookId': annotation.bookId,
            'locator': annotation.locator.toJson(),
            'selectedText': annotation.selectedText,
            'color': annotation.color.value,
            'style': annotation.style.value,
            // Without the target and the anchor, an exported image annotation
            // is indistinguishable from a text one and cannot be drawn again.
            'target': annotation.target.value,
            if (annotation.imageAnchor != null)
              'imageAnchor': annotation.imageAnchor!.toJson(),
            if (annotation.noteId != null) 'noteId': annotation.noteId,
            'createdAt': DateTime.fromMillisecondsSinceEpoch(
              annotation.createdAt,
            ).toIso8601String(),
            'updatedAt': DateTime.fromMillisecondsSinceEpoch(
              annotation.updatedAt,
            ).toIso8601String(),
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _renderNotebookMarkdown(
    List<Note> notes,
    List<Bookmark> bookmarks,
    List<Annotation> annotations,
    List<AiConversation> conversations,
  ) {
    final entries = <_NotebookExportEntry>[
      for (final bookmark in bookmarks)
        _NotebookExportEntry(
          type: '书签',
          title: bookmark.title ?? bookmark.locator.displayLabel,
          body: bookmark.note ?? bookmark.excerpt ?? '',
          bookId: bookmark.bookId,
          locator: bookmark.locator,
          timestamp: bookmark.updatedAt,
        ),
      for (final annotation in annotations)
        _NotebookExportEntry(
          type: '标注',
          title: annotation.selectedText,
          body: '颜色：${annotation.color.value}；样式：${annotation.style.value}',
          bookId: annotation.bookId,
          locator: annotation.locator,
          timestamp: annotation.updatedAt,
        ),
      for (final note in notes)
        _NotebookExportEntry(
          type: '笔记',
          title: note.title ?? '无标题笔记',
          body: [
            if (note.sourceText?.isNotEmpty == true)
              '> ${note.sourceText!.replaceAll('\n', '\n> ')}',
            note.content,
          ].join('\n\n'),
          bookId: note.bookId,
          locator: note.locator,
          timestamp: note.updatedAt,
        ),
      for (final conversation in conversations)
        _NotebookExportEntry(
          type: 'AI',
          title: conversation.prompt,
          body: [
            if (conversation.sourceText?.isNotEmpty == true)
              '> ${conversation.sourceText!.replaceAll('\n', '\n> ')}',
            '回答状态：${_aiAnswerStatusLabel(conversation)}',
            conversation.answer,
            if (conversation.answerMeta != null)
              '回答核验：`${conversation.answerMeta!.toJsonText()}`',
            if (conversation.profileSnapshot != null)
              '请求配置快照：`${conversation.profileSnapshot!}`',
            if (conversation.contextSnapshot != null)
              _renderAiSources(conversation.contextSnapshot!),
          ].join('\n\n'),
          bookId: conversation.bookId,
          locator: conversation.locator,
          timestamp: conversation.createdAt,
        ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final buffer = StringBuffer()
      ..writeln('# PageSage Notebook 导出')
      ..writeln()
      ..writeln('导出时间：${DateTime.now().toIso8601String()}')
      ..writeln();
    if (entries.isEmpty) {
      buffer.writeln('暂无 Notebook 条目。');
      return buffer.toString();
    }
    for (final entry in entries) {
      buffer
        ..writeln('## ${_escapeHeading(entry.title)}')
        ..writeln()
        ..writeln('- 类型：${entry.type}')
        ..writeln(
          '- 更新时间：${DateTime.fromMillisecondsSinceEpoch(entry.timestamp).toIso8601String()}',
        );
      if (entry.bookId != null) {
        buffer.writeln('- 书籍 ID：`${entry.bookId}`');
      }
      if (entry.locator != null) {
        buffer.writeln('- 位置：`${entry.locator!.toJsonText()}`');
      }
      if (entry.body.trim().isNotEmpty) {
        buffer
          ..writeln()
          ..writeln(entry.body.trim());
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _renderAiSources(AiContextSnapshot snapshot) {
    return [
      '### 引用来源',
      '',
      for (final reference in snapshot.references)
        '- ${_escapeHeading(reference.label)}',
      '',
      '```json',
      snapshot.toJsonText(),
      '```',
    ].join('\n');
  }

  String _renderAiConversations(List<AiConversation> conversations) {
    final buffer = StringBuffer()
      ..writeln('# PageSage AI 问答导出')
      ..writeln()
      ..writeln('导出时间：${DateTime.now().toIso8601String()}')
      ..writeln();

    if (conversations.isEmpty) {
      buffer.writeln('暂无 AI 问答。');
      return buffer.toString();
    }

    for (final conversation in conversations) {
      buffer
        ..writeln('## ${_escapeHeading(conversation.prompt)}')
        ..writeln()
        ..writeln('- Provider：${conversation.provider}')
        ..writeln('- 模型：${conversation.model}')
        ..writeln('- 回答状态：${_aiAnswerStatusLabel(conversation)}')
        ..writeln(
          '- 创建时间：${DateTime.fromMillisecondsSinceEpoch(conversation.createdAt).toIso8601String()}',
        );
      if (conversation.bookId != null) {
        buffer.writeln('- 书籍 ID：`${conversation.bookId}`');
      }
      if (conversation.locator != null) {
        buffer.writeln('- 位置：`${conversation.locator!.toJsonText()}`');
      }
      if (conversation.contextSnapshot != null) {
        buffer.writeln(_renderAiSources(conversation.contextSnapshot!));
      }
      if (conversation.answerMeta != null) {
        buffer
          ..writeln()
          ..writeln('### 回答核验')
          ..writeln()
          ..writeln('```json');
        buffer.writeln(conversation.answerMeta!.toJsonText());
        buffer.writeln('```');
      }
      if (conversation.profileSnapshot != null) {
        buffer
          ..writeln()
          ..writeln('### 请求配置快照')
          ..writeln()
          ..writeln('```json');
        buffer.writeln(conversation.profileSnapshot!);
        buffer.writeln('```');
      }
      if (conversation.contextText?.isNotEmpty == true) {
        buffer
          ..writeln()
          ..writeln('### 上下文摘要')
          ..writeln()
          ..writeln(_truncate(conversation.contextText!, 1200));
      }
      if (conversation.sourceText?.isNotEmpty == true) {
        buffer
          ..writeln()
          ..writeln('### 原文')
          ..writeln()
          ..writeln('> ${conversation.sourceText!.replaceAll('\n', '\n> ')}');
      }
      buffer
        ..writeln()
        ..writeln('### 回答')
        ..writeln()
        ..writeln(conversation.answer)
        ..writeln();
    }

    return buffer.toString();
  }

  String _aiAnswerStatusLabel(AiConversation conversation) {
    final meta = conversation.answerMeta;
    if (meta == null) return '历史回答，未执行本次核验';
    return switch (meta.answerStatus) {
      'sourceLinked' => '已关联来源（未独立验证结论）',
      'insufficient' =>
        meta.producer == 'localPolicy' ? '本地检索反馈 · 证据不足，未调用模型' : '证据不足',
      'unverified' => '未核验引用',
      'interrupted' => '生成未完成',
      'failed' => '生成失败',
      _ => '历史回答，未执行本次核验',
    };
  }

  String _csv(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  Future<File> _targetFile(
    String? targetPath, {
    required String prefix,
    required String extension,
  }) async {
    if (targetPath != null && targetPath.trim().isNotEmpty) {
      return File(targetPath);
    }
    final dir = await _appPaths.exportsDirectory();
    final date = DateTime.now();
    return File(
      p.join(
        dir.path,
        '$prefix-${date.year}${_two(date.month)}${_two(date.day)}.$extension',
      ),
    );
  }

  Future<File> _writeTextAtomically(
    File file,
    String content, {
    TaskCancelToken? cancelToken,
  }) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.${const Uuid().v4()}.part');
    try {
      cancelToken?.throwIfCancelled();
      await tempFile.writeAsString(content, flush: true);
      cancelToken?.throwIfCancelled();
      return await tempFile.rename(file.path);
    } on Object {
      await _deleteIfExists(tempFile);
      rethrow;
    }
  }

  String _truncate(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength)}\n\n...（已截断）';
  }

  bool _looksLikeSqlite(Uint8List bytes) {
    const magic = 'SQLite format 3\u0000';
    return bytes.length >= magic.length &&
        ascii.decode(bytes.sublist(0, magic.length), allowInvalid: true) ==
            magic;
  }

  Future<void> _validateBackupDatabase(File file) async {
    late final sqlite.Database candidate;
    try {
      candidate = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
    } on sqlite.SqliteException {
      throw const FormatException('备份数据库无法打开');
    }
    try {
      final integrity = candidate.select('PRAGMA integrity_check');
      if (integrity.length != 1 || integrity.first.values.first != 'ok') {
        throw const FormatException('备份数据库完整性校验失败');
      }
      final version = candidate.userVersion;
      if (version < 1 || version > _database.schemaVersion) {
        throw const FormatException('备份数据库版本不受支持');
      }
      final tables = candidate
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      final requiredTables = <String>{
        'books',
        if (version >= 2) 'reading_progress',
        if (version >= 2) 'search_chunks',
        if (version >= 3) 'ocr_pages',
        if (version >= 12) 'ocr_jobs',
        if (version >= 12) 'ocr_job_pages',
      };
      if (!tables.containsAll(requiredTables)) {
        throw const FormatException('备份数据库缺少 PageSage 必需数据表');
      }
    } on sqlite.SqliteException {
      throw const FormatException('备份数据库完整性校验失败');
    } finally {
      candidate.close();
    }

    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await migrated.customSelect('SELECT COUNT(*) FROM books').get();
      await migrated.customSelect('SELECT COUNT(*) FROM search_chunks').get();
      await migrated.customSelect('SELECT COUNT(*) FROM ocr_jobs').get();
      await prepareRestoredDatabase(migrated);
    } on Object {
      throw const FormatException('备份数据库无法升级到当前版本');
    } finally {
      await migrated.close();
    }
  }

  Future<File> _rollbackFileFor(File database) async {
    final dir = await _appPaths.exportsDirectory();
    final date = DateTime.now();
    return File(
      p.join(
        dir.path,
        'pagesage-rollback-${date.year}${_two(date.month)}${_two(date.day)}-'
        '${_two(date.hour)}${_two(date.minute)}${_two(date.second)}-${const Uuid().v4()}.sqlite',
      ),
    );
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
