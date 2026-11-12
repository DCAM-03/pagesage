import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/ocr/ocr_jobs.dart';

void main() {
  test('parses, sorts, and deduplicates mixed ranges', () {
    expect(OcrPageRange.parse('10–12, 2, 1-3, 8', pageCount: 12), [
      1,
      2,
      3,
      8,
      10,
      11,
      12,
    ]);
    expect(OcrPageRange.parse(' 5 ', pageCount: 12), [5]);
    expect(OcrPageRange.parse('5-3', pageCount: 12), [3, 4, 5]);
  });

  test('rejects malformed, out-of-range, and oversized ranges', () {
    for (final input in ['', '1,,2', 'a-b', '0', '13', '1-13']) {
      expect(
        () => OcrPageRange.parse(input, pageCount: 12),
        throwsA(isA<FormatException>()),
        reason: input,
      );
    }
    expect(
      () => OcrPageRange.parse('1-5', pageCount: 12, maxPages: 4),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => OcrPageRange.parse('1', pageCount: 0),
      throwsA(isA<FormatException>()),
    );
  });

  test('job config round-trips safely and falls back on bad JSON', () {
    const config = OcrJobConfig(
      languageHint: 'zh-Hans',
      dpi: 300,
      maxEdge: 3300,
    );
    final decoded = OcrJobConfig.decode(config.encode());
    expect(decoded.languageHint, 'zh-Hans');
    expect(decoded.dpi, 300);
    expect(decoded.maxEdge, 3300);
    final fallback = OcrJobConfig.decode('{bad json');
    expect(fallback.dpi, 200);
    expect(fallback.maxEdge, 2200);
    expect(fallback.languageHint, isNull);
  });
}
