import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_paginator.dart';

void main() {
  test('paginates long paragraphs without exceeding measured page height', () {
    final chapter = EpubChapter(
      index: 0,
      href: 'chapter.xhtml',
      title: 'Long chapter',
      text: '${'很长的一段文本用于分页测试。' * 120}\n\n${'Second paragraph. ' * 80}',
    );
    final document = EpubDocument(chapters: [chapter]);
    const settings = ReaderSettings(
      fontSize: 18,
      lineHeight: 1.7,
      paragraphSpacing: 12,
      pageMargin: 24,
    );

    final pages = const EpubPaginator().paginate(
      document: document,
      settings: settings,
      viewport: const Size(420, 520),
    );

    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: const Size(420, 520),
    );
    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      expect(page.paragraphs, isNotEmpty);
      expect(page.fragments, isNotEmpty);
      expect(page.startOffset, lessThan(page.endOffset));
      expect(
        page.measuredHeight,
        lessThanOrEqualTo(metrics.contentHeight + 0.5),
      );
    }
  });

  test('a table gives its wide column the wider share of the line', () {
    final flex = epubTableColumnFlex([
      ['数量', '说明'],
      ['3', '这一列是整段说明文字，应该分到更多宽度。'],
    ]);

    expect(flex, hasLength(2));
    expect(flex[1], greaterThan(flex[0]));
    // Bounded: one verbose cell cannot push the other columns off the page.
    expect(flex.every((share) => share >= 4 && share <= 28), isTrue);
  });

  test('a table longer than a page is split by rows, header repeated', () {
    final rows = <List<String>>[
      ['名称', '说明'],
      for (var index = 0; index < 40; index++) ['第$index项', '这一行的说明文字。'],
    ];
    final text = rows.map((row) => row.join('   ')).join('\n');
    final chapter = EpubChapter(
      index: 0,
      href: 'table.md',
      title: '表格',
      text: text,
      blocks: [
        EpubTableBlock(
          startOffset: 0,
          endOffset: text.length,
          text: text,
          rows: rows,
          hasHeader: true,
        ),
      ],
    );
    const settings = ReaderSettings(
      fontSize: 18,
      lineHeight: 1.7,
      paragraphSpacing: 12,
      pageMargin: 24,
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: settings,
      viewport: const Size(420, 520),
    );

    expect(pages.length, greaterThan(1));
    final bodyRows = <List<String>>[];
    for (final page in pages) {
      final fragment = page.fragments.single;
      expect(fragment.blockType, EpubBlockType.table);
      expect(fragment.tableRows, isNotNull);
      // Every page of the table says what its columns are.
      expect(fragment.tableRows!.first, ['名称', '说明']);
      bodyRows.addAll(fragment.tableRows!.skip(1));
    }
    // Every row appears once, in order, and none is lost at a page break.
    expect(bodyRows, rows.skip(1).toList());
  });

  test('pagination progress is monotonic across chapters and sizes', () {
    final document = EpubDocument(
      chapters: [
        EpubChapter(
          index: 0,
          href: 'one.xhtml',
          title: 'One',
          text: 'Alpha ' * 300,
        ),
        EpubChapter(
          index: 1,
          href: 'two.xhtml',
          title: 'Two',
          text: 'Beta ' * 300,
        ),
      ],
    );

    final pages = const EpubPaginator().paginate(
      document: document,
      settings: const ReaderSettings(fontSize: 22, lineHeight: 1.9),
      viewport: const Size(600, 700),
    );

    var previous = -1.0;
    for (final page in pages) {
      expect(page.progress, greaterThanOrEqualTo(previous));
      previous = page.progress;
    }
  });

  test('splits long text into monotonic chapter offset fragments', () {
    final chapter = EpubChapter(
      index: 0,
      href: 'chapter.xhtml',
      title: 'Offsets',
      text: '标题\n\n${'Alpha beta gamma delta. ' * 180}',
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(fontSize: 20, lineHeight: 1.8),
      viewport: const Size(420, 500),
    );

    expect(pages.length, greaterThan(1));
    var previousEnd = -1;
    for (final fragment in pages.expand((page) => page.fragments)) {
      expect(fragment.startOffset, greaterThanOrEqualTo(previousEnd));
      expect(fragment.endOffset, greaterThan(fragment.startOffset));
      previousEnd = fragment.endOffset;
    }
  });

  test('uses constrained reader measure width and detects code blocks', () {
    final chapter = EpubChapter(
      index: 0,
      href: 'code.xhtml',
      title: 'Code',
      text:
          'Code\n\n  final answer = 42;\n  print(answer);\n\nPlain paragraph.',
    );
    const settings = ReaderSettings(pageMargin: 24);

    final blocks = epubBlocks(chapter);
    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: const Size(1200, 800),
    );

    expect(blocks.map((block) => block.type), contains(EpubBlockType.code));
    expect(metrics.contentWidth, 760);
    expect(
      metrics.measureWidthFor(EpubBlockType.code),
      lessThan(metrics.contentWidth),
    );
  });

  test('paginateChapter keeps progress monotonic within a chapter', () {
    final chapter = EpubChapter(
      index: 1,
      href: 'two.xhtml',
      title: 'Chapter Two',
      text: '${'分页单章测试文本。' * 100}\n\n${'Another block. ' * 60}',
    );
    const settings = ReaderSettings(
      fontSize: 18,
      lineHeight: 1.7,
      paragraphSpacing: 12,
      pageMargin: 24,
    );
    final pages = const EpubPaginator().paginateChapter(
      chapter: chapter,
      settings: settings,
      viewport: const Size(420, 520),
      globalOffset: 500,
      totalLength: 5000,
    );
    expect(pages, isNotEmpty);
    expect(pages.first.chapter.index, 1);
    expect(pages.first.progress, greaterThan(0));
    for (var i = 1; i < pages.length; i += 1) {
      expect(pages[i].progress, greaterThanOrEqualTo(pages[i - 1].progress));
      expect(pages[i].pageNumberInChapter, i + 1);
      expect(pages[i].totalPagesInChapter, pages.length);
    }
  });

  test('a heading of a higher level is set larger but leaves less air', () {
    const settings = ReaderSettings(
      fontSize: 18,
      lineHeight: 1.7,
      paragraphSpacing: 12,
      pageMargin: 24,
    );
    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: const Size(420, 520),
    );

    final h2 = metrics.styleFor(EpubBlockType.heading, headingLevel: 2);
    final h3 = metrics.styleFor(EpubBlockType.heading, headingLevel: 3);
    expect(h2.fontSize, greaterThan(h3.fontSize!));
    expect(
      metrics.spacingFor(EpubBlockType.heading, headingLevel: 1),
      greaterThan(metrics.spacingFor(EpubBlockType.heading, headingLevel: 3)),
    );
  });

  test('inline styles travel with the text they belong to', () {
    final text = '一段粗体的文字。';
    final chapter = EpubChapter(
      index: 0,
      href: 'note.md',
      title: '笔记',
      text: text,
      blocks: [
        EpubTextBlock(
          startOffset: 0,
          endOffset: text.length,
          text: text,
          type: EpubBlockType.paragraph,
          runs: const [
            EpubInlineRun(start: 2, end: 4, style: EpubInlineStyle.strong),
          ],
        ),
      ],
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
      viewport: const Size(420, 520),
    );

    final fragment = pages.single.fragments.single;
    expect(fragment.text, text);
    expect(fragment.inlineRuns.single.style, EpubInlineStyle.strong);
    // The run still points at the same words in chapter coordinates.
    expect(text.substring(2, 4), '粗体');
  });

  test('a rule is a block of its own, between the paragraphs', () {
    const first = '上面。';
    const second = '下面。';
    final text = '\$first\n\n\$second';
    final chapter = EpubChapter(
      index: 0,
      href: 'note.md',
      title: '笔记',
      text: text,
      blocks: [
        const EpubTextBlock(
          startOffset: 0,
          endOffset: first.length,
          text: first,
          type: EpubBlockType.paragraph,
        ),
        const EpubDividerBlock(startOffset: first.length + 2),
        EpubTextBlock(
          startOffset: first.length + 4,
          endOffset: text.length,
          text: second,
          type: EpubBlockType.paragraph,
        ),
      ],
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
      viewport: const Size(420, 520),
    );

    final fragments = pages.expand((page) => page.fragments).toList();
    final divider = fragments.indexWhere(
      (fragment) => fragment.blockType == EpubBlockType.divider,
    );
    expect(divider, greaterThan(0));
    expect(fragments[divider + 1].blockType, EpubBlockType.paragraph);
    expect(pages.first.measuredHeight, greaterThan(epubDividerHeight));
  });
}
