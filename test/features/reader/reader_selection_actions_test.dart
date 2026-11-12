import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/database/drift_note_repository.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/features/reader/application/reader_notebook_providers.dart';
import 'package:pagesage/features/reader/presentation/reader_image_actions.dart';
import 'package:pagesage/features/reader/presentation/reader_page.dart';
import 'package:pagesage/features/reader/presentation/reader_renderer_host.dart';
import 'package:pagesage/features/reader/presentation/reader_selection_actions.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late _DelayedNoteRepository notes;

  setUpAll(() async {
    if (captureWorkbench) await loadWorkbenchCaptureFonts();
  });

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
          format: 'epub',
          libraryFilePath: '/library/$id.epub',
          fileHash: 'hash-$id',
          fileSize: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
    }
    notes = _DelayedNoteRepository(
      DriftNoteRepository(
        database.noteDao,
        DriftSearchRepository(database.searchDao),
      ),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        noteRepositoryProvider.overrideWithValue(notes),
        readerRendererHostProvider.overrideWithValue(
          (config) => _RecordingRenderer(config: config),
        ),
      ],
    );
    await container
        .read(settingsRepositoryProvider)
        .saveReaderSettings(const ReaderSettings(desktopTocOpen: false));
  });

  void selectionTest(
    String description,
    Future<void> Function(WidgetTester) body, {
    Size size = const Size(1280, 900),
  }) {
    testWidgets(description, (tester) async {
      await tester.binding.setSurfaceSize(size);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: const MaterialApp(home: ReaderPage(bookId: 'book-a')),
            ),
          ),
        );
        await tester.runAsync(() async {
          await container.read(bookRepositoryProvider).getBook('book-a');
        });
        await tester.pumpAndSettle();
        expect(find.byType(_RecordingRenderer), findsOneWidget);
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
        await tester.runAsync(database.close);
        await tester.binding.setSurfaceSize(null);
      }
    }, timeout: const Timeout(Duration(seconds: 45)));
  }

  selectionTest('replacement keeps duplicate selection events idempotent', (
    tester,
  ) async {
    _emit(tester, _selection('First passage'));
    await tester.pump();
    _emit(tester, _selection('Second passage'));
    await tester.pump();
    final currentMenu = tester.element(find.text('复制').first);
    final clearVersion = _config(tester).clearSelectionVersion;

    _emit(tester, _selection('Second passage'));
    await tester.pump();

    expect(tester.element(find.text('复制').first), same(currentMenu));
    expect(_config(tester).clearSelectionVersion, clearVersion);
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pump();
    expect(_config(tester).clearSelectionVersion, clearVersion + 1);
  });

  for (final changeFile in [false, true]) {
    selectionTest(
      changeFile
          ? 'same text in another file uses the new source'
          : 'same text at another offset uses the new source',
      (tester) async {
        final first = _selection('Repeated passage', offset: 10);
        final second = _selection(
          'Repeated passage',
          href: changeFile ? 'second.xhtml' : 'chapter.xhtml',
          offset: changeFile ? 10 : 80,
        );
        _emit(tester, first);
        await tester.pump();
        _emit(tester, second);
        await tester.pump();
        await tester.tap(find.text('高亮').first);
        await tester.pump();
        final annotations = await tester.runAsync(
          () =>
              container.read(annotationRepositoryProvider).getByBook('book-a'),
        );
        expect(annotations, hasLength(1));
        expect(
          annotations!.single.locator.toJsonText(),
          second.locator.toJsonText(),
        );
      },
    );
  }

  selectionTest('rectangle jitter keeps the menu and copy preserves paint', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        final arguments = call.arguments;
        if (call.method == 'Clipboard.setData' && arguments is Map) {
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    _emit(tester, _selection('Stable passage'));
    await tester.pump();
    final menu = tester.element(find.text('复制').first);
    final clearVersion = _config(tester).clearSelectionVersion;
    _emit(tester, _selection('Stable passage', x: 122));
    await tester.pump();
    expect(tester.element(find.text('复制').first), same(menu));

    await tester.tap(find.text('复制').first);
    await tester.pumpAndSettle();
    expect(_config(tester).clearSelectionVersion, clearVersion);
    expect(copiedText, 'Stable passage');
  });

  selectionTest('excerpt cancel and save survive dialog exit animations', (
    tester,
  ) async {
    _emit(tester, _selection('Original excerpt', offset: 40));
    await tester.pump();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('笔记'), 'Discarded note');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => notes.getByBook('book-a')), isEmpty);
    expect(tester.takeException(), isNull);

    _emit(tester, _selection('Original excerpt', offset: 40));
    await tester.pump();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('标题'), '  My title  ');
    await tester.enterText(_field('笔记'), '  My note  ');
    await tester.tap(find.text('保存'));
    await tester.pump();
    final saved = await tester.runAsync(() => notes.completed.future);
    await tester.pumpAndSettle();
    expect(saved!.bookId, 'book-a');
    expect(saved.title, 'My title');
    expect(saved.content, 'My note');
    expect(saved.sourceText, 'Original excerpt');
    expect(saved.locator!.chapterOffset, 40);
    expect(saved.noteType, NoteType.excerpt);
    expect(tester.takeException(), isNull);
  });

  selectionTest('empty excerpt content never creates a note', (tester) async {
    _emit(tester, _selection('Original excerpt'));
    await tester.pump();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('笔记'), '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => notes.getByBook('book-a')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  selectionTest('a selection creates a comment that opens from its mark', (
    tester,
  ) async {
    _emit(tester, _selection('Comment source', offset: 24));
    await tester.pump();
    await tester.tap(find.text('批注'));
    await tester.pumpAndSettle();

    expect(find.text('添加批注'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '这里需要再查一下');
    await tester.tap(find.text('保存批注'));
    await tester.pumpAndSettle();

    final annotations = await tester.runAsync(
      () => container.read(annotationRepositoryProvider).getByBook('book-a'),
    );
    final savedNotes = await tester.runAsync(
      () => container.read(noteRepositoryProvider).getByBook('book-a'),
    );
    expect(annotations, hasLength(1));
    expect(savedNotes, hasLength(1));
    expect(savedNotes!.single.noteType, NoteType.comment);
    expect(savedNotes.single.content, '这里需要再查一下');
    expect(savedNotes.single.sourceText, 'Comment source');
    expect(annotations!.single.noteId, savedNotes.single.id);

    _emit(
      tester,
      RendererAnnotationSelected(
        annotations.single.id,
        sourceRect: const ReaderRect(
          page: 1,
          x: 120,
          y: 200,
          width: 200,
          height: 24,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('这里需要再查一下'), findsOneWidget);
    expect(find.text('编辑批注'), findsOneWidget);
    expect(find.text('删除批注'), findsOneWidget);
    for (final label in ['编辑批注', '删除批注']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length),
        ),
        hasLength(1),
        reason: '批注操作应保持完整文字，按钮整体换行',
      );
    }
    expect(find.byTooltip('删除标注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  selectionTest('saving after reader removal refreshes the original notebook', (
    tester,
  ) async {
    final before = await tester.runAsync(
      () => container.read(notesByBookProvider('book-a').future),
    );
    expect(before, isEmpty);
    await tester.runAsync(
      () => container.read(notesByBookProvider('book-b').future),
    );
    notes.saveBarrier = Completer<void>();
    _emit(tester, _selection('Original excerpt', offset: 20));
    await tester.pump();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('笔记'), 'Saved after leaving');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      notes.saveBarrier!.complete();
      await notes.completed.future;
    });
    await tester.pump();

    expect(
      await tester.runAsync(
        () => container.read(notesByBookProvider('book-a').future),
      ),
      hasLength(1),
    );
    expect(
      await tester.runAsync(
        () => container.read(notesByBookProvider('book-b').future),
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  selectionTest(
    'mobile selection replacement updates one sheet and its source',
    (tester) async {
      _emit(tester, _selection('First passage', offset: 10));
      await tester.pumpAndSettle();
      _emit(tester, _selection('Latest passage', offset: 80));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
      expect(find.text('Latest passage'), findsOneWidget);
      expect(find.text('First passage', skipOffstage: false), findsNothing);
      await tester.tap(find.text('高亮'));
      await tester.pumpAndSettle();
      final annotations = await tester.runAsync(
        () => container.read(annotationRepositoryProvider).getByBook('book-a'),
      );
      expect(annotations, hasLength(1));
      expect(annotations!.single.selectedText, 'Latest passage');
      expect(annotations.single.locator.chapterOffset, 80);
      expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
    },
    size: const Size(390, 844),
  );

  selectionTest(
    'mobile dismissal clears paint and excerpt saves with a cleared title',
    (tester) async {
      final before = _config(tester).clearSelectionVersion;
      _emit(tester, _selection('Mobile passage', offset: 60));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭选择操作'));
      await tester.pumpAndSettle();
      expect(_config(tester).clearSelectionVersion, before + 1);

      _emit(tester, _selection('Mobile passage', offset: 60));
      await tester.pumpAndSettle();
      await tester.tap(find.text('笔记').last);
      await tester.pumpAndSettle();
      await tester.enterText(_field('标题'), '  ');
      await tester.enterText(_field('笔记'), 'Mobile note');
      await tester.tap(find.text('保存'));
      await tester.pump();
      final saved = await tester.runAsync(() => notes.completed.future);
      await tester.pumpAndSettle();
      expect(saved!.title, isNull);
      expect(saved.content, 'Mobile note');
      expect(saved.sourceText, 'Mobile passage');
      expect(saved.locator!.chapterOffset, 60);
      expect(tester.takeException(), isNull);
    },
    size: const Size(390, 844),
  );

  for (final mobile in [false, true]) {
    selectionTest(
      mobile
          ? 'mobile action surface wraps and returns each requested action'
          : 'desktop action surface returns each requested action',
      (tester) async {
        final actions = <ReaderSelectionAction>[];
        var dismissals = 0;
        final selected = _selection('A long selection with a clear source');
        await tester.pumpWidget(
          _surface(
            mobile
                ? ReaderSelectionActionSurface(
                    selection: selected,
                    compact: true,
                    onAction: actions.add,
                    onDismiss: () => dismissals++,
                  )
                : DesktopReaderSelectionOverlay(
                    selection: selected,
                    onAction: actions.add,
                    onDismiss: () => dismissals++,
                  ),
            mobile: mobile,
          ),
        );
        await tester.pumpAndSettle();
        for (final entry in {
          '高亮': ReaderSelectionAction.highlight,
          '下划线': ReaderSelectionAction.underline,
          '批注': ReaderSelectionAction.comment,
          '笔记': ReaderSelectionAction.note,
          '复制': ReaderSelectionAction.copy,
          '搜索': ReaderSelectionAction.search,
          'AI': ReaderSelectionAction.ai,
        }.entries) {
          await tester.tap(find.text(entry.key));
          expect(actions.last, entry.value);
        }
        await tester.tap(find.byTooltip(mobile ? '关闭选择操作' : '关闭'));
        expect(dismissals, 1);
        expect(actions, hasLength(7));
        await tester.pumpAndSettle();
        await captureWorkbenchWidget(
          tester,
          mobile ? 'selection-mobile' : 'selection-desktop',
        );
        expect(tester.takeException(), isNull);
      },
      size: mobile ? const Size(390, 844) : const Size(1280, 900),
    );
  }

  selectionTest('image actions disable caption copy only when absent', (
    tester,
  ) async {
    final actions = <ReaderImageAction>[];
    for (final hasCaption in [false, true]) {
      actions.clear();
      await tester.pumpWidget(
        _surface(
          ReaderImageActionOverlay(
            hasCaption: hasCaption,
            onAction: actions.add,
            onDismiss: () {},
          ),
        ),
      );
      await tester.tap(find.text('复制图注'));
      expect(actions, hasCaption ? [ReaderImageAction.copyCaption] : isEmpty);
      await tester.tap(find.text('注释此图'));
      expect(actions.last, ReaderImageAction.annotate);
      await tester.tap(find.text('保存图片'));
      expect(actions.last, ReaderImageAction.save);
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _surface(Widget child, {bool mobile = false}) {
  return MediaQuery(
    data: MediaQueryData(
      size: mobile ? const Size(390, 844) : const Size(1280, 900),
      textScaler: TextScaler.linear(mobile ? 1.4 : 1),
    ),
    child: MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: workbenchCaptureKey,
          child: Material(child: Center(child: child)),
        ),
      ),
    ),
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

ReaderRendererHostConfig _config(WidgetTester tester) =>
    tester.widget<_RecordingRenderer>(find.byType(_RecordingRenderer)).config;

void _emit(WidgetTester tester, RendererEvent event) {
  _config(tester).onEvent(event);
}

RendererTextSelected _selection(
  String text, {
  String href = 'chapter.xhtml',
  int offset = 0,
  double x = 120,
}) {
  return RendererTextSelected(
    text: text,
    locator: ReadingLocator.epub(
      href: href,
      chapterIndex: 0,
      chapterOffset: offset,
      chapterEndOffset: offset + text.length,
      progress: 0.2,
      excerpt: text,
    ),
    sourceRect: ReaderRect(page: 1, x: x, y: 200, width: 200, height: 24),
  );
}

final class _RecordingRenderer extends StatelessWidget {
  const _RecordingRenderer({required this.config});

  final ReaderRendererHostConfig config;

  @override
  Widget build(BuildContext context) => const Center(child: Text('Reader'));
}

final class _DelayedNoteRepository implements NoteRepository {
  _DelayedNoteRepository(this._inner);

  final NoteRepository _inner;
  final completed = Completer<Note>();
  Completer<void>? saveBarrier;

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
    await saveBarrier?.future;
    final note = await _inner.saveNote(
      id: id,
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: locator,
      noteType: noteType,
    );
    completed.complete(note);
    return note;
  }

  @override
  Stream<List<Note>> watchNotes() => _inner.watchNotes();

  @override
  Future<List<Note>> getNotes() => _inner.getNotes();

  @override
  Future<List<Note>> getByBook(String bookId) => _inner.getByBook(bookId);

  @override
  Future<Set<String>> getBookIdsWithNotes() => _inner.getBookIdsWithNotes();

  @override
  Future<Note?> getNote(String id) => _inner.getNote(id);

  @override
  Future<void> deleteNote(String id) => _inner.deleteNote(id);
}
