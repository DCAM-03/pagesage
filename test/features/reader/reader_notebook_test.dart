import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/image_cache_store.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/annotations/image_anchor.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/features/reader/application/reader_annotation_comment_service.dart';
import 'package:pagesage/features/reader/presentation/reader_annotation_editor.dart';
import 'package:pagesage/features/reader/presentation/reader_notebook.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late _RecordingImageCache cache;

  setUp(() async {
    database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    for (final id in ['book-a', 'book-b']) {
      await database.bookDao.insertBook(
        BooksCompanion.insert(
          id: id,
          title: id,
          format: 'pdf',
          libraryFilePath: '/library/$id.pdf',
          fileHash: 'hash-$id',
          fileSize: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
    }
    cache = _RecordingImageCache();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        imageCacheStoreProvider.overrideWithValue(cache),
      ],
    );
  });

  void notebookTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
        await tester.runAsync(database.close);
      }
    });
  }

  notebookTest(
    'mixed entries retain location order and stay scoped to a book',
    (tester) async {
      await tester.runAsync(() async {
        await container
            .read(bookmarkRepositoryProvider)
            .saveBookmark(
              id: 'bookmark',
              bookId: 'book-a',
              locator: ReadingLocator.pdf(page: 1),
              title: 'Bookmark entry',
              excerpt: 'Bookmark excerpt',
            );
        await container
            .read(annotationRepositoryProvider)
            .saveAnnotation(
              id: 'text',
              bookId: 'book-a',
              locator: ReadingLocator.pdf(page: 2),
              selectedText: 'Text annotation',
            );
        await container
            .read(annotationRepositoryProvider)
            .saveAnnotation(
              id: 'image',
              bookId: 'book-a',
              locator: ReadingLocator.pdf(page: 3),
              selectedText: 'Image caption',
              imageAnchor: _imageAnchor,
            );
        await container
            .read(noteRepositoryProvider)
            .saveNote(
              id: 'note',
              bookId: 'book-a',
              title: 'Located note',
              content: 'Note content',
              locator: ReadingLocator.pdf(page: 4),
            );
        await container
            .read(aiConversationRepositoryProvider)
            .saveConversation(
              id: 'ai',
              bookId: 'book-a',
              locator: ReadingLocator.pdf(page: 5),
              provider: 'fixture',
              model: 'fixture',
              prompt: 'AI entry',
              answer: 'AI answer',
            );
        await container
            .read(noteRepositoryProvider)
            .saveNote(
              id: 'unlocated',
              bookId: 'book-a',
              title: 'Unlocated note',
              content: 'No location',
            );
        await container
            .read(aiConversationRepositoryProvider)
            .saveConversation(
              id: 'foreign',
              bookId: 'book-b',
              provider: 'fixture',
              model: 'fixture',
              prompt: 'Foreign entry',
              answer: 'Other book',
            );
      });
      final selected = <ReadingLocator>[];
      await _mountNotebook(tester, container, onSelected: selected.add);

      final titles = [
        'Bookmark entry',
        'Text annotation',
        'Image caption',
        'Located note',
        'AI entry',
        'Unlocated note',
      ];
      for (final title in titles) {
        expect(find.text(title), findsOneWidget);
      }
      for (var index = 1; index < titles.length; index += 1) {
        expect(
          tester.getTopLeft(find.text(titles[index - 1])).dy,
          lessThan(tester.getTopLeft(find.text(titles[index])).dy),
        );
      }
      expect(find.text('Foreign entry'), findsNothing);
      await _entryAction(tester, 'Text annotation', '跳回原文');
      expect(selected.single.page, 2);
      expect(selected.single.excerpt, 'Text annotation');

      await tester.pumpWidget(
        _notebookApp(container, bookId: 'book-b', onSelected: selected.add),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foreign entry'), findsOneWidget);
      expect(find.text('Bookmark entry'), findsNothing);
      expect(find.text('AI entry'), findsNothing);
    },
  );

  notebookTest('bookmark editing cancels safely, saves and clears notes', (
    tester,
  ) async {
    final bookmark = await tester.runAsync(
      () => container
          .read(bookmarkRepositoryProvider)
          .saveBookmark(
            id: 'bookmark',
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 2),
            title: 'Editable bookmark',
            note: 'Existing note',
            excerpt: 'Original excerpt',
          ),
    );
    await _mountNotebook(tester, container);
    await _entryAction(tester, 'Editable bookmark', '编辑备注');
    await tester.enterText(find.byType(TextField), 'Discard this');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    final unchanged = await tester.runAsync(
      () => container.read(bookmarkRepositoryProvider).getByBook('book-a'),
    );
    expect(unchanged!.single.note, 'Existing note');

    await _entryAction(tester, 'Editable bookmark', '编辑备注');
    await tester.enterText(find.byType(TextField), '  Revised note  ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final revised = await tester.runAsync(
      () => container.read(bookmarkRepositoryProvider).getByBook('book-a'),
    );
    expect(revised!.single.note, 'Revised note');
    expect(find.text('Revised note'), findsOneWidget);

    await _entryAction(tester, 'Editable bookmark', '编辑备注');
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(
      () => container.read(bookmarkRepositoryProvider).getByBook('book-a'),
    );
    expect(saved!.single.id, bookmark!.id);
    expect(saved.single.createdAt, bookmark.createdAt);
    expect(saved.single.title, bookmark.title);
    expect(saved.single.excerpt, bookmark.excerpt);
    expect(saved.single.locator.toJsonText(), bookmark.locator.toJsonText());
    expect(saved.single.note, isNull);
    expect(find.text('Original excerpt'), findsOneWidget);
  });

  notebookTest(
    'annotation editor cancels and preserves text across style rebuilds',
    (tester) async {
      final results = <ReaderAnnotationEditorResult?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  results.add(
                    await showReaderAnnotationEditor(
                      context,
                      initialText: 'Initial quote',
                    ),
                  );
                },
                child: const Text('Edit annotation'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit annotation'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Discard this');
      await tester.tap(find.widgetWithText(ChoiceChip, '绿色'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(results, [null]);

      await tester.tap(find.text('Edit annotation'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Initial quote',
      );
      await tester.enterText(find.byType(TextField), 'Revised quote');
      await tester.tap(find.widgetWithText(ChoiceChip, '紫色'));
      await tester.tap(find.text('下划线'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Revised quote',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(results, hasLength(2));
      expect(results.last!.selectedText, 'Revised quote');
      expect(results.last!.color, AnnotationColor.purple);
      expect(results.last!.style, AnnotationStyle.underline);
    },
  );

  notebookTest('bookmark delete and undo restore identity and source fields', (
    tester,
  ) async {
    final bookmark = await tester.runAsync(
      () => container
          .read(bookmarkRepositoryProvider)
          .saveBookmark(
            id: 'undo-bookmark',
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 7),
            title: 'Undo bookmark',
            note: 'Keep note',
            excerpt: 'Keep excerpt',
          ),
    );
    await _mountNotebook(tester, container);
    await _entryAction(tester, 'Undo bookmark', '删除');
    final deleted = await tester.runAsync(
      () => container.read(bookmarkRepositoryProvider).getByBook('book-a'),
    );
    expect(deleted, isEmpty);
    expect(find.text('Undo bookmark'), findsNothing);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    final restored = await tester.runAsync(
      () => container.read(bookmarkRepositoryProvider).getByBook('book-a'),
    );
    expect(restored!.single.id, bookmark!.id);
    expect(restored.single.title, bookmark.title);
    expect(restored.single.note, bookmark.note);
    expect(restored.single.excerpt, bookmark.excerpt);
    expect(restored.single.locator.toJsonText(), bookmark.locator.toJsonText());
    expect(find.text('Undo bookmark'), findsOneWidget);
  });

  notebookTest('image style editing preserves its anchor and linked note', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await container
          .read(annotationRepositoryProvider)
          .saveAnnotation(
            id: 'image',
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 3),
            selectedText: 'Editable image',
            imageAnchor: _imageAnchor,
          );
      final note = await container
          .read(noteRepositoryProvider)
          .saveNote(
            id: 'linked-note',
            bookId: 'book-a',
            annotationId: 'image',
            content: 'Linked content',
          );
      await container
          .read(annotationRepositoryProvider)
          .linkNote(annotationId: 'image', noteId: note.id);
    });
    await _mountNotebook(tester, container);
    await _entryAction(tester, 'Editable image', '修改样式');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, '绿色'));
    await tester.tap(find.text('下划线'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
      () => container.read(annotationRepositoryProvider).getByBook('book-a'),
    );
    expect(saved!.single.id, 'image');
    expect(saved.single.selectedText, 'Editable image');
    expect(saved.single.color, AnnotationColor.green);
    expect(saved.single.style, AnnotationStyle.underline);
    expect(saved.single.noteId, 'linked-note');
    expect(saved.single.target, AnnotationTarget.image);
    expect(saved.single.imageAnchor!.toJson(), _imageAnchor.toJson());
  });

  notebookTest('annotation comments link once and refresh the Notebook list', (
    tester,
  ) async {
    await tester.runAsync(
      () => container
          .read(annotationRepositoryProvider)
          .saveAnnotation(
            id: 'text',
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 2),
            selectedText: 'Annotation source',
          ),
    );
    await _mountNotebook(tester, container);
    await _entryAction(tester, 'Annotation source', '添加/编辑批注');
    expect(find.text('添加批注'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '第一条批注');
    await tester.tap(find.text('保存批注'));
    await tester.pumpAndSettle();
    expect(find.text('第一条批注'), findsOneWidget);

    await _entryAction(tester, 'Annotation source', '添加/编辑批注');
    await tester.enterText(find.byType(TextFormField), '修改后的批注');
    await tester.tap(find.text('保存批注'));
    await tester.pumpAndSettle();
    final notes = await tester.runAsync(
      () => container.read(noteRepositoryProvider).getByBook('book-a'),
    );
    final annotations = await tester.runAsync(
      () => container.read(annotationRepositoryProvider).getByBook('book-a'),
    );
    expect(notes, hasLength(1));
    expect(notes!.single.annotationId, 'text');
    expect(notes.single.noteType, NoteType.comment);
    expect(notes.single.content, '修改后的批注');
    expect(notes.single.sourceText, 'Annotation source');
    expect(notes.single.locator!.page, 2);
    expect(annotations!.single.noteId, notes.single.id);
  });

  notebookTest('AI notes retain stored context and link the original turn', (
    tester,
  ) async {
    await tester.runAsync(
      () => container
          .read(aiConversationRepositoryProvider)
          .saveConversation(
            id: 'ai-turn',
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 9),
            provider: 'fixture',
            model: 'fixture',
            prompt: 'Saved question',
            answer: 'Saved answer',
            contextText: 'Stored context',
            threadId: 'original-thread',
          ),
    );
    await _mountNotebook(tester, container);
    await _entryAction(tester, 'Saved question', '保存为笔记');
    final notes = await tester.runAsync(
      () => container.read(noteRepositoryProvider).getByBook('book-a'),
    );
    final turns = await tester.runAsync(
      () => container.read(aiConversationRepositoryProvider).getConversations(),
    );
    expect(notes, hasLength(1));
    expect(notes!.single.title, 'Saved question');
    expect(notes.single.content, 'Saved answer');
    expect(notes.single.sourceText, 'Stored context');
    expect(notes.single.noteType, NoteType.ai);
    expect(notes.single.locator!.page, 9);
    expect(turns!.single.id, 'ai-turn');
    expect(turns.single.threadId, 'original-thread');
    expect(turns.single.noteId, notes.single.id);
    expect(find.text('Saved question'), findsNWidgets(2));
  });

  notebookTest(
    'image deletion confirms, drops the cache and keeps linked notes',
    (tester) async {
      await tester.runAsync(() async {
        await container
            .read(annotationRepositoryProvider)
            .saveAnnotation(
              id: 'image',
              bookId: 'book-a',
              locator: ReadingLocator.pdf(page: 3),
              selectedText: 'Delete image',
              imageAnchor: _imageAnchor,
            );
        final note = await container
            .read(noteRepositoryProvider)
            .saveNote(
              id: 'retained-note',
              bookId: 'book-a',
              annotationId: 'image',
              title: 'Retained note',
              content: 'Keep this note',
            );
        await container
            .read(annotationRepositoryProvider)
            .linkNote(annotationId: 'image', noteId: note.id);
      });
      await _mountNotebook(tester, container);
      final linkedAnnotation = await tester.runAsync(
        () => container.read(annotationRepositoryProvider).getByBook('book-a'),
      );
      final linkedComment = await tester.runAsync(
        () => container
            .read(readerAnnotationCommentServiceProvider)
            .commentFor(linkedAnnotation!.single),
      );
      expect(linkedComment, isNull);
      expect(find.text('Keep this note'), findsOneWidget);
      await _entryAction(tester, 'Delete image', '删除');
      expect(find.text('只删除这条标注，关联笔记会保留。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('Delete image'), findsOneWidget);
      expect(cache.deleted, isEmpty);

      await _entryAction(tester, 'Delete image', '删除');
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      final annotations = await tester.runAsync(
        () => container.read(annotationRepositoryProvider).getByBook('book-a'),
      );
      final note = await tester.runAsync(
        () => container.read(noteRepositoryProvider).getNote('retained-note'),
      );
      expect(annotations, isEmpty);
      expect(note!.content, 'Keep this note');
      expect(cache.deleted, hasLength(1));
      expect(cache.deleted.single.bookId, 'book-a');
      expect(cache.deleted.single.anchor.toJson(), _imageAnchor.toJson());
      expect(find.text('Delete image'), findsNothing);
      expect(find.text('Retained note'), findsOneWidget);
    },
  );

  notebookTest('deleting a comment annotation removes its comment note', (
    tester,
  ) async {
    await tester.runAsync(
      () => container
          .read(readerAnnotationCommentServiceProvider)
          .createWithComment(
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 6),
            selectedText: 'Comment source',
            comment: 'Comment body',
          ),
    );
    await _mountNotebook(tester, container);
    await _entryAction(tester, 'Comment source', '删除');
    expect(find.text('删除标注会同时删除这条批注。'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    final annotations = await tester.runAsync(
      () => container.read(annotationRepositoryProvider).getByBook('book-a'),
    );
    final notes = await tester.runAsync(
      () => container.read(noteRepositoryProvider).getByBook('book-a'),
    );
    expect(annotations, isEmpty);
    expect(notes, isEmpty);
  });

  notebookTest(
    'deleting only a comment keeps the annotation and clears its link',
    (tester) async {
      await tester.runAsync(
        () => container
            .read(readerAnnotationCommentServiceProvider)
            .createWithComment(
              bookId: 'book-a',
              locator: ReadingLocator.pdf(page: 7),
              selectedText: 'Keep the mark',
              comment: 'Remove only this',
            ),
      );
      await _mountNotebook(tester, container);
      await _entryAction(tester, 'Keep the mark', '删除批注');
      expect(find.text('只删除批注，保留这条划线。'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '删除批注'));
      await tester.pumpAndSettle();

      final annotations = await tester.runAsync(
        () => container.read(annotationRepositoryProvider).getByBook('book-a'),
      );
      final notes = await tester.runAsync(
        () => container.read(noteRepositoryProvider).getByBook('book-a'),
      );
      expect(annotations, hasLength(1));
      expect(annotations!.single.noteId, isNull);
      expect(notes, isEmpty);
      expect(find.text('Keep the mark'), findsOneWidget);
    },
  );

  notebookTest(
    'note deletion invalidates cached notes only after confirmation',
    (tester) async {
      await tester.runAsync(
        () => container
            .read(noteRepositoryProvider)
            .saveNote(
              id: 'delete-note',
              bookId: 'book-a',
              title: 'Delete note',
              content: 'Note body',
            ),
      );
      await _mountNotebook(tester, container);
      await _entryAction(tester, 'Delete note', '删除');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('Delete note'), findsOneWidget);

      await _entryAction(tester, 'Delete note', '删除');
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(
        () => container.read(noteRepositoryProvider).getByBook('book-a'),
      );
      expect(saved, isEmpty);
      expect(find.text('Delete note'), findsNothing);
      expect(find.text('这本书还没有 Notebook 条目'), findsOneWidget);
    },
  );

  notebookTest('mobile Notebook returns the chosen locator and closes', (
    tester,
  ) async {
    await tester.runAsync(
      () => container
          .read(bookmarkRepositoryProvider)
          .saveBookmark(
            bookId: 'book-a',
            locator: ReadingLocator.pdf(page: 6),
            title: 'Mobile bookmark',
          ),
    );
    ReadingLocator? selected;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<ReadingLocator>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ReaderNotebookSheet(bookId: 'book-a'),
                  );
                },
                child: const Text('Open Notebook'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Notebook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile bookmark'));
    await tester.pumpAndSettle();
    expect(selected!.page, 6);
    expect(find.byType(ReaderNotebookSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _imageAnchor = PdfImageAnchor(
  page: 3,
  ordinal: 2,
  resourceName: 'ImageResource',
  rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
);

Future<void> _mountNotebook(
  WidgetTester tester,
  ProviderContainer container, {
  ValueChanged<ReadingLocator>? onSelected,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _notebookApp(container, onSelected: onSelected ?? (_) {}),
  );
  await tester.pumpAndSettle();
}

Widget _notebookApp(
  ProviderContainer container, {
  String bookId = 'book-a',
  required ValueChanged<ReadingLocator> onSelected,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ReaderNotebookPane(bookId: bookId, onSelected: onSelected),
      ),
    ),
  );
}

Future<void> _entryAction(
  WidgetTester tester,
  String title,
  String action,
) async {
  final titleFinder = find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == title && widget.maxLines == 2,
  );
  final entry = find
      .ancestor(of: titleFinder, matching: find.byType(InkWell))
      .first;
  await tester.tap(
    find.descendant(of: entry, matching: find.byTooltip('Notebook 条目操作')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).hitTestable());
  await tester.pumpAndSettle();
}

final class _RecordingImageCache extends CachedImageStore {
  _RecordingImageCache() : super(appPaths: AppPaths());

  final deleted = <({String bookId, ImageAnchor anchor})>[];

  @override
  Future<void> delete({
    required String bookId,
    required ImageAnchor anchor,
  }) async {
    deleted.add((bookId: bookId, anchor: anchor));
  }
}
