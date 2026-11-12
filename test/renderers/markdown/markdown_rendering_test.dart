import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/book_document_loader.dart';
import 'package:pagesage/renderers/common/code_syntax.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pagesage/renderers/common/diagram/diagram_view.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_paginator.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';
import 'package:pagesage/renderers/markdown/markdown_document_loader.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  testWidgets('a Markdown book is laid out as prose, not as markup', (
    tester,
  ) async {
    if (captureWorkbench) {
      await tester.runAsync(loadWorkbenchCaptureFonts);
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    // The file is read in the test's real async zone: file I/O triggered from
    // inside the fake-async zone of `testWidgets` never settles.
    final document = await tester.runAsync(_loadDocument);

    await tester.pumpWidget(
      RepaintBoundary(
        key: workbenchCaptureKey,
        child: MaterialApp(
          home: Scaffold(
            body: EpubRendererView(
              book: Book(
                id: 'note-1',
                title: '笔记',
                format: BookFormat.markdown,
                libraryFilePath: '/unused.md',
                fileHash: 'hash',
                fileSize: 1,
                createdAt: 0,
                updatedAt: 0,
              ),
              settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
              initialProgress: null,
              annotations: const [],
              onEvent: (_) {},
              documentLoader: _StubLoader(document!),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The reader shows the words.
    expect(find.textContaining('正文第一段'), findsWidgets);
    expect(find.textContaining('列表项'), findsWidgets);
    // And not the markup that produced them.
    expect(find.textContaining('# '), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.text('笔记'), findsOneWidget);
    expect(find.textContaining('笔记'), findsOneWidget);
    expect(find.text('上一章'), findsNothing);
    expect(find.text('下一章'), findsNothing);
    await captureWorkbenchWidget(tester, 'markdown-continuous');
  });

  testWidgets('paged Markdown keeps chapter controls inside its layout', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadDocument);
    await _pumpMarkdownReader(
      tester,
      document!,
      [],
      settings: const ReaderSettings(readerMode: ReaderMode.paged),
    );
    expect(find.text('上一章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);
    final reader = tester.getRect(find.byType(EpubRendererView));
    final next = tester.getRect(find.text('下一章'));
    expect(next.bottom, lessThanOrEqualTo(reader.bottom));
    expect(next.top, greaterThanOrEqualTo(reader.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested Markdown quotes indent by level', (tester) async {
    final document = await tester.runAsync(_loadNestedQuoteDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final outer = tester.getTopLeft(find.text('外层引用'));
    final inner = tester.getTopLeft(find.text('内层引用'));
    final deep = tester.getTopLeft(find.text('深层引用'));

    expect(inner.dx - outer.dx, closeTo(epubQuoteIndent, 0.5));
    expect(deep.dx - inner.dx, closeTo(epubQuoteIndent, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a table inside a quote stays inside the quote column', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadQuotedTableDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final prose = tester.getTopLeft(find.text('引用段落'));
    final header = tester.getTopLeft(find.text('名称'));
    final table = tester.getRect(find.byType(Table));
    final reader = tester.getRect(find.byType(EpubRendererView));

    expect(header.dx, greaterThan(prose.dx));
    expect(table.left, greaterThan(reader.left));
    expect(table.right, lessThanOrEqualTo(reader.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quoted headings keep quote indentation without a new chapter', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadQuotedHeadingDocument);

    expect(document!.chapters, hasLength(2));
    await _pumpMarkdownReader(tester, document, <RendererEvent>[]);

    final plain = tester.getTopLeft(find.text('普通段落'));
    final quoted = tester.getTopLeft(find.text('引用正文'));

    expect(find.text('引用一级标题'), findsOneWidget);
    expect(quoted.dx - plain.dx, closeTo(epubQuoteIndent, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a folder file opens as its own document', (tester) async {
    final document = await tester.runAsync(_loadFolderDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'notes-folder',
              title: '笔记库',
              format: BookFormat.markdown,
              libraryFilePath: '/unused-folder',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('第一篇的正文'), findsWidgets);
    expect(find.textContaining('第二篇的正文'), findsNothing);
    expect(find.textContaining('# '), findsNothing);
  });

  testWidgets('a picture in a note is drawn from the file, not from memory', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadPictureDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-picture',
              title: '笔记',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image).first);
    // The document carries the picture's path, not its bytes: a folder of
    // notes with screenshots would otherwise hold every screenshot in memory.
    final resized = image.image as ResizeImage;
    expect((resized.imageProvider as FileImage).file.path, endsWith('pic.png'));
    // And it is decoded at the size the page shows, not at the file's own.
    expect(resized.width, isNotNull);
  });

  testWidgets('a picture caption is shown without entering chapter text', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadPictureDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    expect(find.text('一张图'), findsOneWidget);
    expect(document.chapters.single.text, isNot(contains('一张图')));
    final imageFragment = epubBlocks(
      document.chapters.single,
    ).firstWhere((block) => block.type == EpubBlockType.image);
    expect(imageFragment.imageCaption, '一张图');
    expect(imageFragment.startOffset, imageFragment.endOffset);
  });

  testWidgets('an unavailable picture still shows its caption once', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadMissingPictureDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    expect(find.textContaining('图片不在磁盘上'), findsOneWidget);
    expect(find.text('缺失的图'), findsOneWidget);
  });

  testWidgets('list markers and wrapped lines align to separate columns', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadListDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final marker = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.width == epubListHangingIndent &&
          widget.child is SelectionContainer,
    );
    expect(marker, findsOneWidget);
    expect(find.text('•'), findsOneWidget);
    expect(find.textContaining('这一项很长，需要换行后仍然对齐到内容列'), findsOneWidget);
    expect(document.chapters.single.text, contains('• 这一项很长'));
  });

  testWidgets('a task item draws one checkbox instead of a bullet', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadTaskListDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.text('•'), findsNothing);
    expect(find.text('☐'), findsNothing);
    expect(find.text('☑'), findsNothing);
    expect(find.textContaining('未完成的一项'), findsOneWidget);
    expect(find.textContaining('已完成的一项'), findsOneWidget);
  });

  testWidgets('a fenced code block fills the text column as a quiet panel', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadCodeBlockDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final codeText = find.textContaining('定义问题', findRichText: true);
    expect(codeText, findsOneWidget);
    final panelFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(4),
    );
    expect(panelFinder, findsOneWidget);

    final decoration =
        tester.widget<DecoratedBox>(panelFinder).decoration as BoxDecoration;
    expect(decoration.border, isNull);

    final readerWidth = tester.getSize(find.byType(EpubRendererView)).width;
    final panelWidth = tester.getSize(panelFinder).width;
    final textWidth = tester.getSize(codeText).width;
    // The panel spans the column instead of shrinking around its longest line.
    expect(panelWidth, greaterThan(readerWidth * 0.7));
    expect(panelWidth, greaterThan(textWidth + 40));
    // The fence's language is a quiet label, not part of the code text.
    expect(find.text('text'), findsOneWidget);
    final code = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .singleWhere((block) => block.type == EpubBlockType.code);
    expect(code.text, isNot(contains('text')));
    expect(document.chapters.single.text, isNot(contains('```')));
  });

  testWidgets('a fenced code block colours syntax without changing words', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadSyntaxDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final codeText = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan != null &&
            widget.textSpan!.toPlainText().contains('final answer = 42;'),
      ),
    );
    final plain = codeText.textSpan!.toPlainText();
    final spans = <TextSpan>[];
    codeText.textSpan!.visitChildren((span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
    TextSpan spanFor(String words) =>
        spans.firstWhere((span) => span.text == words);

    expect(plain, contains('// 说明'));
    expect(plain, contains('final answer = 42;'));
    expect(plain, contains('print("完成")'));
    expect(
      spanFor('final').style?.color,
      codeSyntaxColor(ReaderThemePreset.day, EpubCodeTokenType.keyword),
    );
    expect(
      spanFor('42').style?.color,
      codeSyntaxColor(ReaderThemePreset.day, EpubCodeTokenType.number),
    );
    expect(
      spanFor('"完成"').style?.color,
      codeSyntaxColor(ReaderThemePreset.day, EpubCodeTokenType.string),
    );
    expect(
      spanFor(' answer = ').style?.color,
      ReaderThemePreset.day.foreground,
    );
    expect(plain, isNot(contains('```')));
    expect(find.textContaining('```'), findsNothing);
  });

  testWidgets('syntax colours do not erase a search hit inside code', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadSyntaxDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-syntax-search',
              title: '高亮',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            searchQuery: 'final',
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final codeText = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan != null &&
            widget.textSpan!.toPlainText().contains('final answer = 42;'),
      ),
    );
    final spans = <TextSpan>[];
    codeText.textSpan!.visitChildren((span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
    final hit = spans.singleWhere((span) => span.text == 'final');
    expect(
      hit.style?.color,
      codeSyntaxColor(ReaderThemePreset.day, EpubCodeTokenType.keyword),
    );
    expect(hit.style?.backgroundColor, isNotNull);
  });

  testWidgets('math is typeset and diagrams render with switchable source', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadBoundaryDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    expect(find.byType(Math), findsWidgets);
    expect(find.text('Mermaid'), findsOneWidget);
    expect(find.byType(MermaidDiagramView), findsOneWidget);
    expect(find.text('Mermaid 图形'), findsOneWidget);
    expect(find.textContaining(r'\frac{a}{b}'), findsNothing);
    expect(find.textContaining('graph TD'), findsNothing);
    expect(find.textContaining('```'), findsNothing);
    expect(find.textContaining('<script'), findsNothing);
    expect(find.textContaining('alert(1)'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('HTML & 内容'), findsOneWidget);
    expect(find.textContaining('已忽略 script 标签'), findsOneWidget);

    await tester.tap(find.byTooltip('查看源码'));
    await tester.pumpAndSettle();
    expect(find.text('Mermaid 源码'), findsOneWidget);
    expect(find.textContaining('graph TD'), findsOneWidget);

    await tester.tap(find.byTooltip('查看图形'));
    await tester.pumpAndSettle();
    expect(find.text('Mermaid 图形'), findsOneWidget);
    expect(find.textContaining('graph TD'), findsNothing);
  });

  testWidgets('malformed math falls back to its readable source', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadMalformedMathDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    expect(find.textContaining(r'\frac{1}{'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact TeX from a question sheet is typeset as inline math', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadCompactMathDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final math = tester.widgetList<Math>(find.byType(Math));
    expect(math, isNotEmpty);
    expect(find.textContaining(r'\displaystyle'), findsNothing);
    expect(find.textContaining(r'\frac1'), findsNothing);
    expect(find.textContaining(r'$D='), findsNothing);
    expect(find.textContaining(r'\mid'), findsNothing);
    expect(find.textContaining(r'\iint'), findsNothing);
  });

  testWidgets('short prose after display math keeps the reader column', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadShortProseAfterMathDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    // The display equation is narrower than the reading column. The short
    // paragraph after it must stay on the same left edge as the prose above,
    // not shrink-wrap into a centered mini-column.
    final next = tester.getTopLeft(find.text('则（ ）。'));
    expect(next.dx, closeTo(24, 0.5));
  });

  testWidgets('a safe external link asks the host before opening', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadLinkDocument);
    final events = <RendererEvent>[];

    await _pumpMarkdownReader(tester, document!, events);

    await tester.tapOnText(
      find.textRange.ofSubstring(
        '安全',
        descendentOf: find.byType(EpubRendererView),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      events.whereType<RendererExternalLinkRequested>().single.uri,
      'https://example.com',
    );

    await tester.tapOnText(
      find.textRange.ofSubstring(
        '锚点',
        descendentOf: find.byType(EpubRendererView),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapOnText(
      find.textRange.ofSubstring(
        '危险',
        descendentOf: find.byType(EpubRendererView),
      ),
    );
    await tester.pumpAndSettle();
    // The invalid link starts a text selection. Tap the plain words near
    // their left edge instead of going through the selection-aware text
    // finder, which would be blocked by the selection overlay.
    final plain = tester.getRect(find.textContaining('普通').first);
    await tester.tapAt(plain.topLeft + Offset(10, plain.height / 2));
    await tester.pumpAndSettle();
    expect(events.whereType<RendererExternalLinkRequested>(), hasLength(1));
  });

  testWidgets('a heading link jumps inside the document', (tester) async {
    final document = await tester.runAsync(_loadHeadingLinkDocument);
    final events = <RendererEvent>[];
    final source = document!;
    final target = source.chapters.single.anchors['目标小节']!;

    await _pumpMarkdownReader(tester, source, events);

    await tester.tap(find.text('跳到目标'));
    await tester.pumpAndSettle();

    final locator = events
        .whereType<RendererInternalLinkRequested>()
        .single
        .locator;
    expect(locator.chapterIndex, 0);
    expect(locator.chapterOffset, target);
    expect(events.whereType<RendererExternalLinkRequested>(), isEmpty);
  });

  testWidgets('bold, italic, code and links are set apart from the prose', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadInlineDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-inline',
              title: '样式',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere(
          (widget) => widget.textSpan?.toPlainText().contains('粗体') ?? false,
        );
    final spans = <TextSpan>[];
    paragraph.textSpan!.visitChildren((span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
    TextSpan spanFor(String words) =>
        spans.firstWhere((span) => span.text == words);

    expect(spanFor('粗体').style?.fontWeight, FontWeight.w700);
    expect(spanFor('斜体').style?.fontStyle, FontStyle.italic);
    expect(spanFor('代码').style?.fontFamily, 'monospace');
    expect(
      spanFor('链接').style?.decoration,
      TextDecoration.combine(const [TextDecoration.underline]),
    );
    // The plain words beside them are set in nothing special.
    expect(spanFor('普通').style?.fontWeight, isNot(FontWeight.w700));
    expect(spanFor('普通').style?.decoration, isNull);
  });

  testWidgets('safe inline HTML keeps its reading styles and line breaks', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadInlineHtmlDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    final paragraph = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere(
          (widget) => widget.textSpan?.toPlainText().contains('粗体') ?? false,
        );
    final spans = <TextSpan>[];
    paragraph.textSpan!.visitChildren((span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
    TextSpan spanFor(String words) =>
        spans.firstWhere((span) => span.text == words);

    expect(spanFor('粗体').style?.fontWeight, FontWeight.w700);
    expect(
      spanFor('下划线').style?.decoration,
      TextDecoration.combine(const [TextDecoration.underline]),
    );
    expect(spanFor('重点').style?.backgroundColor, isNotNull);
    expect(spanFor('Ctrl').style?.fontFamily, 'monospace');
    expect(
      spanFor('水').style?.fontFeatures,
      contains(const FontFeature.subscripts()),
    );
    expect(
      spanFor('幂').style?.fontFeatures,
      contains(const FontFeature.superscripts()),
    );
    expect(paragraph.textSpan?.toPlainText(), contains('\n下一行。'));
    expect(paragraph.textSpan?.toPlainText(), isNot(contains('<')));
  });

  testWidgets(
    'footnote references are set apart and the back arrows are hidden',
    (tester) async {
      if (captureWorkbench) {
        await tester.runAsync(loadWorkbenchCaptureFonts);
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final document = await tester.runAsync(_loadFootnoteDocument);

      await _pumpMarkdownReader(
        tester,
        document!,
        <RendererEvent>[],
        capture: captureWorkbench,
      );

      expect(find.textContaining('脚注定义'), findsOneWidget);
      expect(find.textContaining('↩'), findsNothing);

      final body = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan?.toPlainText() == '正文有一处脚注1，还有第二处2。',
        ),
      );
      final spans = <TextSpan>[];
      body.textSpan!.visitChildren((span) {
        if (span is TextSpan) {
          spans.add(span);
        }
        return true;
      });
      final reference = spans.firstWhere((span) => span.text == '1');
      expect(reference.style?.fontSize, lessThan(18));
      expect(
        reference.style?.fontFeatures,
        contains(const FontFeature.superscripts()),
      );

      final footnote = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan?.toPlainText().contains('这是一条脚注定义') == true,
        ),
      );
      expect(footnote.textSpan?.style?.fontSize, lessThan(18));
      await captureWorkbenchWidget(tester, 'markdown-footnotes');
    },
  );

  testWidgets('a footnote reference jumps to its definition chapter', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadCrossChapterFootnoteDocument);
    final events = <RendererEvent>[];
    final source = document!;
    final target = source.chapters.last.anchors['fn-cross']!;

    await _pumpMarkdownReader(tester, source, events);

    final body = find.byWidgetPredicate(
      (widget) => widget is Text && widget.textSpan?.toPlainText() == '正文引用1。',
    );
    await tester.tapOnText(find.textRange.ofSubstring('1', descendentOf: body));
    await tester.pumpAndSettle();

    final locator = events
        .whereType<RendererInternalLinkRequested>()
        .single
        .locator;
    expect(locator.chapterIndex, 1);
    expect(locator.chapterOffset, target);
    expect(events.whereType<RendererExternalLinkRequested>(), isEmpty);
  });

  testWidgets('a footnote without a matching anchor stays in place', (
    tester,
  ) async {
    final source = await tester.runAsync(_loadCrossChapterFootnoteDocument);
    final document = EpubDocument(
      chapters: [
        for (final chapter in source!.chapters)
          EpubChapter(
            index: chapter.index,
            href: chapter.href,
            title: chapter.title,
            text: chapter.text,
            blocks: chapter.blocks,
          ),
      ],
    );
    final events = <RendererEvent>[];

    await _pumpMarkdownReader(tester, document, events);

    final body = find.byWidgetPredicate(
      (widget) => widget is Text && widget.textSpan?.toPlainText() == '正文引用1。',
    );
    await tester.tapOnText(find.textRange.ofSubstring('1', descendentOf: body));
    await tester.pumpAndSettle();

    expect(events.whereType<RendererInternalLinkRequested>(), isEmpty);
    expect(events.whereType<RendererExternalLinkRequested>(), isEmpty);
  });

  testWidgets('a saved footnote offset lands on its definition', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadLongFootnoteDocument);
    final source = document!;
    final target = source.chapters.last.anchors['fn-cross']!;
    final progress = source.progressForChapter(
      chapterIndex: 1,
      chapterOffset: target,
    );

    await _pumpMarkdownReader(
      tester,
      source,
      <RendererEvent>[],
      initialProgress: ReadingProgressSnapshot(
        bookId: 'note-p6',
        locator: ReadingLocator.markdown(
          href: 'note.md',
          chapterIndex: 1,
          chapterOffset: target,
          progress: progress,
        ),
        progress: progress,
        updatedAt: 0,
      ),
    );

    expect(find.textContaining('定义在后面的章节'), findsOneWidget);
  });

  testWidgets('a heading is set at the size its level asks for', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadHeadingDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-heading',
              title: '标题',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double sizeOf(String words) {
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere(
            (widget) => widget.textSpan?.toPlainText().contains(words) ?? false,
          );
      return text.textSpan!.style!.fontSize!;
    }

    expect(sizeOf('二级'), greaterThan(sizeOf('三级')));
    expect(sizeOf('三级'), greaterThan(sizeOf('正文')));
  });

  testWidgets('a horizontal rule is drawn as a rule, not as dashes', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadDividerDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-divider',
              title: '分隔线',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == 1 &&
            widget.width == double.infinity,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('---'), findsNothing);
  });

  testWidgets('a table is drawn as a table, not as lines of pipes', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadTableDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-table',
              title: '表格',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('苹果'), findsOneWidget);
    // The markup that made the table is not on the page.
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('---'), findsNothing);
  });

  testWidgets('table columns follow their delimiter alignment', (tester) async {
    final document = await tester.runAsync(_loadAlignedTableDocument);

    await _pumpMarkdownReader(tester, document!, <RendererEvent>[]);

    expect(tester.widget<Text>(find.text('苹果')).textAlign, TextAlign.left);
    expect(tester.widget<Text>(find.text('香蕉')).textAlign, TextAlign.center);
    expect(tester.widget<Text>(find.text('123')).textAlign, TextAlign.right);
    expect(tester.widget<Text>(find.text('右列')).textAlign, TextAlign.right);
  });

  testWidgets('paged tables keep their column alignment', (tester) async {
    final document = await tester.runAsync(_loadAlignedTableDocument);

    await _pumpMarkdownReader(
      tester,
      document!,
      <RendererEvent>[],
      settings: const ReaderSettings(
        fontSize: 18,
        lineHeight: 1.7,
        readerMode: ReaderMode.paged,
      ),
    );

    expect(tester.widget<Text>(find.text('123')).textAlign, TextAlign.right);
    expect(tester.widget<Text>(find.text('香蕉')).textAlign, TextAlign.center);
  });

  testWidgets('table cells set inline styles and links like prose', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadStyledTableDocument);
    final events = <RendererEvent>[];

    await _pumpMarkdownReader(tester, document!, events);

    Text cellFor(String words) => tester.widget<Text>(find.text(words));
    TextSpan spanFor(Text cell, String words) {
      final spans = <TextSpan>[];
      cell.textSpan!.visitChildren((span) {
        if (span is TextSpan) {
          spans.add(span);
        }
        return true;
      });
      return spans.firstWhere((span) => span.text == words);
    }

    final fruit = cellFor('苹果');
    final note = cellFor('3 与 链接');
    expect(spanFor(fruit, '苹果').style?.fontWeight, FontWeight.w700);
    expect(spanFor(note, '3').style?.fontFamily, 'monospace');
    expect(
      spanFor(note, '链接').style?.decoration,
      TextDecoration.combine(const [TextDecoration.underline]),
    );
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining(']('), findsNothing);

    await tester.tapOnText(
      find.textRange.ofSubstring(
        '链接',
        descendentOf: find.byType(EpubRendererView),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      events.whereType<RendererExternalLinkRequested>().single.uri,
      'https://example.com',
    );
  });

  testWidgets('table cells carry search hits, annotations and focus marks', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadStyledTableDocument);
    final chapter = document!.chapters.single;
    final table = chapter.blocks.whereType<EpubTableBlock>().single;
    final fruit = table.cells[1][0];
    final note = table.cells[1][1];
    final annotation = Annotation(
      id: 'annotation-fruit',
      bookId: 'note-p6',
      locator: ReadingLocator.markdown(
        chapterIndex: chapter.index,
        chapterOffset: fruit.chapterOffset,
        chapterEndOffset: fruit.chapterOffset + fruit.text.length,
        excerpt: fruit.text,
      ),
      selectedText: fruit.text,
      color: AnnotationColor.yellow,
      style: AnnotationStyle.highlight,
      createdAt: 0,
      updatedAt: 0,
    );

    await _pumpMarkdownReader(
      tester,
      document,
      <RendererEvent>[],
      annotations: <Annotation>[annotation],
      searchQuery: '3',
      focusLocator: ReadingLocator.markdown(
        chapterIndex: chapter.index,
        chapterOffset: note.chapterOffset + 4,
        chapterEndOffset: note.chapterOffset + 6,
        excerpt: '链接',
      ),
    );

    Text cellFor(String words) => tester.widget<Text>(find.text(words));
    TextSpan spanFor(Text cell, String words) {
      final spans = <TextSpan>[];
      cell.textSpan!.visitChildren((span) {
        if (span is TextSpan) {
          spans.add(span);
        }
        return true;
      });
      return spans.firstWhere((span) => span.text == words);
    }

    final annotated = spanFor(cellFor('苹果'), '苹果');
    expect(annotated.style?.backgroundColor, const Color(0x99FFE58A));
    expect(annotated.recognizer, isNotNull);
    expect(
      spanFor(cellFor('3 与 链接'), '3').style?.backgroundColor,
      const Color(0x99FFD659),
    );
    expect(
      spanFor(cellFor('3 与 链接'), '链接').style?.backgroundColor,
      const Color(0xCCFFE066),
    );
  });
}

