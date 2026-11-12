import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/common/math_source.dart';

void main() {
  test('normalizes compact TeX shorthand used by Markdown notes', () {
    final source = MathSource(
      r'\displaystyle \lim_{x\to0}\left(\frac1{x^2}-\frac1{x\tan x}\right)',
    );

    expect(
      source.expression,
      r'\displaystyle \lim_{x\to0}\left(\frac{1}{x^2}-\frac{1}{x\tan x}\right)',
    );
    expect(source.isValid, isTrue);
  });

  test('rejects malformed TeX instead of throwing while rendering', () {
    final source = MathSource(r'\frac{1}{');

    expect(source.isValid, isFalse);
  });
}
