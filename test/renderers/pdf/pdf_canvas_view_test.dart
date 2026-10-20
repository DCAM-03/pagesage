import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_view.dart';

/// Behavioural tests for the S0 fixes in [PdfCanvasView].
///
/// These run against the real sample PDFs, so they exercise the actual
/// renderer rather than a stand-in. Rasterising needs a frame per page, so
/// every test pumps until the ready event arrives.
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
  }) async {
    final events = <RendererEvent>[];
    final book = bookFor(sample);
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
                settings: const ReaderSettings(),
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
    // And the PageView itself must actually be on page 3.
    final pager = find.text('第 3 / 3 页');
    expect(pager, findsOneWidget);
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
    expect(find.text('第 40 / 80 页'), findsOneWidget);
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
    expect(find.text('第 40 / 80 页'), findsOneWidget);
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
}
