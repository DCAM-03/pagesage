import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/book_document_loader.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_document_loader.dart';
import 'package:pagesage/renderers/epub/epub_paginator.dart' as pagination;
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';

import '../../support/reader_workbench_capture.dart';

const _book = Book(
  id: 'large-navigation',
  title: '章节跳转测试',
  format: BookFormat.epub,
  libraryFilePath: '/unused.epub',
  fileHash: 'navigation',
  fileSize: 1,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  final document = _largeDocument();

  testWidgets('distant chapter jump builds and reports the actual target', (
    tester,
  ) async {
    final events = <RendererEvent>[];
    final loader = _DocumentLoader(document);
    await _pumpReader(tester, loader: loader, events: events);
    await tester.pumpAndSettle();
    events.clear();

    final watch = Stopwatch()..start();
    await _pumpReader(
      tester,
      loader: loader,
      events: events,
      chapterIndex: 370,
      jumpToken: 1,
    );
    await tester.pumpAndSettle();
    watch.stop();

    expect(find.textContaining('chapter-370-paragraph-0 '), findsOneWidget);
    expect(
      events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
      370,
    );
    expect(loader.loads, 1);
    debugPrint('synthetic_distant_jump_ms=${watch.elapsedMilliseconds}');
  });

  testWidgets(
    'restores a distant paragraph without rendering earlier chapters',
    (tester) async {
      final events = <RendererEvent>[];
      final loader = _DocumentLoader(document);
      final offset = document.chapters[320].blocks[16].startOffset;
      await _pumpReader(
        tester,
        loader: loader,
        events: events,
        chapterIndex: 320,
        chapterOffset: offset,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('chapter-320-paragraph-16 '), findsOneWidget);
      expect(find.textContaining('chapter-0-paragraph-0 '), findsNothing);
      final location = events.whereType<RendererLocationChanged>().last;
      expect(location.locator.chapterIndex, 320);
      expect(location.locator.chapterOffset, offset);
    },
  );

  testWidgets('latest chapter jump wins while earlier callbacks are pending', (
    tester,
  ) async {
    final events = <RendererEvent>[];
    final loader = _DocumentLoader(document);
    await _pumpReader(tester, loader: loader, events: events);
    await tester.pumpAndSettle();

    await _pumpReader(
      tester,
      loader: loader,
      events: events,
      chapterIndex: 370,
      jumpToken: 1,
    );
    events.clear();
    await _pumpReader(
      tester,
      loader: loader,
      events: events,
      chapterIndex: 11,
      jumpToken: 2,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('chapter-11-paragraph-0 '), findsOneWidget);
    expect(
      events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
      11,
    );
  });

  testWidgets('chapter shortcut lands on the next chapter in continuous mode', (
    tester,
  ) async {
    final events = <RendererEvent>[];
    await _pumpReader(
      tester,
      loader: _DocumentLoader(document),
      events: events,
      chapterIndex: 320,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.textContaining('chapter-321-paragraph-0 '), findsOneWidget);
    expect(
      events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
      321,
    );
  });

  testWidgets('can scroll before and after a distant chapter anchor', (
    tester,
  ) async {
    final events = <RendererEvent>[];
    await _pumpReader(
      tester,
      loader: _DocumentLoader(document),
      events: events,
      chapterIndex: 319,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('chapter-318-paragraph-23 '),
      -400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
      318,
    );

    await tester.scrollUntilVisible(
      find.textContaining('chapter-319-paragraph-0 '),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('chapter-319-paragraph-0 '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'type and mode changes retain the chapter reached by navigation',
    (tester) async {
      final events = <RendererEvent>[];
      final loader = _DocumentLoader(document);
      await _pumpReader(
        tester,
        loader: loader,
        events: events,
        chapterIndex: 319,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      const settings = ReaderSettings(fontSize: 22, reduceMotion: true);
      for (final next in [
        settings,
        settings.copyWith(readerMode: ReaderMode.paged),
        settings,
      ]) {
        events.clear();
        await _pumpReader(
          tester,
          loader: loader,
          events: events,
          chapterIndex: 319,
          settings: next,
        );
        await tester.pumpAndSettle();
        expect(
          events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
          318,
        );
      }
      expect(loader.loads, 1);
    },
  );

  testWidgets('changing files does not reuse the previous chapter anchor', (
    tester,
  ) async {
    final events = <RendererEvent>[];
    await _pumpReader(
      tester,
      loader: _DocumentLoader(document),
      events: events,
      chapterIndex: 370,
    );
    await tester.pumpAndSettle();
    final pending = _DeferredLoader();
    await _pumpReader(
      tester,
      loader: pending,
      events: events,
      documentPath: '/next.epub',
    );
    expect(find.textContaining('chapter-370-paragraph-0 '), findsNothing);
    pending.document.complete(
      EpubDocument(chapters: [_chapter(0), _chapter(1)]),
    );
    events.clear();
    await tester.pumpAndSettle();
    expect(find.textContaining('chapter-0-paragraph-0 '), findsOneWidget);
    expect(
      events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('first paged frame only measures the requested chapter', (
    tester,
  ) async {
    final initialBlocks = _CountingBlocks(_chapter(0).blocks);
    final targetBlocks = _CountingBlocks(_chapter(1).blocks);
    final pagedDocument = EpubDocument(
      chapters: [
        _chapterWithBlocks(0, initialBlocks),
        _chapterWithBlocks(1, targetBlocks),
      ],
    );
    final events = <RendererEvent>[];
    await _pumpReader(
      tester,
      loader: _DocumentLoader(pagedDocument),
      events: events,
      chapterIndex: 1,
      settings: const ReaderSettings(
        readerMode: ReaderMode.paged,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(initialBlocks.reads, 0);
    expect(targetBlocks.reads, greaterThan(0));
    expect(
      events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
      1,
    );
  });

  testWidgets('paged layout width changes preserve the current text anchor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final events = <RendererEvent>[];
    const settings = ReaderSettings(
      readerMode: ReaderMode.paged,
      reduceMotion: true,
    );
    const chapterIndex = 320;
    await _pumpReader(
      tester,
      loader: _DocumentLoader(document),
      events: events,
      chapterIndex: chapterIndex,
      chapterOffset: document.chapters[chapterIndex].blocks[32].startOffset,
      settings: settings,
    );
    await tester.pumpAndSettle();

    for (final width in [620.0, 1100.0, 720.0]) {
      final anchor = events.whereType<RendererLocationChanged>().last;
      await tester.binding.setSurfaceSize(Size(width, 700));
      await tester.pumpAndSettle();
      final pages = const pagination.EpubPaginator().paginateChapter(
        chapter: document.chapters[chapterIndex],
        settings: settings,
        viewport: Size(width, 700),
        globalOffset: document.chapters
            .take(chapterIndex)
            .fold(0, (sum, chapter) => sum + chapter.text.length),
        totalLength: document.totalTextLength,
      );
      final pageView = tester.widget<PageView>(find.byType(PageView));
      final currentPage = pages[pageView.controller!.page!.round()];
      expect(currentPage.chapter.index, chapterIndex);
      expect(
        currentPage.startOffset,
        lessThanOrEqualTo(anchor.locator.chapterOffset!),
      );
      expect(
        currentPage.endOffset,
        greaterThanOrEqualTo(anchor.locator.chapterOffset!),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'paged chapter navigation retains measurements until type changes',
    (tester) async {
      final blocks = _CountingBlocks(_chapter(1).blocks);
      final pagedDocument = EpubDocument(
        chapters: [_chapter(0), _chapterWithBlocks(1, blocks), _chapter(2)],
      );
      final loader = _DocumentLoader(pagedDocument);
      final events = <RendererEvent>[];
      const settings = ReaderSettings(
        readerMode: ReaderMode.paged,
        reduceMotion: true,
      );
      await _pumpReader(
        tester,
        loader: loader,
        events: events,
        chapterIndex: 1,
        settings: settings,
      );
      await tester.pumpAndSettle();
      final measuredReads = blocks.reads;
      expect(measuredReads, greaterThan(0));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        events.whereType<RendererLocationChanged>().last.locator.chapterIndex,
        1,
      );
      expect(blocks.reads, measuredReads);

      await _pumpReader(
        tester,
        loader: loader,
        events: events,
        chapterIndex: 1,
        settings: settings.copyWith(themePreset: ReaderThemePreset.night),
      );
      await tester.pumpAndSettle();
      expect(blocks.reads, measuredReads);

      await _pumpReader(
        tester,
        loader: loader,
        events: events,
        chapterIndex: 1,
        settings: settings.copyWith(fontSize: 22),
      );
      await tester.pumpAndSettle();
      expect(blocks.reads, greaterThan(measuredReads));
    },
  );

  testWidgets('distant chapter layout remains readable after navigation', (
    tester,
  ) async {
    if (captureWorkbench) {
      await tester.runAsync(loadWorkbenchCaptureFonts);
      await tester.binding.setSurfaceSize(const Size(1100, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    final events = <RendererEvent>[];
    await _pumpReader(
      tester,
      loader: _DocumentLoader(document),
      events: events,
      chapterIndex: 319,
    );
    await tester.pumpAndSettle();
    final target = find.textContaining('chapter-319-paragraph-0 ');
    expect(target, findsOneWidget);
    final reader = tester.getRect(find.byType(EpubRendererView));
    final paragraph = tester.getRect(target);
    expect(paragraph.left, greaterThanOrEqualTo(reader.left + 20));
    expect(paragraph.right, lessThanOrEqualTo(reader.right - 20));
    expect(paragraph.top, greaterThanOrEqualTo(reader.top));
    expect(paragraph.top, lessThan(reader.bottom));
    await captureWorkbenchWidget(tester, 'epub-distant-chapter');
    expect(tester.takeException(), isNull);
  });

  const sample = String.fromEnvironment('EPUB_NAVIGATION_SAMPLE');
  testWidgets(
    'real EPUB navigation benchmark',
    (tester) async {
      expect(File(sample).existsSync(), isTrue);
      await tester.runAsync(loadWorkbenchCaptureFonts);
      final loadWatch = Stopwatch()..start();
      final realDocument = await tester.runAsync(
        () => const EpubDocumentLoader().load(sample),
      );
      loadWatch.stop();
      expect(realDocument, isNotNull);
      final loaded = realDocument!;
      final loader = _DocumentLoader(loaded);
      final events = <RendererEvent>[];
      debugPrint(
        'sample_metrics chapters=${loaded.chapters.length} '
        'characters=${loaded.totalTextLength} '
        'load_ms=${loadWatch.elapsedMilliseconds}',
      );
      await _pumpReader(tester, loader: loader, events: events);
      await tester.pumpAndSettle();
      final targets = [
        loaded.chapters.length ~/ 7,
        loaded.chapters.length ~/ 2,
        loaded.chapters.length - 4,
        loaded.chapters.length ~/ 7,
      ];
      for (var index = 0; index < targets.length; index++) {
        final target = targets[index];
        events.clear();
        final watch = Stopwatch()..start();
        await _pumpReader(
          tester,
          loader: loader,
          events: events,
          chapterIndex: target,
          jumpToken: index + 1,
        );
        await tester.pumpAndSettle();
        watch.stop();
        final actual = events
            .whereType<RendererLocationChanged>()
            .last
            .locator
            .chapterIndex;
        debugPrint(
          'sample_jump target=$target actual=$actual '
          'elapsed_ms=${watch.elapsedMilliseconds}',
        );
        expect(actual, target);
      }
      expect(loader.loads, 1);
    },
    skip: sample.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required BookDocumentLoader loader,
  required List<RendererEvent> events,
  int chapterIndex = 0,
  int chapterOffset = 0,
  int jumpToken = 0,
  String? documentPath,
  ReaderSettings settings = const ReaderSettings(reduceMotion: true),
}) {
  return tester.pumpWidget(
    RepaintBoundary(
      key: workbenchCaptureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: EpubRendererView(
            book: _book,
            settings: settings,
            initialProgress: ReadingProgressSnapshot(
              bookId: _book.id,
              locator: ReadingLocator.epub(
                chapterIndex: chapterIndex,
                chapterOffset: chapterOffset,
              ),
              progress: 0,
              updatedAt: 0,
            ),
            jumpToken: jumpToken,
            annotations: const [],
            onEvent: events.add,
            documentLoader: loader,
            documentPath: documentPath,
          ),
        ),
      ),
    ),
  );
}

EpubChapter _chapterWithBlocks(int index, List<EpubBlock> blocks) {
  final chapter = _chapter(index);
  return EpubChapter(
    index: chapter.index,
    href: chapter.href,
    title: chapter.title,
    text: chapter.text,
    blocks: blocks,
  );
}

final class _CountingBlocks extends ListBase<EpubBlock> {
  _CountingBlocks(this.blocks);

  final List<EpubBlock> blocks;
  int reads = 0;

  @override
  int get length => blocks.length;

  @override
  set length(int value) => throw UnsupportedError('immutable blocks');

  @override
  EpubBlock operator [](int index) {
    reads++;
    return blocks[index];
  }

  @override
  void operator []=(int index, EpubBlock value) {
    throw UnsupportedError('immutable blocks');
  }
}

EpubDocument _largeDocument() {
  return EpubDocument(
    chapters: [
      for (var chapterIndex = 0; chapterIndex < 400; chapterIndex++)
        _chapter(chapterIndex),
    ],
  );
}

EpubChapter _chapter(int chapterIndex) {
  final blocks = <EpubBlock>[];
  final text = StringBuffer();
  final paragraphs = chapterIndex % 5 == 0 ? 80 : 24;
  for (var paragraph = 0; paragraph < paragraphs; paragraph++) {
    if (text.isNotEmpty) text.write('\n\n');
    final start = text.length;
    final content =
        'chapter-$chapterIndex-paragraph-$paragraph '
        '${List.filled(chapterIndex % 7 + 1, 'paragraph content for navigation. ').join()}';
    text.write(content);
    blocks.add(
      EpubTextBlock(
        startOffset: start,
        endOffset: text.length,
        text: content,
        type: EpubBlockType.paragraph,
      ),
    );
  }
  return EpubChapter(
    index: chapterIndex,
    href: 'chapter-$chapterIndex.xhtml',
    title: 'Chapter $chapterIndex',
    text: text.toString(),
    blocks: blocks,
  );
}

final class _DocumentLoader implements BookDocumentLoader {
  _DocumentLoader(this.document);

  final EpubDocument document;
  int loads = 0;

  @override
  Future<EpubDocument> load(String filePath) async {
    loads++;
    return document;
  }
}

final class _DeferredLoader implements BookDocumentLoader {
  final document = Completer<EpubDocument>();

  @override
  Future<EpubDocument> load(String filePath) => document.future;
}
