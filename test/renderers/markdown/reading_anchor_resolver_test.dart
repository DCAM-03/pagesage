import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/markdown/markdown_folder_diff.dart';

void main() {
  const resolver = ReadingAnchorResolver();

  test('unchanged revision keeps the exact locator', () {
    final locator = _locator(offset: 4, endOffset: 8, progress: 0.4);

    final result = resolver.resolve(
      locator,
      oldText: '旧文本内容',
      newText: '新文本内容',
      textRevisionChanged: false,
    );

    expect(result.precision, ReadingAnchorPrecision.exact);
    expect(result.locator.chapterOffset, 4);
  });

  test('a unique quote is reanchored to its new offset', () {
    final locator = _locator(offset: 2, endOffset: 6, progress: 0.2);

    final result = resolver.resolve(
      locator,
      oldText: '开头重点结尾',
      newText: '新增前言开头重点结尾',
    );

    expect(result.precision, ReadingAnchorPrecision.reanchored);
    expect(result.locator.chapterOffset, 6);
    expect(result.locator.chapterEndOffset, 10);
  });

  test('a repeated quote is marked ambiguous', () {
    final locator = _locator(offset: 0, endOffset: 4, progress: 0.2);

    final result = resolver.resolve(
      locator,
      oldText: '重复文本',
      newText: '重复文本中间重复文本',
    );

    expect(result.precision, ReadingAnchorPrecision.ambiguous);
  });

  test('excerpt reanchors when the stored range is unavailable', () {
    final locator = ReadingLocator.markdown(
      href: 'a.md',
      excerpt: '重点',
      progress: 0.2,
    );

    final result = resolver.resolve(
      locator,
      oldText: '开头重点结尾',
      newText: '前言开头重点结尾',
    );

    expect(result.precision, ReadingAnchorPrecision.reanchored);
    expect(result.locator.chapterOffset, 4);
  });

  test('progress gives an approximate offset for rewritten text', () {
    final locator = _locator(offset: null, endOffset: null, progress: 0.5);

    final result = resolver.resolve(
      locator,
      oldText: '旧内容',
      newText: List.filled(20, 'x').join(),
    );

    expect(result.precision, ReadingAnchorPrecision.approximate);
    expect(result.locator.chapterOffset, 10);
  });

  test('empty replacement text is missing', () {
    final locator = _locator(offset: null, endOffset: null, progress: 0.5);

    final result = resolver.resolve(locator, oldText: '旧内容', newText: '');

    expect(result.precision, ReadingAnchorPrecision.missing);
  });
}

ReadingLocator _locator({
  required int? offset,
  required int? endOffset,
  required double progress,
}) {
  return ReadingLocator.markdown(
    href: 'a.md',
    chapterOffset: offset,
    chapterEndOffset: endOffset,
    progress: progress,
  );
}
