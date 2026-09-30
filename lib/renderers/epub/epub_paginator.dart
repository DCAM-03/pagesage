import 'package:flutter/material.dart';

import '../../domain/books/reader_fonts.dart';
import '../../domain/books/reader_settings.dart';
import 'epub_document.dart';

final class EpubPaginator {
  const EpubPaginator();

  List<EpubPage> paginate({
    required EpubDocument document,
    required ReaderSettings settings,
    required Size viewport,
  }) {
    final totalLength = document.totalTextLength <= 0
        ? 1
        : document.totalTextLength;
    final pages = <EpubPage>[];
    var globalOffset = 0;
    for (final chapter in document.chapters) {
      final chapterPages = paginateChapter(
        chapter: chapter,
        settings: settings,
        viewport: viewport,
        globalOffset: globalOffset,
        totalLength: totalLength,
      );
      pages.addAll(chapterPages);
      globalOffset += chapter.text.length;
    }
    if (pages.isNotEmpty || document.chapters.isEmpty) {
      return pages;
    }
    final chapter = document.chapters.first;
    return [
      EpubPage(
        chapter: chapter,
        fragments: [
          EpubPageFragment(
            chapterIndex: chapter.index,
            href: chapter.href,
            startOffset: 0,
            endOffset: chapter.text.length,
            text: chapter.text,
            blockType: EpubBlockType.paragraph,
          ),
        ],
        pageNumberInChapter: 1,
        totalPagesInChapter: 1,
        progress: 0,
        measuredHeight: 0,
      ),
    ];
  }

  /// Paginate a single chapter. Used by paged mode to avoid measuring the whole book on open.
  List<EpubPage> paginateChapter({
    required EpubChapter chapter,
    required ReaderSettings settings,
    required Size viewport,
    required int globalOffset,
    required int totalLength,
  }) {
    final metrics = EpubPageMetrics.from(
      settings: settings,
      viewport: viewport,
    );
    final pages = <EpubPage>[];
    var current = <_MeasuredFragment>[];
    var currentHeight = 0.0;

    void flush() {
      if (current.isEmpty) {
        return;
      }
      final fragments = current
          .map((fragment) => fragment.fragment)
          .toList(growable: false);
      final progress =
          ((globalOffset + fragments.first.startOffset) / totalLength)
              .clamp(0, 1)
              .toDouble();
      pages.add(
        EpubPage(
          chapter: chapter,
          fragments: fragments,
          pageNumberInChapter: pages.length + 1,
          totalPagesInChapter: 1,
          progress: progress,
          measuredHeight: currentHeight,
        ),
      );
      current = <_MeasuredFragment>[];
      currentHeight = 0;
    }

    void addMeasured(_MeasuredFragment measured) {
      current.add(measured);
      currentHeight += measured.height;
    }

    final blocks = epubBlocks(chapter);
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      final block = blocks[blockIndex];
      final measured = _measureBlock(block, metrics);

      if (block.type == EpubBlockType.heading &&
          current.isNotEmpty &&
          blockIndex + 1 < blocks.length) {
        final nextMeasured = _measureBlock(blocks[blockIndex + 1], metrics);
        if (currentHeight + measured.height + nextMeasured.height >
            metrics.contentHeight) {
          flush();
        }
      }

      if (measured.height <= metrics.contentHeight) {
        if (current.isNotEmpty &&
            currentHeight + measured.height > metrics.contentHeight) {
          flush();
        }
        addMeasured(measured);
        continue;
      }

      flush();
      var localStart = 0;
      var continuation = false;
      while (localStart < block.text.length) {
        final remainingHeight = metrics.contentHeight - currentHeight;
        final maxHeight = remainingHeight <= metrics.minLineHeight
            ? metrics.contentHeight
            : remainingHeight;
        if (remainingHeight <= metrics.minLineHeight && current.isNotEmpty) {
          flush();
        }
        final split = _largestFittingFragment(
          block: block,
          localStart: localStart,
          metrics: metrics,
          maxHeight: maxHeight,
          isContinuation: continuation,
        );
        if (split.fragment.text.isEmpty) {
          break;
        }
        addMeasured(split);
        localStart = split.fragment.endOffset - block.startOffset;
        continuation = true;
        if (localStart < block.text.length) {
          flush();
        }
      }
    }
    flush();

