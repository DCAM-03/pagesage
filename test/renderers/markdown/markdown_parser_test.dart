import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/markdown/markdown_document_loader.dart';
import 'package:pagesage/renderers/markdown/markdown_parser.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pagesage_md_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<EpubDocument> parse(String markdown, {String fallbackTitle = '笔记'}) {
    return MarkdownParser(
      basePath: tempDir.path,
    ).parse(markdown, fallbackTitle: fallbackTitle);
  }

  test(
    'a heading structures the book into chapters and a table of contents',
    () async {
      final document = await parse('''
# 第一章

正文一。

## 小节

正文二。

# 第二章

正文三。
''');

      expect(document.chapters, hasLength(2));
      expect(document.chapters[0].title, '第一章');
      expect(document.chapters[1].title, '第二章');
      expect(document.chapters[0].text, contains('正文一。'));
      expect(document.chapters[0].text, contains('小节'));
      expect(document.chapters[1].text, contains('正文三。'));

      expect(document.toc, hasLength(2));
      expect(document.toc[0].title, '第一章');
      expect(document.toc[0].chapterIndex, 0);
      expect(document.toc[0].children.single.title, '小节');
      expect(document.toc[1].chapterIndex, 1);
    },
  );

  test('every block sits exactly at its own offsets', () async {
    final document = await parse('''
前记。

# 标题

第一段。
第二行（软换行，应当接上）。

- 一项
- 另一项
''');

    for (final chapter in document.chapters) {
      for (final block in chapter.blocks.whereType<EpubTextBlock>()) {
        expect(
          chapter.text.substring(block.startOffset, block.endOffset),
          block.text,
        );
      }
    }

    // A soft line wrap is a wrap, not a line break: the sentence reflows.
    final prose = document.chapters
        .expand((chapter) => chapter.blocks)
        .whereType<EpubTextBlock>()
        .firstWhere((block) => block.text.contains('第一段'));
    expect(prose.text, '第一段。 第二行（软换行，应当接上）。');
  });

  test('lists, quotes and fenced code keep their shape', () async {
    final document = await parse('''
# 一章

- 一项
- 另一项
  1. 嵌套

> 引用的话。

```dart
final a = 1;
```
''');

    final blocks = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .toList();
    final texts = blocks.map((block) => block.text).toList();

    expect(texts, contains('• 一项'));
    expect(texts, contains('• 另一项'));
    expect(texts, contains('  1. 嵌套'));
    expect(
      blocks.firstWhere((block) => block.text.contains('引用的话')).type,
      EpubBlockType.quote,
    );

    final code = blocks.firstWhere((block) => block.type == EpubBlockType.code);
    expect(code.text, 'final a = 1;');
  });

  test('a table keeps its rows and columns apart', () async {
    final document = await parse('''
# 表格

| 名称 | 数量 |
| --- | --- |
| 苹果 | 3 |
| 香蕉 | 12 |
''');

    final chapter = document.chapters.single;
    final table = chapter.blocks.whereType<EpubTableBlock>().single;

    expect(table.hasHeader, isTrue);
    expect(table.rows, [
      ['名称', '数量'],
      ['苹果', '3'],
      ['香蕉', '12'],
    ]);
    // The words are still in the chapter's text, which is what search and
    // progress work on.
    expect(
      chapter.text.substring(table.startOffset, table.endOffset),
      table.text,
    );
    expect(chapter.text, contains('香蕉'));
    // …and no markup leaked into what the reader sees.
    expect(chapter.text, isNot(contains('---')));
    expect(chapter.text, isNot(contains('|')));
  });

  test('a delimiter row with the wrong number of cells still parses', () async {
    // Written by hand: the header has two cells, the delimiter three, and
    // package:markdown would drop the whole table.
    final document = await parse('''
# 表格

| 名称 | 数量 |
| --- | --- | --- |
| 苹果 | 3 |
''');

    final table = document.chapters.single.blocks
        .whereType<EpubTableBlock>()
        .single;
    expect(table.rows, [
      ['名称', '数量'],
      ['苹果', '3'],
    ]);
  });

  test('a table in a fenced code block stays code', () async {
    final document = await parse('''
# 代码

```
| a | b |
| --- | --- |
| 1 | 2 |
```
''');

    final chapter = document.chapters.single;
    expect(chapter.blocks.whereType<EpubTableBlock>(), isEmpty);
    final code = chapter.blocks.whereType<EpubTextBlock>().singleWhere(
      (block) => block.type == EpubBlockType.code,
    );
    expect(code.text, contains('| a | b |'));
  });

  test(
    'a picture is read from beside the file and takes no characters',
    () async {
      final image = File('${tempDir.path}/pic.png')
        ..writeAsBytesSync(_pngBytes(width: 32, height: 16));

      final document = await parse('''
# 图

前文。

![一张图](pic.png)

后文。
''');

      final chapter = document.chapters.single;
      final imageBlock = chapter.blocks.whereType<EpubImageBlock>().single;

      expect(imageBlock.image.isAvailable, isTrue);
      expect(imageBlock.image.pixelWidth, 32);
      expect(imageBlock.image.alt, '一张图');
      expect(imageBlock.startOffset, imageBlock.endOffset);

      // The picture is not in the text, and the text around it is intact.
      expect(chapter.text, isNot(contains('pic.png')));
      expect(chapter.text.substring(0, imageBlock.startOffset), contains('前文'));
      expect(chapter.text.substring(imageBlock.endOffset), contains('后文'));
      expect(image.path, endsWith('pic.png'));
    },
  );

  test('a missing picture and a remote picture say why', () async {
    final document = await parse('''
# 图

![缺失](gone.png)

![远程](https://example.com/a.png)
''');

    final images = document.chapters.single.blocks
        .whereType<EpubImageBlock>()
        .map((block) => block.image)
        .toList();
    expect(images[0].isAvailable, isFalse);
    expect(images[0].unavailableReason, contains('不在磁盘上'));
    expect(images[1].isAvailable, isFalse);
    expect(images[1].unavailableReason, contains('远程'));
  });

  test('front matter names the book and stays out of the text', () async {
    final document = await parse('''
---
title: 真正的标题
tags: [a, b]
---

# 第一章

正文。
''');

    expect(document.chapters.first.title, '第一章');
    expect(document.chapters.first.text, isNot(contains('tags')));
  });

  test('a file without a level-one heading is one chapter', () async {
    final document = await parse('只有正文。\n\n第二段。', fallbackTitle: '笔记');
    expect(document.chapters, hasLength(1));
    expect(document.chapters.single.title, '笔记');
    expect(document.chapters.single.text, contains('只有正文'));
  });

  test('inline styles are kept as runs over the chapter\'s own text', () async {
    final document = await parse(
      '这一段有**粗体**、*斜体*、~~删除~~、`代码`和[链接](https://example.com)。',
    );
    final chapter = document.chapters.single;
    final paragraph = chapter.blocks.whereType<EpubTextBlock>().firstWhere(
      (block) => block.text.contains('粗体'),
    );

    String wordsIn(EpubInlineStyle style) {
      final run = paragraph.runs.firstWhere((run) => run.style == style);
      return chapter.text.substring(run.start, run.end);
    }

    expect(wordsIn(EpubInlineStyle.strong), '粗体');
    expect(wordsIn(EpubInlineStyle.emphasis), '斜体');
    expect(wordsIn(EpubInlineStyle.strike), '删除');
    expect(wordsIn(EpubInlineStyle.code), '代码');
    expect(wordsIn(EpubInlineStyle.link), '链接');
    // The words themselves stay the book's words: no asterisks or backticks.
    expect(paragraph.text, isNot(contains('*')));
    expect(paragraph.text, isNot(contains('`')));
  });

  test('two styles over the same words compose', () async {
    final document = await parse('***又粗又斜***');
    final block = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .first;
    final styles = block.runs.map((run) => run.style).toSet();
    expect(styles, contains(EpubInlineStyle.strong));
    expect(styles, contains(EpubInlineStyle.emphasis));
    // Both runs cover the same words rather than one replacing the other.
    final strong = block.runs.firstWhere(
      (run) => run.style == EpubInlineStyle.strong,
    );
    final emphasis = block.runs.firstWhere(
      (run) => run.style == EpubInlineStyle.emphasis,
    );
    expect(strong.start, emphasis.start);
    expect(strong.end, emphasis.end);
  });

  test('a heading remembers the level it was written at', () async {
    final document = await parse('# 一\n\n## 二\n\n### 三\n\n正文。');
    final levels = <int>[
      for (final chapter in document.chapters)
        for (final block in chapter.blocks.whereType<EpubTextBlock>())
          if (block.headingLevel != null) block.headingLevel!,
    ];
    expect(levels, [1, 2, 3]);
  });

  test('a horizontal rule is a divider where it stands', () async {
    final document = await parse('上面。\n\n---\n\n下面。');
    final blocks = document.chapters.single.blocks;
    final index = blocks.indexWhere((block) => block is EpubDividerBlock);
    expect(index, greaterThan(0));
    expect(blocks[index - 1], isA<EpubTextBlock>());
    expect(blocks[index + 1], isA<EpubTextBlock>());
    final divider = blocks[index] as EpubDividerBlock;
    // Text blocks are separated by the blank line the next block writes, so
    // a rule can share the offset the paragraph before it ends on.
    expect(
      divider.startOffset,
      greaterThanOrEqualTo(blocks[index - 1].endOffset),
    );
    expect(divider.startOffset, lessThan(blocks[index + 1].startOffset));
  });

  test('the loader refuses a file with nothing to read', () async {
    final file = File('${tempDir.path}/empty.md')..writeAsStringSync('');
    expect(
      () => const MarkdownDocumentLoader().load(file.path),
      throwsA(
        isA<MarkdownLoadException>().having(
          (error) => error.message,
          'message',
          contains('没有可读的正文'),
        ),
      ),
    );
  });
}

/// A PNG header with the given size.
///
/// The parser reads the size from the header and never decodes the pixels,
/// so the header is all this fixture needs.
List<int> _pngBytes({required int width, required int height}) {
  return <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    0x08,
    0x02,
    0x00,
    0x00,
    0x00,
  ];
}
