import 'reading_position.dart';

String? compactLocatorExcerpt(String? text, {int maxChars = 120}) {
  final compact = text?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact == null || compact.isEmpty) {
    return null;
  }
  if (compact.length <= maxChars) {
    return compact;
  }
  return compact.substring(0, maxChars).trim();
}

ReadingLocator enrichLocatorForJump(
  ReadingLocator locator, {
  String? fallbackExcerpt,
}) {
  final existing = locator.excerpt?.trim();
  if (existing != null && existing.isNotEmpty) {
    return locator;
  }
  final excerpt = compactLocatorExcerpt(fallbackExcerpt, maxChars: 160);
  if (excerpt == null) {
    return locator;
  }
  return switch (locator.type) {
    ReadingLocatorType.epub => ReadingLocator.epub(
      cfi: locator.cfi,
      href: locator.href,
      chapterIndex: locator.chapterIndex,
      chapterOffset: locator.chapterOffset,
      chapterEndOffset: locator.chapterEndOffset,
      progress: locator.progress,
      excerpt: excerpt,
      selectionRects: locator.selectionRects,
    ),
    ReadingLocatorType.markdown => ReadingLocator.markdown(
      href: locator.href,
      chapterIndex: locator.chapterIndex,
      chapterOffset: locator.chapterOffset,
      chapterEndOffset: locator.chapterEndOffset,
      progress: locator.progress,
      excerpt: excerpt,
      selectionRects: locator.selectionRects,
    ),
    ReadingLocatorType.pdf => ReadingLocator.pdf(
      page: locator.page ?? 1,
      scrollOffset: locator.scrollOffset ?? 0,
      pageOffsetFraction: locator.pageOffsetFraction,
      zoom: locator.zoom ?? 1,
      progress: locator.progress,
      excerpt: excerpt,
      selectionRects: locator.selectionRects,
    ),
  };
}
