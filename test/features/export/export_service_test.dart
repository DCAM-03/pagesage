import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/books/bookmark.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/features/export/application/export_service.dart';
import 'package:path/path.dart' as p;

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
      final sqliteHeader = <int>[
        ...ascii.encode('SQLite format 3'),
        0,
        ...List<int>.filled(48, 1),
      ];
      await databaseFile.writeAsBytes(sqliteHeader, flush: true);
      final covers = await appPaths.coversDirectory();
      await File(p.join(covers.path, 'cover-a.png')).writeAsBytes([1, 2, 3]);

      final service = ExportService(
        appPaths: appPaths,
        noteRepository: const _FakeNoteRepository([]),
        bookmarkRepository: const _FakeBookmarkRepository([]),
        annotationRepository: const _FakeAnnotationRepository([]),
        aiConversationRepository: const _FakeAiConversationRepository([]),
        database: database,
      );

      final backup = await service.backupDatabaseZip(
        targetPath: p.join(tempDir.path, 'backup.zip'),
      );
      expect(await backup.exists(), isTrue);

      await databaseFile.writeAsBytes([9, 9, 9], flush: true);
      final restore = await service.restoreDatabaseBackup(backup);
      expect(await File(restore.databasePath).exists(), isTrue);
      final restored = await File(restore.databasePath).readAsBytes();
      expect(restored.sublist(0, 16), [...ascii.encode('SQLite format 3'), 0]);
      expect(await File(restore.rollbackPath).exists(), isTrue);
    },
  );
}

ExportService _service(
  AppDatabase database, {
  List<Note> notes = const [],
  List<Bookmark> bookmarks = const [],
  List<Annotation> annotations = const [],
  List<AiConversation> conversations = const [],
}) {
  return ExportService(
    appPaths: AppPaths(),
    noteRepository: _FakeNoteRepository(notes),
    bookmarkRepository: _FakeBookmarkRepository(bookmarks),
    annotationRepository: _FakeAnnotationRepository(annotations),
    aiConversationRepository: _FakeAiConversationRepository(conversations),
    database: database,
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
  Future<Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    AnnotationColor color = AnnotationColor.yellow,
    AnnotationStyle style = AnnotationStyle.highlight,
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
      createdAt: 1,
    );
  }

  @override
  Stream<List<AiConversation>> watchConversations() =>
      Stream.value(conversations);
}
