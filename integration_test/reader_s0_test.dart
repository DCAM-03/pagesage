import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_view.dart';

import 'support/reader_harness.dart';

/// S0 acceptance on a real Linux desktop window.
///
/// These drive the production [ReaderPage] against the real canvas renderer
/// and real sample PDFs. The widget tests already pin the renderer's own
/// geometry; what is verified here is what only the live host can show: menus
/// placed by the host overlay, Flutter pointer gestures in the GTK window, and
/// progress surviving a reopen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The page's painted box inside the reader, found by the 612x792 aspect of
  /// the letter-size samples. Returns null while the page has not painted.
  Rect? pageRect(WidgetTester tester) {
    for (final element in find.byType(CustomPaint).evaluate()) {
      final box = element.renderObject! as RenderBox;
      if (!box.hasSize || box.size.width < 100 || box.size.height < 100) {
        continue;
      }
      final aspect = box.size.width / box.size.height;
      if ((aspect - 612 / 792).abs() > 0.01) continue;
      final origin = box.localToGlobal(Offset.zero);
      return origin & box.size;
    }
    return null;
  }

  /// Drags across the sample page's second body line with a mouse pointer.
  ///
  /// The first line sits under the host's floating PDF toolbar, which would
  /// swallow the pointer. The second line starts 90pt from the page top, below
  /// the toolbar in a window at least 1000px tall.
  ///
  /// Mouse, not touch: the `PageView` only claims touch drags, which is also
  /// how the desktop reader behaves.
  Future<Offset> dragBodyLine(WidgetTester tester, Rect page) async {
    final scale = page.height / 792;
    final start = page.topLeft + Offset(74 * scale, 90 * scale);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 60; i++) {
      await gesture.moveTo(start + Offset(i * 4.0, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    return start;
  }

  /// The painted page box as the reader laid it out, by page aspect.
  Rect? pageOfAspect(WidgetTester tester, double aspect) {
    Rect? best;
    for (final element in find.byType(CustomPaint).evaluate()) {
      final widget = element.widget as CustomPaint;
      if (widget.painter == null) continue;
      final box = element.renderObject! as RenderBox;
      if (!box.hasSize || box.size.width < 100 || box.size.height < 100) {
        continue;
      }
      if ((box.size.width / box.size.height - aspect).abs() > 0.01) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (best == null || rect.width * rect.height > best.width * best.height) {
        best = rect;
      }
    }
    return best;
  }

  /// One mouse-wheel notch at the centre of the reader.
  Future<void> wheel(WidgetTester tester, Offset delta) async {
    final page = pageOfAspect(tester, 612 / 792);
    final center =
        page?.center ?? tester.getCenter(find.byType(Scaffold).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    // In the live binding, `GestureBinding.handlePointerEvent` treats events as
    // device-sourced and drops them; `sendEventToBinding` marks them as test
    // events so the real hit-test path runs.
    await tester.sendEventToBinding(pointer.scroll(delta));
  }

  Future<ReaderHarness> harnessFor({
    String sample = 'standard-text.pdf',
    String id = 'standard',
    ReadingLocator? saved,
  }) async {
    final harness = await ReaderHarness.create(
      books: [sampleBook(id: id, sample: sample)],
      progress: saved == null
          ? const {}
          : {
              id: ReadingProgressSnapshot(
                bookId: id,
                locator: saved,
                progress: saved.progress,
                updatedAt: 0,
                pageNumber: saved.page,
              ),
            },
    );
    addTearDown(harness.dispose);
    return harness;
  }

  testWidgets('opens a PDF and restores the saved page', (tester) async {
    final harness = await harnessFor(
      saved: ReadingLocator.pdf(page: 3, progress: 1),
    );
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));

    expect(find.byType(PdfCanvasView), findsOneWidget);
    expect(find.textContaining('3 / 3'), findsWidgets);
    expect(tester.takeException(), isNull);

    await harness.capture('01-restore-saved-page');
    await harness.closeReader(tester);
  });

  testWidgets('drag selection opens the menu above the selected text', (
    tester,
  ) async {
    final harness = await harnessFor();
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));

    final page = pageRect(tester);
    expect(page, isNotNull, reason: 'page should be painted');
    final start = await dragBodyLine(tester, page!);
    await harness.settle(tester);

    // The desktop selection menu is an Overlay entry with these actions.
    expect(find.text('高亮'), findsWidgets);
    expect(find.text('复制'), findsWidgets);

    // Its position must sit above the line the selection started on.
    final menu = tester.getRect(find.text('高亮').first);
    expect(menu.center.dy, lessThan(start.dy));
    expect(tester.takeException(), isNull);

    await harness.capture('02-drag-selection-menu');
    await harness.closeReader(tester);
  });

  testWidgets('stored annotation is clickable and opens its menu', (
    tester,
  ) async {
    final harness = await harnessFor();
    // Insert before the reader opens, so the annotation stream's first value
    // already contains it (no timing window to race).
    await harness.database.annotationDao.upsertAnnotation(
      AnnotationsCompanion.insert(
        id: 'ann-1',
        bookId: 'standard',
        locator: ReadingLocator.pdf(
          page: 1,
          selectionRects: const [
            // Second body line: below the host's floating PDF toolbar.
            ReaderRect(page: 1, x: 0.10, y: 0.093, width: 0.35, height: 0.022),
          ],
        ).toJsonText(),
        selectedText: 'PageSage',
        color: 'yellow',
        style: 'highlight',
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));

    final page = pageRect(tester);
    expect(page, isNotNull);

    final annotationPoint =
        page!.topLeft +
        Offset(
          (0.10 + 0.35 / 2) * page.width,
          (0.093 + 0.022 / 2) * page.height,
        );
    await tester.tapAt(annotationPoint);
    await harness.settle(tester);

    expect(find.text('标注'), findsWidgets);
    expect(find.byTooltip('删除标注'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.capture('03-annotation-menu');
    await harness.closeReader(tester);
  });

  testWidgets('page jump dialog moves the reader to the requested page', (
    tester,
  ) async {
    final harness = await harnessFor(sample: 'large-text.pdf', id: 'large');
    await harness.pumpReader(tester, 'large', size: const Size(1280, 800));

    final reveal = find.byTooltip('显示阅读工具').hitTestable();
    if (reveal.evaluate().isNotEmpty) {
      await tester.tap(reveal);
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.byTooltip('跳转页码').hitTestable().first);
    await harness.settle(tester, rounds: 10);
    expect(find.text('跳转页码'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, '40');
    await tester.tap(find.text('跳转'));
    await harness.settle(tester);

    expect(find.textContaining('40 / 80'), findsWidgets);
    expect(tester.takeException(), isNull);

    await harness.capture('04-page-jump');
    await harness.closeReader(tester);
  });

  testWidgets('scanned PDF shows the disabled reason instead of selection', (
    tester,
  ) async {
    final harness = await harnessFor(sample: 'image-only.pdf', id: 'scanned');
    await harness.pumpReader(tester, 'scanned', size: const Size(1280, 800));

    expect(find.textContaining('无文本层'), findsWidgets);

    // Leaving the reader flushes progress, including for a scanned page.
    await harness.capture('05-scanned-disabled');
    await harness.closeReader(tester);
    final stored = await harness.database.progressDao.getProgress('scanned');
    expect(stored?.pageNumber, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page 40 of an 80-page book survives a reopen', (tester) async {
    final harness = await harnessFor(
      sample: 'large-text.pdf',
      id: 'large',
      saved: ReadingLocator.pdf(page: 40, progress: 39 / 79),
    );
    await harness.pumpReader(tester, 'large', size: const Size(1280, 800));

    expect(find.textContaining('40 / 80'), findsWidgets);

    // Closing unmounts the reader and flushes pending progress, which is what
    // exiting the app does for persistence.
    await harness.capture('06-page40-reopen-a');
    await harness.closeReader(tester);
    final stored = await harness.database.progressDao.getProgress('large');
    expect(stored?.pageNumber, 40);

    // Reopen with no initial locator: the reader must restore from the stored
    // row alone, and closing again must leave it at 40 rather than resetting
    // to page 1 (the defect-8 regression point).
    await harness.pumpReader(tester, 'large', size: const Size(1280, 800));
    expect(find.textContaining('40 / 80'), findsWidgets);
    await harness.capture('06-page40-reopen-b');
    await harness.closeReader(tester);

    final after = await harness.database.progressDao.getProgress('large');
    expect(after?.pageNumber, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection menu stays inside a narrow window', (tester) async {
    final harness = await harnessFor();
    // Width 900 keeps the side-panel menu path; the extra height keeps the
    // second text line clear of the floating PDF toolbar.
    await harness.pumpReader(tester, 'standard', size: const Size(900, 1000));

    final page = pageRect(tester);
    expect(page, isNotNull);
    await dragBodyLine(tester, page!);
    await harness.settle(tester);

    final menu = tester.getRect(find.text('高亮').first);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(menu.left, greaterThanOrEqualTo(0));
    expect(menu.right, lessThanOrEqualTo(window.width));
    expect(menu.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);

    await harness.capture('07-narrow-window-menu');
    await harness.closeReader(tester);
  });

  testWidgets('Ctrl+wheel zooms the page and the scale survives a reopen', (
    tester,
  ) async {
    final harness = await harnessFor();
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));

    final before = pageOfAspect(tester, 612 / 792);
    expect(before, isNotNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await wheel(tester, const Offset(0, -40));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);

    final after = pageOfAspect(tester, 612 / 792);
    await harness.capture('08-ctrl-wheel-zoom');
    expect(after, isNotNull);
    // The zoom was a step up from fit-width, so the page grew.
    expect(after!.width, greaterThan(before!.width));

    // The requirement is that the zoom survives leaving and reopening the
    // reader, not that a particular settings key exists: reopen from the
    // stored settings and check the page is laid out at the same scale.
    await harness.closeReader(tester);
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));
    final reopened = pageOfAspect(tester, 612 / 792);
    expect(reopened, isNotNull);
    expect(reopened!.width, closeTo(after.width, 1));
  });

  testWidgets('a rotated page reads landscape in the real window', (
    tester,
  ) async {
    final harness = await harnessFor(sample: 'rotated-text.pdf', id: 'rotated');
    await harness.pumpReader(
      tester,
      'rotated',
      size: const Size(1280, 800),
      settings: const ReaderSettings(pdfZoomMode: PdfZoomMode.fitPage),
    );

    final page = pageOfAspect(tester, 792 / 612);
    expect(page, isNotNull, reason: 'rotated page should lay out 792x612');
    expect(page!.width, greaterThan(page.height));

    // A tap on the text column selects a word, proving the rotated geometry
    // maps pointers onto the real glyphs.
    final target = page.topLeft + Offset(page.width * 0.92, page.height * 0.12);
    await tester.tapAt(target);
    await harness.settle(tester);
    expect(find.text('高亮'), findsWidgets);

    await harness.capture('09-rotated-page');
    await harness.closeReader(tester);
  });

  testWidgets('a rotated page keeps its annotation readable at night', (
    tester,
  ) async {
    final harness = await harnessFor(
      sample: 'rotated-text.pdf',
      id: 'rotated-night',
    );
    // The stored rect is in displayed-page fractions, exactly what a
    // selection on the rotated page reports. It must land on that same band
    // after a reopen, and the night wash must stay visible instead of being
    // inverted with the page picture.
    await harness.database.annotationDao.upsertAnnotation(
      AnnotationsCompanion.insert(
        id: 'rotated-night-ann',
        bookId: 'rotated-night',
        locator: ReadingLocator.pdf(
          page: 1,
          selectionRects: const [
            ReaderRect(page: 1, x: 0.90, y: 0.15, width: 0.04, height: 0.25),
          ],
        ).toJsonText(),
        selectedText: 'PageSage',
        color: 'yellow',
        style: 'highlight',
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    await harness.pumpReader(
      tester,
      'rotated-night',
      size: const Size(1280, 800),
      settings: const ReaderSettings(
        themePreset: ReaderThemePreset.night,
        pdfZoomMode: PdfZoomMode.fitPage,
      ),
    );

    final page = pageOfAspect(tester, 792 / 612);
    expect(page, isNotNull, reason: 'rotated page should lay out 792x612');
    final target =
        page!.topLeft +
        Offset((0.90 + 0.04 / 2) * page.width, (0.15 + 0.25 / 2) * page.height);
    await tester.tapAt(target);
    await harness.settle(tester);

    expect(find.text('标注'), findsWidgets);
    expect(find.byTooltip('删除标注'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.capture('10-rotated-night-annotation');
    await harness.closeReader(tester);
  });

  testWidgets('continuous scrolling restores the place inside a page', (
    tester,
  ) async {
    final harness = await harnessFor();
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));

    // Several Scrollables exist in the reader chrome (the TOC, side panels),
    // and the first one is horizontal. Resolve the canvas list through the
    // page widget itself: its nearest scrollable ancestor can only be the
    // continuous list.
    ScrollPosition listPosition() {
      final page = find.byKey(const ValueKey('pdf-page-0'));
      expect(page, findsOneWidget);
      final scrollable = Scrollable.maybeOf(tester.element(page));
      expect(scrollable, isNotNull, reason: 'page must sit in the list');
      return scrollable!.position;
    }

    final first = listPosition();
    expect(first.axis, Axis.vertical);
    // The sample is 3 letter pages at fit-width, taller than the window.
    expect(first.maxScrollExtent, greaterThan(0));

    // Drag the page itself, the way a reader scrolls: the page is taller than
    // the viewport, so the list scrolls within one page.
    await tester.drag(
      find.byKey(const ValueKey('pdf-page-0')),
      const Offset(0, -160),
    );
    await harness.settle(tester);
    final scrolled = listPosition().pixels;
    expect(scrolled, greaterThan(0), reason: 'the drag must scroll the list');
    await harness.capture('10-continuous-scroll');

    // Reopen: the stored scrollOffset must put the reader back at the same
    // position, which is S2's acceptance criterion.
    await harness.closeReader(tester);
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));
    final reopened = listPosition().pixels;
    // One text line at fit-width is roughly 20–30 logical pixels.
    expect(reopened, closeTo(scrolled, 30));
    await harness.capture('11-continuous-restored');
    await harness.closeReader(tester);
  });

  testWidgets('long-press selects a word and a handle extends it', (
    tester,
  ) async {
    final harness = await harnessFor();
    await harness.pumpReader(tester, 'standard', size: const Size(1280, 800));

    final page = pageOfAspect(tester, 612 / 792);
    expect(page, isNotNull);
    final scale = page!.height / 792;
    // Second body line: the first is under the floating PDF toolbar.
    final wordAt = page.topLeft + Offset(80 * scale, 90 * scale);

    // Touch, not mouse: a long press is the mobile selection gesture, and the
    // recognizer only arms for touch. 700 ms clears the platform hold timer.
    await tester.runAsync(() async {
      final gesture = await tester.startGesture(
        wordAt,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
    await harness.settle(tester, rounds: 6);

    // The touch menu is a modal sheet with the same actions.
    expect(find.text('高亮'), findsWidgets);
    final startHandle = find.byKey(
      const ValueKey('pdf-selection-handle-start'),
    );
    final endHandle = find.byKey(const ValueKey('pdf-selection-handle-end'));
    expect(startHandle, findsOneWidget);
    expect(endHandle, findsOneWidget);
    await harness.capture('12-long-press-select');

    // Drag the end handle right along the line. It has to own the drag; if
    // the barrier or the list's scroll recognizer wins instead, the page
    // scrolls (or nothing happens) and the selection stays one word long.
    // Downward would not extend here: the sample's second line is the last
    // one, so the caret would clamp to its end.
    final handleBox = tester.getRect(endHandle);
    await tester.runAsync(() async {
      final from = handleBox.topCenter + const Offset(0, 6);
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.touch,
      );
      final to = from + Offset(220 * scale, 0);
      for (var i = 1; i <= 16; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 16)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
    await harness.settle(tester, rounds: 6);
    await harness.capture('13-handle-extended');
    // The menu reopens for the wider selection and previews its new text.
    expect(find.textContaining('Generated by'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Dismissing the menu must also drop the paint; a frozen highlight with
    // no menu would be unselectable and look like a stuck annotation. Tap a
    // blank part of the page: the menu is an overlay entry, not a route, so
    // popping the navigator would leave the reader itself.
    await tester.tapAt(page.topLeft + Offset(24 * scale, 420 * scale));
    await harness.settle(tester, rounds: 10);
    expect(find.text('高亮'), findsNothing);
    expect(
      find.byKey(const ValueKey('pdf-selection-handle-start')),
      findsNothing,
    );
    await harness.capture('14-selection-cleared');
    await harness.closeReader(tester);
  });
}
