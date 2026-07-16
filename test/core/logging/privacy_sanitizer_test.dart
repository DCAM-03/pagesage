import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/logging/privacy_sanitizer.dart';

void main() {
  test('sanitizes api keys local paths and selected text payloads', () {
    const sanitizer = PrivacySanitizer();

    final result = sanitizer.sanitize(
      r'Authorization: Bearer abc.def.ghi path C:\Users\Chaos\book.epub selectedText: very private excerpt',
    );

    expect(result, isNot(contains('abc.def.ghi')));
    expect(result, isNot(contains(r'C:\Users\Chaos')));
    expect(result, isNot(contains('very private excerpt')));
    expect(result, contains('[已隐藏密钥]'));
    expect(result, contains('[本地路径]'));
    expect(result, contains('[已隐藏正文]'));
  });
}
