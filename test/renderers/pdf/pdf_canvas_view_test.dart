import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/annotations/image_anchor.dart';
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

/// A painted page box for [sample], found by its aspect ratio.
///
/// Matches the page's `CustomPaint` rather than a widget type: the page is
/// painted by a painter whose non-null painter and aspect ratio identify it
/// among the reader's chrome.
Rect pageBox(WidgetTester tester, {double aspect = 612 / 792}) {
  Rect? best;
  for (final element in find.byType(CustomPaint).evaluate()) {
    final widget = element.widget as CustomPaint;
    if (widget.painter == null) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    if (box.size.width < 100 || box.size.height < 100) continue;
    final ratio = box.size.width / box.size.height;
    if ((ratio - aspect).abs() > 0.01) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (best == null || rect.width * rect.height > best.width * best.height) {
      best = rect;
    }
  }
  return best!;
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

  Future<
    ({List<RendererEvent> events, Book book, ValueNotifier<int> clearSelection})
  >
  pumpReader(
    WidgetTester tester,
    String sample, {
    ReadingLocator? savedLocator,
    int session = 0,
    ReaderSettings settings = const ReaderSettings(),
    Size? viewport,
    PdfZoomChanged? onZoomChanged,
    int clearSelectionVersion = 0,
    String? searchQuery,
    bool imageDragMode = false,
    List<Annotation> annotations = const [],
    int? ocrOverlayPage,
    List<Map<String, Object?>> ocrOverlayBlocks = const [],
    void Function(RendererImageAreaSelected area)? onImageAreaSelected,
  }) async {
    final events = <RendererEvent>[];
    // The host clears the paint by bumping this; exposed so tests can do the
    // same without rebuilding the whole reader page.
    final clearSelection = ValueNotifier<int>(clearSelectionVersion);
    addTearDown(clearSelection.dispose);
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
              body: ValueListenableBuilder<int>(
                valueListenable: clearSelection,
                builder: (context, clearVersion, _) => PdfCanvasView(
                  // A fresh key per sample: without it the previous test's
                  // state is reused and no new open happens. `session` does
                  // the same for a deliberate reopen of the same sample.
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
                  annotations: annotations,
                  ocrOverlayPage: ocrOverlayPage,
                  ocrOverlayBlocks: ocrOverlayBlocks,
                  onEvent: events.add,
                  onZoomChanged: onZoomChanged,
                  clearSelectionVersion: clearVersion,
                  searchQuery: searchQuery,
                  imageDragMode: imageDragMode,
                  onImageAreaSelected: onImageAreaSelected,
                ),
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
    return (events: events, book: book, clearSelection: clearSelection);
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

  testWidgets('an OCR overlay enables selection without claiming search', (
    tester,
  ) async {
    final result = await pumpReader(
      tester,
      'image-only.pdf',
      viewport: const Size(1000, 900),
      ocrOverlayPage: 1,
      ocrOverlayBlocks: const [
        {
          'text': 'Scanned line text',
          'left': 0.1,
          'top': 0.1,
          'width': 0.6,
          'height': 0.05,
        },
      ],
    );

    final capability = result.events
        .whereType<RendererCapabilityChanged>()
        .last;
    expect(capability.textSelection, isTrue);
    expect(capability.search, isFalse);
    expect(capability.nativeTextLayer, isFalse);
    expect(capability.ocrTextLayer, isTrue);
    expect(capability.reason, isNull);
  });

  testWidgets('a tap on an OCR line emits the standard selection event', (
    tester,
  ) async {
    final result = await pumpReader(
      tester,
      'image-only.pdf',
      viewport: const Size(1000, 900),
      ocrOverlayPage: 1,
      ocrOverlayBlocks: const [
        {
          'text': 'Scanned line text',
          'left': 0.1,
          'top': 0.1,
          'width': 0.6,
          'height': 0.05,
        },
      ],
    );
    final rect = pageBox(tester);
    await tester.runAsync(() async {
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.22, rect.top + rect.height * 0.125),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    final selection = result.events.whereType<RendererTextSelected>().last;
    expect(selection.text, 'Scanned');
    expect(selection.locator.page, 1);
    expect(selection.locator.excerpt, 'Scanned');
    expect(selection.selectionRects, isNotEmpty);
    expect(selection.selectionRects.first.page, 1);
    expect(selection.sourceRect, isNotNull);
    expect(selection.sourceRect!.x, greaterThan(rect.left));
    expect(selection.sourceRect!.width, greaterThan(1));
  });

  testWidgets('a drag across OCR lines selects both lines', (tester) async {
    final result = await pumpReader(
      tester,
      'image-only.pdf',
      viewport: const Size(1000, 900),
      ocrOverlayPage: 1,
      ocrOverlayBlocks: const [
        {
          'text': 'Scanned line text',
          'left': 0.1,
          'top': 0.1,
          'width': 0.6,
          'height': 0.05,
        },
        {
          'text': 'Second OCR line',
          'left': 0.1,
          'top': 0.2,
          'width': 0.6,
          'height': 0.05,
        },
      ],
    );
    final rect = pageBox(tester);
    final start = Offset(
      rect.left + rect.width * 0.11,
      rect.top + rect.height * 0.125,
    );
    final delta = Offset(rect.width * 0.39, rect.height * 0.1);
    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 1; i <= 20; i++) {
        await gesture.moveTo(start + delta * (i / 20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    final selection = result.events.whereType<RendererTextSelected>().last;
    expect(selection.text, contains('Scanned'));
    expect(selection.text, contains('Second OCR'));
    expect(selection.selectionRects, hasLength(2));
    expect({for (final r in selection.selectionRects) r.page}, {1});
  });

  testWidgets('a stored annotation on an OCR page stays clickable', (
    tester,
  ) async {
    final annotation = Annotation(
      id: 'ocr-annotation',
      bookId: 'test',
      locator: ReadingLocator.pdf(
        page: 1,
        selectionRects: [
          ReaderRect(page: 1, x: 0.1, y: 0.1, width: 0.6, height: 0.05),
        ],
      ),
      selectedText: 'Scanned line text',
      color: AnnotationColor.yellow,
      style: AnnotationStyle.highlight,
      createdAt: 0,
      updatedAt: 0,
    );
    final result = await pumpReader(
      tester,
      'image-only.pdf',
      viewport: const Size(1000, 900),
      annotations: [annotation],
      ocrOverlayPage: 1,
      ocrOverlayBlocks: const [
        {
          'text': 'Scanned line text',
          'left': 0.1,
          'top': 0.1,
          'width': 0.6,
          'height': 0.05,
        },
      ],
    );
    final rect = pageBox(tester);
    await tester.runAsync(() async {
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.4, rect.top + rect.height * 0.125),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    final selected = result.events.whereType<RendererAnnotationSelected>().last;
    expect(selected.annotationId, 'ocr-annotation');
    expect(selected.sourceRect, isNotNull);
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
      expect(location.locator.pageOffsetFraction, isNotNull);
      expect(location.locator.pageOffsetFraction, greaterThan(0));
      expect(location.locator.pageOffsetFraction, lessThanOrEqualTo(1));
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

  group('S3 selection', () {
    /// Drags with a mouse pointer from [from] by [delta], in steps.
    Future<void> dragBy(
      WidgetTester tester,
      Offset from,
      Offset delta, {
      int steps = 24,
    }) async {
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 1; i <= steps; i++) {
        await gesture.moveTo(from + delta * (i / steps));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('a mouse drag selects a range of text', (tester) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      // First line's baseline area at fit-width.
      final lineY = rect.top + (792 - 733) * scale;
      await tester.runAsync(() async {
        await dragBy(
          tester,
          Offset(rect.left + 76 * scale, lineY),
          Offset(80 * scale, 0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final selections = result.events.whereType<RendererTextSelected>();
      expect(selections, isNotEmpty);
      expect(selections.last.text, startsWith('PageSage'));
      // Rects are stored normalised, one band per selected line.
      for (final r in selections.last.selectionRects) {
        expect(r.x, inInclusiveRange(0, 1));
        expect(r.y, inInclusiveRange(0, 1));
        expect(r.page, 1);
      }
    });

    testWidgets('a tap selects the whole word under the pointer', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        await tester.tapAt(
          Offset(rect.left + 80 * scale, rect.top + (792 - 733) * scale),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final selection = result.events.whereType<RendererTextSelected>().last;
      // "PageSage" starts at 72pt; a tap 8pt into it must not stop at "P".
      expect(selection.text, 'PageSage');
    });

    testWidgets('a cross-page drag lists rects on both pages', (tester) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
      );
      // Start in page 1's body, drag far enough to reach page 2's text.
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      final start = Offset(
        rect.left + 76 * scale,
        rect.top + (792 - 700) * scale,
      );
      await tester.runAsync(() async {
        await dragBy(tester, start, const Offset(0, 1400), steps: 40);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      final selection = result.events.whereType<RendererTextSelected>().last;
      final pages = {for (final r in selection.selectionRects) r.page};
      expect(pages.length, greaterThanOrEqualTo(2));
      expect(selection.text, contains('PageSage'));
    });

    testWidgets('a drag held below the window keeps scrolling', (tester) async {
      // The drag runs off the bottom of the viewport, which is exactly when
      // the view has to follow. It used to animate half a screen per pointer
      // move; a move event arrives every frame, each animation was cancelled
      // by the next, and the list never advanced — so the caret stayed on
      // page 1 and the drag could not reach page 2 at all.
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      final start = Offset(
        rect.left + 76 * scale,
        rect.top + (792 - 700) * scale,
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, 0);

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        for (var i = 1; i <= 40; i++) {
          // Long past the 900px viewport bottom, as a reader dragging to the
          // next page does.
          await gesture.moveTo(start + Offset(0, 1400 * (i / 40)));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 200));
      });

      expect(scrollable.position.pixels, greaterThan(0));
      expect(result.events.whereType<RendererTextSelected>(), isNotEmpty);
    });

    testWidgets('a scanned page says there is no selectable text', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'image-only.pdf',
        viewport: const Size(1000, 900),
      );
      final rect = pageBox(tester);
      await tester.runAsync(() async {
        await dragBy(tester, rect.center, const Offset(120, 0));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
      // A non-text document must say so rather than silently swallow the
      // gesture, per the interaction spec §8.3.
      expect(
        result.events.whereType<RendererNotice>().map((n) => n.message),
        contains('此 PDF 没有可选择文本'),
      );
      expect(result.events.whereType<RendererTextSelected>(), isEmpty);
    });

    testWidgets('a tap on a CJK page selects exactly one character', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'chinese-embedded.pdf',
        viewport: const Size(1000, 900),
      );
      // The document is A4 (595x842); fit-width makes it taller than the
      // window, so aim at the title line near the top of the page.
      final rect = pageBox(tester, aspect: 595 / 842);
      final scale = rect.width / 595;
      await tester.runAsync(() async {
        await tester.tapAt(
          Offset(rect.left + 60 * scale, rect.top + 58 * scale),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final selection = result.events.whereType<RendererTextSelected>().last;
      // "嵌" is the first character of the title 嵌入字体渲染测试. Selecting
      // the whole run would mean the CJK word splitter fell back to Latin
      // rules, which have no spaces to stop at.
      expect(selection.text.length, 1);
      expect('嵌入字体渲染测试', contains(selection.text));
      expect(selection.selectionRects, isNotEmpty);
    });

    testWidgets('a rotated page reports rects against the displayed box', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'rotated-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
      );
      // /Rotate 90 on a 612x792 page means the displayed box is 792x612.
      // The body line runs vertically in display space, at ~90.3% of the
      // box width; drag down its length.
      final rect = pageBox(tester, aspect: 792 / 612);
      await tester.runAsync(() async {
        await dragBy(
          tester,
          Offset(
            rect.left + rect.width * 0.903,
            rect.top + rect.height * 0.163,
          ),
          Offset(0, rect.height * 0.245),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final selection = result.events.whereType<RendererTextSelected>().last;
      expect(selection.text, contains('PageSage'));
      expect(selection.selectionRects, isNotEmpty);
      for (final r in selection.selectionRects) {
        // The normalisation basis is the rotated (displayed) page box: a
        // rect computed from the raw crop box would come out rotated the
        // wrong way and land outside 0..1 on one axis.
        expect(r.x, inInclusiveRange(0, 1));
        expect(r.y, inInclusiveRange(0, 1));
        expect(r.x + r.width, lessThanOrEqualTo(1.0001));
        expect(r.y + r.height, lessThanOrEqualTo(1.0001));
        // A vertical run of rotated text is tall and narrow in display space.
        expect(r.height, greaterThan(r.width));
      }
    });

    testWidgets('a stored annotation is clickable on a rotated page', (
      tester,
    ) async {
      final first = await pumpReader(
        tester,
        'rotated-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
      );
      final firstPage = pageBox(tester, aspect: 792 / 612);
      await tester.runAsync(() async {
        await dragBy(
          tester,
          Offset(
            firstPage.left + firstPage.width * 0.903,
            firstPage.top + firstPage.height * 0.163,
          ),
          Offset(0, firstPage.height * 0.245),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
      final selection = first.events.whereType<RendererTextSelected>().last;
      expect(selection.selectionRects, isNotEmpty);
      final saved = selection.selectionRects.first;
      final annotation = Annotation(
        id: 'rotated-annotation',
        bookId: 'test',
        locator: ReadingLocator.pdf(page: 1, selectionRects: [saved]),
        selectedText: selection.text,
        color: AnnotationColor.yellow,
        style: AnnotationStyle.highlight,
        createdAt: 0,
        updatedAt: 0,
      );

      final second = await pumpReader(
        tester,
        'rotated-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
        session: 1,
        annotations: [annotation],
      );
      final page = pageBox(tester, aspect: 792 / 612);
      final inside =
          page.topLeft +
          Offset(
            (saved.x + saved.width / 2) * page.width,
            (saved.y + saved.height / 2) * page.height,
          );
      await tester.runAsync(() async {
        await tester.tapAt(inside);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final hits = second.events
          .whereType<RendererAnnotationSelected>()
          .where((event) => event.annotationId == annotation.id)
          .toList();
      expect(
        hits,
        hasLength(1),
        reason:
            'saved=(${saved.x},${saved.y},${saved.width},${saved.height}) '
            'inside=$inside page=$page',
      );
      expect(hits.single.sourceRect?.page, 1);
      expect(hits.single.sourceRect?.width, greaterThan(0));
      expect(hits.single.sourceRect?.height, greaterThan(0));

      // A point away from the stored band must not reuse the annotation's
      // rotated position.
      await tester.runAsync(() async {
        await tester.tapAt(
          page.topLeft + Offset(page.width * 0.5, page.height * 0.8),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
      expect(
        second.events.whereType<RendererAnnotationSelected>().where(
          (event) => event.annotationId == annotation.id,
        ),
        hasLength(1),
      );
    });

    testWidgets('the end handle drags the selection further', (tester) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        // A short drag on the first line, then extend downward by its handle.
        await dragBy(
          tester,
          Offset(rect.left + 76 * scale, rect.top + (792 - 733) * scale),
          Offset(80 * scale, 0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
      final first = result.events.whereType<RendererTextSelected>().last;

      final endHandle = find.byKey(const ValueKey('pdf-selection-handle-end'));
      expect(endHandle, findsOneWidget);

      await tester.runAsync(() async {
        // The handle's touch box is 44 px, and its top edge starts only a few
        // px below the anchor; a mouse press at the centre would sit on the
        // page (and start a new selection) rather than on the handle. Grab
        // the knob itself at the top of the box.
        final box = tester.getRect(endHandle);
        final from = box.topCenter + Offset(0, 6);

        final gesture = await tester.startGesture(
          from,
          kind: PointerDeviceKind.touch,
        );
        // Two lines down: the second line sits 28pt below the first.
        final to = from + Offset(0, 56 * scale);
        for (var i = 1; i <= 12; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 12)!);
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final extended = result.events.whereType<RendererTextSelected>().last;
      expect(extended.text.length, greaterThan(first.text.length));
      expect(extended.text, startsWith(first.text));
      // More than one band now: the selection crossed a line break.
      expect(
        extended.selectionRects.length,
        greaterThan(first.selectionRects.length),
      );
    });

    testWidgets('a host clear request drops the highlight and handles', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        await tester.tapAt(
          Offset(rect.left + 80 * scale, rect.top + (792 - 733) * scale),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
      expect(result.events.whereType<RendererTextSelected>(), isNotEmpty);
      final handle = find.byKey(const ValueKey('pdf-selection-handle-end'));
      expect(handle, findsOneWidget);

      result.clearSelection.value += 1;
      await tester.pump();

      // The menu is gone, so the paint it belonged to must go too; otherwise
      // the page keeps a frozen highlight with nothing that can act on it.
      expect(handle, findsNothing);
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

  group('S4 outline, search and links', () {
    testWidgets('reports the document outline after opening', (tester) async {
      final result = await pumpReader(
        tester,
        'outline-link.pdf',
        viewport: const Size(1000, 900),
      );

      final outline = result.events
          .whereType<RendererOutlineChanged>()
          .last
          .items;
      expect(outline.map((i) => i.title), [
        'Chapter One',
        'Chapter Two',
        'Section 2.1',
      ]);
      expect(outline.map((i) => i.page), [1, 2, 2]);
      expect(outline.last.level, 1);
      // The destination names a y position, so the TOC can land on the
      // heading rather than the top of the page.
      expect(outline.first.offsetFraction, isNotNull);
    });

    testWidgets('a PDF without an outline reports an empty list', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
      );

      final outline = result.events
          .whereType<RendererOutlineChanged>()
          .last
          .items;
      // Empty — not absent: the host has to clear a previous book's outline,
      // and then falls back to its page-number list.
      expect(outline, isEmpty);
    });

    testWidgets('search reports every hit in the document', (tester) async {
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        searchQuery: 'PageSage',
      );

      final results = result.events
          .whereType<RendererSearchResults>()
          .last
          .results;
      // Every page starts with "PageSage PDF sample page N"; the phrase also
      // appears in the second line, so each page contributes two hits.
      expect(results.map((r) => r.locator.page).toSet(), {1, 2, 3});
      expect(results, hasLength(6));
      expect(results.first.snippet, contains('PageSage'));
      // The locator names the scale the result was found at, so reopening the
      // hit does not need to guess a zoom.
      expect(results.first.locator.zoom, isNotNull);
    });

    testWidgets('dropping the query clears the painted hits', (tester) async {
      // The host clears highlights by dropping the query on the same view;
      // the renderer must answer with an empty list, or the page stays tinted
      // after the search panel closes.
      final events = <RendererEvent>[];
      final query = ValueNotifier<String?>('PageSage');
      addTearDown(query.dispose);
      tester.view.physicalSize =
          const Size(1000, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder<String?>(
                  valueListenable: query,
                  builder: (context, value, _) => PdfCanvasView(
                    book: bookFor('standard-text.pdf'),
                    settings: const ReaderSettings(),
                    initialProgress: null,
                    annotations: const [],
                    onEvent: events.add,
                    searchQuery: value,
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(
          events.whereType<RendererSearchResults>().last.results,
          isNotEmpty,
        );

        query.value = null;
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });

      expect(events.whereType<RendererSearchResults>().last.results, isEmpty);
    });

    testWidgets('tapping a GoTo link jumps to its page', (tester) async {
      final result = await pumpReader(
        tester,
        'outline-link.pdf',
        viewport: const Size(1000, 900),
        savedLocator: ReadingLocator.pdf(page: 1, progress: 0),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      // The link covers x 70..260, y 725..750 in page space.
      await tester.runAsync(() async {
        await tester.tapAt(
          Offset(rect.left + 150 * scale, rect.top + (792 - 737) * scale),
        );
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 60));
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });

      final locations = result.events
          .whereType<RendererLocationChanged>()
          .toList();
      expect(locations.last.pageNumber, 3);
    });

    testWidgets('tapping a URI link asks the host instead of opening it', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'outline-link.pdf',
        viewport: const Size(1000, 900),
        savedLocator: ReadingLocator.pdf(page: 2, progress: 0.5),
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        await tester.tapAt(
          Offset(rect.left + 150 * scale, rect.top + (792 - 737) * scale),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      final links = result.events.whereType<RendererExternalLinkRequested>();
      expect(links, isNotEmpty);
      expect(links.last.uri, 'https://example.com/pagesage');
      // The renderer itself must not navigate away from the book.
      expect(
        result.events.whereType<RendererLocationChanged>().last.pageNumber,
        2,
      );
    });
  });

  group('B1 image box', () {
    Future<void> dragBox(
      WidgetTester tester,
      Offset from,
      Offset delta, {
      PointerDeviceKind kind = PointerDeviceKind.mouse,
    }) async {
      final gesture = await tester.startGesture(from, kind: kind);
      for (var i = 1; i <= 20; i++) {
        await gesture.moveTo(from + delta * (i / 20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('a box drawn over the image snaps to its bounds', (
      tester,
    ) async {
      final areas = <RendererImageAreaSelected>[];
      // `image-xobject.pdf` paints one 300x200 image at user-space
      // (150, 400); on this 612x792 page that is x 0.245..0.735 and
      // y 0.242..0.495 of the displayed box.
      await pumpReader(
        tester,
        'image-xobject.pdf',
        viewport: const Size(1000, 900),
        imageDragMode: true,
        onImageAreaSelected: areas.add,
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      // Display box of the image: x 150..450, y 192..392.
      const start = Offset(160, 205);
      const delta = Offset(280, 175);
      await tester.runAsync(() async {
        // Deliberately sloppy: starts inside the picture and stops short of
        // its right and bottom edges, but still covers most of it.
        await dragBox(
          tester,
          Offset(rect.left + start.dx * scale, rect.top + start.dy * scale),
          Offset(delta.dx * scale, delta.dy * scale),
        );
        await tester.pump();
      });

      expect(areas, hasLength(1));
      final anchor = areas.single.anchor as PdfImageAnchor;
      expect(anchor.page, 1);
      expect(
        anchor.ordinal,
        0,
        reason: 'the drawn box must identify the image',
      );
      expect(anchor.resourceName, 'Im1');
      expect(anchor.rect.x, closeTo(150 / 612, 1e-6));
      expect(anchor.rect.width, closeTo(300 / 612, 1e-6));
      expect(anchor.rect.height, closeTo(200 / 792, 1e-6));
    });

    testWidgets('text selection is not also started by that drag', (
      tester,
    ) async {
      final result = await pumpReader(
        tester,
        'image-xobject.pdf',
        viewport: const Size(1000, 900),
        imageDragMode: true,
        onImageAreaSelected: (_) {},
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        await dragBox(
          tester,
          Offset(rect.left + 160 * scale, rect.top + 205 * scale),
          Offset(280 * scale, 175 * scale),
        );
        await tester.pump();
      });
      expect(
        result.events.whereType<RendererTextSelected>(),
        isEmpty,
        reason: 'one gesture cannot mean both a box and a selection',
      );
    });

    testWidgets('a page with no detected image keeps the drawn box', (
      tester,
    ) async {
      final areas = <RendererImageAreaSelected>[];
      // Vector artwork only: nothing to snap to, and the reader's box is the
      // only geometry that exists.
      await pumpReader(
        tester,
        'image-only.pdf',
        viewport: const Size(1000, 900),
        imageDragMode: true,
        onImageAreaSelected: areas.add,
      );
      final rect = pageBox(tester);
      await tester.runAsync(() async {
        await dragBox(
          tester,
          rect.topLeft + const Offset(120, 120),
          const Offset(200, 160),
        );
        await tester.pump();
      });
      expect(areas, hasLength(1));
      final anchor = areas.single.anchor as PdfImageAnchor;
      expect(anchor.ordinal, isNull, reason: 'nothing was detected to snap to');
      expect(anchor.rect.width, closeTo(200 / rect.width, 1e-6));
      expect(anchor.rect.height, closeTo(160 / rect.height, 1e-6));
    });

    testWidgets('a drag with the mode off still selects text', (tester) async {
      final areas = <RendererImageAreaSelected>[];
      final result = await pumpReader(
        tester,
        'standard-text.pdf',
        viewport: const Size(1000, 900),
        onImageAreaSelected: areas.add,
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        await dragBox(
          tester,
          Offset(rect.left + 76 * scale, rect.top + (792 - 733) * scale),
          Offset(80 * scale, 0),
        );
        await tester.pump();
      });
      expect(areas, isEmpty);
      expect(result.events.whereType<RendererTextSelected>(), isNotEmpty);
    });

    testWidgets('a touch drag draws a box only in image mode', (tester) async {
      final areas = <RendererImageAreaSelected>[];
      await pumpReader(
        tester,
        'image-xobject.pdf',
        viewport: const Size(1000, 900),
        imageDragMode: true,
        onImageAreaSelected: areas.add,
      );
      final rect = pageBox(tester);
      final scale = rect.width / 612;
      await tester.runAsync(() async {
        await dragBox(
          tester,
          Offset(rect.left + 160 * scale, rect.top + 205 * scale),
          Offset(280 * scale, 175 * scale),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
      });
      expect(areas, hasLength(1));
    });
  });
}
