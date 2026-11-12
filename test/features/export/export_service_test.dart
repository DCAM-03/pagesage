import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/image_cache_store.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/annotations/image_anchor.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/bookmark.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/export/application/export_service.dart';
import 'package:pagesage/core/database/drift_ai_profile_repository.dart';
import 'package:pagesage/core/database/drift_ocr_job_repository.dart';
import 'package:pagesage/core/database/drift_task_repository.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/core/security/security_keys.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/domain/ocr/ocr_jobs.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late AppDatabase database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pagesage-export-test-');
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'AI and notebook exports preserve structured cross-book sources',
    () async {
      final snapshot = AiContextSnapshot(
        range: 'folder',
        references: [
          AiContextReference(
            id: 'ref-9',
            title: '第 42 页',
            text: '跨书原文',
            bookId: 'book-b',
            bookTitle: '乙书',
            locator: ReadingLocator.pdf(page: 42),
            sourceKey: 'book-b:42',
            startOffset: 3,
            endOffset: 7,
          ),
        ],
      );
      final service = _service(
        database,
        conversations: [
          AiConversation(
            id: 'conv-a',
            bookId: 'book-1',
            provider: 'local',
            model: 'm',
            prompt: '问题',
            answer: '回答',
            createdAt: 1,
            contextSnapshot: snapshot,
          ),
        ],
      );
      final file = await service.exportAiConversationsMarkdown(
        targetPath: '${tempDir.path}/ai.md',
      );
      final text = await file.readAsString();
      expect(text, contains('乙书 · 第 42 页'));
      expect(text, contains(snapshot.toJsonText()));
      final notebook = await service.exportNotebookMarkdown(
        targetPath: '${tempDir.path}/notebook.md',
      );
      final notebookText = await notebook.readAsString();
      expect(notebookText, contains(snapshot.toJsonText()));
      expect(notebookText, contains('历史回答，未执行本次核验'));
    },
  );

  test(
    'portable image export contains Markdown and its relative assets',
    () async {
      final markdown = File(p.join(tempDir.path, 'pictures.md'));
      final images = Directory(p.join(tempDir.path, 'pictures.assets'));
      await images.create();
      await markdown.writeAsString('![图](pictures.assets/one.png)');
      await File(p.join(images.path, 'one.png')).writeAsBytes([1, 2, 3]);
      final service = _service(database);
      final zip = await service.packageImageAnnotations(
        ImageAnnotationExportResult(
          markdownFile: markdown,
          imageDirectory: images,
          imageCount: 1,
          missingCount: 0,
        ),
      );
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(archive.files.map((file) => file.name).toSet(), {
        'pictures.md',
        'pictures.assets/one.png',
      });
      expect(archive.findFile('pictures.assets/one.png')!.content, [1, 2, 3]);
      final cancelled = TaskCancelToken()..cancel();
      final original = await zip.readAsBytes();
      await expectLater(
        service.packageImageAnnotations(
          ImageAnnotationExportResult(
            markdownFile: markdown,
            imageDirectory: images,
            imageCount: 1,
            missingCount: 0,
          ),
          cancelToken: cancelled,
        ),
        throwsA(isA<TaskCancelledException>()),
      );
      expect(await zip.readAsBytes(), original);
    },
  );

  test('exports answer verification and frozen request profile', () async {
    final meta = AiAnswerMeta(
      intent: 'sourceQuestion',
      evidenceState: 'eligible',
      answerStatus: 'sourceLinked',
      policyVersion: 'evidence-policy-v1',
      reasonCodes: const ['explicit_text'],
      citations: const ['R1'],
      claimChecks: const [],
      scopeCompleteness: 'ready',
      truncated: false,
    );
    final service = _service(
      database,
      conversations: [
        AiConversation(
          id: 'conv-verified',
          provider: 'openai-compatible',
          model: 'test-model',
          prompt: '书中说了什么',
          answer: '书中有依据。[R1]',
          createdAt: 1,
          answerMeta: meta,
          profileSnapshot: '{"version":1,"profileId":"profile-a"}',
        ),
      ],
    );
    final ai = await service.exportAiConversationsMarkdown(
      targetPath: '${tempDir.path}/ai-verified.md',
    );
    final aiText = await ai.readAsString();
    expect(aiText, contains(meta.toJsonText()));
    expect(aiText, contains('"profileId":"profile-a"'));
    expect(aiText, contains('已关联来源（未独立验证结论）'));
    final notebook = await service.exportNotebookMarkdown(
      targetPath: '${tempDir.path}/notebook-verified.md',
    );
    final notebookText = await notebook.readAsString();
    expect(notebookText, contains(meta.toJsonText()));
    expect(notebookText, contains('"profileId":"profile-a"'));
  });

  test('exports annotations as stable JSON with locator offsets', () async {
    final service = _service(
      database,
      annotations: [
        Annotation(
          id: 'annotation-1',
          bookId: 'book-1',
          locator: ReadingLocator.epub(
            href: 'chapter.xhtml',
            chapterIndex: 0,
            chapterOffset: 12,
            chapterEndOffset: 24,
          ),
          selectedText: 'highlighted text',
          color: AnnotationColor.yellow,
          style: AnnotationStyle.highlight,
          createdAt: 1,
          updatedAt: 2,
        ),
      ],
    );

    final file = await service.exportAnnotationsJson(
      targetPath: '${tempDir.path}/annotations.json',
    );

    final content = await file.readAsString();
    expect(content, contains('"annotations"'));
    expect(content, contains('"chapterOffset": 12'));
    expect(content, contains('"selectedText": "highlighted text"'));
  });

  test('annotations JSON keeps the target and the image anchor', () async {
    final service = _service(
      database,
      annotations: [
        Annotation(
          id: 'annotation-image',
          bookId: 'book-1',
          locator: ReadingLocator.pdf(
            page: 12,
            selectionRects: const [
              ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            ],
          ),
          selectedText: '图 3 的说明',
          color: AnnotationColor.blue,
          style: AnnotationStyle.highlight,
          createdAt: 1,
          updatedAt: 2,
          target: AnnotationTarget.image,
          imageAnchor: const PdfImageAnchor(
            page: 12,
            ordinal: 3,
            resourceName: 'Im1',
            rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
          ),
        ),
      ],
    );

    final file = await service.exportAnnotationsJson(
      targetPath: '${tempDir.path}/annotations.json',
    );

    final content = await file.readAsString();
    // Without these two the export cannot tell an image annotation from a
    // text one, and the picture's place in the book is lost.
    expect(content, contains('"target": "image"'));
    expect(content, contains('"kind": "pdf"'));
    expect(content, contains('"resourceName": "Im1"'));
    expect(content, contains('"ordinal": 3'));
  });

  group('image annotation export', () {
    test(
      'same image anchors in different books remain distinct and failed publication cleans assets',
      () async {
        final paths = AppPaths(overrideRoot: tempDir);
        final cache = CachedImageStore(appPaths: paths);
        const anchor = PdfImageAnchor(
          page: 1,
          ordinal: 1,
          resourceName: 'Im1',
          rect: ReaderRect(x: .1, y: .1, width: .2, height: .2),
        );
        await cache.put(
          bookId: 'one',
          anchor: anchor,
          bytes: Uint8List.fromList([1]),
        );
        await cache.put(
          bookId: 'two',
          anchor: anchor,
          bytes: Uint8List.fromList([2]),
        );
        final service = _service(
          database,
          appPaths: paths,
          imageCacheStore: cache,
          annotations: [
            for (final bookId in ['one', 'two'])
              Annotation(
                id: 'image-$bookId',
                bookId: bookId,
                locator: ReadingLocator.pdf(page: 1),
                selectedText: bookId,
                color: AnnotationColor.blue,
                style: AnnotationStyle.highlight,
                createdAt: 1,
                updatedAt: 1,
                target: AnnotationTarget.image,
                imageAnchor: anchor,
              ),
          ],
        );
        final result = await service.exportImageAnnotations(
          targetPath: '${tempDir.path}/images.md',
        );
        final files = await result.imageDirectory
            .list()
            .where((entry) => entry is File)
            .cast<File>()
            .toList();
        expect(files, hasLength(2));
        final values = await Future.wait(
          files.map((file) => file.readAsBytes()),
        );
        expect(
          values,
          unorderedEquals([
            [1],
            [2],
          ]),
        );
        final blocked = Directory('${tempDir.path}/blocked.md');
        await blocked.create();
        final before = (await tempDir.list().toList())
            .map((entry) => entry.path)
            .toSet();
        await expectLater(
          service.exportImageAnnotations(targetPath: blocked.path),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          (await tempDir.list().toList()).map((entry) => entry.path).toSet(),
          before,
        );
        expect(
          await result.markdownFile.readAsString(),
          contains('# PageSage 图片批注导出'),
        );
      },
    );

    test(
      'writes the markdown and copies the cached picture next to it',
      () async {
        final appPaths = AppPaths(overrideRoot: tempDir);
        final cache = CachedImageStore(appPaths: appPaths);
        const anchor = PdfImageAnchor(
          page: 12,
          ordinal: 3,
          resourceName: 'Im1',
          rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
        );
        await cache.put(
          bookId: 'book-1',
          anchor: anchor,
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        final service = _service(
          database,
          annotations: [
            Annotation(
              id: 'annotation-image',
              bookId: 'book-1',
              locator: ReadingLocator.pdf(page: 12),
              selectedText: '图 3 的说明',
              color: AnnotationColor.blue,
              style: AnnotationStyle.highlight,
              createdAt: 1,
              updatedAt: 2,
              target: AnnotationTarget.image,
              imageAnchor: anchor,
            ),
          ],
          imageCacheStore: cache,
          bookRepository: _FakeBookRepository({'book-1': '一本书'}),
        );

        final target = p.join(tempDir.path, 'export', 'images.md');
        final result = await service.exportImageAnnotations(targetPath: target);

        expect(result.imageCount, 1);
        expect(result.missingCount, 0);
        expect(await result.markdownFile.exists(), isTrue);

        final markdown = await result.markdownFile.readAsString();
        expect(markdown, contains('# PageSage 图片批注导出'));
        expect(markdown, contains('一本书'));
        expect(markdown, contains('第 12 页'));
        expect(markdown, contains('图 3 的说明'));

        // The picture is referenced relative to the Markdown, so moving the
        // pair together keeps the link working.
        final match = RegExp(r'!\[[^\]]*\]\(([^)]+)\)').firstMatch(markdown);
        expect(match, isNotNull);
        final relative = match!.group(1)!;
        expect(relative, isNot(startsWith('/')));
        final copied = File(p.join(p.dirname(target), relative));
        expect(await copied.exists(), isTrue);
        expect(await copied.readAsBytes(), [1, 2, 3]);
      },
    );

    test('an annotation without a cached picture keeps its comment', () async {
      final appPaths = AppPaths(overrideRoot: tempDir);
      final service = _service(
        database,
        annotations: [
          Annotation(
            id: 'annotation-image',
            bookId: 'book-1',
            locator: ReadingLocator.pdf(page: 12),
            selectedText: '图 3 的说明',
            color: AnnotationColor.blue,
            style: AnnotationStyle.highlight,
            createdAt: 1,
            updatedAt: 2,
            target: AnnotationTarget.image,
            imageAnchor: const PdfImageAnchor(
              page: 12,
              ordinal: 3,
              rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            ),
          ),
        ],
        imageCacheStore: CachedImageStore(appPaths: appPaths),
        bookRepository: _FakeBookRepository({'book-1': '一本书'}),
      );

      final result = await service.exportImageAnnotations(
        targetPath: p.join(tempDir.path, 'export', 'images.md'),
      );

      expect(result.imageCount, 0);
      expect(result.missingCount, 1);
      final markdown = await result.markdownFile.readAsString();
      // The picture is gone, but the comment is the reader's own writing and
      // must not be dropped along with it.
      expect(markdown, contains('图 3 的说明'));
      expect(markdown, contains('图片未缓存'));
    });

    test(
      'an image without a caption says so instead of inventing one',
      () async {
        final appPaths = AppPaths(overrideRoot: tempDir);
        final service = _service(
          database,
          annotations: [
            Annotation(
              id: 'annotation-image',
              bookId: 'book-1',
              locator: ReadingLocator.pdf(page: 12),
              selectedText: '',
              color: AnnotationColor.blue,
              style: AnnotationStyle.highlight,
              createdAt: 1,
              updatedAt: 2,
              target: AnnotationTarget.image,
              imageAnchor: const PdfImageAnchor(
                page: 12,
                ordinal: 1,
                rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
              ),
            ),
          ],
          imageCacheStore: CachedImageStore(appPaths: appPaths),
          bookRepository: _FakeBookRepository({'book-1': '一本书'}),
        );

        final result = await service.exportImageAnnotations(
          targetPath: p.join(tempDir.path, 'export', 'images.md'),
        );

        final markdown = await result.markdownFile.readAsString();
        expect(markdown, contains('未标注'));
      },
    );
  });

  test('exports combined notebook markdown', () async {
    final service = _service(
      database,
      bookmarks: [
        Bookmark(
          id: 'bookmark-1',
          bookId: 'book-1',
          locator: ReadingLocator.epub(chapterIndex: 0),
          title: '重要位置',
          note: '稍后复习',
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      notes: [
        Note(
          id: 'note-1',
          bookId: 'book-1',
          title: '摘录',
          content: '自己的想法',
          sourceText: '原文',
          locator: ReadingLocator.epub(chapterIndex: 0, chapterOffset: 10),
          noteType: NoteType.excerpt,
          createdAt: 2,
          updatedAt: 2,
        ),
      ],
      conversations: [
        AiConversation(
          id: 'ai-1',
          bookId: 'book-1',
          locator: ReadingLocator.epub(chapterIndex: 0, chapterOffset: 20),
          provider: 'openai-compatible',
          model: 'test-model',
          prompt: '解释',
          answer: '回答',
          createdAt: 3,
        ),
      ],
    );

    final file = await service.exportNotebookMarkdown(
      targetPath: '${tempDir.path}/notebook.md',
    );

    final content = await file.readAsString();
    expect(content, contains('# PageSage Notebook 导出'));
    expect(content, contains('- 类型：书签'));
    expect(content, contains('- 类型：笔记'));
    expect(content, contains('- 类型：AI'));
  });

  test(
    'backupDatabaseZip packages sqlite and restores with rollback',
    () async {
      final root = Directory(p.join(tempDir.path, 'data-root'));
      await root.create(recursive: true);
      final appPaths = AppPaths(overrideRoot: root);
      final databaseFile = await appPaths.databaseFile();
      await databaseFile.parent.create(recursive: true);
      final backupSource = File(p.join(tempDir.path, 'backup-source.sqlite'));
      final backupDatabase = AppDatabase.forTesting(
        NativeDatabase(backupSource),
      );
      await backupDatabase.customStatement(
        "INSERT INTO books (id, title, format, library_file_path, file_hash, "
        "file_size, created_at, updated_at) VALUES "
        "('backup-book', 'Backup', 'pdf', '/book.pdf', 'hash', 1, 1, 1)",
      );
      await backupDatabase.close();
      await backupSource.copy(databaseFile.path);
      final covers = await appPaths.coversDirectory();
      await File(p.join(covers.path, 'cover-a.png')).writeAsBytes([1, 2, 3]);

      final service = ExportService(
        appPaths: appPaths,
        noteRepository: const _FakeNoteRepository([]),
        bookmarkRepository: const _FakeBookmarkRepository([]),
        annotationRepository: const _FakeAnnotationRepository([]),
        aiConversationRepository: const _FakeAiConversationRepository([]),
        database: database,
        imageCacheStore: CachedImageStore(appPaths: appPaths),
        bookRepository: _FakeBookRepository(),
      );

      final backup = await service.backupDatabaseZip(
        targetPath: p.join(tempDir.path, 'backup.zip'),
      );
      expect(await backup.exists(), isTrue);

      await databaseFile.writeAsBytes([
        ...ascii.encode('SQLite format 3'),
        0,
        ...List<int>.filled(48, 1),
      ], flush: true);
      final restore = await service.restoreDatabaseBackup(backup);
      expect(await File(restore.databasePath).exists(), isTrue);
      final restored = await File(restore.databasePath).readAsBytes();
      expect(restored.sublist(0, 16), [...ascii.encode('SQLite format 3'), 0]);
      expect(await File(restore.rollbackPath).exists(), isTrue);
      final restoredDatabase = AppDatabase.forTesting(
        NativeDatabase(File(restore.databasePath)),
      );
      expect(
        await restoredDatabase
            .customSelect('SELECT id FROM books')
            .map((row) => row.read<String>('id'))
            .get(),
        ['backup-book'],
      );
      final settings = await DriftAiProfileRepository(
        restoredDatabase,
        SecureStore.memory(seed: {aiApiKeyStorageKey: 'old-device-key'}),
      ).getSettings();
      expect(settings.profileIds, isEmpty);
      expect(settings.hasApiKey, isFalse);
      await restoredDatabase.close();
      expect(
        (await databaseFile.parent.list().toList()).where(
          (entity) => entity.path.endsWith('.restore'),
        ),
        isEmpty,
      );
    },
  );

  test('restore migrates a v11 backup and preserves book and OCR data', () async {
    final root = Directory(p.join(tempDir.path, 'v11-data-root'));
    await root.create(recursive: true);
    final appPaths = AppPaths(overrideRoot: root);
    final databaseFile = await appPaths.databaseFile();
    await databaseFile.parent.create(recursive: true);
    final sourceFile = File(p.join(tempDir.path, 'v11-source.sqlite'));
    final source = AppDatabase.forTesting(NativeDatabase(sourceFile));
    await source.customStatement(
      "INSERT INTO books (id, title, format, library_file_path, file_hash, "
      "file_size, created_at, updated_at) VALUES "
      "('v11-book', 'Legacy PDF', 'pdf', '/legacy.pdf', 'legacy-hash', 4, 1, 1)",
    );
    await source.searchDao.upsertChunk(
      SearchChunksCompanion.insert(
        id: 'v11-search-chunk',
        bookId: const Value('v11-book'),
        sourceType: 'book',
        sourceId: const Value('v11-book:chapter-1'),
        title: const Value('旧索引章节'),
        body: '旧版备份恢复后中文搜索依然可用。',
        sortOrder: const Value(0),
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await source.ocrPageDao.upsertPage(
      OcrPagesCompanion.insert(
        id: 'v11-ocr-page',
        bookId: 'v11-book',
        pageNumber: 2,
        body: '历史 OCR 正文',
        blocksJson: '[]',
        createdAt: 2,
        updatedAt: 2,
      ),
    );
    await source.close();

    final legacy = sqlite.sqlite3.open(sourceFile.path);
    for (final column in const [
      'source_revision',
      'cache_signature',
      'text_revision',
      'engine_version',
      'pipeline_version',
      'result_state',
      'index_state',
    ]) {
      legacy.execute('ALTER TABLE ocr_pages DROP COLUMN $column');
    }
    legacy.execute('DROP TABLE ocr_job_pages');
    legacy.execute('DROP TABLE ocr_jobs');
    legacy.userVersion = 11;
    legacy.close();
    await sourceFile.copy(databaseFile.path);

    final service = ExportService(
      appPaths: appPaths,
      noteRepository: const _FakeNoteRepository([]),
      bookmarkRepository: const _FakeBookmarkRepository([]),
      annotationRepository: const _FakeAnnotationRepository([]),
      aiConversationRepository: const _FakeAiConversationRepository([]),
      database: database,
      imageCacheStore: CachedImageStore(appPaths: appPaths),
      bookRepository: _FakeBookRepository(),
    );
    final backup = await service.backupDatabaseZip(
      targetPath: p.join(tempDir.path, 'v11-backup.zip'),
    );

    final restored = await service.restoreDatabaseBackup(backup);
    final reopened = AppDatabase.forTesting(
      NativeDatabase(File(restored.databasePath)),
    );
    expect(
      (await reopened.customSelect('PRAGMA user_version').get()).single
          .read<int>('user_version'),
      12,
    );
    expect(
      (await reopened.customSelect('SELECT title FROM books').get()).single
          .read<String>('title'),
      'Legacy PDF',
    );
    final ocrPage = await reopened.ocrPageDao.getPage('v11-book', 2);
    expect(ocrPage?.body, '历史 OCR 正文');
    expect(ocrPage?.resultState, 'legacy');
    final searchRepository = DriftSearchRepository(reopened.searchDao);
    expect(
      await searchRepository.search(
        const SearchQuery(query: '中文搜索', bookId: 'v11-book'),
      ),
      isNotEmpty,
    );
    await reopened.close();
  });

  test(
    'restore migrates a v10 backup through multiple schema changes',
    () async {
      final root = Directory(p.join(tempDir.path, 'v10-data-root'));
      await root.create(recursive: true);
      final appPaths = AppPaths(overrideRoot: root);
      final databaseFile = await appPaths.databaseFile();
      await databaseFile.parent.create(recursive: true);
      final sourceFile = File(p.join(tempDir.path, 'v10-source.sqlite'));
      final source = AppDatabase.forTesting(NativeDatabase(sourceFile));
      await source.customStatement(
        "INSERT INTO books (id, title, format, library_file_path, file_hash, "
        "file_size, created_at, updated_at) VALUES "
        "('v10-book', 'Older PDF', 'pdf', '/older.pdf', 'older-hash', 4, 1, 1)",
      );
      await source.customStatement(
        "INSERT INTO ai_conversations "
        "(id, provider, model, prompt, answer, created_at) VALUES "
        "('v10-conversation', 'local', 'model', '问题', '回答', 1)",
      );
      await source.close();

      final legacy = sqlite.sqlite3.open(sourceFile.path);
      legacy.execute('ALTER TABLE ai_conversations DROP COLUMN answer_meta');
      for (final column in const [
        'source_revision',
        'cache_signature',
        'text_revision',
        'engine_version',
        'pipeline_version',
        'result_state',
        'index_state',
      ]) {
        legacy.execute('ALTER TABLE ocr_pages DROP COLUMN $column');
      }
      legacy.execute('DROP TABLE ocr_job_pages');
      legacy.execute('DROP TABLE ocr_jobs');
      legacy.userVersion = 10;
      legacy.close();
      await sourceFile.copy(databaseFile.path);

      final service = ExportService(
        appPaths: appPaths,
        noteRepository: const _FakeNoteRepository([]),
        bookmarkRepository: const _FakeBookmarkRepository([]),
        annotationRepository: const _FakeAnnotationRepository([]),
        aiConversationRepository: const _FakeAiConversationRepository([]),
        database: database,
        imageCacheStore: CachedImageStore(appPaths: appPaths),
        bookRepository: _FakeBookRepository(),
      );
      final backup = await service.backupDatabaseZip(
        targetPath: p.join(tempDir.path, 'v10-backup.zip'),
      );

      final restored = await service.restoreDatabaseBackup(backup);
      final reopened = AppDatabase.forTesting(
        NativeDatabase(File(restored.databasePath)),
      );
      expect(
        (await reopened.customSelect('PRAGMA user_version').get()).single
            .read<int>('user_version'),
        12,
      );
      expect(
        (await reopened
                .customSelect('SELECT answer_meta FROM ai_conversations')
                .get())
            .single
            .readNullable<String>('answer_meta'),
        isNull,
      );
      expect(
        (await reopened.customSelect('SELECT id FROM books').get()).single
            .read<String>('id'),
        'v10-book',
      );
      await reopened.close();
    },
  );

  test(
    'restore rejects a SQLite header without a valid PageSage schema',
    () async {
      final root = Directory(p.join(tempDir.path, 'invalid-data-root'));
      await root.create(recursive: true);
      final appPaths = AppPaths(overrideRoot: root);
      final databaseFile = await appPaths.databaseFile();
      await databaseFile.parent.create(recursive: true);
      final invalidBytes = <int>[
        ...ascii.encode('SQLite format 3'),
        0,
        ...List<int>.filled(48, 1),
      ];
      await databaseFile.writeAsBytes(invalidBytes, flush: true);
      final service = ExportService(
        appPaths: appPaths,
        noteRepository: const _FakeNoteRepository([]),
        bookmarkRepository: const _FakeBookmarkRepository([]),
        annotationRepository: const _FakeAnnotationRepository([]),
        aiConversationRepository: const _FakeAiConversationRepository([]),
        database: database,
        imageCacheStore: CachedImageStore(appPaths: appPaths),
        bookRepository: _FakeBookRepository(),
      );
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'app': 'PageSage',
              'version': 1,
              'contents': ['database/pagesage.sqlite'],
            }),
          ),
        )
        ..add(
          ArchiveFile(
            'database/pagesage.sqlite',
            invalidBytes.length,
            invalidBytes,
          ),
        );
      final backup = File(p.join(tempDir.path, 'invalid-backup.zip'));
      await backup.writeAsBytes(ZipEncoder().encode(archive));

      await expectLater(
        service.restoreDatabaseBackup(backup),
        throwsA(isA<FormatException>()),
      );
      expect(await databaseFile.readAsBytes(), invalidBytes);
      expect(await database.customSelect('SELECT 1').get(), hasLength(1));
      expect(
        (await databaseFile.parent.list().toList()).where(
          (entity) => entity.path.endsWith('.restore'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'WAL backup restores linked data, profiles, OCR and active search',
    () async {
      final paths = AppPaths(overrideRoot: Directory('${tempDir.path}/live'));
      final file = await paths.databaseFile();
      await file.parent.create(recursive: true);
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      await database.customSelect('PRAGMA journal_mode=WAL').get();
      await database.customStatement('PRAGMA wal_autocheckpoint=0');
      final source = File('${tempDir.path}/source/chapter.md');
      await source.parent.create();
      await source.writeAsString('# 原文件\n知识管理');
      final locator = ReadingLocator.epub(href: 'chapter.md', chapterIndex: 0);
      await database
          .into(database.books)
          .insert(
            BooksCompanion.insert(
              id: 'joint-book',
              title: '联合验证',
              format: 'markdown',
              libraryFilePath: source.parent.path,
              fileHash: 'revision',
              fileSize: 30,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.readingProgress)
          .insert(
            ReadingProgressCompanion.insert(
              bookId: 'joint-book',
              locator: locator.toJsonText(),
              updatedAt: 1,
            ),
          );
      await database
          .into(database.notes)
          .insert(
            NotesCompanion.insert(
              id: 'note',
              bookId: const Value('joint-book'),
              annotationId: const Value('annotation'),
              content: '知识管理笔记',
              noteType: 'text',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.annotations)
          .insert(
            AnnotationsCompanion.insert(
              id: 'annotation',
              bookId: 'joint-book',
              locator: locator.toJsonText(),
              selectedText: '知识管理',
              color: 'yellow',
              style: 'highlight',
              noteId: const Value('note'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bookmark',
              bookId: 'joint-book',
              locator: locator.toJsonText(),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final secrets = SecureStore.memory();
      final profiles = DriftAiProfileRepository(database, secrets);
      final profile = await profiles.createProfile(name: '本地模型');
      await profiles.setActiveProfile(profile.id);
      await database.customStatement(
        "UPDATE ai_profiles SET base_url = 'https://model.example.test/v1', model = 'fixture-model' WHERE id = ?",
        [profile.id],
      );
      await database
          .into(database.aiCredentialOperations)
          .insert(
            AiCredentialOperationsCompanion.insert(
              id: 'pending-secret',
              profileId: profile.id,
              operation: 'update',
              phase: 'pending',
              expectedRevision: 1,
              ownerSessionId: 'old-session',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await secrets.write(
        aiProfileApiKeyStorageKey(profile.id),
        'old-device-key',
      );
      await secrets.write(aiApiKeyStorageKey, 'old-legacy-key');
      await database
          .into(database.aiConversations)
          .insert(
            AiConversationsCompanion.insert(
              id: 'answer',
              bookId: const Value('joint-book'),
              provider: 'openai-compatible',
              model: 'test-model',
              prompt: '问题',
              answer: '有来源的回答 [R1]',
              profileId: Value(profile.id),
              profileSnapshot: Value(
                '{"version":1,"profileId":"${profile.id}"}',
              ),
              createdAt: 1,
            ),
          );
      final ocr = DriftOcrPageStore(database.ocrPageDao);
      await ocr.putPage(
        bookId: 'joint-book',
        pageNumber: 2,
        result: const OcrPageResult(
          text: '矩阵运算识别文本',
          language: 'zh',
          engine: 'fixture',
        ),
        sourceRevision: 'revision',
        cacheSignature: 'signature',
        textRevision: 'text-revision',
        resultState: 'recognized',
      );
      final tasks = DriftTaskRepository(database.taskDao);
      final task = await tasks.saveTask(
        type: PageSageTaskType.ocrPages,
        status: PageSageTaskStatus.running,
        bookId: 'joint-book',
      );
      final jobs = DriftOcrJobRepository(database);
      final job = await jobs.createJob(
        taskId: task.id,
        bookId: 'joint-book',
        sourceRevision: 'revision',
        config: const OcrJobConfig(),
        pageNumbers: [2, 3],
        expectedCacheSignature: 'signature',
      );
      await jobs.updateJob(id: job.id, status: OcrJobStatus.running);
      final pages = await jobs.getPages(job.id);
      await jobs.updatePage(id: pages.first.id, status: OcrPageJobStatus.done);
      await jobs.updatePage(
        id: pages.last.id,
        status: OcrPageJobStatus.recognizing,
      );
      final search = DriftSearchRepository(database.searchDao);
      final generation = await search.beginBookGeneration('joint-book');
      await search.indexGenerationTexts(generation.id, [
        SearchIndexEntry(
          sourceType: 'book',
          sourceId: 'chapter.md',
          bookId: 'joint-book',
          title: '知识管理',
          text: '知识管理原文',
          locator: locator,
        ),
        SearchIndexEntry(
          sourceType: 'book',
          sourceId: 'ocr:2',
          bookId: 'joint-book',
          title: '识别页',
          text: '矩阵运算识别文本',
          textOrigin: 'ocr',
          locator: ReadingLocator.pdf(page: 2),
        ),
      ]);
      await search.publishBookGeneration(generation.id);
      final covers = await paths.coversDirectory();
      final cover = File('${covers.path}/cover.png');
      await cover.writeAsBytes([1, 2, 3]);
      expect(await File('${file.path}-wal').length(), greaterThan(0));
      final service = _service(database, appPaths: paths);
      final backup = await service.backupDatabaseZip(
        targetPath: '${tempDir.path}/joint.zip',
      );
      final malicious = ZipDecoder().decodeBytes(await backup.readAsBytes())
        ..add(ArchiveFile.string('covers/../../escape.png', 'invalid'));
      final invalidBackup = File('${tempDir.path}/bad-cover.zip');
      await invalidBackup.writeAsBytes(ZipEncoder().encode(malicious));
      await expectLater(
        service.restoreDatabaseBackup(invalidBackup),
        throwsA(isA<FormatException>()),
      );
      expect(await database.select(database.notes).get(), hasLength(1));
      expect(await File('${tempDir.path}/escape.png').exists(), isFalse);
      await database.customStatement("UPDATE notes SET content = '备份后的改动'");
      await cover.writeAsBytes([9]);
      final result = await service.restoreDatabaseBackup(backup);
      database = AppDatabase.forTesting(
        NativeDatabase(File(result.databasePath)),
      );
      expect(
        (await database.select(database.notes).getSingle()).content,
        '知识管理笔记',
      );
      expect(
        (await database.select(database.annotations).getSingle()).noteId,
        'note',
      );
      expect(
        (await database.select(database.notes).getSingle()).annotationId,
        'annotation',
      );
      expect(
        (await database.select(database.readingProgress).getSingle()).locator,
        locator.toJsonText(),
      );
      expect(await database.select(database.bookmarks).get(), hasLength(1));
      final restoredProfiles = DriftAiProfileRepository(database, secrets);
      final restored = (await restoredProfiles.listProfiles()).single;
      expect(restored.id, isNot(profile.id));
      expect(restored.name, '本地模型');
      expect(restored.baseUrl, 'https://model.example.test/v1');
      expect(restored.model, 'fixture-model');
      expect(restored.hasApiKey, isFalse);
      expect(
        await database.select(database.aiCredentialOperations).get(),
        isEmpty,
      );
      expect(
        (await restoredProfiles.getSettings()).activeProfileId,
        restored.id,
      );
      expect(
        await secrets.read(aiProfileApiKeyStorageKey(profile.id)),
        'old-device-key',
      );
      final answer = await database
          .select(database.aiConversations)
          .getSingle();
      expect(answer.profileId, restored.id);
      expect(answer.profileSnapshot, contains(profile.id));
      final restoredJobs = DriftOcrJobRepository(database);
      expect((await restoredJobs.getJob(job.id))?.status, OcrJobStatus.paused);
      expect((await restoredJobs.getPages(job.id)).map((page) => page.status), [
        OcrPageJobStatus.done,
        OcrPageJobStatus.pending,
      ]);
      expect(
        (await DriftTaskRepository(database.taskDao).getTasks()).single.status,
        PageSageTaskStatus.paused,
      );
      expect(
        (await database.select(database.ocrPages).getSingle()).body,
        '矩阵运算识别文本',
      );
      final restoredSearch = DriftSearchRepository(database.searchDao);
      expect(
        (await restoredSearch.search(
          const SearchQuery(query: '知识管理'),
        )).single.locator?.href,
        'chapter.md',
      );
      final ocrHit = (await restoredSearch.search(
        const SearchQuery(query: '矩阵运算'),
      )).single;
      expect(ocrHit.locator?.page, 2);
      expect(ocrHit.precision, SearchMatchPrecision.pageOnly);
      expect(await cover.readAsBytes(), [1, 2, 3]);
      expect(await source.readAsString(), '# 原文件\n知识管理');
      final rollback = AppDatabase.forTesting(
        NativeDatabase(File(result.rollbackPath)),
      );
      expect(
        (await rollback.select(rollback.notes).getSingle()).content,
        '备份后的改动',
      );
      await rollback.close();
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await database.select(database.notes).getSingle()).content,
        '知识管理笔记',
      );
    },
  );

  test('cancelled export preserves an existing destination', () async {
    final file = File('${tempDir.path}/notes.md');
    await file.writeAsString('原导出');
    final token = TaskCancelToken()..cancel();
    await expectLater(
      _service(
        database,
      ).exportAllNotesMarkdown(targetPath: file.path, cancelToken: token),
      throwsA(isA<TaskCancelledException>()),
    );
    expect(await file.readAsString(), '原导出');
  });

  test('successful export replaces the exact selected filename', () async {
    final file = File('${tempDir.path}/chosen-name');
    await file.writeAsString('原导出');
    final result = await _service(
      database,
    ).exportAllNotesMarkdown(targetPath: file.path);
    expect(result.path, file.path);
    expect(await file.readAsString(), contains('# PageSage 笔记导出'));
    expect(await File('${file.path}.md').exists(), isFalse);
  });

  test(
    'failed atomic rename removes staging and preserves destination',
    () async {
      final destination = Directory('${tempDir.path}/notes.md');
      await destination.create();
      await File('${destination.path}/sentinel').writeAsString('保留');
      await expectLater(
        _service(database).exportAllNotesMarkdown(targetPath: destination.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File('${destination.path}/sentinel').readAsString(), '保留');
      expect(
        (await tempDir.list().toList()).where(
          (entry) => entry.path.endsWith('.part'),
        ),
        isEmpty,
      );
    },
  );
}

ExportService _service(
  AppDatabase database, {
  List<Note> notes = const [],
  List<Bookmark> bookmarks = const [],
  List<Annotation> annotations = const [],
  List<AiConversation> conversations = const [],
  CachedImageStore? imageCacheStore,
  BookRepository? bookRepository,
  AppPaths? appPaths,
}) {
  return ExportService(
    appPaths: appPaths ?? AppPaths(),
    noteRepository: _FakeNoteRepository(notes),
    bookmarkRepository: _FakeBookmarkRepository(bookmarks),
    annotationRepository: _FakeAnnotationRepository(annotations),
    aiConversationRepository: _FakeAiConversationRepository(conversations),
    database: database,
    imageCacheStore: imageCacheStore ?? CachedImageStore(appPaths: AppPaths()),
    bookRepository: bookRepository ?? _FakeBookRepository(),
  );
}

final class _FakeNoteRepository implements NoteRepository {
  const _FakeNoteRepository(this.notes);

  final List<Note> notes;

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<List<Note>> getByBook(String bookId) async =>
      notes.where((note) => note.bookId == bookId).toList(growable: false);

  @override
  Future<Set<String>> getBookIdsWithNotes() async => {
    for (final note in notes)
      if (note.bookId != null) note.bookId!,
  };

  @override
  Future<Note?> getNote(String id) async {
    for (final note in notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<List<Note>> getNotes() async => notes;

  @override
  Future<Note> saveNote({
    String? id,
    String? bookId,
    String? annotationId,
    String? title,
    required String content,
    String? sourceText,
    ReadingLocator? locator,
    NoteType noteType = NoteType.text,
  }) async {
    return Note(
      id: id ?? 'note-new',
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: locator,
      noteType: noteType,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Stream<List<Note>> watchNotes() => Stream.value(notes);
}

final class _FakeBookmarkRepository implements BookmarkRepository {
  const _FakeBookmarkRepository(this.bookmarks);

  final List<Bookmark> bookmarks;

  @override
  Future<void> deleteBookmark(String id) async {}

  @override
  Future<Bookmark?> findAtLocator(String bookId, ReadingLocator locator) async {
    return null;
  }

  @override
  Future<List<Bookmark>> getAll() async => bookmarks;

  @override
  Future<Set<String>> getBookIdsWithBookmarks() async =>
      bookmarks.map((bookmark) => bookmark.bookId).toSet();

  @override
  Future<List<Bookmark>> getByBook(String bookId) async => bookmarks
      .where((bookmark) => bookmark.bookId == bookId)
      .toList(growable: false);

  @override
  Future<Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  }) async {
    return Bookmark(
      id: id ?? 'bookmark-new',
      bookId: bookId,
      locator: locator,
      title: title,
      note: note,
      excerpt: excerpt,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Stream<List<Bookmark>> watchByBook(String bookId) => Stream.value(bookmarks);
}

final class _FakeAnnotationRepository implements AnnotationRepository {
  const _FakeAnnotationRepository(this.annotations);

  final List<Annotation> annotations;

  @override
  Future<void> deleteAnnotation(String id) async {}

  @override
  Future<List<Annotation>> getAll() async => annotations;

  @override
  Future<List<Annotation>> getByBook(String bookId) async => annotations
      .where((annotation) => annotation.bookId == bookId)
      .toList(growable: false);

  @override
  Future<void> linkNote({
    required String annotationId,
    required String noteId,
  }) async {}

  @override
  Future<void> unlinkNote({required String annotationId}) async {}

  @override
  Future<Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    AnnotationColor color = AnnotationColor.yellow,
    AnnotationStyle style = AnnotationStyle.highlight,
    ImageAnchor? imageAnchor,
  }) async {
    return Annotation(
      id: id ?? 'annotation-new',
      bookId: bookId,
      locator: locator,
      selectedText: selectedText,
      color: color,
      style: style,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Stream<List<Annotation>> watchByBook(String bookId) =>
      Stream.value(annotations);
}

final class _FakeAiConversationRepository implements AiConversationRepository {
  const _FakeAiConversationRepository(this.conversations);

  final List<AiConversation> conversations;

  @override
  Future<void> clearAll() async {}

  @override
  Future<List<AiConversation>> getConversations() async => conversations;

  @override
  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) async {}

  @override
  Future<AiConversation> saveConversation({
    String? id,
    String? bookId,
    ReadingLocator? locator,
    required String provider,
    required String model,
    required String prompt,
    String? contextText,
    required String answer,
    String? sourceText,
    String? threadId,
    AiContextSnapshot? contextSnapshot,
  }) async {
    return AiConversation(
      id: id ?? 'ai-new',
      bookId: bookId,
      locator: locator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      threadId: threadId,
      contextSnapshot: contextSnapshot,
      createdAt: 1,
    );
  }

  @override
  Stream<List<AiConversation>> watchConversations() =>
      Stream.value(conversations);
}

/// A repository that only knows the titles the export prints.
final class _FakeBookRepository implements BookRepository {
  _FakeBookRepository([Map<String, String> titles = const {}])
    : _titles = titles;

  final Map<String, String> _titles;

  @override
  Future<Book?> getBook(String id) async {
    final title = _titles[id];
    if (title == null) {
      return null;
    }
    return Book(
      id: id,
      title: title,
      format: BookFormat.pdf,
      libraryFilePath: '/library/$id.pdf',
      fileHash: 'hash-$id',
      fileSize: 1,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<Book> createImportedBook(NewBookDraft draft) =>
      throw UnimplementedError();

  @override
  Future<List<LibraryBook>> getLibrary() async => const [];

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async => null;

  @override
  Future<Book?> findByHash(String fileHash) async => null;

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
    String? coverPath,
    String? description,
  }) async {}

  @override
  Future<void> updateReadStatus(String bookId, ReadStatus readStatus) async {}

  @override
  Stream<List<LibraryBook>> watchLibrary() => Stream.value(const []);
}
