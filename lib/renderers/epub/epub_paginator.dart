import 'package:flutter/material.dart';

import '../../domain/books/reader_fonts.dart';
import '../../domain/books/reader_settings.dart';
import 'epub_document.dart';

/// A table cell's padding, shared with the renderer so that what the
/// paginator measures and what the page draws agree.
const double epubTableCellPaddingHorizontal = 6;
const double epubTableCellPaddingVertical = 4;

/// The rule above, below and between a table's rows.
const double epubTableBorderWidth = 1;

/// The width a list marker and the space after hanging lines occupy.
const double epubListHangingIndent = 28;

/// Horizontal space taken by one nested blockquote level.
const double epubQuoteIndent = 16;

/// The quiet code panel's vertical padding.
const double epubCodeBlockPadding = 11;

/// The room a fenced code block's language label takes above the code.
const double epubCodeLanguageHeight = 18;

/// How much of a paragraph gap sits between two list items.
///
/// Paragraphs need air between them; list items are one thought. Typora keeps
/// the list compact, so the reader should too.
const double epubListSpacingFactor = 0.3;

/// The gap between a picture and the caption below it.
const double epubImageCaptionGap = 6;

/// How much room an `alt` caption adds to an image block.
double epubImageCaptionHeight(
  EpubImage? image,
  EpubPageMetrics metrics, {
  int quoteDepth = 0,
}) {
  final alt = _imageCaption(image);
  if (alt == null || alt.isEmpty) {
    return 0;
  }
  return _measureText(
        alt,
        metrics.imageCaptionTextStyle,
        metrics.measureWidthFor(EpubBlockType.image, quoteDepth: quoteDepth),
      ) +
      epubImageCaptionGap;
}

String? _imageCaption(EpubImage? image) {
  final alt = image?.alt?.trim();
  return alt == null || alt.isEmpty ? null : alt;
}

/// How much larger than body text a heading of [level] is set.
///
/// Typora's hierarchy is mostly size: an h2 is clearly bigger than an h3, and
/// the reader should see the document's shape without reading the words.
double epubHeadingScale(int? level) {
  return switch (level) {
    1 => 1.62,
    2 => 1.36,
    3 => 1.16,
    4 => 1.06,
    5 => 1.0,
    6 => 0.96,
    _ => 1.22,
  };
}

/// The space above a heading of [level], as a multiple of paragraph spacing.
double epubHeadingSpacingFactor(int? level) {
  return switch (level) {
    1 => 1.95,
    2 => 1.7,
    3 => 1.5,
    4 => 1.35,
    5 => 1.25,
    6 => 1.2,
    _ => 1.55,
  };
}

/// The gap below a block, shared by the paginator and the renderer.
double epubBlockSpacing({
  required EpubBlockType type,
  required double paragraphSpacing,
  int? headingLevel,
  bool isList = false,
}) {
  if (isList) {
    return paragraphSpacing * epubListSpacingFactor;
  }
  return switch (type) {
    EpubBlockType.heading =>
      paragraphSpacing * epubHeadingSpacingFactor(headingLevel),
    EpubBlockType.code => paragraphSpacing * 1.35,
    EpubBlockType.math || EpubBlockType.diagram => paragraphSpacing * 1.25,
    EpubBlockType.caption => paragraphSpacing * 0.6,
    EpubBlockType.image => paragraphSpacing * 1.2,
    EpubBlockType.table => paragraphSpacing * 1.1,
    EpubBlockType.divider => paragraphSpacing * 1.6,
    EpubBlockType.quote || EpubBlockType.paragraph => paragraphSpacing,
  };
}

TextStyle epubHeadingTextStyle(TextStyle baseStyle, int? level) {
  return baseStyle.copyWith(
    fontSize: baseStyle.fontSize! * epubHeadingScale(level),
    fontWeight: FontWeight.w700,
    height: (baseStyle.height ?? 1.5) * 0.92,
  );
}

/// How tall a rule drawn across the column is, with its breathing room.
const double epubDividerHeight = 18;

/// The style a table's cells are set in.
///
/// A table puts more on a line than prose does, so its text is a touch
/// smaller than the paragraph around it.
TextStyle epubTableTextStyle(TextStyle baseStyle) {
  return baseStyle.copyWith(
    fontSize: baseStyle.fontSize! * 0.94,
    height: (baseStyle.height ?? 1.5) * 0.95,
  );
}

