import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/features/ai/presentation/ai_panel.dart';
import 'package:pagesage/features/ocr/application/ocr_providers.dart';
import 'package:pagesage/features/reader/presentation/reader_page.dart';

import 'support/reader_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Book scannedBook(String id) {
    final file = File('.codex-run/ocr-window/scanned-three-pages.pdf').absolute;
    expect(file.existsSync(), isTrue, reason: '需要用户授权扫描书的三页抽样件');
    return Book(
      id: id,
      title: '扫描书 OCR 验收',
      format: BookFormat.pdf,
      libraryFilePath: file.path,
      fileHash: 'window-scan-$id',
      fileSize: file.lengthSync(),
      createdAt: 1,
      updatedAt: 1,
    );
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ReaderPage)));

  Rect paintedPage(WidgetTester tester, int page) {
    final candidates = find.descendant(
      of: find.byKey(ValueKey('pdf-page-${page - 1}')),
      matching: find.byType(CustomPaint),
    );
    final paint = candidates.evaluate().where((element) {
      final widget = element.widget as CustomPaint;
      final box = element.renderObject! as RenderBox;
      return widget.painter != null && box.hasSize && box.size.width > 100;
    }).single;
    return tester.getRect(find.byWidget(paint.widget));
  }

  List<OcrTextBlock> bodyLines(OcrPageResult result) => result.blocks
      .where(
        (block) =>
            block.hasGeometry &&
            block.text.length > 12 &&
            block.width! > 0.35 &&
            block.top! > 0.20 &&
            block.top! < 0.7,
      )
      .toList();

  Future<void> select(
    WidgetTester tester,
    ReaderHarness harness,
    int page,
    OcrTextBlock line,
  ) async {
    final rect = paintedPage(tester, page);
    final y = rect.top + (line.top! + line.height! / 2) * rect.height;
    final start = Offset(rect.left + line.left! * rect.width + 1, y);
    final end = Offset(
      rect.left + (line.left! + line.width!) * rect.width - 1,
      y,
    );
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 1; step <= 15; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 15)!);
      await tester.pump(const Duration(milliseconds: 15));
    }
    await gesture.up();
    await harness.settle(tester, rounds: 6);
    expect(find.text('复制').hitTestable(), findsOneWidget);
  }

  Future<void> recognize(
    WidgetTester tester,
    ReaderHarness harness,
    String bookId,
    List<int> pages,
  ) async {
    final reveal = find.byTooltip('显示阅读工具').hitTestable();
    if (reveal.evaluate().isNotEmpty) {
      await tester.tap(reveal);
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.byTooltip('识别当前可见页（双页模式会识别对开两页）').hitTestable());
    final store = container(tester).read(ocrPageStoreProvider);
    var completed = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      await harness.settle(tester, rounds: 10);
      final results = await Future.wait([
        for (final page in pages) store.getPage(bookId, page),
      ]);
      if (results.every((result) => result?.hasGeometry ?? false)) {
        completed = true;
        break;
      }
    }
    expect(completed, isTrue, reason: '真实 Tesseract 应输出并持久化可见页文字及坐标');
    await harness.settle(tester, rounds: 10);
  }

  testWidgets('real OCR selection supports copy annotations notes and AI', (
    tester,
  ) async {
    final book = scannedBook('ocr-actions');
    final harness = await ReaderHarness.create(books: [book]);
    addTearDown(harness.dispose);
    addTearDown(() => harness.closeReader(tester));
    await harness.pumpReader(
      tester,
      book.id,
      size: const Size(1440, 1000),
      settings: const ReaderSettings(
        pdfZoomMode: PdfZoomMode.fitPage,
        readerMode: ReaderMode.paged,
      ),
    );
    await recognize(tester, harness, book.id, [1]);
    final store = container(tester).read(ocrPageStoreProvider);
    final result = (await store.getPage(book.id, 1))!;
    final lines = bodyLines(result);
    expect(lines.length, greaterThan(6));
    await harness.capture('ocr-01-recognized-original');

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
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
    await select(tester, harness, 1, lines[0]);
    await tester.tap(find.text('复制').hitTestable());
    await harness.settle(tester, rounds: 6);
    expect(copied, isNotEmpty);
    expect(lines[0].text, contains(copied));
    await select(tester, harness, 1, lines[0]);
    await tester.tap(find.text('高亮').hitTestable());
    await harness.settle(tester, rounds: 8);
    final annotations = await container(
      tester,
    ).read(annotationRepositoryProvider).getByBook(book.id);
    expect(annotations, hasLength(1));
    expect(annotations.single.selectedText, copied);
    expect(annotations.single.locator.selectionRects, isNotEmpty);

    await select(tester, harness, 1, lines[2]);
    await tester.tap(find.text('批注').hitTestable());
    await harness.settle(tester, rounds: 6);
    await tester.enterText(find.byType(TextFormField), '扫描页批注验收');
    await tester.tap(find.text('保存批注'));
    await harness.settle(tester, rounds: 8);
    final notes = await container(
      tester,
    ).read(noteRepositoryProvider).getByBook(book.id);
    expect(
      notes.where((note) => note.noteType == NoteType.comment),
      hasLength(1),
    );

    final page = paintedPage(tester, 1);
    final commentLine = lines[2];
    await tester.tapAt(
      page.topLeft +
          Offset(
            (commentLine.left! + commentLine.width! / 2) * page.width,
            (commentLine.top! + commentLine.height! / 2) * page.height,
          ),
    );
    await harness.settle(tester, rounds: 6);
    expect(find.text('扫描页批注验收'), findsOneWidget);
    await harness.capture('ocr-02-inline-comment');
    await tester.tap(find.byTooltip('关闭').hitTestable().last);
    await harness.settle(tester, rounds: 4);

    await select(tester, harness, 1, lines[4]);
    await tester.tap(find.text('笔记').hitTestable().last);
    await harness.settle(tester, rounds: 6);
    await tester.enterText(find.byType(TextFormField).last, '扫描页摘录验收');
    await tester.tap(find.text('保存'));
    await harness.settle(tester, rounds: 8);
    final saved = await container(
      tester,
    ).read(noteRepositoryProvider).getByBook(book.id);
    final excerpt = saved.singleWhere(
      (note) => note.noteType == NoteType.excerpt,
    );
    expect(excerpt.content, '扫描页摘录验收');
    expect(excerpt.sourceText, isNotEmpty);
    expect(excerpt.locator?.page, 1);

    await select(tester, harness, 1, lines[6]);
    await tester.tap(find.text('AI').hitTestable().last);
    await harness.settle(tester, rounds: 10);
    final panel = tester.widget<AiPanel>(find.byType(AiPanel));
    expect(panel.initialContext, isNotEmpty);
    expect(lines[6].text, contains(panel.initialContext));
    expect(panel.locator?.page, 1);
    final resizedPage = paintedPage(tester, 1);
    final selectionRect = panel.locator!.selectionRects.single;
    final startHandle = tester.getCenter(
      find.byKey(const ValueKey('pdf-selection-handle-start')),
    );
    final endHandle = tester.getCenter(
      find.byKey(const ValueKey('pdf-selection-handle-end')),
    );
    expect(
      startHandle.dx,
      closeTo(resizedPage.left + selectionRect.x * resizedPage.width, 1),
    );
    expect(
      startHandle.dy + 16,
      closeTo(resizedPage.top + selectionRect.y * resizedPage.height, 1),
    );
    expect(
      endHandle.dx,
      closeTo(
        resizedPage.left +
            (selectionRect.x + selectionRect.width) * resizedPage.width,
        1,
      ),
    );
    expect(
      endHandle.dy - 28,
      closeTo(
        resizedPage.top +
            (selectionRect.y + selectionRect.height) * resizedPage.height,
        1,
      ),
    );
    await harness.capture('ocr-03-ai-selection-context');
    expect(tester.takeException(), isNull);

    await harness.closeReader(tester);
    await harness.pumpReader(tester, book.id, size: const Size(1440, 1000));
    final reopened = await container(
      tester,
    ).read(annotationRepositoryProvider).getByBook(book.id);
    expect(reopened, hasLength(2));
    expect(
      reopened.any((annotation) => annotation.selectedText == copied),
      isTrue,
    );
    await select(tester, harness, 1, lines[6]);
    await harness.capture('ocr-04-reopened-selection');
    expect(tester.takeException(), isNull);
    await harness.closeReader(tester);
  });

  testWidgets('real OCR keeps both spread pages selectable after returning', (
    tester,
  ) async {
    final book = scannedBook('ocr-spread');
    final harness = await ReaderHarness.create(books: [book]);
    addTearDown(harness.dispose);
    addTearDown(() => harness.closeReader(tester));
    await harness.pumpReader(
      tester,
      book.id,
      initialLocator: ReadingLocator.pdf(page: 2),
      size: const Size(1600, 1000),
      settings: const ReaderSettings(
        pdfZoomMode: PdfZoomMode.fitPage,
        readerMode: ReaderMode.paged,
      ),
    );
    await recognize(tester, harness, book.id, [2, 3]);
    final store = container(tester).read(ocrPageStoreProvider);
    final left = bodyLines((await store.getPage(book.id, 2))!).first;
    final right = bodyLines((await store.getPage(book.id, 3))!).first;
    await select(tester, harness, 2, left);
    await tester.tap(find.byTooltip('关闭').hitTestable().last);
    await harness.settle(tester, rounds: 4);
    await select(tester, harness, 3, right);
    await harness.capture('ocr-05-both-spread-pages');
    await tester.tap(find.byTooltip('关闭').hitTestable().last);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await harness.settle(tester, rounds: 10);
    expect(find.byKey(const ValueKey('pdf-page-0')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await harness.settle(tester, rounds: 10);
    await select(tester, harness, 2, left);
    await tester.tap(find.byTooltip('关闭').hitTestable().last);
    await harness.settle(tester, rounds: 4);
    await select(tester, harness, 3, right);
    await harness.capture('ocr-06-returned-spread');
    expect(tester.takeException(), isNull);
    await harness.closeReader(tester);
  });
}
