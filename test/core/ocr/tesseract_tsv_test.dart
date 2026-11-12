import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/tesseract_tsv.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';

import 'support/fake_tesseract_process.dart';

OcrPageResult parse(String value) => parseTesseractTsv(
  value,
  imageWidth: 64,
  imageHeight: 64,
  language: 'chi_sim+eng',
  engine: 'tesseract',
);

void main() {
  test(
    'joins Latin tokens, preserves internal spaces, and merges line boxes',
    () {
      final result = parse(
        pageTsv(
          words: [
            wordTsv('Hello', left: 2, width: 15, confidence: '80'),
            wordTsv(
              'OCR text',
              word: 2,
              left: 20,
              width: 30,
              confidence: '100',
            ),
          ],
        ),
      );
      expect(result.text, 'Hello OCR text');
      expect(result.blocks.single.text, result.text);
      expect(result.blocks.single.left, 2 / 64);
      expect(result.blocks.single.width, 48 / 64);
      expect(result.confidence, closeTo((5 * 0.8 + 8) / 13, 0.000001));
    },
  );

  test('joins CJK and punctuation without inserting artificial spaces', () {
    final result = parse(
      pageTsv(
        words: [
          wordTsv('你'),
          wordTsv('好', word: 2),
          wordTsv('，', word: 3),
          wordTsv('世', word: 4),
          wordTsv('界', word: 5),
          wordTsv('。', word: 6),
        ],
      ),
    );
    expect(result.text, '你好，世界。');
  });

  test('handles Latin punctuation and parentheses consistently', () {
    final words = ['Hello', ',', 'world', '!', '(', 'next', ')'];
    final result = parse(
      pageTsv(
        words: [
          for (var index = 0; index < words.length; index += 1)
            wordTsv(words[index], word: index + 1),
        ],
      ),
    );
    expect(result.text, 'Hello, world! (next)');
  });

  test(
    'orders by block paragraph line word and preserves paragraph breaks',
    () {
      final result = parse(
        pageTsv(
          words: [
            wordTsv('last', block: 2),
            wordTsv('line', line: 2),
            wordTsv('second', word: 2),
            wordTsv('first'),
            wordTsv('paragraph', paragraph: 2),
          ],
        ),
      );
      expect(result.text, 'first second\nline\n\nparagraph\n\nlast');
      expect(result.blocks.map((block) => block.text), [
        'first second',
        'line',
        'paragraph',
        'last',
      ]);
    },
  );

  test('blank pages and unknown confidence remain empty or null', () {
    final blank = parse(pageTsv());
    expect(blank.text, isEmpty);
    expect(blank.blocks, isEmpty);
    expect(blank.confidence, isNull);
    final unknown = parse(pageTsv(words: [wordTsv('text', confidence: '-1')]));
    expect(unknown.confidence, isNull);
    final zero = parse(pageTsv(words: [wordTsv('text', confidence: '0')]));
    expect(zero.confidence, 0);
  });

  final badRows = {
    'out of bounds': wordTsv('text', left: 60, width: 10),
    'negative coordinate': wordTsv('text', top: -1),
    'zero-sized word': wordTsv('text', height: 0),
    'missing hierarchy': wordTsv('text', block: 0),
    'invalid confidence': wordTsv('text', confidence: 'NaN'),
    'negative confidence': wordTsv('text', confidence: '-0.5'),
    'confidence out of range': wordTsv('text', confidence: '101'),
    'malformed row': '5\t1\ttext',
  };
  for (final entry in badRows.entries) {
    test('rejects ${entry.key}', () {
      expect(
        () => parse(pageTsv(words: [entry.value])),
        throwsA(
          isA<OcrFailedException>().having(
            (error) => error.code,
            'code',
            'ocr_output_invalid',
          ),
        ),
      );
    });
  }

  test(
    'rejects plain text, header-only output, duplicate words and image size mismatch',
    () {
      for (final value in [
        'plain text',
        tesseractTsvHeader,
        pageTsv(words: [wordTsv('first'), wordTsv('duplicate')]),
        pageTsv(width: 65),
      ]) {
        expect(() => parse(value), throwsA(isA<OcrFailedException>()));
      }
    },
  );

  test('bounds word count and UTF-8 text size without truncating success', () {
    expect(
      () => parse(
        pageTsv(
          words: [
            for (var word = 1; word <= 20001; word += 1)
              wordTsv('text', word: word),
          ],
        ),
      ),
      throwsA(
        isA<OcrFailedException>().having(
          (error) => error.code,
          'code',
          'ocr_output_too_large',
        ),
      ),
    );
    expect(
      () => parse(pageTsv(words: [wordTsv('文' * 350000)])),
      throwsA(
        isA<OcrFailedException>().having(
          (error) => error.code,
          'code',
          'ocr_output_too_large',
        ),
      ),
    );
  });
}
