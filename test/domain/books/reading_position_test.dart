import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';

void main() {
  test('serializes and restores EPUB locator fallback fields', () {
    final locator = ReadingLocator.epub(
      cfi: 'epubcfi(/6/4)',
      href: 'chapter-03.xhtml',
      chapterIndex: 3,
      chapterOffset: 120,
      chapterEndOffset: 180,
      progress: 0.42,
      excerpt: 'nearby text',
    );

    final restored = ReadingLocator.fromJsonText(locator.toJsonText());

    expect(restored.type, ReadingLocatorType.epub);
    expect(restored.cfi, 'epubcfi(/6/4)');
    expect(restored.href, 'chapter-03.xhtml');
    expect(restored.chapterIndex, 3);
    expect(restored.chapterOffset, 120);
    expect(restored.chapterEndOffset, 180);
    expect(restored.progress, 0.42);
    expect(restored.excerpt, 'nearby text');
  });

  test('serializes and restores PDF page, scroll and zoom', () {
    final locator = ReadingLocator.pdf(
      page: 12,
      scrollOffset: 320,
      zoom: 1.25,
      progress: 0.5,
      selectionRects: const [
        ReaderRect(page: 12, x: 0.1, y: 0.2, width: 0.3, height: 0.04),
      ],
    );

    final restored = ReadingLocator.fromJsonText(locator.toJsonText());

    expect(restored.type, ReadingLocatorType.pdf);
    expect(restored.page, 12);
    expect(restored.scrollOffset, 320);
    expect(restored.zoom, 1.25);
    expect(restored.progress, 0.5);
    expect(restored.selectionRects, hasLength(1));
    expect(restored.selectionRects.single.page, 12);
    expect(restored.selectionRects.single.x, 0.1);
  });

  test('restores old locator JSON without selection rects', () {
    final restored = ReadingLocator.fromJson({
      'type': 'pdf',
      'page': 3,
      'progress': 0.2,
    });

    expect(restored.page, 3);
    expect(restored.selectionRects, isEmpty);
  });

  test('falls back to a safe locator for invalid JSON text', () {
    final restored = ReadingLocator.fromJsonText('not-json');

    expect(restored.type, ReadingLocatorType.epub);
    expect(restored.progress, 0);
  });

  test('clamps progress during JSON serialization', () {
    final restored = ReadingLocator.fromJsonText(
      ReadingLocator.pdf(page: 2, progress: 1.7).toJsonText(),
    );

    expect(restored.progress, 1);
  });

  test('matches EPUB locators by stable fallback fields', () {
    final locator = ReadingLocator.epub(
      href: 'chapter.xhtml',
      chapterIndex: 2,
      progress: 0.25,
    );

    expect(
      locator.matches(
        ReadingLocator.epub(
          href: 'chapter.xhtml',
          chapterIndex: 2,
          progress: 0.27,
        ),
      ),
      isTrue,
    );
    expect(
      locator.matches(
        ReadingLocator.epub(href: 'other.xhtml', chapterIndex: 2),
      ),
      isFalse,
    );
  });

  test('matches EPUB locators by overlapping chapter offsets', () {
    final locator = ReadingLocator.epub(
      href: 'chapter.xhtml',
      chapterIndex: 2,
      chapterOffset: 100,
      chapterEndOffset: 180,
    );

    expect(
      locator.matches(
        ReadingLocator.epub(
          href: 'chapter.xhtml',
          chapterIndex: 2,
          chapterOffset: 160,
          chapterEndOffset: 220,
        ),
      ),
      isTrue,
    );
    expect(
      locator.matches(
        ReadingLocator.epub(
          href: 'chapter.xhtml',
          chapterIndex: 2,
          chapterOffset: 220,
          chapterEndOffset: 260,
        ),
      ),
      isFalse,
    );
  });

  test('matches PDF locators by page with scroll tolerance', () {
    final locator = ReadingLocator.pdf(page: 8, scrollOffset: 100);

    expect(
      locator.matches(ReadingLocator.pdf(page: 8, scrollOffset: 118)),
      isTrue,
    );
    expect(
      locator.matches(ReadingLocator.pdf(page: 8, scrollOffset: 140)),
      isFalse,
    );
    expect(locator.matches(ReadingLocator.pdf(page: 9)), isFalse);
  });
}
