import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/features/reader/presentation/reader_ocr_overlay_controller.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_view.dart';

void main() {
  const block = <String, Object?>{
    'text': 'OCR retained',
    'left': 0.1,
    'top': 0.2,
    'width': 0.6,
    'height': 0.04,
  };

  Future<void> settle(WidgetTester tester) => tester.runAsync(() async {
    for (var round = 0; round < 25; round++) {
      await tester.pump(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  });

  Future<({ReaderOcrOverlayController overlays, List<RendererEvent> events})>
  mount(
    WidgetTester tester, {
    GlobalKey? captureKey,
    bool rebuildOnCapabilities = false,
    ReaderSettings settings = const ReaderSettings(
      pdfZoomMode: PdfZoomMode.fitPage,
    ),
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overlays = ReaderOcrOverlayController();
    addTearDown(overlays.dispose);
    final events = <RendererEvent>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RepaintBoundary(
            key: captureKey,
            child: StatefulBuilder(
              builder: (context, setParentState) => ListenableBuilder(
                listenable: overlays,
                builder: (context, _) => PdfCanvasView(
                  book: const Book(
                    id: 'scanned',
                    title: 'scanned',
                    format: BookFormat.pdf,
                    libraryFilePath: 'poc_pdf_canvas/samples/image-only.pdf',
                    fileHash: 'sample',
                    fileSize: 0,
                    createdAt: 0,
                    updatedAt: 0,
                  ),
                  settings: settings,
                  initialProgress: null,
                  onEvent: (event) {
                    events.add(event);
                    if (rebuildOnCapabilities &&
                        event is RendererCapabilityChanged) {
                      setParentState(() {});
                    }
                  },
                  annotations: const [],
                  ocrOverlayPage: overlays.state.page,
                  ocrOverlayBlocks: overlays.state.blocks,
                  ocrOverlayToken: overlays.state.token,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(events.whereType<RendererReady>(), isNotEmpty);
    return (overlays: overlays, events: events);
  }

  Rect paintedRect(WidgetTester tester) {
    final paints = find.byType(CustomPaint).evaluate().where((element) {
      final widget = element.widget as CustomPaint;
      final box = element.renderObject! as RenderBox;
      return widget.painter != null &&
          box.hasSize &&
          box.size.width > 100 &&
          (box.size.aspectRatio - 612 / 792).abs() < 0.01;
    });
    return tester.getRect(find.byWidget(paints.single.widget));
  }

  testWidgets('later page overlays retain selection on an earlier page', (
    tester,
  ) async {
    final result = await mount(tester);
    result.overlays.show([
      (page: 1, blocks: [block]),
    ]);
    await settle(tester);
    result.overlays.show([
      (
        page: 2,
        blocks: [
          {...block, 'text': 'Other page'},
        ],
      ),
    ]);
    await settle(tester);

    final rect = paintedRect(tester);
    await tester.tapAt(
      rect.topLeft + Offset(rect.width * 0.15, rect.height * 0.22),
    );
    await settle(tester);
    final selected = result.events.whereType<RendererTextSelected>();
    expect(selected, isNotEmpty);
    expect(selected.last.text, 'OCR');
    expect(selected.last.locator.page, 1);
  });

  testWidgets('OCR selection handles follow a small centered page', (
    tester,
  ) async {
    final result = await mount(
      tester,
      settings: const ReaderSettings(
        pdfZoomMode: PdfZoomMode.custom,
        pdfScale: 0.5,
        readerMode: ReaderMode.paged,
      ),
    );
    result.overlays.show([
      (
        page: 1,
        blocks: [
          {...block, 'top': 0.7},
        ],
      ),
    ]);
    await settle(tester);
    final page = paintedRect(tester);
    final start =
        page.topLeft + Offset(page.width * 0.1 + 1, page.height * 0.72);
    final end = page.topLeft + Offset(page.width * 0.7 - 1, page.height * 0.72);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 1; step <= 12; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 12)!);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await settle(tester);
    final selected = result.events.whereType<RendererTextSelected>().last;
    final rect = selected.selectionRects.single;
    final first = tester.getCenter(
      find.byKey(const ValueKey('pdf-selection-handle-start')),
    );
    final last = tester.getCenter(
      find.byKey(const ValueKey('pdf-selection-handle-end')),
    );
    expect(first.dx, closeTo(page.left + rect.x * page.width, 1));
    expect(last.dx, closeTo(page.left + (rect.x + rect.width) * page.width, 1));
    expect(first.dy + 16, closeTo(page.top + rect.y * page.height, 1));
    expect(
      last.dy - 28,
      closeTo(page.top + (rect.y + rect.height) * page.height, 1),
    );
  });

  testWidgets('OCR capabilities can safely rebuild the reader host', (
    tester,
  ) async {
    final result = await mount(tester, rebuildOnCapabilities: true);
    result.overlays.show([
      (page: 1, blocks: [block]),
    ]);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      result.events.whereType<RendererCapabilityChanged>().last.textSelection,
      isTrue,
    );
  });

  testWidgets('invalid OCR geometry never advertises selectable text', (
    tester,
  ) async {
    final result = await mount(tester);
    result.overlays.show([
      (
        page: 1,
        blocks: [
          {...block, 'width': -1},
        ],
      ),
    ]);
    await settle(tester);
    final capabilities = result.events
        .whereType<RendererCapabilityChanged>()
        .last;
    expect(capabilities.ocrTextLayer, isFalse);
    expect(capabilities.textSelection, isFalse);
  });

  testWidgets('OCR text layer preserves the scanned page pixels', (
    tester,
  ) async {
    final key = GlobalKey();
    final result = await mount(tester, captureKey: key);
    Future<List<int>> pixels() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    final before = await tester.runAsync(pixels);
    result.overlays.show([
      (page: 1, blocks: [block]),
    ]);
    await settle(tester);
    final after = await tester.runAsync(pixels);
    expect(after, orderedEquals(before!));
  });
}