    final totalPages = pages.length.clamp(1, 99999).toInt();
    return [
      for (final page in pages)
        EpubPage(
          chapter: page.chapter,
          fragments: page.fragments,
          pageNumberInChapter: page.pageNumberInChapter,
          totalPagesInChapter: totalPages,
          progress: page.progress,
          measuredHeight: page.measuredHeight,
        ),
    ];
  }

  _MeasuredFragment _measureBlock(EpubBlock block, EpubPageMetrics metrics) {
    final height = _measure(
      block.text,
      metrics.styleFor(block.type),
      metrics.measureWidthFor(block.type),
    );
    return _MeasuredFragment(
      fragment: EpubPageFragment(
        chapterIndex: block.chapter.index,
        href: block.chapter.href,
        startOffset: block.startOffset,
        endOffset: block.endOffset,
        text: block.text,
        blockType: block.type,
      ),
      height:
          height +
          metrics.chromeHeightFor(block.type) +
          metrics.spacingFor(block.type),
    );
  }

  _MeasuredFragment _largestFittingFragment({
    required EpubBlock block,
    required int localStart,
    required EpubPageMetrics metrics,
    required double maxHeight,
    required bool isContinuation,
  }) {
    final text = block.text.substring(localStart);
    final style = metrics.styleFor(block.type);
    final width = metrics.measureWidthFor(block.type);
    final chromeHeight = metrics.chromeHeightFor(block.type);
    final spacing = metrics.spacingFor(block.type);
    // Reserve spacing inside the budget so measuredHeight never exceeds maxHeight.
    final textMaxHeight = (maxHeight - chromeHeight - spacing)
        .clamp(metrics.minLineHeight, maxHeight)
        .toDouble();
    var low = 1;
    var high = text.length;
    var best = 1;
    while (low <= high) {
      final mid = ((low + high) / 2).floor();
      final candidate = text.substring(0, mid);
      if (_measure(candidate, style, width) <= textMaxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    var end = best.clamp(1, text.length).toInt();
    if (end < text.length) {
      final boundary = block.type == EpubBlockType.code
          ? text.lastIndexOf('\n', end)
          : text.lastIndexOf(RegExp(r'[。！？.!?；;，,、\s]'), end);
      if (boundary > end * 0.62) {
        end = boundary + 1;
      }
    }
    final fragmentText = text.substring(0, end).trimRight();
    final endOffset = block.startOffset + localStart + fragmentText.length;
    final height = _measure(fragmentText, style, width);
    return _MeasuredFragment(
      fragment: EpubPageFragment(
        chapterIndex: block.chapter.index,
        href: block.chapter.href,
        startOffset: block.startOffset + localStart,
        endOffset: endOffset,
        text: fragmentText,
        blockType: block.type,
        isContinuation: isContinuation,
      ),
      height: height + chromeHeight + spacing,
    );
  }

  double _measure(String text, TextStyle style, double width) {
    // Match the renderer: SelectableText uses forceStrutHeight, which is
    // often taller than a bare TextPainter layout of the same style.
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      maxLines: null,
    )..layout(maxWidth: width);
    return painter.height;
  }
}

final class EpubPageMetrics {
  const EpubPageMetrics({
    required this.contentWidth,
    required this.contentHeight,
    required this.baseStyle,
    required this.paragraphSpacing,
  });

  factory EpubPageMetrics.from({
    required ReaderSettings settings,
    required Size viewport,
  }) {
    final availableWidth = viewport.width - settings.pageMargin * 2;
    final contentWidth = availableWidth > 760
        ? 760.0
        : availableWidth < 120
        ? 120.0
        : availableWidth.toDouble();
    final verticalPadding = (settings.pageMargin * 0.72)
        .clamp(12, 36)
        .toDouble();
    // Page chrome: title row + gaps + content padding top/bottom + footer.
    // Keep a small safety margin for SelectableText vs TextPainter delta.
    const pageChromeHeight = 118.0;
    const contentPaddingHeight = 30.0; // top 18 + bottom 12
    const safetyMargin = 20.0;
    final contentHeight =
        (viewport.height -
                verticalPadding * 2 -
                pageChromeHeight -
                contentPaddingHeight -
                safetyMargin)
            .clamp(200, 1400)
            .toDouble();
    return EpubPageMetrics(
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      baseStyle: TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        fontFamily: () {
          final family = ReaderFonts.renderFamilyFor(settings.fontFamily);
          return family.isEmpty ? null : family;
        }(),
      ),
      paragraphSpacing: settings.paragraphSpacing,
    );
  }

  final double contentWidth;
  final double contentHeight;
  final TextStyle baseStyle;
  final double paragraphSpacing;

  double get minLineHeight => baseStyle.fontSize! * (baseStyle.height ?? 1.4);

  TextStyle styleFor(EpubBlockType type) {
    return switch (type) {
      EpubBlockType.heading => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 1.22,
        fontWeight: FontWeight.w700,
        height: (baseStyle.height ?? 1.5) * 0.92,
      ),
      EpubBlockType.code => baseStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: baseStyle.fontSize! * 0.92,
        height: 1.52,
      ),
      EpubBlockType.imagePlaceholder || EpubBlockType.paragraph => baseStyle,
    };
  }

  double measureWidthFor(EpubBlockType type) {
    final chrome = switch (type) {
      EpubBlockType.code => 28.0,
      EpubBlockType.imagePlaceholder => 32.0,
      EpubBlockType.heading || EpubBlockType.paragraph => 0.0,
    };
    final width = contentWidth - chrome;
    return width < 120 ? contentWidth : width;
  }

  double chromeHeightFor(EpubBlockType type) {
    return switch (type) {
      EpubBlockType.code => 22.0,
      EpubBlockType.imagePlaceholder => 44.0,
      EpubBlockType.heading || EpubBlockType.paragraph => 0.0,
    };
  }

  double spacingFor(EpubBlockType type) {
    return switch (type) {
      EpubBlockType.heading => paragraphSpacing * 1.55,
      EpubBlockType.code => paragraphSpacing * 1.35,
      EpubBlockType.imagePlaceholder => paragraphSpacing * 1.2,
      EpubBlockType.paragraph => paragraphSpacing,
    };
  }
}