/// A note with every inline style on one line.
Future<EpubDocument> _loadInlineDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_inline_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 样式

普通**粗体**和*斜体*还有`代码`与[链接](https://example.com)。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadInlineHtmlDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_html_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString(r'''
# 行内 HTML

前 <b>粗体</b>、<u>下划线</u>、<mark>重点</mark>、<kbd>Ctrl</kbd>。
H<sub>水</sub>O，x<sup>幂</sup>。<br>下一行。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadMissingPictureDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_missing_pic_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('# 图\n\n![缺失的图](gone.png)');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadListDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_list_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString(
    '# 列表\n\n- 这一项很长，需要换行后仍然对齐到内容列，'
    '于是渲染器必须把标记和文字分到两个视觉列里。\n',
  );
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadTaskListDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_task_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 任务

- [ ] 未完成的一项
- [x] 已完成的一项
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadCodeBlockDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_code_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 代码

```text
定义问题
→ 判断决策等级
```
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadSyntaxDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_syntax_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 高亮

```dart
// 说明
final answer = 42;
print("完成");
```
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadBoundaryDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_boundary_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString(r'''
# 边界

$$
\frac{a}{b} + \sqrt{x}
$$

```mermaid
graph TD
  A[开始] --> B[结束]
```

<script>alert(1)</script>

<div class="note">
  <p>HTML &amp; 内容。</p>
</div>
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadMalformedMathDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_bad_math_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString(r'''
# 公式

$$
\frac{1}{
$$
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadCompactMathDocument() async {
  final dir = await Directory.systemTemp.createTemp(
    'pagesage_md_compact_math_',
  );
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString(r'''
# 选择题

设 $\displaystyle \lim_{x\to0}\frac1{x^2}=1$，则（ ）。

设 $D=\{(x,y)\mid x^2+y^2\le4,\ y\ge0\}$，则 $\displaystyle\iint_D(x^2+y^2)\,dxdy=\underline{\hspace{3cm}}$。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadShortProseAfterMathDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_math_column_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString(r'''
# 题

设 $f(x)$ 在 $x=0$ 的某邻域内有定义，且

$$
\lim_{x\to0}\frac{f(x)-f(0)}{x^2}=1,
$$

则（ ）。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadLinkDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_link_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 链接

普通 [安全](https://example.com) [锚点](#section)
[危险](javascript:alert(1)) [邮件](mailto:reader@example.com)。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadHeadingLinkDocument() async {
  final dir = await Directory.systemTemp.createTemp(
    'pagesage_md_heading_link_',
  );
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 标题

[跳到目标](#目标小节)

## 目标小节

目标正文。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadFootnoteDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_footnote_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 脚注

正文有一处脚注[^why]，还有第二处[^two]。

[^why]: 这是一条脚注定义，里面有 **重点**。
[^two]: 第二条。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadCrossChapterFootnoteDocument() async {
  final dir = await Directory.systemTemp.createTemp(
    'pagesage_md_cross_footnote_ui_',
  );
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 第一章

正文引用[^cross]。

# 第二章

后记。

[^cross]: 定义在后面的章节。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadLongFootnoteDocument() async {
  final dir = await Directory.systemTemp.createTemp(
    'pagesage_md_long_footnote_ui_',
  );
  addTearDown(() => dir.delete(recursive: true));
  final filler = List<String>.generate(
    48,
    (index) => '这是第二章的第 $index 段文字，用来把脚注推到很远的下面。',
  ).join('\n\n');
  await File('${dir.path}/note.md').writeAsString('''
# 第一章

正文引用[^cross]。

# 第二章

$filler

[^cross]: 定义在后面的章节。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<void> _pumpMarkdownReader(
  WidgetTester tester,
  EpubDocument document,
  List<RendererEvent> events, {
  ReaderSettings settings = const ReaderSettings(fontSize: 18, lineHeight: 1.7),
  ReadingProgressSnapshot? initialProgress,
  List<Annotation> annotations = const <Annotation>[],
  String? searchQuery,
  ReadingLocator? focusLocator,
  int jumpToken = 0,
  bool capture = false,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture ? workbenchCaptureKey : null,
      child: MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-p6',
              title: '笔记',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: settings,
            initialProgress: initialProgress,
            annotations: annotations,
            searchQuery: searchQuery,
            focusLocator: focusLocator,
            onEvent: events.add,
            jumpToken: jumpToken,
            documentLoader: _StubLoader(document),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A note with headings of two levels above a paragraph.
Future<EpubDocument> _loadHeadingDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_head_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 一级

## 二级

### 三级

正文。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadNestedQuoteDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_quote_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 引用

> 外层引用
>
> > 内层引用
> >
> > > 深层引用
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadQuotedTableDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_quote_table_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 引用表格

> 引用段落
>
> | 名称 | 数量 |
> | --- | --- |
> | 苹果 | 3 |
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadQuotedHeadingDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_quote_head_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 第一章

普通段落

> # 引用一级标题
>
> 引用正文

# 第二章

结尾
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

/// A note with a rule between two paragraphs.
Future<EpubDocument> _loadDividerDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_rule_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 分隔线

上面。

---

下面。
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

/// A note with one table in it.
Future<EpubDocument> _loadTableDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_table_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 表格

| 名称 | 数量 |
| --- | --- |
| 苹果 | 3 |
| 香蕉 | 12 |
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadAlignedTableDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_align_table_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 对齐

| 左列 | 中列 | 右列 |
| :--- | :---: | ---: |
| 苹果 | 香蕉 | 123 |
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

Future<EpubDocument> _loadStyledTableDocument() async {
  final dir = await Directory.systemTemp.createTemp(
    'pagesage_md_styled_table_',
  );
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 样式表格

| 名称 | 说明 |
| --- | --- |
| **苹果** | `3` 与 [链接](https://example.com) |
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

/// A note with one picture beside it.

/// A note with one picture beside it.
Future<EpubDocument> _loadPictureDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_pic_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/pic.png').writeAsBytes(_pngBytes(32, 16));
  await File('${dir.path}/note.md').writeAsString('# 图\n\n![一张图](pic.png)');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

List<int> _pngBytes(int width, int height) {
  return <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52,
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    0x08, 0x02, 0x00, 0x00, 0x00,
  ];
}

/// Builds a small folder and opens only the selected note.
Future<EpubDocument> _loadFolderDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_folder_ui_');
  addTearDown(() => dir.delete(recursive: true));
  final first = File('${dir.path}/a.md')..writeAsStringSync('# 第一篇\n\n第一篇的正文。');
  await File('${dir.path}/b.md').writeAsString('# 第二篇\n\n第二篇的正文。');
  return const MarkdownDocumentLoader().loadWithHref(first.path, 'a.md');
}

/// Builds a small Markdown book on disk and opens it the way the app does.
Future<EpubDocument> _loadDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_ui_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/note.md');
  await file.writeAsString('''
# 笔记

正文第一段，带**强调**。

- 列表项一
- 列表项二
''');
  return const MarkdownDocumentLoader().load(file.path);
}

/// Hands the renderer a document built outside the fake-async zone.
final class _StubLoader implements BookDocumentLoader {
  const _StubLoader(this.document);

  final EpubDocument document;

  @override
  Future<EpubDocument> load(String filePath) async => document;
}
