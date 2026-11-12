import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/common/math_source.dart';
import 'package:pagesage/renderers/markdown/markdown_boundaries.dart';
import 'package:pagesage/renderers/markdown/markdown_parser.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pagesage_md_boundary_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<EpubDocument> parse(String source) {
    return MarkdownParser(
      basePath: tempDir.path,
    ).parse(source, fallbackTitle: '笔记');
  }

  test('display math becomes a renderable TeX block', () async {
    final document = await parse(r'''
# 公式

$$
\frac{a}{b} + \sqrt{x}
$$
''');
    final chapter = document.chapters.single;
    final math = chapter.blocks.whereType<EpubTextBlock>().singleWhere(
      (block) => block.type == EpubBlockType.math,
    );

    expect(math.codeLanguage, 'LaTeX');
    expect(math.mathSource, r'\frac{a}{b} + \sqrt{x}');
    expect(math.text, r'\frac{a}{b} + \sqrt{x}');
    expect(chapter.text, isNot(contains(r'$$')));
    expect(chapter.text.substring(math.startOffset, math.endOffset), math.text);
    expect(
      chapter.blocks.whereType<EpubTextBlock>().first.type,
      EpubBlockType.heading,
    );
  });

  test('a Mermaid fence becomes readable diagram source', () async {
    final document = await parse('''
# 图

```mermaid
graph TD
  A[开始] --> B{判断}
  B --> C[结束]
```
''');
    final chapter = document.chapters.single;
    final diagram = chapter.blocks.whereType<EpubTextBlock>().singleWhere(
      (block) => block.type == EpubBlockType.diagram,
    );

    expect(diagram.codeLanguage, 'Mermaid');
    expect(diagram.text, 'graph TD\n  A[开始] --> B{判断}\n  B --> C[结束]');
    expect(chapter.text, isNot(contains('```')));
    expect(chapter.text, isNot(contains('mermaid')));
    expect(
      chapter.text.substring(diagram.startOffset, diagram.endOffset),
      diagram.text,
    );
  });

  test('inline math keeps its expression and chapter-offset run', () async {
    final document = await parse(r'公式 $x^2$ 与 $$y^2$$，价格 \$10。');
    final chapter = document.chapters.single;
    final paragraph = chapter.blocks.whereType<EpubTextBlock>().single;
    final expressions = paragraph.runs
        .where((run) => run.style == EpubInlineStyle.math)
        .map((run) => chapter.text.substring(run.start, run.end))
        .toList();
    final sources = paragraph.runs
        .where((run) => run.style == EpubInlineStyle.math)
        .map((run) => run.mathSource)
        .toList();

    expect(chapter.text, r'公式 x^2 与 y^2，价格 $10。');
    expect(expressions, <String>['x^2', 'y^2']);
    expect(sources, <String?>['x^2', 'y^2']);
    expect(
      paragraph.text,
      chapter.text.substring(paragraph.startOffset, paragraph.endOffset),
    );
  });

  test('slash-delimited inline math keeps the same text contract', () async {
    final document = await parse(r'公式 \(a^2+b^2=c^2\) 结束。');
    final chapter = document.chapters.single;
    final paragraph = chapter.blocks.whereType<EpubTextBlock>().single;
    final math = paragraph.runs.singleWhere(
      (run) => run.style == EpubInlineStyle.math,
    );

    expect(chapter.text, '公式 a^2+b^2=c^2 结束。');
    expect(chapter.text.substring(math.start, math.end), 'a^2+b^2=c^2');
    expect(math.mathSource, 'a^2+b^2=c^2');
    expect(MathSource(math.mathSource!).isValid, isTrue);
  });

  test('compact display math from notes has normalized TeX source', () async {
    final document = await parse(
      r'设 $\displaystyle \lim_{x\to0}\frac1{x^2}=1$，求极值。',
    );
    final chapter = document.chapters.single;
    final math = chapter.blocks
        .whereType<EpubTextBlock>()
        .single
        .runs
        .singleWhere((run) => run.style == EpubInlineStyle.math);

    expect(math.mathSource, contains(r'\frac{1}{x^2}'));
    expect(MathSource(math.mathSource!).isValid, isTrue);
  });

  test('inline math ending in an escaped brace stays whole', () async {
    final document = await parse(
      r'设 $D=\{(x,y)\mid x^2+y^2\le4,\ y\ge0\}$，则求积分。',
    );
    final chapter = document.chapters.single;
    final math = chapter.blocks
        .whereType<EpubTextBlock>()
        .single
        .runs
        .singleWhere((run) => run.style == EpubInlineStyle.math);

    expect(math.mathSource, r'D=\{(x,y)\mid x^2+y^2\le4,\ y\ge0\}');
    expect(MathSource(math.mathSource!).isValid, isTrue);
    expect(chapter.text, isNot(contains(r'$D=')));
    expect(
      chapter.text.substring(math.start, math.end),
      r'D=\{(x,y)\mid x^2+y^2\le4,\ y\ge0\}',
    );
  });

  test('inline and embedded HTML keep only safe visible words', () async {
    final document = await parse(r'''
# 边界

前 <b>粗体</b>、<script>alert(1)</script>、
<img src="https://example.com/a.png"> 与
<a href="https://example.com">链接文字</a>。

<div class="note">
  <p>HTML &amp; 块里的文字。</p>
</div>

<!-- 隐藏注释 -->可见。
''');
    final chapter = document.chapters.single;
    final text = chapter.text;

    expect(text, contains('前 粗体、'));
    expect(text, contains('已忽略 script 标签'));
    expect(text, contains('链接文字'));
    expect(text, contains('HTML & 块里的文字。'));
    expect(text, contains('可见。'));
    expect(text, isNot(contains('<script>')));
    expect(text, isNot(contains('alert(1)')));
    expect(text, isNot(contains('<img')));
    expect(text, isNot(contains('example.com')));
    expect(text, isNot(contains('href=')));
    expect(text, isNot(contains('&amp;')));
    expect(text, isNot(contains('隐藏注释')));
    for (final block in chapter.blocks.whereType<EpubTextBlock>()) {
      expect(text.substring(block.startOffset, block.endOffset), block.text);
    }
  });

  test(
    'safe inline HTML keeps its reading semantics and line breaks',
    () async {
      final document = await parse(r'''
前 <b>粗体</b>、<u>下划线</u>、<mark>重点</mark>、<kbd>Ctrl</kbd>。
H<sub>水</sub>O，x<sup>幂</sup>。<br>下一行。
''');
      final chapter = document.chapters.single;
      final paragraph = chapter.blocks.whereType<EpubTextBlock>().single;

      expect(chapter.text, contains('前 粗体、下划线、重点、Ctrl。'));
      expect(chapter.text, contains('H水O，x幂。\n下一行。'));
      expect(chapter.text, isNot(contains('<b>')));
      expect(chapter.text, isNot(contains('<mark>')));
      expect(chapter.text, isNot(contains('<br>')));

      EpubInlineStyle styleFor(String text) {
        final run = paragraph.runs.singleWhere(
          (run) => chapter.text.substring(run.start, run.end) == text,
        );
        return run.style;
      }

      expect(styleFor('粗体'), EpubInlineStyle.strong);
      expect(styleFor('下划线'), EpubInlineStyle.underline);
      expect(styleFor('重点'), EpubInlineStyle.highlight);
      expect(styleFor('Ctrl'), EpubInlineStyle.code);
      expect(styleFor('水'), EpubInlineStyle.subscript);
      expect(styleFor('幂'), EpubInlineStyle.superscript);
    },
  );

  test(
    'dangerous HTML blocks remove their source instead of showing it',
    () async {
      final document = await parse('''
# 安全

<style>body { color: red; }</style>

<svg><text>矢量文字</text></svg>

<script>alert(1)</script><script>alert(2)</script>
''');
      final text = document.chapters.single.text;

      expect(text, contains('已忽略 style 标签'));
      expect(text, contains('已忽略 svg 标签'));
      expect(text, contains('已忽略 script 标签'));
      expect(text, isNot(contains('color: red')));
      expect(text, isNot(contains('矢量文字')));
      expect(text, isNot(contains('alert(')));
    },
  );

  test('standalone HTML void tags do not consume following Markdown', () async {
    final document = await parse('''
# 第一章

<img src="https://example.com/cover.png">
<br>

# 第二章

正文保留。
''');

    expect(document.chapters, hasLength(2));
    expect(document.chapters.last.title, '第二章');
    expect(document.chapters.last.text, contains('正文保留。'));
    expect(
      document.chapters.last.blocks.whereType<EpubTextBlock>().first.type,
      EpubBlockType.heading,
    );
    expect(document.chapters.first.text, isNot(contains('HTML')));
  });

  test('Mermaid and math markers inside code remain code', () async {
    final document = await parse(r'''
# 代码

````text
```mermaid
graph TD
```
$$
x^2
$$
````
''');
    final blocks = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .toList();
    final code = blocks.singleWhere(
      (block) => block.type == EpubBlockType.code,
    );

    expect(
      blocks.where((block) => block.type == EpubBlockType.diagram),
      isEmpty,
    );
    expect(blocks.where((block) => block.type == EpubBlockType.math), isEmpty);
    expect(code.text, contains('```mermaid'));
    expect(code.text, contains(r'$$'));
  });

  test('unknown named HTML entities remain visible as source text', () async {
    final document = await parse(
      '<div>Copyright &copy; 2026 &mdash; PageSage</div>',
    );

    expect(document.chapters.single.text, contains('&copy;'));
    expect(document.chapters.single.text, contains('&mdash;'));
    expect(document.chapters.single.text, contains('PageSage'));
  });

  test(
    'unclosed boundaries and code fences keep their original text',
    () async {
      final document = await parse(r'''
# 原文

$$
\frac{1}{2}

```mermaid
graph TD
  A --> B
```

```dart
final a = "$x$";
$$
not math
$$
```
''');
      final text = document.chapters.single.text;
      final blocks = document.chapters.single.blocks
          .whereType<EpubTextBlock>()
          .toList();

      expect(text, contains(r'\frac{1}{2}'));
      expect(text, contains(r'$$'));
      expect(text, contains('graph TD\n  A --> B'));
      expect(text, contains(r'final a = "$x$";'));
      expect(text, contains('not math'));
      expect(
        blocks.where((block) => block.type == EpubBlockType.math),
        isEmpty,
      );
      expect(
        blocks.where((block) => block.type == EpubBlockType.diagram).length,
        1,
      );
      expect(
        blocks.where((block) => block.type == EpubBlockType.code).length,
        1,
      );
    },
  );

  test('a very long math source stays bounded', () async {
    final expression = 'x' * (MarkdownBoundary.maxSourceLength + 100);
    final document = await parse('${r'$$'}\n$expression\n${r'$$'}');
    final math = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .singleWhere((block) => block.type == EpubBlockType.math);

    expect(math.text.length, MarkdownBoundary.maxSourceLength + 1);
    expect(math.text.endsWith('…'), isTrue);
  });

  test('author-supplied boundary markers are ordinary text', () async {
    final document = await parse('''
<pagesage-safe-boundary data-pagesage-kind="math">
注入内容
</pagesage-safe-boundary>

正文 \$x\$。
''');
    final text = document.chapters.single.text;

    expect(text, contains('<pagesage-safe-boundary'));
    expect(text, contains('注入内容'));
    expect(text, contains('正文 x。'));
    expect(
      document.chapters.single.blocks.whereType<EpubTextBlock>().where(
        (block) => block.type == EpubBlockType.math,
      ),
      isEmpty,
    );
  });
}
