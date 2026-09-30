import '../../domain/books/reading_position.dart';

/// Lightweight continuous-list item shape used for jump targeting.
final class EpubJumpListItem {
  const EpubJumpListItem.header({required this.chapterIndex})
    : startOffset = null,
      endOffset = null,
      isHeader = true;

  const EpubJumpListItem.fragment({
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
  }) : isHeader = false;

  final int chapterIndex;
  final int? startOffset;
  final int? endOffset;
  final bool isHeader;
}

/// Resolves the continuous ListView index that best matches [locator].
///
/// Prefers an exact fragment containing [ReadingLocator.chapterOffset], then
/// the next fragment at/after the offset, then the chapter header.
int epubContinuousItemIndexForLocator({
  required List<EpubJumpListItem> items,
  required ReadingLocator locator,
}) {
  if (items.isEmpty) {
    return 0;
  }

  final chapterIndex = locator.chapterIndex;
  if (chapterIndex == null) {
    return 0;
  }

  final offset = locator.chapterOffset ?? 0;
  var headerIndex = -1;
  var exactFragmentIndex = -1;
  var nextFragmentIndex = -1;
  var lastFragmentIndex = -1;

  for (var i = 0; i < items.length; i += 1) {
    final item = items[i];
    if (item.chapterIndex != chapterIndex) {
      continue;
    }
    if (item.isHeader) {
      headerIndex = i;
      continue;
    }
    final start = item.startOffset ?? 0;
    final end = item.endOffset ?? start;
    lastFragmentIndex = i;
    if (offset >= start && offset < end) {
      exactFragmentIndex = i;
      break;
    }
    if (nextFragmentIndex < 0 && start >= offset) {
      nextFragmentIndex = i;
    }
  }

  if (exactFragmentIndex >= 0) {
    return exactFragmentIndex;
  }
  if (nextFragmentIndex >= 0) {
    return nextFragmentIndex;
  }
  if (lastFragmentIndex >= 0) {
    return lastFragmentIndex;
  }
  if (headerIndex >= 0) {
    return headerIndex;
  }
  return 0;
}

/// Builds a temporary focus range for flash-highlight after a jump.
///
/// Returns null when the locator has no usable chapter anchors or excerpt.
({int chapterIndex, int start, int end, String? excerpt})? epubFocusRangeFor(
  ReadingLocator locator,
) {
  if (locator.type != ReadingLocatorType.epub) {
    return null;
  }
  final chapterIndex = locator.chapterIndex;
  if (chapterIndex == null) {
    return null;
  }
  final start = locator.chapterOffset;
  final excerpt = locator.excerpt?.trim();
  final end = locator.chapterEndOffset;
  if (start != null) {
    final resolvedEnd =
        end ??
        (excerpt != null && excerpt.isNotEmpty
            ? start + excerpt.length
            : start + 1);
    return (
      chapterIndex: chapterIndex,
      start: start,
      end: resolvedEnd > start ? resolvedEnd : start + 1,
      excerpt: excerpt,
    );
  }
  if (excerpt != null && excerpt.isNotEmpty) {
    return (chapterIndex: chapterIndex, start: 0, end: 0, excerpt: excerpt);
  }
  return null;
}

/// Text used to flash a PDF search hit after landing on a page.
String? pdfFlashQueryFor(ReadingLocator locator) {
  if (locator.type != ReadingLocatorType.pdf) {
    return null;
  }
  final excerpt = locator.excerpt?.trim();
  if (excerpt == null || excerpt.isEmpty) {
    return null;
  }
  // Prefer a short stable needle so text-layer spans still match.
  final compact = excerpt.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 48) {
    return compact;
  }
  return compact.substring(0, 48).trim();
}

/// How precisely a jump can land and flash-highlight.
enum JumpPrecision {
  /// Chapter/offset or page + excerpt — can flash a phrase.
  phrase,

  /// Chapter or page only — can land nearby, no phrase flash.
  section,

  /// Only progress / empty — weak restore.
  coarse,
}

JumpPrecision jumpPrecisionFor(ReadingLocator locator) {
  return switch (locator.type) {
    ReadingLocatorType.epub => () {
      final hasChapter = locator.chapterIndex != null;
      final hasOffset = locator.chapterOffset != null;
      final hasExcerpt = (locator.excerpt?.trim().isNotEmpty ?? false);
      if (hasChapter && (hasOffset || hasExcerpt)) {
        return JumpPrecision.phrase;
      }
      if (hasChapter || hasExcerpt) {
        return JumpPrecision.section;
      }
      return JumpPrecision.coarse;
    }(),
    ReadingLocatorType.pdf => () {
      final hasExcerpt = (locator.excerpt?.trim().isNotEmpty ?? false);
      if (hasExcerpt) {
        return JumpPrecision.phrase;
      }
      if (locator.page != null) {
        return JumpPrecision.section;
      }
      return JumpPrecision.coarse;
    }(),
  };
}

/// Status line after a jump — honest about precision.
String jumpStatusLabelFor(
  ReadingLocator locator, {
  bool pdfTextLayerAvailable = true,
}) {
  final precision = jumpPrecisionFor(locator);
  return switch (locator.type) {
    ReadingLocatorType.epub => switch (precision) {
      JumpPrecision.phrase =>
        locator.chapterIndex == null
            ? '已定位到原文'
            : '已定位到章节 ${locator.chapterIndex! + 1}',
      JumpPrecision.section =>
        locator.chapterIndex == null
            ? '已定位到附近位置'
            : '已定位到章节 ${locator.chapterIndex! + 1}（粗定位）',
      JumpPrecision.coarse => '已尽量恢复阅读位置（定位信息较弱）',
    },
    ReadingLocatorType.pdf => () {
      final page = locator.page;
      if (!pdfTextLayerAvailable) {
        return page == null
            ? '已打开 PDF（无文本层，无法高亮原文）'
            : '已定位到第 $page 页（无文本层，无法高亮原文）';
      }
      return switch (precision) {
        JumpPrecision.phrase => page == null ? '已定位到原文' : '已定位到第 $page 页',
        JumpPrecision.section =>
          page == null ? '已定位到附近页' : '已定位到第 $page 页（粗定位）',
        JumpPrecision.coarse => '已尽量恢复阅读位置（定位信息较弱）',
      };
    }(),
  };
}

/// Compact excerpt suitable for flash-highlight and search locators.
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

/// Fills missing [ReadingLocator.excerpt] from note/AI source text so flash works.
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
    ReadingLocatorType.pdf => ReadingLocator.pdf(
      page: locator.page ?? 1,
      scrollOffset: locator.scrollOffset ?? 0,
      zoom: locator.zoom ?? 1,
      progress: locator.progress,
      excerpt: excerpt,
      selectionRects: locator.selectionRects,
    ),
  };
}
