import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';

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

    expect(tester.takeException(), isNull);
    await harness.capture('markdown-01-prose');
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

## 列表

- 第一项
- 第二项
  1. 嵌套的一项
  2. 嵌套的另一项
- 第三项

## 引用与代码

> 阅读是安静的，工具也应当是安静的。

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