/// [baseStyle] with every inline style reaching across this stretch applied.
///
/// Two styles over the same words compose rather than fight: bold italic
/// stays both, and a strikethrough link keeps its underline. The paginator
/// and the view share this so a measured line is set in the same face as the
/// one that is drawn.
TextStyle epubInlineRunStyle(
  TextStyle baseStyle,
  List<EpubInlineRun> runs,
  int start,
  int end, {
  required Color accent,
  Color? codeBackground,
}) {
  var strong = false;
  var emphasis = false;
  var code = false;
  var strike = false;
  var link = false;
  var footnote = false;
  var math = false;
  var underline = false;
  var highlight = false;
  var superscript = false;
  var subscript = false;
  for (final run in runs) {
    if (run.start > start || run.end < end) {
      continue;
    }
    switch (run.style) {
      case EpubInlineStyle.strong:
        strong = true;
      case EpubInlineStyle.emphasis:
        emphasis = true;
      case EpubInlineStyle.code:
        code = true;
      case EpubInlineStyle.strike:
        strike = true;
      case EpubInlineStyle.link:
        link = true;
      case EpubInlineStyle.footnote:
        footnote = true;
      case EpubInlineStyle.math:
        math = true;
      case EpubInlineStyle.underline:
        underline = true;
      case EpubInlineStyle.highlight:
        highlight = true;
      case EpubInlineStyle.superscript:
        superscript = true;
      case EpubInlineStyle.subscript:
        subscript = true;
    }
  }
  if (!strong &&
      !emphasis &&
      !code &&
      !strike &&
      !link &&
      !footnote &&
      !math &&
      !underline &&
      !highlight &&
      !superscript &&
      !subscript) {
    return baseStyle;
  }
  var style = baseStyle;
  if (strong) {
    style = style.copyWith(fontWeight: FontWeight.w700);
  }
  if (emphasis) {
    style = style.copyWith(fontStyle: FontStyle.italic);
  }
  if (code) {
    style = style.copyWith(
      fontFamily: 'monospace',
      fontSize: style.fontSize! * 0.94,
      backgroundColor:
          codeBackground ??
          style.color?.withValues(alpha: 0.06) ??
          Colors.black.withValues(alpha: 0.06),
    );
  }
  if (link) {
    style = style.copyWith(color: accent);
  }
  if (footnote) {
    style = style.copyWith(
      fontSize: style.fontSize! * 0.72,
      height: (style.height ?? 1.5) * 0.9,
      fontFeatures: const [FontFeature.superscripts()],
      color: accent,
    );
  }
  if (superscript) {
    style = style.copyWith(
      fontSize: style.fontSize! * 0.72,
      height: (style.height ?? 1.5) * 0.9,
      fontFeatures: const [FontFeature.superscripts()],
    );
  }
  if (subscript) {
    style = style.copyWith(
      fontSize: style.fontSize! * 0.72,
      height: (style.height ?? 1.5) * 0.9,
      fontFeatures: const [FontFeature.subscripts()],
    );
  }
  if (highlight) {
    style = style.copyWith(backgroundColor: accent.withValues(alpha: 0.18));
  }
  final decorations = <TextDecoration>[
    if (style.decoration != null && style.decoration != TextDecoration.none)
      style.decoration!,
    if (strike) TextDecoration.lineThrough,
    if (link) TextDecoration.underline,
    if (underline && !link) TextDecoration.underline,
  ];
  if (decorations.isNotEmpty) {
    style = style.copyWith(
      decoration: TextDecoration.combine(decorations),
      decorationColor: link ? accent : style.color,
    );
  }
  return style;
}

