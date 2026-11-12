import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_paginator.dart';

void main() {
  test('list items sit closer than paragraphs and rules keep their air', () {
    const spacing = 12.0;
    final paragraph = epubBlockSpacing(
      type: EpubBlockType.paragraph,
      paragraphSpacing: spacing,
    );
    final list = epubBlockSpacing(
      type: EpubBlockType.paragraph,
      paragraphSpacing: spacing,
      isList: true,
    );

    expect(list, lessThan(paragraph));
    expect(list, closeTo(spacing * epubListSpacingFactor, 0.0001));
    expect(
      epubBlockSpacing(type: EpubBlockType.divider, paragraphSpacing: spacing),
      closeTo(spacing * 1.6, 0.0001),
    );
  });

  test(
    'nested quote depth survives pagination and narrows the text column',
    () {
      const outer = '外层引用';
      const inner = '内层引用';
      const deep = '深层引用';
      final text = '$outer\n\n$inner\n\n$deep';
      final chapter = EpubChapter(
        index: 0,
        href: 'quote.md',
        title: '引用',
        text: text,
        blocks: [
          const EpubTextBlock(
            startOffset: 0,
            endOffset: 4,
            text: outer,
            type: EpubBlockType.quote,
            quoteDepth: 1,
          ),
          const EpubTextBlock(
            startOffset: 6,
            endOffset: 10,
            text: inner,
            type: EpubBlockType.quote,
            quoteDepth: 2,
          ),
          const EpubTextBlock(
            startOffset: 12,
            endOffset: 16,
            text: deep,
            type: EpubBlockType.quote,
            quoteDepth: 3,
          ),
        ],
      );
      const settings = ReaderSettings(pageMargin: 24);
      const viewport = Size(420, 520);

      final fragments = const EpubPaginator()
          .paginate(
            document: EpubDocument(chapters: [chapter]),
            settings: settings,
            viewport: viewport,
          )
          .expand((page) => page.fragments)
          .toList();
      final metrics = EpubPageMetrics.from(
        settings: settings,
        viewport: viewport,
      );

      expect(
        [for (final fragment in fragments) fragment.quoteDepth],
        [1, 2, 3],
      );
      expect(
        metrics.measureWidthFor(EpubBlockType.quote, quoteDepth: 3),
        lessThan(metrics.measureWidthFor(EpubBlockType.quote, quoteDepth: 1)),
      );
      expect(
        metrics.measureWidthFor(EpubBlockType.paragraph, quoteDepth: 3),
        lessThan(
          metrics.measureWidthFor(EpubBlockType.paragraph, quoteDepth: 1),
        ),
      );
      expect(
        metrics.measureWidthForList(1, quoteDepth: 3),
        lessThan(metrics.measureWidthForList(1, quoteDepth: 1)),
      );
      const rows = <List<String>>[
        <String>['名称', '数量'],
        <String>['苹果', '3'],
      ];
      final cells = _cells(rows);
      expect(
        metrics.tableColumnTextWidths(cells, quoteDepth: 3).first,
        lessThan(metrics.tableColumnTextWidths(cells, quoteDepth: 1).first),
      );
    },
  );

  test('non-text blocks in a quote carry their depth into pages', () {
    const body = '段落';
    const tableText = '名称   数量\n苹果   3';
    final image = EpubImage(
      archivePath: 'picture.png',
      bytes: Uint8List(0),
      pixelWidth: 100,
      pixelHeight: 50,
    );
    final chapter = EpubChapter(
      index: 0,
      href: 'quote-blocks.md',
      title: '引用',
      text: '$body$tableText',
      blocks: [
        const EpubTextBlock(
          startOffset: 0,
          endOffset: 2,
          text: body,
          type: EpubBlockType.quote,
          quoteDepth: 1,
        ),
        const EpubDividerBlock(startOffset: 2, quoteDepth: 2),
        EpubImageBlock(startOffset: 2, image: image, quoteDepth: 2),
        EpubTableBlock(
          startOffset: 2,
          endOffset: 2 + tableText.length,
          text: tableText,
          cells: _cells(const [
            <String>['名称', '数量'],
            <String>['苹果', '3'],
          ]),
          hasHeader: true,
          quoteDepth: 2,
        ),
      ],
    );

    final fragments = const EpubPaginator()
        .paginate(
          document: EpubDocument(chapters: [chapter]),
          settings: const ReaderSettings(pageMargin: 24),
          viewport: const Size(420, 520),
        )
        .expand((page) => page.fragments)
        .toList();

    expect(
      fragments
          .firstWhere((fragment) => fragment.blockType == EpubBlockType.divider)
          .quoteDepth,
      2,
    );
    expect(
      fragments
          .firstWhere((fragment) => fragment.blockType == EpubBlockType.image)
          .quoteDepth,
      2,
    );
    expect(
      fragments
          .firstWhere((fragment) => fragment.blockType == EpubBlockType.table)
          .quoteDepth,
      2,
    );
  });

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
      expect(page.measuredHeight, lessThanOrEqualTo(metrics.contentHeight + 8));
    }
  });

  test('a table gives its wide column the wider share of the line', () {
    final flex = epubTableColumnFlex(
      _cells(const [
        ['数量', '说明'],
        ['3', '这一列是整段说明文字，应该分到更多宽度。'],
      ]),
    );

    expect(flex, hasLength(2));
    expect(flex[1], greaterThan(flex[0]));
    // Bounded: one verbose cell cannot push the other columns off the page.
    expect(flex.every((share) => share >= 4 && share <= 28), isTrue);
  });

  test('a table longer than a page is split by rows, header repeated', () {
    final rowTexts = <List<String>>[
      ['名称', '说明'],
      for (var index = 0; index < 40; index++) ['第$index项', '这一行的说明文字。'],
    ];
    final rows = _cells(rowTexts);
    final text = rowTexts.map((row) => row.join('   ')).join('\n');
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
          cells: rows,
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
    expect(bodyRows, rowTexts.skip(1).toList());
  });

  test('table cell runs survive row splitting and repeated headers', () {
    final rows = <List<EpubTableCell>>[
      <EpubTableCell>[
        const EpubTableCell(
          text: '名称',
          runs: [
            EpubInlineRun(start: 0, end: 2, style: EpubInlineStyle.strong),
          ],
        ),
        const EpubTableCell(text: '说明'),
      ],
      for (var index = 0; index < 40; index++)
        <EpubTableCell>[
          EpubTableCell(
            text: '第$index项',
            runs: const [
              EpubInlineRun(start: 0, end: 1, style: EpubInlineStyle.emphasis),
            ],
          ),
          const EpubTableCell(text: '这一行的说明文字。'),
        ],
    ];
    final text = rows
        .map((row) => row.map((cell) => cell.text).join('   '))
        .join('\n');
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
          cells: rows,
          hasHeader: true,
        ),
      ],
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(
        fontSize: 18,
        lineHeight: 1.7,
        paragraphSpacing: 12,
        pageMargin: 24,
      ),
      viewport: const Size(420, 520),
    );

    expect(pages.length, greaterThan(1));
    final bodyCells = <EpubTableCell>[];
    for (final page in pages) {
      final cells = page.fragments.single.tableCells!;
      final header = cells.first.first;
      expect(header.text, '名称');
      expect(header.runs.single.style, EpubInlineStyle.strong);
      expect(
        header.text.substring(header.runs.single.start, header.runs.single.end),
        '名称',
      );
      bodyCells.addAll(cells.skip(1).map((row) => row.first));
    }
    expect(bodyCells, hasLength(40));
    for (final cell in bodyCells) {
      expect(cell.runs.single.style, EpubInlineStyle.emphasis);
      expect(
        cell.text.substring(cell.runs.single.start, cell.runs.single.end),
        '第',
      );
    }
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

  test('an inline formula is never cut between page fragments', () {
    const expression = r'D=\{(x,y)\mid x^2+y^2\le4,\ y\ge0\}';
    final before = '很长的前文。' * 103;
    final after = '很长的后文。' * 120;
    final text = '$before$expression$after';
    final runStart = before.length;
    final runEnd = runStart + expression.length;
    final chapter = EpubChapter(
      index: 0,
      href: 'math.md',
      title: 'Formula',
      text: text,
      blocks: [
        EpubTextBlock(
          startOffset: 0,
          endOffset: text.length,
          text: text,
          type: EpubBlockType.paragraph,
          runs: [
            EpubInlineRun(
              start: runStart,
              end: runEnd,
              style: EpubInlineStyle.math,
              mathSource: expression,
            ),
          ],
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
      viewport: const Size(500, 520),
    );
    final fragments = pages.expand((page) => page.fragments).toList();
    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: const Size(500, 520),
    );

    for (final fragment in fragments) {
      final overlaps =
          fragment.startOffset < runEnd && fragment.endOffset > runStart;
      final holdsWhole =
          fragment.startOffset <= runStart && fragment.endOffset >= runEnd;
      expect(
        overlaps && !holdsWhole,
        isFalse,
        reason:
            'fragment ${fragment.startOffset}-${fragment.endOffset} '
            'cuts formula $runStart-$runEnd',
      );
    }
    expect(fragments.any((fragment) => fragment.endOffset >= runEnd), isTrue);
    for (final page in pages) {
      expect(
        page.measuredHeight,
        lessThanOrEqualTo(metrics.contentHeight + metrics.minLineHeight),
      );
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

  test(
    'a code language label reserves measured room and travels with pages',
    () {
      const text = 'final answer = 42;\nprint(answer);';
      EpubDocument documentFor(String? language) {
        return EpubDocument(
          chapters: [
            EpubChapter(
              index: 0,
              href: 'code.md',
              title: 'Code',
              text: text,
              blocks: [
                EpubTextBlock(
                  startOffset: 0,
                  endOffset: text.length,
                  text: text,
                  type: EpubBlockType.code,
                  codeLanguage: language,
                ),
              ],
            ),
          ],
        );
      }

      const settings = ReaderSettings(
        fontSize: 16,
        lineHeight: 1.6,
        paragraphSpacing: 12,
        pageMargin: 24,
      );
      final plain = const EpubPaginator().paginate(
        document: documentFor(null),
        settings: settings,
        viewport: const Size(600, 800),
      );
      final labelled = const EpubPaginator().paginate(
        document: documentFor('dart'),
        settings: settings,
        viewport: const Size(600, 800),
      );

      expect(plain.single.fragments.single.codeLanguage, isNull);
      expect(labelled.single.fragments.single.codeLanguage, 'dart');
      expect(labelled.single.fragments.single.text, text);
      expect(
        labelled.single.measuredHeight - plain.single.measuredHeight,
        closeTo(epubCodeLanguageHeight, 0.001),
      );
    },
  );

  test('code syntax runs keep their chapter offsets across pages', () {
    const line = 'final answer = 42; // 说明\n';
    final text = line * 30;
    final runs = const <EpubCodeRun>[
      EpubCodeRun(start: 0, end: 5, type: EpubCodeTokenType.keyword),
      EpubCodeRun(start: 16, end: 18, type: EpubCodeTokenType.number),
    ];
    final pages = const EpubPaginator().paginate(
      document: EpubDocument(
        chapters: [
          EpubChapter(
            index: 0,
            href: 'code.md',
            title: 'Code',
            text: text,
            blocks: [
              EpubTextBlock(
                startOffset: 0,
                endOffset: text.length,
                text: text,
                type: EpubBlockType.code,
                codeLanguage: 'dart',
                codeRuns: runs,
              ),
            ],
          ),
        ],
      ),
      settings: const ReaderSettings(
        fontSize: 16,
        lineHeight: 1.6,
        pageMargin: 24,
      ),
      viewport: const Size(600, 400),
    );

    expect(pages.length, greaterThan(1));
    final fragments = pages.expand((page) => page.fragments).toList();
    expect(fragments.first.codeRuns, runs);
    expect(fragments.last.codeRuns, runs);
    expect(
      fragments.map((fragment) => fragment.text).join(),
      contains('final answer = 42;'),
    );
    for (final fragment in fragments) {
      expect(fragment.codeLanguage, 'dart');
      expect(fragment.startOffset, lessThan(fragment.endOffset));
    }
  });

  test('math and diagram fragments keep their labels across line splits', () {
    EpubDocument documentFor(EpubBlockType type, String label) {
      const line = 'graph TD --> node; \n';
      final text = line * 30;
      return EpubDocument(
        chapters: [
          EpubChapter(
            index: 0,
            href: 'boundary.md',
            title: 'Boundary',
            text: text,
            blocks: [
              EpubTextBlock(
                startOffset: 0,
                endOffset: text.length,
                text: text,
                type: type,
                codeLanguage: label,
              ),
            ],
          ),
        ],
      );
    }

    const settings = ReaderSettings(
      fontSize: 16,
      lineHeight: 1.6,
      pageMargin: 24,
    );
    for (final entry in const <MapEntry<EpubBlockType, String>>[
      MapEntry(EpubBlockType.math, 'LaTeX'),
      MapEntry(EpubBlockType.diagram, 'Mermaid'),
    ]) {
      final pages = const EpubPaginator().paginate(
        document: documentFor(entry.key, entry.value),
        settings: settings,
        viewport: const Size(600, 400),
      );
      final fragments = pages.expand((page) => page.fragments).toList();

      expect(pages.length, greaterThan(1));
      expect(
        fragments.every((fragment) => fragment.blockType == entry.key),
        isTrue,
      );
      expect(
        fragments.every((fragment) => fragment.codeLanguage == entry.value),
        isTrue,
      );
      expect(
        fragments.skip(1).every((fragment) => fragment.isContinuation),
        isTrue,
      );
      expect(
        fragments.map((fragment) => fragment.text).join(),
        contains('graph TD --> node;'),
      );
    }
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

  test('link targets survive page fragmentation', () {
    const text = '一段粗体的文字。';
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
            EpubInlineRun(
              start: 2,
              end: 4,
              style: EpubInlineStyle.link,
              target: 'https://example.com',
            ),
          ],
        ),
      ],
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
      viewport: const Size(420, 520),
    );

    final run = pages.single.fragments.single.inlineRuns.single;
    expect(run.target, 'https://example.com');
    expect(run.start, 2);
    expect(run.end, 4);
  });

  test('footnote targets survive page fragmentation', () {
    final prefix = List<String>.filled(90, '前文').join();
    final text = '${prefix}1。';
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
          runs: [
            EpubInlineRun(
              start: prefix.length,
              end: prefix.length + 1,
              style: EpubInlineStyle.footnote,
              target: '#fn-note',
            ),
          ],
        ),
      ],
      anchors: {'fn-note': prefix.length},
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
      viewport: const Size(360, 260),
    );

    expect(pages.length, greaterThan(1));
    final runs = pages
        .expand((page) => page.fragments)
        .expand((fragment) => fragment.inlineRuns)
        .where((run) => run.style == EpubInlineStyle.footnote)
        .toList();
    expect(runs, isNotEmpty);
    for (final run in runs) {
      expect(run.target, '#fn-note');
      expect(run.start, prefix.length);
      expect(run.end, prefix.length + 1);
    }
  });

  test('list styling shares one hanging-indent width', () {
    const text = '• 一项很长的列表内容。';
    final chapter = EpubChapter(
      index: 0,
      href: 'note.md',
      title: '笔记',
      text: text,
      blocks: const [
        EpubTextBlock(
          startOffset: 0,
          endOffset: text.length,
          text: text,
          type: EpubBlockType.paragraph,
          listMarker: '• ',
        ),
      ],
    );
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

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: settings,
      viewport: const Size(420, 520),
    );

    final fragment = pages.single.fragments.single;
    expect(fragment.listMarker, '• ');
    expect(fragment.hasListHangingIndent, isTrue);
    expect(
      metrics.measureWidthForList(0),
      metrics.contentWidth - epubListHangingIndent,
    );
  });

  test('an image caption is included in the measured image height', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const settings = ReaderSettings(fontSize: 18, lineHeight: 1.7);
    const viewport = Size(420, 520);
    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: viewport,
    );
    final image = EpubImage(
      archivePath: 'pic.png',
      bytes: Uint8List(0),
      pixelWidth: 32,
      pixelHeight: 16,
      alt: '一张图',
    );
    final withoutAlt = EpubImage(
      archivePath: 'pic.png',
      bytes: Uint8List(0),
      pixelWidth: 32,
      pixelHeight: 16,
    );
    List<EpubPage> pagesFor(EpubImage picture) {
      return const EpubPaginator().paginate(
        document: EpubDocument(
          chapters: [
            EpubChapter(
              index: 0,
              href: 'note.md',
              title: '图',
              text: '',
              blocks: [EpubImageBlock(startOffset: 0, image: picture)],
            ),
          ],
        ),
        settings: settings,
        viewport: viewport,
      );
    }

    final captioned = pagesFor(image);
    final plain = pagesFor(withoutAlt);
    expect(captioned.single.fragments.single.imageCaption, '一张图');
    expect(plain.single.fragments.single.imageCaption, isNull);
    expect(
      captioned.single.measuredHeight - plain.single.measuredHeight,
      epubImageCaptionHeight(image, metrics),
    );
    expect(epubImageCaptionHeight(withoutAlt, metrics), 0);
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

List<List<EpubTableCell>> _cells(List<List<String>> rows) {
  return <List<EpubTableCell>>[
    for (final row in rows)
      <EpubTableCell>[for (final text in row) EpubTableCell(text: text)],
  ];
}
