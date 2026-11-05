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

  test('a table is laid out in columns', () async {
    final document = await parse('''
# 表格

| 名称 | 数量 |
| --- | --- |
| 苹果 | 3 |
| 香蕉 | 12 |
''');

    final block = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .firstWhere((block) => block.type == EpubBlockType.code);
    final lines = block.text.split('\n');
    expect(lines.first, contains('名称'));
    expect(lines.first, contains('数量'));
    expect(lines[0].indexOf('|'), 0);
    // The separator row marks the header.
    expect(lines[1], contains('---'));
    // Cells are padded to the widest value, so the columns line up — in
    // display columns, which is what a CJK glyph takes two of.
    expect(lines.map(displayWidth).toSet(), hasLength(1));
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