/// The quiet line under a picture.
///
/// The paginator and the view share this style so the caption's measured
/// height is the height the page actually draws.
TextStyle epubImageCaptionTextStyle(TextStyle baseStyle, Color foreground) {
  return baseStyle.copyWith(
    color: foreground.withValues(alpha: 0.62),
    fontSize: baseStyle.fontSize! * 0.82,
    height: (baseStyle.height ?? 1.5) * 0.95,
  );
}

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
      if (block.type == EpubBlockType.table) {
        final rows = block.tableCells ?? const <List<EpubTableCell>>[];
        if (rows.isEmpty) {
          continue;
        }
        final tableStyle = metrics.styleFor(EpubBlockType.table);
        final cellWidths = metrics.tableColumnTextWidths(
          rows,
          quoteDepth: block.quoteDepth,
        );
        final hasHeader = block.tableHasHeader;
        final rowHeights = <double>[
          for (var index = 0; index < rows.length; index += 1)
            _tableRowHeight(
              rows[index],
              tableStyle,
              cellWidths,
              isHeader: hasHeader && index == 0,
              accent: metrics.foreground,
            ),
        ];
        final headerHeight = hasHeader ? rowHeights.first : 0.0;
        final spacing = metrics.spacingFor(EpubBlockType.table);
        var cursor = hasHeader ? 1 : 0;
        var firstFragment = true;
        while (firstFragment || cursor < rows.length) {
          // The header goes on every page the table continues onto: a row
          // lifted away from its columns still has to say what they are.
          final frame = <List<EpubTableCell>>[if (hasHeader) rows.first];
          final headerCount = frame.length;
          var frameHeight =
              spacing + (hasHeader ? headerHeight + epubTableBorderWidth : 0);
          if (current.isNotEmpty &&
              currentHeight +
                      frameHeight +
                      (cursor < rows.length
                          ? rowHeights[cursor] + epubTableBorderWidth
                          : 0) >
                  metrics.contentHeight) {
            flush();
          }
          while (cursor < rows.length) {
            final candidate =
                frameHeight + rowHeights[cursor] + epubTableBorderWidth;
            // The first row always goes on the page: a row cut in three is
            // unreadable, and a page one row too tall is still a page.
            if (frame.length > headerCount &&
                currentHeight + candidate > metrics.contentHeight) {
              break;
            }
            frame.add(rows[cursor]);
            frameHeight = candidate;
            cursor += 1;
          }
          addMeasured(
            _MeasuredFragment(
              fragment: EpubPageFragment(
                chapterIndex: block.chapter.index,
                href: block.chapter.href,
                startOffset: block.startOffset,
                endOffset: block.endOffset,
                text: frame
                    .map((row) => row.map((cell) => cell.text).join('   '))
                    .join('\n'),
                blockType: EpubBlockType.table,
                isContinuation: !firstFragment,
                tableCells: List<List<EpubTableCell>>.unmodifiable(frame),
                tableHasHeader: headerCount > 0,
                tableAlignments: block.tableAlignments,
                quoteDepth: block.quoteDepth,
              ),
              height: frameHeight,
            ),
          );
          firstFragment = false;
          if (cursor < rows.length) {
            flush();
          }
        }
        continue;
      }
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

      // A picture is never split: it either fits on a page or it is
      // scaled to fit one. A rule is a line, not a paragraph.
      if (block.type == EpubBlockType.image ||
          block.type == EpubBlockType.divider) {
        flush();
        addMeasured(measured);
        flush();
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
    if (block.type == EpubBlockType.divider) {
      return _MeasuredFragment(
        fragment: EpubPageFragment(
          chapterIndex: block.chapter.index,
          href: block.chapter.href,
          startOffset: block.startOffset,
          endOffset: block.endOffset,
          text: '',
          blockType: EpubBlockType.divider,
          quoteDepth: block.quoteDepth,
        ),
        height:
            epubDividerHeight +
            metrics.chromeHeightFor(block.type) +
            metrics.spacingFor(block.type, headingLevel: block.headingLevel),
      );
    }
    if (block.type == EpubBlockType.image) {
      final caption = _imageCaption(block.image);
      return _MeasuredFragment(
        fragment: EpubPageFragment(
          chapterIndex: block.chapter.index,
          href: block.chapter.href,
          startOffset: block.startOffset,
          endOffset: block.endOffset,
          text: '',
          blockType: EpubBlockType.image,
          image: block.image,
          imageCaption: caption,
          quoteDepth: block.quoteDepth,
        ),
        height:
            _imageHeight(block.image, metrics, quoteDepth: block.quoteDepth) +
            epubImageCaptionHeight(
              block.image,
              metrics,
              quoteDepth: block.quoteDepth,
            ) +
            metrics.chromeHeightFor(block.type) +
            metrics.spacingFor(block.type, headingLevel: block.headingLevel),
      );
    }
    final listWidth = !block.hasListHangingIndent
        ? metrics.measureWidthFor(block.type, quoteDepth: block.quoteDepth)
        : metrics.measureWidthForList(
            block.listIndent,
            quoteDepth: block.quoteDepth,
          );
    final measuredText = block.listMarker != null
        ? block.text.substring(
            (block.listMarker?.length ?? 0).clamp(0, block.text.length),
          )
        : block.text;
    final markerLength =
        block.listMarker?.length.clamp(0, block.text.length) ?? 0;
    final style = metrics.styleFor(
      block.type,
      headingLevel: block.headingLevel,
    );
    final height =
        block.type == EpubBlockType.diagram && block.diagramSource != null
        ? 360.0
        : block.type == EpubBlockType.math && block.mathSource != null
        ? _measureMath(block.mathSource!, block.text, metrics)
        : _measureText(measuredText, style, listWidth) +
              _inlineMathHeightReserve(
                block,
                localStart: 0,
                markerLength: markerLength,
                length: measuredText.length,
                style: style,
              );
    return _MeasuredFragment(
      fragment: EpubPageFragment(
        chapterIndex: block.chapter.index,
        href: block.chapter.href,
        startOffset: block.startOffset,
        endOffset: block.endOffset,
        text: block.text,
        blockType: block.type,
        inlineRuns: block.inlineRuns,
        headingLevel: block.headingLevel,
        listMarker: block.listMarker,
        listIndent: block.listIndent,
        quoteDepth: block.quoteDepth,
        hasListHangingIndent: block.hasListHangingIndent,
        taskChecked: block.taskChecked,
        codeLanguage: block.codeLanguage,
        codeRuns: block.codeRuns,
        mathSource: block.mathSource,
        diagramSource: block.diagramSource,
      ),
      height:
          height +
          metrics.chromeHeightFor(
            block.type,
            codeLanguage: block.codeLanguage,
          ) +
          metrics.spacingFor(
            block.type,
            headingLevel: block.headingLevel,
            isList: block.listMarker != null,
          ),
    );
  }

  /// How tall a picture is on the page.
  ///
  /// The picture is drawn at the width of the text column, so its height
  /// follows from its own proportions. A picture taller than the page is
  /// scaled down to fit: a page that shows half a figure is worse than a
  /// smaller whole one.
  ///
  /// A picture smaller than the column is not blown up to fill it. A
  /// 64-pixel icon drawn across 760 points is a blur, and a book that
  /// meant it as an icon should look like one.
  double _imageHeight(
    EpubImage? image,
    EpubPageMetrics metrics, {
    int quoteDepth = 0,
  }) {
    if (image == null) {
      return 0;
    }
    final width = metrics.imageWidthFor(image, quoteDepth: quoteDepth);
    final height = width / image.aspectRatio;
    final maxHeight = metrics.contentHeight * 0.82;
    if (height <= maxHeight) {
      return height;
    }
    return maxHeight;
  }

  _MeasuredFragment _largestFittingFragment({
    required EpubBlock block,
    required int localStart,
    required EpubPageMetrics metrics,
    required double maxHeight,
    required bool isContinuation,
  }) {
    final markerLength = localStart == 0
        ? (block.listMarker?.length ?? 0).clamp(0, block.text.length)
        : 0;
    final text = block.text.substring(localStart + markerLength);
    final style = metrics.styleFor(
      block.type,
      headingLevel: block.headingLevel,
    );
    final width = !block.hasListHangingIndent
        ? metrics.measureWidthFor(block.type, quoteDepth: block.quoteDepth)
        : metrics.measureWidthForList(
            block.listIndent,
            quoteDepth: block.quoteDepth,
          );
    final chromeHeight = metrics.chromeHeightFor(
      block.type,
      codeLanguage: block.codeLanguage,
    );
    final spacing = metrics.spacingFor(
      block.type,
      headingLevel: block.headingLevel,
      isList: block.listMarker != null,
    );
    double measure(String value) =>
        _measureText(value, style, width) +
        _inlineMathHeightReserve(
          block,
          localStart: localStart,
          markerLength: markerLength,
          length: value.length,
          style: style,
        );
    // Reserve spacing inside the budget so measuredHeight never exceeds maxHeight.
    final textMaxHeight = (maxHeight - chromeHeight - spacing)
        .clamp(metrics.minLineHeight, maxHeight)
        .toDouble();
    var low = 1;
    var high = text.length;
    var best = low;
    while (low <= high) {
      final mid = ((low + high) / 2).floor();
      final candidate = text.substring(0, mid);
      if (measure(candidate) <= textMaxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    var end = best.clamp(1, text.length).toInt();
    if (end < text.length) {
      final sourceBlock = const <EpubBlockType>{
        EpubBlockType.code,
        EpubBlockType.math,
        EpubBlockType.diagram,
      }.contains(block.type);
      final boundary = sourceBlock
          ? text.lastIndexOf('\n', end)
          : text.lastIndexOf(RegExp(r'[。！？.!?；;，,、\s]'), end);
      if (boundary > end * 0.62) {
        end = boundary + 1;
      }
    }
    end = _avoidInlineMathSplit(
      block,
      localStart: localStart,
      markerLength: markerLength,
      end: end,
      textLength: text.length,
    );
    final fragmentText = text.substring(0, end).trimRight();
    final endOffset =
        block.startOffset + localStart + markerLength + fragmentText.length;
    final height = measure(fragmentText);
    return _MeasuredFragment(
      fragment: EpubPageFragment(
        chapterIndex: block.chapter.index,
        href: block.chapter.href,
        startOffset: block.startOffset + localStart + markerLength,
        endOffset: endOffset,
        text: fragmentText,
        blockType: block.type,
        isContinuation: isContinuation,
        inlineRuns: block.inlineRuns,
        headingLevel: block.headingLevel,
        listMarker: localStart == 0 ? block.listMarker : null,
        listIndent: block.listIndent,
        quoteDepth: block.quoteDepth,
        hasListHangingIndent: false,
        taskChecked: localStart == 0 ? block.taskChecked : null,
        codeLanguage: block.codeLanguage,
        codeRuns: block.codeRuns,
        mathSource: block.mathSource,
        diagramSource: block.diagramSource,
      ),
      height: height + chromeHeight + spacing,
    );
  }
}

/// How tall [text] is when laid out at [width].
///
/// Match the renderer: SelectableText uses forceStrutHeight, which is often
/// taller than a bare TextPainter layout of the same style.
double _measureText(String text, TextStyle style, double width) {
  return _measureSpan(TextSpan(text: text, style: style), style, width);
}

/// How tall [span] is when laid out at [width], using the same strut as the
/// renderer's text widgets.
double _measureSpan(InlineSpan span, TextStyle style, double width) {
  final painter = TextPainter(
    text: TextSpan(style: style, children: <InlineSpan>[span]),
    textDirection: TextDirection.ltr,
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    maxLines: null,
  )..layout(maxWidth: width);
  return painter.height;
}

/// Keeps a page break from landing inside an inline formula.
///
/// A fragment that holds only half an expression cannot draw the formula;
/// the renderer would fall back to source text on both pages. Moving the
/// whole formula to the next fragment keeps it whole and keeps the pages
/// honest about what they contain.
int _avoidInlineMathSplit(
  EpubBlock block, {
  required int localStart,
  required int markerLength,
  required int end,
  required int textLength,
}) {
  if (end <= 0 || end >= textLength) {
    return end;
  }
  final base = block.startOffset + localStart + markerLength;
  var adjusted = end;
  for (final run in block.inlineRuns) {
    if (run.style != EpubInlineStyle.math || run.mathSource == null) {
      continue;
    }
    final start = run.start - base;
    final finish = run.end - base;
    if (finish <= 0 || start >= textLength) {
      continue;
    }
    if (adjusted <= 0 || adjusted >= finish) {
      continue;
    }
    if (start > 0) {
      if (adjusted > start) {
        adjusted = start;
      }
    } else if (finish <= textLength) {
      adjusted = finish;
    }
  }
  return adjusted;
}

/// Room an inline formula needs beyond its source characters.
///
/// The source text measures as one plain line, but a fraction, limit, root or
/// integral grows above and below the baseline. Reserving a little height per
/// formula keeps paged mode from clipping the bottom of a line; over-reserving
/// is preferable to dropping the tail of an equation.
double _inlineMathHeightReserve(
  EpubBlock block, {
  required int localStart,
  required int markerLength,
  required int length,
  required TextStyle style,
}) {
  if (length <= 0) {
    return 0;
  }
  final base = block.startOffset + localStart + markerLength;
  var count = 0;
  var tall = false;
  for (final run in block.inlineRuns) {
    if (run.style != EpubInlineStyle.math || run.mathSource == null) {
      continue;
    }
    final start = run.start - base;
    final end = run.end - base;
    if (end <= 0 || start >= length) {
      continue;
    }
    count += 1;
    tall =
        tall ||
        RegExp(
          r'\\(?:d?frac|tfrac|sqrt|binom|int|iint|iiint|sum|prod|lim|'
          r'begin|left|right)\b',
        ).hasMatch(run.mathSource!);
  }
  if (count == 0) {
    return 0;
  }
  final perFormula = style.fontSize! * (tall ? 1.15 : 0.6);
  return perFormula * count.clamp(1, 2);
}

/// A displayed equation is taller than the same number of source characters.
///
/// Fractions, limits and roots add vertical boxes; reserving a line and a half
/// per expression keeps paged mode from measuring it as one plain text line.
double _measureMath(String source, String fallback, EpubPageMetrics metrics) {
  final style = metrics.baseStyle;
  final lineHeight = style.fontSize! * (style.height ?? 1.4);
  return _measureText(fallback, style, metrics.contentWidth - 28) +
      lineHeight * 0.75;
}

/// How tall one table row is: its tallest cell, plus the cell's own padding.
double _tableRowHeight(
  List<EpubTableCell> cells,
  TextStyle style,
  List<double> cellWidths, {
  required bool isHeader,
  required Color accent,
}) {
  final rowStyle = isHeader
      ? style.copyWith(fontWeight: FontWeight.w600)
      : style;
  var height = 0.0;
  for (var column = 0; column < cells.length; column += 1) {
    final cell = cells[column];
    if (cell.text.isEmpty) {
      continue;
    }
    final width = column < cellWidths.length
        ? cellWidths[column]
        : cellWidths.isEmpty
        ? 24.0
        : cellWidths.last;
    final cellHeight = _measureSpan(
      _tableCellSpan(cell, rowStyle, accent),
      rowStyle,
      width,
    );
    if (cellHeight > height) {
      height = cellHeight;
    }
  }
  return height + epubTableCellPaddingVertical * 2;
}

InlineSpan _tableCellSpan(EpubTableCell cell, TextStyle style, Color accent) {
  if (cell.runs.isEmpty) {
    return TextSpan(text: cell.text, style: style);
  }
  final points = <int>{0, cell.text.length};
  for (final run in cell.runs) {
    points
      ..add(run.start.clamp(0, cell.text.length))
      ..add(run.end.clamp(0, cell.text.length));
  }
  final boundaries = points.toList()..sort();
  final spans = <InlineSpan>[];
  for (var index = 0; index + 1 < boundaries.length; index += 1) {
    final start = boundaries[index];
    final end = boundaries[index + 1];
    if (start >= end) {
      continue;
    }
    spans.add(
      TextSpan(
        text: cell.text.substring(start, end),
        style: epubInlineRunStyle(style, cell.runs, start, end, accent: accent),
      ),
    );
  }
  return TextSpan(style: style, children: spans);
}

/// The relative width each column deserves.
///
/// A column of prose should not be squeezed into the same slot as a column of
/// numbers: notes are full of tables where one column holds a paragraph and
/// the next holds `3`. Each column asks for as many shares as its longest cell
/// takes, bounded so one verbose cell cannot push the others off the page.
List<int> epubTableColumnFlex(List<List<EpubTableCell>> rows) {
  if (rows.isEmpty) {
    return const <int>[];
  }
  final columns = rows.first.length;
  final longest = List<int>.filled(columns, 1);
  for (final row in rows) {
    for (var column = 0; column < columns && column < row.length; column++) {
      final length = row[column].text.length;
      if (length > longest[column]) {
        longest[column] = length;
      }
    }
  }
  return <int>[for (final length in longest) length.clamp(4, 28)];
}

final class EpubPageMetrics {
  const EpubPageMetrics({
    required this.contentWidth,
    required this.contentHeight,
    required this.baseStyle,
    required this.paragraphSpacing,
    required this.foreground,
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
      foreground: settings.themePreset.foreground,
    );
  }

  final double contentWidth;
  final double contentHeight;
  final TextStyle baseStyle;
  final double paragraphSpacing;
  final Color foreground;

  double get minLineHeight => baseStyle.fontSize! * (baseStyle.height ?? 1.4);

  TextStyle styleFor(EpubBlockType type, {int? headingLevel}) {
    return switch (type) {
      EpubBlockType.heading => epubHeadingTextStyle(baseStyle, headingLevel),
      EpubBlockType.code => baseStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: baseStyle.fontSize! * 0.92,
        height: 1.52,
      ),
      EpubBlockType.math || EpubBlockType.diagram => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 0.9,
        height: 1.45,
        color: baseStyle.color?.withValues(alpha: 0.72),
      ),
      EpubBlockType.caption => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 0.88,
        height: (baseStyle.height ?? 1.5) * 0.95,
      ),
      EpubBlockType.table => epubTableTextStyle(baseStyle),
      EpubBlockType.quote => baseStyle,
      EpubBlockType.divider ||
      EpubBlockType.image ||
      EpubBlockType.paragraph => baseStyle,
    };
  }

  TextStyle get imageCaptionTextStyle =>
      epubImageCaptionTextStyle(baseStyle, foreground);

  double measureWidthFor(EpubBlockType type, {int quoteDepth = 0}) {
    final quoteLevels = quoteDepth < 1 ? 1 : quoteDepth;
    final baseChrome = switch (type) {
      EpubBlockType.code => 28.0,
      EpubBlockType.math || EpubBlockType.diagram => 28.0,
      EpubBlockType.image => 0.0,
      EpubBlockType.quote => 0.0,
      EpubBlockType.heading ||
      EpubBlockType.caption ||
      EpubBlockType.table ||
      EpubBlockType.divider ||
      EpubBlockType.paragraph => 0.0,
    };
    // Any block inside a quote sits behind one bar per level; quote blocks
    // without depth metadata are legacy single-level quotes.
    final quoteChrome = quoteDepth > 0 || type == EpubBlockType.quote
        ? epubQuoteIndent * quoteLevels
        : 0.0;
    final width = contentWidth - baseChrome - quoteChrome;
    return width < 120 ? contentWidth : width;
  }

  /// How wide the hanging text of a list item at [depth] is measured.
  double measureWidthForList(int depth, {int quoteDepth = 0}) {
    return measureWidthFor(EpubBlockType.paragraph, quoteDepth: quoteDepth) -
        epubListHangingIndent * (depth + 1);
  }

  /// How wide each table cell's text is: the column's share of the line, less
  /// the cell's own padding.
  List<double> tableColumnTextWidths(
    List<List<EpubTableCell>> rows, {
    int quoteDepth = 0,
  }) {
    final flex = epubTableColumnFlex(rows);
    if (flex.isEmpty) {
      return const <double>[];
    }
    final total = flex.fold<int>(0, (sum, share) => sum + share);
    final tableWidth = measureWidthFor(
      EpubBlockType.table,
      quoteDepth: quoteDepth,
    );
    final widths = <double>[];
    for (final share in flex) {
      final textWidth =
          tableWidth * share / total - epubTableCellPaddingHorizontal * 2;
      widths.add(textWidth < 24 ? 24 : textWidth);
    }
    return widths;
  }

  double chromeHeightFor(EpubBlockType type, {String? codeLanguage}) {
    return switch (type) {
      EpubBlockType.code =>
        epubCodeBlockPadding * 2 +
            (codeLanguage == null ? 0 : epubCodeLanguageHeight),
      EpubBlockType.math || EpubBlockType.diagram =>
        epubCodeBlockPadding * 2 + epubCodeLanguageHeight,
      EpubBlockType.image => 0.0,
      EpubBlockType.quote ||
      EpubBlockType.heading ||
      EpubBlockType.caption ||
      EpubBlockType.table ||
      EpubBlockType.divider ||
      EpubBlockType.paragraph => 0.0,
    };
  }

  double spacingFor(
    EpubBlockType type, {
    int? headingLevel,
    bool isList = false,
  }) {
    return epubBlockSpacing(
      type: type,
      paragraphSpacing: paragraphSpacing,
      headingLevel: headingLevel,
      isList: isList,
    );
  }

  /// How wide a picture is drawn.
  ///
  /// The column is the widest a picture goes. A picture that is narrower
  /// than the column in its own pixels keeps its size, so an icon stays
  /// an icon instead of being stretched into a mural.
  double imageWidthFor(EpubImage image, {int quoteDepth = 0}) {
    final column = measureWidthFor(EpubBlockType.image, quoteDepth: quoteDepth);
    if (image.pixelWidth <= 0) {
      return column;
    }
    // One point is one pixel here, so a picture's own width in pixels is
    // the width it would have at full size.
    return image.pixelWidth > column ? column : image.pixelWidth.toDouble();
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
    this.image,
    this.tableCells,
    this.tableHasHeader = false,
    this.tableAlignments = const <EpubTableAlignment>[],
    this.imageCaption,
    this.inlineRuns = const <EpubInlineRun>[],
    this.headingLevel,
    this.listMarker,
    this.listIndent = 0,
    this.quoteDepth = 0,
    this.hasListHangingIndent = false,
    this.taskChecked,
    this.codeLanguage,
    this.codeRuns = const <EpubCodeRun>[],
    this.mathSource,
    this.diagramSource,
  });

  final int chapterIndex;
  final String href;
  final int startOffset;
  final int endOffset;
  final String text;
  final EpubBlockType blockType;
  final bool isContinuation;

  /// The picture, when this fragment is one.
  final EpubImage? image;

  /// The rows this fragment draws, when it is part of a table.
  ///
  /// A table taller than a page is split between rows, and every fragment
  /// repeats the header, so [tableCells] is what this page shows rather than
  /// the whole table.
  final List<List<EpubTableCell>>? tableCells;

  /// The cell text this fragment draws, without styling metadata.
  List<List<String>>? get tableRows => tableCells == null
      ? null
      : <List<String>>[
          for (final row in tableCells!)
            List<String>.unmodifiable(<String>[
              for (final cell in row) cell.text,
            ]),
        ];

  /// Whether the first row of [tableCells] is a header.
  final bool tableHasHeader;

  /// The alignment each table column asks for.
  final List<EpubTableAlignment> tableAlignments;

  /// A visual caption under a picture; it takes no chapter characters.
  final String? imageCaption;

  /// The styled stretches of [text], in chapter offsets.
  final List<EpubInlineRun> inlineRuns;

  /// The heading level this fragment was written at, 1 to 6.
  final int? headingLevel;

  /// The marker at the front of a list item, including its following space.
  final String? listMarker;

  /// How deep the item sits in nested lists.
  final int listIndent;

  /// How many blockquote levels enclose this fragment.
  final int quoteDepth;

  /// Whether lines after the first align under the item's content column.
  final bool hasListHangingIndent;

  /// Whether a task-list item is checked; null for other blocks.
  final bool? taskChecked;

  /// The language named by a fenced code block, if any.
  final String? codeLanguage;

  /// Syntax-colour runs in chapter character offsets.
  final List<EpubCodeRun> codeRuns;

  /// Local TeX source for a display math fragment.
  final String? mathSource;

  /// Raw Mermaid source for a diagram fragment.
  final String? diagramSource;
}

