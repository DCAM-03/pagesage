import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_view.dart';

import 'support/canvas_test_helpers.dart';

/// Behavioural tests for the S0 fixes in [PdfCanvasView].
///
/// These run against the real sample PDFs, so they exercise the actual
/// renderer rather than a stand-in. Rasterising needs a frame per page, so
/// every test pumps until the ready event arrives.
/// Turns to the next spread the way a desktop reader does.
///
/// A touch drag would also work on a tablet, but a PDF page owns mouse drags
/// for text selection, and the arrow key is the reliable desktop path.
Future<void> nextSpread(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pumpAndSettle();
}

void main() {
  Book bookFor(String sample) => Book(
    id: 'test',
    title: sample,
    format: BookFormat.pdf,
    libraryFilePath: 'poc_pdf_canvas/samples/$sample',
    fileHash: 'hash',
    fileSize: 0,
    createdAt: 0,
    updatedAt: 0,
  );

  Future<({List<RendererEvent> events, Book book})> pumpReader(
    WidgetTester tester,
    String sample, {
    ReadingLocator? savedLocator,
    int session = 0,
    ReaderSettings settings = const ReaderSettings(),
    Size? viewport,
    PdfZoomChanged? onZoomChanged,
  }) async {
    final events = <RendererEvent>[];
    final book = bookFor(sample);
    if (viewport != null) {
      tester.view.physicalSize = viewport * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
    }
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PdfCanvasView(
                // A fresh key per sample: without it the previous test's state
                // is reused and no new open happens. `session` does the same
                // for a deliberate reopen of the same sample.
                key: ValueKey('$sample#$session'),
                book: book,
                settings: settings,
                initialProgress: savedLocator == null
                    ? null
                    : ReadingProgressSnapshot(
                        bookId: book.id,
                        locator: savedLocator,
                        progress: savedLocator.progress,
                        updatedAt: 0,
                      ),
                annotations: const [],
                onEvent: events.add,
                onZoomChanged: onZoomChanged,
              ),
            ),
          ),
        ),
      );
      // Rasterising a page needs the frame pipeline; pump while real async
      // work (file read, rasterise) drains so the spinner can hand over.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        await Future<void>.delayed(const Duration(milliseconds: 25));
        if (events.whereType<RendererReady>().isNotEmpty) break;
      }
      // Let the post-frame restore and the location timer fire.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    });
    return (events: events, book: book);
  }

  testWidgets('restores the saved page without interaction', (tester) async {
    final result = await pumpReader(
      tester,
      'standard-text.pdf',
      savedLocator: ReadingLocator.pdf(page: 3, progress: 1),
    );

    // Defect 8: the first jump used to run before the PageView existed, so the
    // reader opened on page 1 while reporting page 3.
    final locations = result.events
        .whereType<RendererLocationChanged>()
        .toList();
    expect(locations, isNotEmpty);
    expect(locations.last.pageNumber, 3);
    // And the layout itself must actually be showing page 3: S2 removed the
    // renderer's own pager, so check the page widget rather than its label.
    expect(find.byKey(const ValueKey('pdf-page-2')), findsOneWidget);
  });

  testWidgets('keeps page 40 of an 80-page book after reopening', (
    tester,
  ) async {
    // The plan's S0 regression point: stop at page 40, reopen, exit without
    // touching anything. Progress must still read page 40 — otherwise the
    // first location tick overwrites it with page 1.
    final saved = ReadingLocator.pdf(page: 40, progress: 39 / 79);
    final first = await pumpReader(
      tester,
      'large-text.pdf',
      savedLocator: saved,
    );
    expect(first.events.whereType<RendererReady>(), isNotEmpty);
    expect(find.byKey(const ValueKey('pdf-page-39')), findsOneWidget);
    expect(
      first.events.whereType<RendererLocationChanged>().last.pageNumber,
      40,
    );

    // Reopen from exactly what the first session reported.
    final reopened = await pumpReader(
      tester,
      'large-text.pdf',
      savedLocator: first.events
          .whereType<RendererLocationChanged>()
          .last
          .locator,
      session: 1,
    );
    expect(reopened.events.whereType<RendererReady>(), isNotEmpty);
    expect(find.byKey(const ValueKey('pdf-page-39')), findsOneWidget);
    expect(
      reopened.events.whereType<RendererLocationChanged>().last.pageNumber,
      40,
    );
  });

  testWidgets('reports no text layer for a scanned PDF', (tester) async {
    final result = await pumpReader(tester, 'image-only.pdf');

    final capability = result.events
        .whereType<RendererCapabilityChanged>()
        .last;
    expect(capability.textSelection, isFalse);
    expect(capability.search, isFalse);
    expect(capability.nativeTextLayer, isFalse);
    expect(capability.reason, isNotNull);
  });

  testWidgets('reports a text layer for a text PDF', (tester) async {
    final result = await pumpReader(tester, 'standard-text.pdf');

    final capability = result.events
        .whereType<RendererCapabilityChanged>()
        .last;
    expect(capability.textSelection, isTrue);
    expect(capability.search, isTrue);
    expect(capability.nativeTextLayer, isTrue);
  });

  testWidgets('emits RendererFailed for a broken file', (tester) async {
    await tester.runAsync(() async {
      final events = <RendererEvent>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PdfCanvasView(
                book: bookFor('broken.pdf'),
                settings: const ReaderSettings(),
                initialProgress: null,
                annotations: const [],
                onEvent: events.add,
              ),
            ),
          ),
        ),
      );
      // Parsing happens on the real file system and throws synchronously; give
      // the open future room to complete outside the fake async zone.
      for (
        var i = 0;
        i < 20 && events.whereType<RendererFailed>().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      expect(events.whereType<RendererFailed>(), isNotEmpty);
    });
  });

  testWidgets('opens each sample without throwing', (tester) async {
    final samples =
        Directory('poc_pdf_canvas/samples')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .where((name) => name.endsWith('.pdf'))
            .toList()
          ..sort();
    expect(samples, isNotEmpty);
    for (final sample in samples) {
      if (sample == 'broken.pdf' || sample == 'chinese.pdf') continue;
      final result = await pumpReader(tester, sample);
      expect(
        result.events.whereType<RendererReady>(),
        isNotEmpty,
        reason: '$sample should reach RendererReady',
      );
    }
  });

  group('S1 zoom', () {
    testWidgets('lays the page out at the resolved fit-width scale', (
      tester,
    ) async {
      // 1000px window, 24px margins → (1000 - 48) / 612 per point.
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
      );
      final page = paintedPageRect(tester);
      expect(page, isNotNull);
      expect(page!.width, closeTo(952, 1));
      expect(page.height, closeTo(792 * 952 / 612, 1));
    });

    testWidgets('a custom scale is applied exactly once', (tester) async {
      // The S0 bug this pins: raster density was multiplied by pdfScale while
      // the FittedBox also fitted the page, so custom zoom cropped the page.
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(
          pdfScale: 1.5,
          pdfZoomMode: PdfZoomMode.custom,
        ),
      );
      final page = paintedPageRect(tester);
      expect(page, isNotNull);
      expect(page!.width, closeTo(612 * 1.5, 1));
      expect(page.height, closeTo(792 * 1.5, 1));
    });

    testWidgets('fit-page fits the shorter axis', (tester) async {
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 500),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
      );
      final page = paintedPageRect(tester);
      expect(page, isNotNull);
      // The page box is 500 tall minus the 24px margins. S2 removed the
      // renderer's own bottom pager, so nothing else is subtracted.
      expect(page!.height, closeTo(452, 1));
    });

    testWidgets('a rotated page is laid out landscape', (tester) async {
      await pumpReader(
        tester,
        'rotated-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
      );
      // Display size is 792x612, so the page box's aspect is landscape.
      final page = paintedPageRect(tester, aspect: 792 / 612);
      expect(page, isNotNull);
      expect(page!.width, greaterThan(page.height));
      expect(page.width / page.height, closeTo(792 / 612, 0.01));
    });

    testWidgets('Ctrl+wheel zooms and reports the new scale', (tester) async {
      final zooms = <(double, PdfZoomMode)>[];
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(
          pdfScale: 1.5,
          pdfZoomMode: PdfZoomMode.custom,
        ),
        onZoomChanged: (scale, mode) => zooms.add((scale, mode)),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      addTearDown(() => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft));
      await simulateWheel(tester, const Offset(0, -40));
      await tester.pumpAndSettle();

      expect(zooms, isNotEmpty);
      expect(zooms.last.$1, closeTo(1.6, 0.001));
      expect(zooms.last.$2, PdfZoomMode.custom);
      // And the layout followed for the rest of the session.
      expect(paintedPageRect(tester)!.width, closeTo(612 * 1.6, 1));
    });

    testWidgets('plain wheel turns pages in paged mode', (tester) async {
      // 1000px is wide enough for a spread, so pin the display to single by
      // narrowing the window.
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(800, 900),
        settings: const ReaderSettings(readerMode: ReaderMode.paged),
        savedLocator: ReadingLocator.pdf(page: 1, progress: 0),
      );
      expect(find.byKey(const ValueKey('pdf-page-0')), findsOneWidget);
      await simulateWheel(tester, const Offset(0, 60));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('pdf-page-1')), findsOneWidget);
    });

    testWidgets('a page wider than the viewport pans instead of turning', (
      tester,
    ) async {
      // 2x is wider than the 1000px window, so the wheel must move the page
      // (a mouse drag selects text and cannot pan) rather than turn it.
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(
          pdfScale: 2.0,
          pdfZoomMode: PdfZoomMode.custom,
        ),
      );
      final before = paintedPageRect(tester);
      await simulateWheel(tester, const Offset(60, 0));
      await tester.pump();
      final after = paintedPageRect(tester);
      expect(before, isNotNull);
      expect(after, isNotNull);
      expect(after!.left, lessThan(before!.left));
    });

    testWidgets('remembers the zoom in the reported locator', (tester) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(
          pdfScale: 1.6,
          pdfZoomMode: PdfZoomMode.custom,
        ),
      );
      final location = result.events.whereType<RendererLocationChanged>().last;
      expect(location.locator.zoom, closeTo(1.6, 0.001));
    });
  });

  group('S2 continuous scrolling', () {
    testWidgets('a saved scrollOffset reopens at the same place', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        // Page 2 with 120 logical pixels scrolled into it.
        savedLocator: ReadingLocator.pdf(
          page: 2,
          progress: 0.5,
          scrollOffset: 120,
        ),
      );
      final location = result.events.whereType<RendererLocationChanged>().last;
      expect(location.pageNumber, 2);
      expect(location.locator.scrollOffset, closeTo(120, 1));
      expect(find.byKey(const ValueKey('pdf-page-1')), findsOneWidget);
    });

    testWidgets('scrolling reports the page and its within-page offset', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        savedLocator: ReadingLocator.pdf(page: 1, progress: 0),
      );

      // The page is taller than the 900px viewport at fit-width, so the list
      // scrolls within page 1 before it reaches page 2.
      await tester.drag(
        find.byKey(const ValueKey('pdf-page-0')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));

      final location = result.events.whereType<RendererLocationChanged>().last;
      expect(location.pageNumber, 1);
      expect(location.locator.scrollOffset, greaterThan(0));
    });

    testWidgets('a wheel notch scrolls instead of turning a page', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        savedLocator: ReadingLocator.pdf(page: 1, progress: 0),
      );
      // A page wider than the viewport closes the wheel as pan for S1; at
      // fit-width it becomes a scroll in continuous mode.
      await simulateWheel(tester, const Offset(0, 80));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));

      final locations = result.events
          .whereType<RendererLocationChanged>()
          .toList();
      // Still on page 1, and the reported offset moved.
      expect(locations.last.pageNumber, 1);
      expect(locations.last.locator.scrollOffset, greaterThan(0));
      expect(find.byKey(const ValueKey('pdf-page-0')), findsOneWidget);
    });

    testWidgets('zooming keeps the same fraction of the page in view', (
      tester,
    ) async {
      // Plan step 3: a scale change re-anchors on page + within-page ratio.
      // Without it the list keeps the raw scroll pixels while every page's
      // height changes, and the reader slides to another line.
      final events = <RendererEvent>[];
      final book = bookFor('standard-text.pdf');
      tester.view.physicalSize =
          const Size(1000, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      Widget app(ReaderSettings settings) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PdfCanvasView(
              // Same key both times: this is a settings change, not a reopen,
              // so the reader must keep its place across the rebuild.
              key: const ValueKey('zoom-anchor'),
              book: book,
              settings: settings,
              initialProgress: ReadingProgressSnapshot(
                bookId: book.id,
                locator: ReadingLocator.pdf(
                  page: 2,
                  progress: 0.5,
                  scrollOffset: 120,
                ),
                progress: 0.5,
                updatedAt: 0,
              ),
              annotations: const [],
              onEvent: events.add,
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(app(const ReaderSettings()));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          await Future<void>.delayed(const Duration(milliseconds: 25));
          if (events.whereType<RendererReady>().isNotEmpty) break;
        }
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }

        final page = find.byKey(const ValueKey('pdf-page-1'));
        final beforeTop = tester.getRect(page).top;
        // The page top sits above the viewport, so `-top` is how far into the
        // page the reader has scrolled.
        expect(beforeTop, closeTo(-120, 2));

        await tester.pumpWidget(
          app(
            const ReaderSettings(
              pdfScale: 1.4,
              pdfZoomMode: PdfZoomMode.custom,
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }

        // Page height went from 1124 to 1013 at the smaller scale; keeping the
        // ratio 120/1124 puts the same line at about 108 px into the page.
        final after = tester.getRect(find.byKey(const ValueKey('pdf-page-1')));
        expect(-after.top, closeTo(108, 2));
        final location = events.whereType<RendererLocationChanged>().last;
        expect(location.locator.scrollOffset, closeTo(108, 2));
        expect(location.pageNumber, 2);
      });
    });
  });

  group('S2 paged modes', () {
    testWidgets('a wide window in paged mode shows a spread', (tester) async {
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1200, 900),
        settings: const ReaderSettings(readerMode: ReaderMode.paged),
      );
      // Cover alone, then pages 2 and 3 together.
      expect(find.byKey(const ValueKey('pdf-page-0')), findsOneWidget);
      await nextSpread(tester);
      expect(find.byKey(const ValueKey('pdf-page-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pdf-page-2')), findsOneWidget);
    });

    testWidgets('a narrow window degrades a spread to a single page', (
      tester,
    ) async {
      await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(800, 900),
        settings: const ReaderSettings(readerMode: ReaderMode.paged),
      );
      await nextSpread(tester);
      expect(find.byKey(const ValueKey('pdf-page-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pdf-page-2')), findsNothing);
    });

    testWidgets('a spread reports a zero scrollOffset', (tester) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1200, 900),
        settings: const ReaderSettings(readerMode: ReaderMode.paged),
        savedLocator: ReadingLocator.pdf(
          page: 2,
          progress: 0.5,
          scrollOffset: 200,
        ),
      );
      final location = result.events.whereType<RendererLocationChanged>().last;
      expect(location.pageNumber, 2);
      // A paged layout has no sub-page position to restore.
      expect(location.locator.scrollOffset, 0);
    });
  });
}
