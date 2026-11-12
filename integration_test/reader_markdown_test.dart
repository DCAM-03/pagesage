import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/reader/presentation/reader_desktop_toc_pane.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';
import 'package:pagesage/renderers/common/diagram/diagram_view.dart';

import 'support/reader_harness.dart';

/// The Markdown check on a real Linux desktop window.
///
/// The parser tests prove the document is built correctly. What only the live
/// window shows is that the page is typeset as prose — headings, lists, a
/// quote rule, a code block and aligned table columns — and that turning the
/// page keeps the reader on the same book.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a Markdown file reads as a book in the real window', (
    tester,
  ) async {
    final dir = Directory('.codex-run/samples')..createSync(recursive: true);
    File(
      '${dir.path}/markdown-picture.png',
    ).writeAsBytesSync(_checkerPng(width: 64, height: 40));
    final file = File('${dir.path}/markdown-note.md')..writeAsStringSync(_note);
    final stat = file.statSync();

    final book = Book(
      id: 'markdown-note',
      title: 'PageSage Markdown 笔记',
      format: BookFormat.markdown,
      libraryFilePath: file.absolute.path,
      fileHash: 'hash-markdown-note',
      fileSize: stat.size,
      createdAt: stat.modified.millisecondsSinceEpoch,
      updatedAt: stat.modified.millisecondsSinceEpoch,
    );

    final harness = await ReaderHarness.create(books: [book]);
    addTearDown(harness.dispose);
    await harness.pumpReader(
      tester,
      'markdown-note',
      size: const Size(1280, 900),
    );
    await harness.settle(tester, rounds: 20);

    expect(find.byType(EpubRendererView), findsOneWidget);
    // The words, not the syntax that produced them.
    expect(find.textContaining('PageSage 把这本书'), findsWidgets);
    expect(find.textContaining('## '), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('| ---'), findsNothing);
    expect(find.textContaining('链接', findRichText: true), findsWidgets);
    // Task lists are checkboxes, not a bullet followed by a second glyph.
    expect(find.text('整理摘录'), findsOneWidget);
    expect(find.text('读完一章'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    // The fence's language is a label, not code text.
    expect(find.text('dart'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await harness.capture('markdown-01-prose');
    await harness.closeReader(tester);
  });

  testWidgets('a Markdown picture shows its alt caption in the real window', (
    tester,
  ) async {
    final dir = Directory('.codex-run/samples')..createSync(recursive: true);
    File(
      '${dir.path}/markdown-picture.png',
    ).writeAsBytesSync(_checkerPng(width: 64, height: 40));
    final file = File('${dir.path}/markdown-picture-note.md')
      ..writeAsStringSync(_pictureNote);
    final stat = file.statSync();

    final book = Book(
      id: 'markdown-picture-note',
      title: 'Markdown 图注',
      format: BookFormat.markdown,
      libraryFilePath: file.absolute.path,
      fileHash: 'hash-markdown-picture-note',
      fileSize: stat.size,
      createdAt: stat.modified.millisecondsSinceEpoch,
      updatedAt: stat.modified.millisecondsSinceEpoch,
    );

    final harness = await ReaderHarness.create(books: [book]);
    addTearDown(harness.dispose);
    await harness.pumpReader(
      tester,
      'markdown-picture-note',
      size: const Size(1280, 900),
    );
    await harness.settle(tester, rounds: 20);

    expect(find.byType(EpubRendererView), findsOneWidget);
    expect(find.text('一张本地插图'), findsOneWidget);
    expect(find.textContaining('图片不在磁盘上'), findsOneWidget);
    expect(find.text('缺失的插图'), findsOneWidget);
    expect(find.textContaining('markdown-picture.png'), findsNothing);

    expect(tester.takeException(), isNull);
    await harness.capture('markdown-02-picture-captions');
    await harness.closeReader(tester);
  });

  testWidgets('a Markdown folder shows its file tree and current outline', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('pagesage_md_folder_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.md').writeAsStringSync('# 甲章\n\n甲篇正文。');
    Directory('${dir.path}/sub').createSync();
    File('${dir.path}/sub/b.md').writeAsStringSync('# 乙章\n\n## 乙小节\n\n乙篇正文。');

    final book = Book(
      id: 'markdown-folder',
      title: '笔记库',
      format: BookFormat.markdown,
      libraryFilePath: dir.path,
      fileHash: 'hash-markdown-folder',
      fileSize: 1,
      createdAt: 1,
      updatedAt: 1,
    );
    final harness = await ReaderHarness.create(
      books: [book],
      progress: {
        book.id: ReadingProgressSnapshot(
          bookId: book.id,
          locator: ReadingLocator.markdown(
            href: 'sub/b.md',
            chapterIndex: 0,
            chapterOffset: 0,
            progress: 0.75,
            folderFileLocal: true,
          ),
          progress: 0.75,
          updatedAt: 1,
        ),
      },
    );
    addTearDown(harness.dispose);

    await harness.pumpReader(tester, book.id, size: const Size(1280, 900));
    await harness.settle(tester, rounds: 24);

    // The saved file is open, and both folder layers are present.
    expect(find.textContaining('乙篇正文'), findsWidgets);
    expect(find.textContaining('甲篇正文'), findsNothing);
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('大纲'), findsOneWidget);

    // The outline names only the active file's headings.
    await tester.tap(find.text('大纲').first);
    await harness.settle(tester, rounds: 12);
    expect(find.text('乙章'), findsWidgets);
    expect(find.text('甲章'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.capture('markdown-03-folder-outline');

    // The file tree keeps the subdirectory boundary; opening a file switches
    // the document instead of merging every note into one body.
    await tester.tap(find.text('文件').first);
    await tester.pump();
    expect(find.text('sub'), findsWidgets);
    await tester.tap(find.text('sub').first);
    await tester.pump();
    expect(find.text('b'), findsOneWidget);
    expect(find.text('过滤文件路径'), findsOneWidget);
    await harness.capture('markdown-04-folder-file-tree');

    await tester.tap(find.text('a').first);
    await harness.settle(tester, rounds: 12);
    expect(find.textContaining('甲篇正文'), findsWidgets);
    expect(find.textContaining('乙篇正文'), findsNothing);
    // Selecting a file changes the document but leaves the file tree visible.
    expect(find.text('过滤文件路径'), findsOneWidget);
    expect(find.text('过滤当前文件标题'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.capture('markdown-05-folder-switched-file');

    // The outline is one explicit tap away, not an automatic jump.
    await tester.tap(find.text('大纲').first);
    await harness.settle(tester, rounds: 12);
    expect(find.text('甲章'), findsWidgets);
    expect(find.text('乙章'), findsNothing);
    await harness.capture('markdown-06-folder-switched-outline');

    File('${dir.path}/a.md').writeAsStringSync('# 甲章更新\n\n外部保存后的新正文。');
    for (var attempt = 0; attempt < 12; attempt++) {
      await harness.settle(tester, rounds: 6);
      if (find.textContaining('外部保存后的新正文').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('外部保存后的新正文'), findsWidgets);
    final outline = find.byType(DesktopTocPane);
    expect(
      find.descendant(of: outline, matching: find.text('甲章更新')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: outline, matching: find.text('甲章')),
      findsNothing,
    );
    expect(find.textContaining('甲篇正文'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.capture('markdown-07-external-save');
    await harness.closeReader(tester);
  });

  testWidgets('Markdown Mermaid switches source and expands its diagram', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('pagesage_mermaid_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/diagram.md')
      ..writeAsStringSync('''
# 流程图验收

```mermaid
flowchart TD
  A[导入文件] --> B[阅读正文]
  B --> C[保存笔记]
```
''');
    final book = Book(
      id: 'mermaid-window',
      title: 'Mermaid',
      format: BookFormat.markdown,
      libraryFilePath: file.path,
      fileHash: 'mermaid-window',
      fileSize: file.lengthSync(),
      createdAt: 1,
      updatedAt: 1,
    );
    final harness = await ReaderHarness.create(books: [book]);
    addTearDown(harness.dispose);
    await harness.pumpReader(tester, book.id, size: const Size(1280, 900));
    expect(find.byType(MermaidDiagramView), findsOneWidget);
    expect(find.text('Mermaid 图形'), findsOneWidget);
    await harness.capture('markdown-08-mermaid-diagram');
    await tester.tap(find.byTooltip('查看源码'));
    await harness.settle(tester, rounds: 4);
    expect(find.textContaining('flowchart TD'), findsOneWidget);
    await tester.tap(find.byTooltip('查看图形'));
    await tester.tap(find.byTooltip('展开查看'));
    await harness.settle(tester, rounds: 4);
    expect(find.text('展开查看 Mermaid 图形'), findsOneWidget);
    await harness.capture('markdown-09-mermaid-expanded');
    await tester.tap(find.byTooltip('复位缩放'));
    await tester.tap(find.byTooltip('关闭').hitTestable().last);
    await harness.settle(tester, rounds: 4);
    expect(find.text('展开查看 Mermaid 图形'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.closeReader(tester);
  });
}

const _note = '''
---
title: 读 Markdown
---

# 第一章 正文的样子

PageSage 把这本书当作普通正文来排版：段落、列表、引用、代码和表格各归其位，
行内强调保留文字本身的顺序。

安全[链接](https://example.com)点击后由宿主确认地址。

## 列表

- 第一项
- 第二项
  1. 嵌套的一项
  2. 嵌套的另一项
- 第三项

## 引用与代码

> 阅读是安静的，工具也应当是安静的。

- [ ] 整理摘录
- [x] 读完一章

```dart
final reader = PageSage();
await reader.open('note.md');
```

## 表格

| 格式 | 状态 |
| --- | --- |
| EPUB | 已支持 |
| PDF | 已支持 |
| Markdown | 正在阅读 |

# 第二章 换页

这一章用来确认翻页之后读者仍然停在同一本书里，并且位置会被记住。
''';

const _pictureNote = '''
# 图注

![一张本地插图](markdown-picture.png)

![缺失的插图](gone.png)
''';

Uint8List _checkerPng({required int width, required int height}) {
  final raw = <int>[];
  for (var y = 0; y < height; y += 1) {
    raw.add(0);
    for (var x = 0; x < width; x += 1) {
      final isLight = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
      raw.addAll(isLight ? const [0xF2, 0xF2, 0xF2] : const [0x33, 0x33, 0x33]);
    }
  }

  final out = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  out.addAll(
    _pngChunk('IHDR', <int>[
      ..._uint32(width),
      ..._uint32(height),
      0x08,
      0x02,
      0x00,
      0x00,
      0x00,
    ]),
  );
  out.addAll(_pngChunk('IDAT', _zlibStore(raw)));
  out.addAll(_pngChunk('IEND', const <int>[]));
  return Uint8List.fromList(out);
}

List<int> _pngChunk(String type, List<int> data) {
  final out = <int>[..._uint32(data.length), ...type.codeUnits, ...data];
  out.addAll(_uint32(_crc32(<int>[...type.codeUnits, ...data])));
  return out;
}

List<int> _zlibStore(List<int> raw) {
  final out = <int>[0x78, 0x01];
  var offset = 0;
  while (offset < raw.length) {
    final end = offset + 65535 > raw.length ? raw.length : offset + 65535;
    final block = raw.sublist(offset, end);
    final isLast = end >= raw.length;
    out.add(isLast ? 1 : 0);
    out.add(block.length & 0xFF);
    out.add((block.length >> 8) & 0xFF);
    out.add((~block.length) & 0xFF);
    out.add(((~block.length) >> 8) & 0xFF);
    out.addAll(block);
    offset = end;
  }
  var a = 1;
  var b = 0;
  for (final byte in raw) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  out.addAll(_uint32(((b << 16) | a) & 0xFFFFFFFF));
  return out;
}

List<int> _uint32(int value) {
  return <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit += 1) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (~crc) & 0xFFFFFFFF;
}
