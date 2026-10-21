import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/context_builder.dart';

void main() {
  test('builds selected-text context by default', () {
    final context = const ContextBuilder().build(
      selectedText: '  选中的句子  ',
      range: AiContextRange.selectedText,
    );

    expect(context.text, '选中的句子');
    expect(context.description, contains('仅选中文本'));
    expect(context.description, contains('仅发送下方文本'));
  });

  test('builds surrounding paragraphs when source text is available', () {
    const source = '第一段\n\n第二段包含目标句子\n\n第三段\n\n第四段';

    final context = const ContextBuilder().build(
      selectedText: '目标句子',
      range: AiContextRange.surroundingParagraphs,
      availableText: source,
    );

    expect(context.text, '第一段\n\n第二段包含目标句子\n\n第三段');
  });

  test(
    'describes current PDF page context without embedding location in payload copy',
    () {
      final builder = const ContextBuilder();
      final context = builder.build(
        selectedText: '页面文字',
        range: AiContextRange.currentPage,
        locator: ReadingLocator.pdf(page: 12),
      );

      expect(context.text, '页面文字');
      expect(context.description, contains('当前页'));
      expect(context.description, isNot(contains('第 12 页')));
      expect(builder.locationLabel(ReadingLocator.pdf(page: 12)), '第 12 页');
    },
  );
}
