import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/search/structure_chunker.dart';

void main() {
  const chunker = StructureAwareChunker(
    parentTargetLength: 500,
    parentMaxLength: 620,
    childTargetLength: 180,
    childMaxLength: 260,
  );

  test('keeps section headings out of the previous parent', () {
    const text = '''
第一章

引言说明。

条件

条件正文。

结论

结论正文。
''';
    final first = text.indexOf('引言说明');
    final condition = text.indexOf('条件\n');
    final conclusion = text.indexOf('结论\n');
    final result = chunker.chunk(
      text: text,
      chapterTitle: '第一章',
      blocks: [
        StructuralBlock(
          startOffset: 0,
          endOffset: text.indexOf('\n\n引言'),
          kind: StructuralBlockKind.heading,
          headingLevel: 1,
        ),
        StructuralBlock(
          startOffset: first,
          endOffset: first + '引言说明。'.length,
          kind: StructuralBlockKind.paragraph,
        ),
        StructuralBlock(
          startOffset: condition,
          endOffset: condition + '条件'.length,
          kind: StructuralBlockKind.heading,
          headingLevel: 2,
        ),
        StructuralBlock(
          startOffset: text.indexOf('条件正文'),
          endOffset: text.indexOf('条件正文') + '条件正文。'.length,
          kind: StructuralBlockKind.paragraph,
        ),
        StructuralBlock(
          startOffset: conclusion,
          endOffset: conclusion + '结论'.length,
          kind: StructuralBlockKind.heading,
          headingLevel: 2,
        ),
        StructuralBlock(
          startOffset: text.indexOf('结论正文'),
          endOffset: text.indexOf('结论正文') + '结论正文。'.length,
          kind: StructuralBlockKind.paragraph,
        ),
      ],
    );

    expect(result.parents.map((parent) => parent.titlePath), [
      '第一章',
      '第一章 › 条件',
      '第一章 › 结论',
    ]);
    expect(result.parents[0].span.endOffset, lessThanOrEqualTo(condition));
    expect(result.parents[1].span.endOffset, lessThanOrEqualTo(conclusion));
  });

  test('children stay inside their parent and preserve every source word', () {
    final text = List.generate(
      18,
      (index) => '第$index段包含足够多的正文内容，用来验证切块不会丢字。',
    ).join('\n\n');
    final result = const StructureAwareChunker(
      parentTargetLength: 280,
      parentMaxLength: 340,
      childTargetLength: 100,
      childMaxLength: 140,
    ).chunk(text: text, chapterTitle: '测试');

    expect(result.parents.length, greaterThan(1));
    for (final parent in result.parents) {
      expect(parent.children, isNotEmpty);
      for (final child in parent.children) {
        expect(
          child.span.startOffset,
          greaterThanOrEqualTo(parent.span.startOffset),
        );
        expect(child.span.endOffset, lessThanOrEqualTo(parent.span.endOffset));
        expect(
          child.text,
          text.substring(child.span.startOffset, child.span.endOffset),
        );
      }
    }

    final sourceNonWhitespace = _nonWhitespace(text);
    final chunkNonWhitespace = _nonWhitespace(
      result.parents.map((parent) => parent.text).join(),
    );
    expect(chunkNonWhitespace, sourceNonWhitespace);
  });

  test('does not emit an empty parent for a heading-only gap', () {
    const text = '章标题\n\n条件标题\n\n条件正文。';
    final result = chunker.chunk(
      text: text,
      chapterTitle: '章标题',
      blocks: [
        const StructuralBlock(
          startOffset: 0,
          endOffset: 3,
          kind: StructuralBlockKind.heading,
          headingLevel: 1,
        ),
        const StructuralBlock(
          startOffset: 5,
          endOffset: 9,
          kind: StructuralBlockKind.heading,
          headingLevel: 2,
        ),
        const StructuralBlock(
          startOffset: 11,
          endOffset: 16,
          kind: StructuralBlockKind.paragraph,
        ),
      ],
    );

    expect(result.parents, hasLength(1));
    expect(result.parents.single.titlePath, '章标题 › 条件标题');
    expect(result.parents.single.text, contains('条件正文'));
  });

  test('splits long prose at sentence boundaries before hard limits', () {
    final sentence = '这是一个完整句子，长度足够用于测试。';
    final text = List.filled(12, sentence).join();
    final result = const StructureAwareChunker(
      parentTargetLength: 80,
      parentMaxLength: 100,
      childTargetLength: 80,
      childMaxLength: 100,
    ).chunk(text: text, chapterTitle: '句子');

    for (final parent in result.parents) {
      expect(parent.span.length, lessThanOrEqualTo(100));
      if (parent.span.endOffset < text.length) {
        expect(text[parent.span.endOffset - 1], anyOf('。', '\n'));
      }
    }
  });

  test('does not split an emoji surrogate pair at the hard boundary', () {
    final text = '${'甲' * 79}😀尾';
    final result = const StructureAwareChunker(
      parentTargetLength: 40,
      parentMaxLength: 80,
      childTargetLength: 40,
      childMaxLength: 80,
    ).chunk(text: text, chapterTitle: '字符');

    for (final parent in result.parents) {
      final value = text.substring(
        parent.span.startOffset,
        parent.span.endOffset,
      );
      expect(
        value.codeUnits.contains(0xD83D) && !value.contains('😀'),
        isFalse,
      );
    }
    expect(result.parents.map((parent) => parent.text).join(), contains('😀'));
  });

  test('falls back to paragraphs when the parser has no blocks', () {
    const text = '第一段。\n\n第二段。';
    final result = chunker.chunk(text: text, chapterTitle: '纯文本');

    expect(result.parents, hasLength(1));
    expect(result.parents.single.text, text);
    expect(result.parents.single.children.single.text, text);
  });
}

String _nonWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), '');
}
