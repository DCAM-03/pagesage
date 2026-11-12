import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_view.dart';

import '../../support/reader_workbench_capture.dart';
import 'support/canvas_test_helpers.dart';

Future<void> settleReader(WidgetTester tester) => tester.runAsync(() async {
  for (var round = 0; round < 24; round++) {
    await tester.pump(const Duration(milliseconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
});

Rect pageRect(WidgetTester tester, int page) {
  final paints = find.descendant(
    of: find.byKey(ValueKey('pdf-page-${page - 1}')),
    matching: find.byType(CustomPaint),
  );
  final pagePaint = paints.evaluate().singleWhere((element) {
    final paint = element.widget as CustomPaint;
    final box = element.renderObject;
    return paint.painter != null &&
        box is RenderBox &&
        box.hasSize &&
        box.size.width > 100 &&
        box.size.height > 100;
  });
  return tester.getRect(find.byWidget(pagePaint.widget));
}

Offset secondLinePoint(Rect page, double x) =>
    page.topLeft + Offset(x, 87) * (page.width / 612);

void main() {
  Future<({List<RendererEvent> events, ValueNotifier<int> targetPage})> mount(
    WidgetTester tester, {
    ReaderSettings settings = const ReaderSettings(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(tester.view.reset);
    final targetPage = ValueNotifier(1);
    addTearDown(targetPage.dispose);
    final events = <RendererEvent>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: workbenchCaptureKey,
              child: ValueListenableBuilder<int>(
                valueListenable: targetPage,
                builder: (context, page, _) => PdfCanvasView(
                  book: const Book(
                    id: 'navigation-selection',
                    title: 'Generated sample',
                    format: BookFormat.pdf,
                    libraryFilePath: 'poc_pdf_canvas/samples/large-text.pdf',
                    fileHash: 'generated',
                    fileSize: 0,
                    createdAt: 0,
                    updatedAt: 0,
                  ),
                  settings: settings,
                  initialProgress: ReadingProgressSnapshot(
                    bookId: 'navigation-selection',
                    locator: ReadingLocator.pdf(page: page),
                    progress: (page - 1) / 79,
                    updatedAt: 0,
                  ),
                  jumpToken: page,
                  searchQuery: 'page 40.',
                  annotations: const [],
                  onEvent: events.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleReader(tester);
    await tester.runAsync(() async {
      for (
        var round = 0;
        round < 400 && events.whereType<RendererSearchResults>().isEmpty;
        round++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    expect(events.whereType<RendererReady>(), isNotEmpty);
    expect(events.whereType<RendererSearchResults>(), isNotEmpty);
    expect(
      events
          .whereType<RendererSearchResults>()
          .last
          .results
          .single
          .locator
          .page,
      40,
    );
    return (events: events, targetPage: targetPage);
  }

  testWidgets(
    'search jump keeps dragged selection and paint on the target page',
    (tester) async {
      final reader = await mount(tester);
      reader.targetPage.value = 40;
      await settleReader(tester);
      expect(
        reader.events.whereType<RendererLocationChanged>().last.pageNumber,
        40,
      );
      final page = pageRect(tester, 40);
      final start = secondLinePoint(page, 76);
      final end = secondLinePoint(page, 200);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      for (var step = 1; step <= 12; step++) {
        await gesture.moveTo(Offset.lerp(start, end, step / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();

      final selected = reader.events.whereType<RendererTextSelected>().last;
      expect(selected.locator.page, 40);
      expect(selected.text, startsWith('Generated'));
      expect(selected.selectionRects, isNotEmpty);
      expect(selected.selectionRects.every((rect) => rect.page == 40), isTrue);
      final handles = find.descendant(
        of: find.byKey(const ValueKey('pdf-page-39')),
        matching: find.byKey(const ValueKey('pdf-selection-handle-end')),
      );
      expect(handles, findsOneWidget);
      expect(
        tester.getRect(handles).overlaps(const Rect.fromLTWH(0, 0, 1000, 900)),
        isTrue,
      );

      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(workbenchCaptureKey),
        );
        final image = await boundary.toImage();
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final band = selected.selectionRects.first;
          final rect = Rect.fromLTWH(
            page.left + band.x * page.width,
            page.top + band.y * page.height,
            band.width * page.width,
            band.height * page.height,
          ).intersect(const Rect.fromLTWH(0, 0, 1000, 900));
          var bluePixels = 0;
          for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
            for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
              final offset = (y * image.width + x) * 4;
              final red = data!.getUint8(offset);
              final green = data.getUint8(offset + 1);
              final blue = data.getUint8(offset + 2);
              if (blue > red + 40 && blue > green + 10) bluePixels++;
            }
          }
          expect(bluePixels, greaterThan(20));
        } finally {
          image.dispose();
        }
      });
      await captureWorkbenchWidget(tester, 'pdf-search-jump-selection');
    },
  );

  testWidgets(
    'same-page scrolling uses the current text position for selection',
    (tester) async {
      final reader = await mount(tester);
      await simulateWheel(tester, const Offset(0, 40));
      await tester.pumpAndSettle();
      final page = pageRect(tester, 1);
      expect(page.top, lessThan(0));
      await tester.tapAt(secondLinePoint(page, 80));
      await tester.pump();
      final selected = reader.events.whereType<RendererTextSelected>().last;
      expect(selected.locator.page, 1);
      expect(selected.text, 'Generated');
    },
  );

  testWidgets(
    'paged search jumps and back navigation select the visible page',
    (tester) async {
      final reader = await mount(
        tester,
        settings: const ReaderSettings(
          readerMode: ReaderMode.paged,
          pdfZoomMode: PdfZoomMode.fitPage,
        ),
      );
      for (final target in [40, 1, 20]) {
        reader.targetPage.value = target;
        await settleReader(tester);
        await tester.tapAt(secondLinePoint(pageRect(tester, target), 80));
        await tester.pump();
        final selected = reader.events.whereType<RendererTextSelected>().last;
        expect(selected.locator.page, target);
        expect(selected.text, 'Generated');
      }
    },
  );

  testWidgets(
    'resizing after a search jump keeps selection on the visible text',
    (tester) async {
      final reader = await mount(tester);
      reader.targetPage.value = 40;
      await settleReader(tester);
      tester.view.physicalSize = const Size(1200, 760);
      await settleReader(tester);
      await tester.tapAt(secondLinePoint(pageRect(tester, 40), 80));
      await tester.pump();
      final selected = reader.events.whereType<RendererTextSelected>().last;
      expect(selected.locator.page, 40);
      expect(selected.text, 'Generated');
    },
  );

  testWidgets(
    'a touch long press after a search jump selects the target page',
    (tester) async {
      final reader = await mount(tester);
      reader.targetPage.value = 40;
      await settleReader(tester);
      await tester.longPressAt(secondLinePoint(pageRect(tester, 40), 80));
      await tester.pump();
      final selected = reader.events.whereType<RendererTextSelected>().last;
      expect(selected.locator.page, 40);
      expect(selected.text, 'Generated');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pdf-page-39')),
          matching: find.byKey(const ValueKey('pdf-selection-handle-end')),
        ),
        findsOneWidget,
      );
    },
  );
}
