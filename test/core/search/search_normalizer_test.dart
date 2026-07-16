import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/search/search_normalizer.dart';

void main() {
  test('normalizes case whitespace and full-width ASCII', () {
    const normalizer = SearchNormalizer();

    expect(normalizer.normalize('  ＡＰＩ　Search\tTerm  '), 'api search term');
  });

  test('detects CJK queries for fallback search', () {
    const normalizer = SearchNormalizer();

    expect(normalizer.containsCjk('中文关键字'), isTrue);
    expect(normalizer.containsCjk('plain text'), isFalse);
  });
}
