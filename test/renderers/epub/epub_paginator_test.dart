import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_paginator.dart';

void main() {
  test('paginates long paragraphs without exceeding measured page height', () {
    final chapter = EpubChapter(
      index: 0,
      href: 'chapter.xhtml',
      title: 'Long chapter',
      text: '${'很长的一段文本用于分页测试。' * 120}\n\n${'Second paragraph. ' * 80}',
    );
    final document = EpubDocument(chapters: [chapter]);
    const settings = ReaderSettings(
      fontSize: 18,
      lineHeight: 1.7,
      paragraphSpacing: 12,
      pageMargin: 24,
    );

    final pages = const EpubPaginator().paginate(
      document: document,
      settings: settings,
      viewport: const Size(420, 520),
    );

    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: const Size(420, 520),
    );
    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      expect(page.paragraphs, isNotEmpty);
      expect(page.fragments, isNotEmpty);
      expect(page.startOffset, lessThan(page.endOffset));
      expect(
        page.measuredHeight,
        lessThanOrEqualTo(metrics.contentHeight + 0.5),
      );
    }
  });

  test('pagination progress is monotonic across chapters and sizes', () {
    final document = EpubDocument(
      chapters: [
        EpubChapter(
          index: 0,
          href: 'one.xhtml',
          title: 'One',
          text: 'Alpha ' * 300,
        ),
        EpubChapter(
          index: 1,
          href: 'two.xhtml',
          title: 'Two',
          text: 'Beta ' * 300,
        ),
      ],
    );

    final pages = const EpubPaginator().paginate(
      document: document,
      settings: const ReaderSettings(fontSize: 22, lineHeight: 1.9),
      viewport: const Size(600, 700),
    );

    var previous = -1.0;
    for (final page in pages) {
      expect(page.progress, greaterThanOrEqualTo(previous));
      previous = page.progress;
    }
  });

  test('splits long text into monotonic chapter offset fragments', () {
    final chapter = EpubChapter(
      index: 0,
      href: 'chapter.xhtml',
      title: 'Offsets',
      text: '标题\n\n${'Alpha beta gamma delta. ' * 180}',
    );

    final pages = const EpubPaginator().paginate(
      document: EpubDocument(chapters: [chapter]),
      settings: const ReaderSettings(fontSize: 20, lineHeight: 1.8),
      viewport: const Size(420, 500),
    );

    expect(pages.length, greaterThan(1));
    var previousEnd = -1;
    for (final fragment in pages.expand((page) => page.fragments)) {
      expect(fragment.startOffset, greaterThanOrEqualTo(previousEnd));
      expect(fragment.endOffset, greaterThan(fragment.startOffset));
      previousEnd = fragment.endOffset;
    }
  });

  test('uses constrained reader measure width and detects code blocks', () {
    final chapter = EpubChapter(
      index: 0,
      href: 'code.xhtml',
      title: 'Code',
      text:
          'Code\n\n  final answer = 42;\n  print(answer);\n\nPlain paragraph.',
    );
    const settings = ReaderSettings(pageMargin: 24);

    final blocks = epubBlocks(chapter);
    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: const Size(1200, 800),
    );

    expect(blocks.map((block) => block.type), contains(EpubBlockType.code));
    expect(metrics.contentWidth, 760);
    expect(
      metrics.measureWidthFor(EpubBlockType.code),
      lessThan(metrics.contentWidth),
    );
  });

  test('paginateChapter keeps progress monotonic within a chapter', () {
    final chapter = EpubChapter(
      index: 1,
      href: 'two.xhtml',
      title: 'Chapter Two',
      text: '${'分页单章测试文本。' * 100}\n\n${'Another block. ' * 60}',
    );
    const settings = ReaderSettings(
      fontSize: 18,
      lineHeight: 1.7,
      paragraphSpacing: 12,
      pageMargin: 24,
    );
    final pages = const EpubPaginator().paginateChapter(
      chapter: chapter,
      settings: settings,
      viewport: const Size(420, 520),
      globalOffset: 500,
      totalLength: 5000,
    );
    expect(pages, isNotEmpty);
    expect(pages.first.chapter.index, 1);
    expect(pages.first.progress, greaterThan(0));
    for (var i = 1; i < pages.length; i += 1) {
      expect(pages[i].progress, greaterThanOrEqualTo(pages[i - 1].progress));
      expect(pages[i].pageNumberInChapter, i + 1);
      expect(pages[i].totalPagesInChapter, pages.length);
    }
  });
}