final class EpubPage {
  const EpubPage({
    required this.chapter,
    required this.fragments,
    required this.pageNumberInChapter,
    required this.totalPagesInChapter,
    required this.progress,
    required this.measuredHeight,
  });

  final EpubChapter chapter;
  final List<EpubPageFragment> fragments;
  final int pageNumberInChapter;
  final int totalPagesInChapter;
  final double progress;
  final double measuredHeight;

  List<String> get paragraphs => fragments
      .map((fragment) => fragment.text)
      .where((text) => text.isNotEmpty)
      .toList(growable: false);

  int get startOffset => fragments.isEmpty ? 0 : fragments.first.startOffset;

  int get endOffset =>
      fragments.isEmpty ? startOffset : fragments.last.endOffset;
}

final class EpubPageFragment {
  const EpubPageFragment({
    required this.chapterIndex,
    required this.href,
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.blockType,
    this.isContinuation = false,
  });

  final int chapterIndex;
  final String href;
  final int startOffset;
  final int endOffset;
  final String text;
  final EpubBlockType blockType;
  final bool isContinuation;
}

final class EpubBlock {
  const EpubBlock({
    required this.chapter,
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.type,
  });

  final EpubChapter chapter;
  final int startOffset;
  final int endOffset;
  final String text;
  final EpubBlockType type;
}

enum EpubBlockType { paragraph, heading, code, imagePlaceholder }

final class _MeasuredFragment {
  const _MeasuredFragment({required this.fragment, required this.height});

  final EpubPageFragment fragment;
  final double height;
}

List<EpubBlock> epubBlocks(EpubChapter chapter) {
  final text = chapter.text;
  final blocks = <EpubBlock>[];
  var cursor = 0;
  while (cursor < text.length) {
    while (cursor < text.length && _isWhitespace(text.codeUnitAt(cursor))) {
      cursor++;
    }
    if (cursor >= text.length) {
      break;
    }
    final separator = RegExp(r'\n\s*\n').firstMatch(text.substring(cursor));
    final rawEnd = separator == null ? text.length : cursor + separator.start;
    var end = rawEnd;
    while (end > cursor && _isWhitespace(text.codeUnitAt(end - 1))) {
      end--;
    }
    if (end > cursor) {
      final blockText = text.substring(cursor, end);
      blocks.add(
        EpubBlock(
          chapter: chapter,
          startOffset: cursor,
          endOffset: end,
          text: blockText,
          type: _detectBlockType(blockText, chapter.title),
        ),
      );
    }
    cursor = separator == null ? text.length : cursor + separator.end;
  }
  if (blocks.isEmpty && text.trim().isNotEmpty) {
    final start = text.indexOf(text.trimLeft());
    final trimmed = text.trim();
    blocks.add(
      EpubBlock(
        chapter: chapter,
        startOffset: start,
        endOffset: start + trimmed.length,
        text: trimmed,
        type: EpubBlockType.paragraph,
      ),
    );
  }
  return blocks;
}

List<String> epubParagraphs(String text) {
  final chapter = EpubChapter(index: 0, href: '', title: '', text: text);
  final parts = epubBlocks(chapter)
      .map((block) => block.text)
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? [text] : parts;
}

EpubBlockType _detectBlockType(String text, String chapterTitle) {
  final trimmed = text.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('[image') ||
      lower.startsWith('image:') ||
      lower.startsWith('figure:')) {
    return EpubBlockType.imagePlaceholder;
  }
  final lines = trimmed.split('\n');
  final indentedLines = lines
      .where((line) => line.startsWith('  ') || line.startsWith('\t'))
      .length;
  if (lines.length > 1 &&
      (indentedLines >= (lines.length / 2).ceil() ||
          RegExp(r'[{};]\s*$').hasMatch(trimmed))) {
    return EpubBlockType.code;
  }
  final normalizedTitle = chapterTitle.trim();
  if (trimmed == normalizedTitle && trimmed.length <= 120) {
    return EpubBlockType.heading;
  }
  if (lines.length == 1 &&
      trimmed.length <= 90 &&
      !RegExp(r'[。！？.!?；;:]$').hasMatch(trimmed)) {
    return EpubBlockType.heading;
  }
  return EpubBlockType.paragraph;
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x0C;
}
