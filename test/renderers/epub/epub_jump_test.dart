import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/epub/epub_jump.dart';

void main() {
  group('epubContinuousItemIndexForLocator', () {
    final items = <EpubJumpListItem>[
      const EpubJumpListItem.header(chapterIndex: 0),
      const EpubJumpListItem.fragment(
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 40,
      ),
      const EpubJumpListItem.fragment(
        chapterIndex: 0,
        startOffset: 40,
        endOffset: 90,
      ),
      const EpubJumpListItem.header(chapterIndex: 1),
      const EpubJumpListItem.fragment(
        chapterIndex: 1,
        startOffset: 0,
        endOffset: 20,
      ),
      const EpubJumpListItem.fragment(
        chapterIndex: 1,
        startOffset: 20,
        endOffset: 80,
      ),
    ];

    test('prefers exact fragment containing chapterOffset', () {
      final index = epubContinuousItemIndexForLocator(
        items: items,
        locator: ReadingLocator.epub(chapterIndex: 1, chapterOffset: 35),
      );
      expect(index, 5);
    });

    test('falls back to next fragment after offset', () {
      final index = epubContinuousItemIndexForLocator(
        items: items,
        locator: ReadingLocator.epub(chapterIndex: 0, chapterOffset: 55),
      );
      expect(index, 2);
    });

    test('falls back to chapter header when chapter has no fragments', () {
      final sparse = <EpubJumpListItem>[
        const EpubJumpListItem.header(chapterIndex: 2),
        const EpubJumpListItem.header(chapterIndex: 3),
      ];
      final index = epubContinuousItemIndexForLocator(
        items: sparse,
        locator: ReadingLocator.epub(chapterIndex: 3, chapterOffset: 12),
      );
      expect(index, 1);
    });
  });

  group('epubFocusRangeFor', () {
    test('uses chapter offsets when available', () {
      final range = epubFocusRangeFor(
        ReadingLocator.epub(
          chapterIndex: 2,
          chapterOffset: 10,
          chapterEndOffset: 24,
          excerpt: 'hello world',
        ),
      );
      expect(range, isNotNull);
      expect(range!.chapterIndex, 2);
      expect(range.start, 10);
      expect(range.end, 24);
      expect(range.excerpt, 'hello world');
    });

    test('derives end from excerpt length when end is missing', () {
      final range = epubFocusRangeFor(
        ReadingLocator.epub(
          chapterIndex: 0,
          chapterOffset: 5,
          excerpt: 'abcd',
        ),
      );
      expect(range, isNotNull);
      expect(range!.start, 5);
      expect(range.end, 9);
    });

    test('returns null for pdf locators', () {
      expect(
        epubFocusRangeFor(ReadingLocator.pdf(page: 3, excerpt: 'x')),
        isNull,
      );
    });
  });

  group('pdfFlashQueryFor', () {
    test('returns compact excerpt for pdf', () {
      expect(
        pdfFlashQueryFor(
          ReadingLocator.pdf(page: 1, excerpt: '  foo   bar  '),
        ),
        'foo bar',
      );
    });

    test('returns null for epub', () {
      expect(
        pdfFlashQueryFor(
          ReadingLocator.epub(chapterIndex: 0, excerpt: 'x'),
        ),
        isNull,
      );
    });
  });

  group('jumpPrecisionFor / jumpStatusLabelFor', () {
    test('classifies epub phrase and section precision', () {
      expect(
        jumpPrecisionFor(
          ReadingLocator.epub(chapterIndex: 1, chapterOffset: 12),
        ),
        JumpPrecision.phrase,
      );
      expect(
        jumpPrecisionFor(ReadingLocator.epub(chapterIndex: 1)),
        JumpPrecision.section,
      );
      expect(
        jumpPrecisionFor(ReadingLocator.epub(progress: 0.4)),
        JumpPrecision.coarse,
      );
    });

    test('mentions missing text layer for pdf section jump', () {
      final label = jumpStatusLabelFor(
        ReadingLocator.pdf(page: 4),
        pdfTextLayerAvailable: false,
      );
      expect(label, contains('第 4 页'));
      expect(label, contains('无文本层'));
    });
  });

  group('enrichLocatorForJump', () {
    test('fills missing excerpt from fallback text', () {
      final enriched = enrichLocatorForJump(
        ReadingLocator.epub(chapterIndex: 2, chapterOffset: 8),
        fallbackExcerpt: '  alpha   beta  ',
      );
      expect(enriched.excerpt, 'alpha beta');
      expect(enriched.chapterIndex, 2);
      expect(enriched.chapterOffset, 8);
    });

    test('keeps existing excerpt', () {
      final enriched = enrichLocatorForJump(
        ReadingLocator.pdf(page: 3, excerpt: 'keep me'),
        fallbackExcerpt: 'ignore me',
      );
      expect(enriched.excerpt, 'keep me');
    });
  });

  group('compactLocatorExcerpt', () {
    test('collapses whitespace and truncates', () {
      expect(compactLocatorExcerpt('  a   b  '), 'a b');
      final long = List.filled(200, 'x').join();
      expect(compactLocatorExcerpt(long, maxChars: 40)!.length, lessThanOrEqualTo(40));
    });
  });
}