final class EpubBlock {
  const EpubBlock({
    required this.chapter,
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.type,
    this.image,
    this.tableCells,
    this.tableHasHeader = false,
    this.tableAlignments = const <EpubTableAlignment>[],
    this.imageCaption,
    this.inlineRuns = const <EpubInlineRun>[],
    this.headingLevel,
    this.listMarker,
    this.listIndent = 0,
    this.quoteDepth = 0,
    this.hasListHangingIndent = false,
    this.taskChecked,
    this.codeLanguage,
    this.codeRuns = const <EpubCodeRun>[],
    this.mathSource,
    this.diagramSource,
  });

  final EpubChapter chapter;
  final int startOffset;
  final int endOffset;
  final String text;
  final EpubBlockType type;

  /// The picture, when this block is one.
  final EpubImage? image;

  /// The cells, when this block is a table.
  final List<List<EpubTableCell>>? tableCells;

  /// The cell text, without styling metadata.
  List<List<String>>? get tableRows => tableCells == null
      ? null
      : <List<String>>[
          for (final row in tableCells!)
            List<String>.unmodifiable(<String>[
              for (final cell in row) cell.text,
            ]),
        ];

  /// Whether the first row of [tableCells] is a header.
  final bool tableHasHeader;

  /// The alignment each table column asks for.
  final List<EpubTableAlignment> tableAlignments;

