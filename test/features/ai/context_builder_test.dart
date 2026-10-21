import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/ai_context_range.dart';
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

  group('chapter ranges', () {
    test('send the chapter text rather than the selection', () {
      final context = const ContextBuilder().build(
        selectedText: '目标句子',
        range: AiContextRange.currentChapter,
        availableText: '开头段落\n\n目标句子在这里\n\n结尾段落',
      );

      expect(context.text, contains('开头段落'));
      expect(context.text, contains('结尾段落'));
      expect(context.description, contains('当前章节'));
    });

    test('fall back to the selection when no chapter text was loaded', () {
      final context = const ContextBuilder().build(
        selectedText: '目标句子',
        range: AiContextRange.currentChapter,
      );

      expect(context.text, '目标句子');
    });

    test('cut a long chapter to the request ceiling instead of failing', () {
      final paragraph = '这是一个很长的段落，用来把章节撑过预算。\n\n';
      final chapter = List.filled(900, paragraph).join();
      expect(chapter.length, greaterThan(ContextBuilder.maxSourceChars));

      final context = const ContextBuilder().build(
        selectedText: '目标句子',
        range: AiContextRange.currentChapter,
        availableText: chapter,
      );

      expect(
        context.text.length,
        lessThanOrEqualTo(ContextBuilder.maxSourceChars),
      );
      expect(context.text, isNotEmpty);
    });

    test('centre the window on the selection when the chapter is cut', () {
      final filler = List.filled(600, '填充文字' * 10).join('\n\n');
      final marker = '只在中间出现的定位句';
      final chapter = '$filler\n\n$marker\n\n$filler';
      expect(chapter.length, greaterThan(ContextBuilder.maxSourceChars));

      final context = const ContextBuilder().build(
        selectedText: marker,
        range: AiContextRange.currentChapter,
        availableText: chapter,
      );

      expect(context.text, contains(marker));
      expect(
        context.text.length,
        lessThanOrEqualTo(ContextBuilder.maxSourceChars),
      );
    });

    test('a chapter with no blank lines is still cut to the ceiling', () {
      // One endless paragraph: the surrounding-paragraph range would return
      // the whole thing, and `_ask` would then refuse to send it.
      final chapter = '没有空行的长文' * 2000;
      expect(chapter.length, greaterThan(ContextBuilder.maxSourceChars));

      final context = const ContextBuilder().build(
        selectedText: '没有空行的长文',
        range: AiContextRange.surroundingParagraphs,
        availableText: chapter,
      );

      expect(
        context.text.length,
        lessThanOrEqualTo(ContextBuilder.maxSourceChars),
      );
      expect(context.text, isNotEmpty);
    });

    test('a short chapter passes through unchanged', () {
      const chapter = '短章节正文';

      final context = const ContextBuilder().build(
        selectedText: '选中的字',
        range: AiContextRange.currentChapter,
        availableText: chapter,
      );

      expect(context.text, chapter);
    });
  });
}