  /// A visual caption under a picture; it takes no chapter characters.
  final String? imageCaption;

  /// The styled stretches of [text], in chapter offsets.
  final List<EpubInlineRun> inlineRuns;

  /// The heading level this block was written at, 1 to 6.
  final int? headingLevel;

  /// The marker at the front of a list item, including its following space.
  final String? listMarker;

  /// How deep the item sits in nested lists.
  final int listIndent;

  /// How many blockquote levels enclose this block.
  final int quoteDepth;

  /// Whether lines after the first align under the item's content column.
  final bool hasListHangingIndent;

  /// Whether a task-list item is checked; null for other blocks.
  final bool? taskChecked;

  /// The language named by a fenced code block, if any.
  final String? codeLanguage;

  /// Syntax-colour runs for a fenced code block.
  final List<EpubCodeRun> codeRuns;

  /// Local TeX source for a display math block.
  final String? mathSource;

  /// Raw Mermaid source for a diagram block.
  final String? diagramSource;
}

final class _MeasuredFragment {
  const _MeasuredFragment({required this.fragment, required this.height});

  final EpubPageFragment fragment;
  final double height;
}

/// The blocks of a chapter, in the order they are read.
///
/// A chapter parsed from markup already knows its blocks, including where
/// its pictures sit. A chapter that was not parsed — one built by hand in
/// a test, say — has only text, and its blocks are found by splitting the
/// text on blank lines.
List<EpubBlock> epubBlocks(EpubChapter chapter) {
  if (chapter.blocks.isNotEmpty) {
    return [
      for (final block in chapter.blocks)
        if (block is EpubTextBlock)
          EpubBlock(
            chapter: chapter,
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            text: block.text,
            type: block.type,
            inlineRuns: block.runs,
            headingLevel: block.headingLevel,
            listMarker: block.listMarker,
            listIndent: block.listIndent,
            quoteDepth: block.quoteDepth,
            hasListHangingIndent: block.listMarker != null,
            taskChecked: block.taskChecked,
            codeLanguage: block.codeLanguage,
            codeRuns: block.codeRuns,
            mathSource: block.mathSource,
            diagramSource: block.diagramSource,
          )
        else if (block is EpubDividerBlock)
          EpubBlock(
            chapter: chapter,
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            text: '',
            type: EpubBlockType.divider,
            quoteDepth: block.quoteDepth,
          )
        else if (block is EpubTableBlock)
          EpubBlock(
            chapter: chapter,
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            text: block.text,
            type: EpubBlockType.table,
            tableCells: block.cells,
            tableHasHeader: block.hasHeader,
            tableAlignments: block.alignments,
            quoteDepth: block.quoteDepth,
          )
        else if (block is EpubImageBlock)
          EpubBlock(
            chapter: chapter,
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            text: '',
            type: EpubBlockType.image,
            image: block.image,
            imageCaption: _imageCaption(block.image),
            quoteDepth: block.quoteDepth,
          ),
    ];
  }
  return _blocksFromText(chapter);
}

List<EpubBlock> _blocksFromText(EpubChapter chapter) {
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
