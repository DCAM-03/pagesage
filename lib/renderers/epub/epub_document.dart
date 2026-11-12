import 'dart:typed_data';

final class EpubDocument {
  const EpubDocument({required this.chapters, this.toc = const []});

  final List<EpubChapter> chapters;
  final List<EpubTocItem> toc;

  int get totalTextLength {
    return chapters.fold<int>(
      0,
      (total, chapter) => total + chapter.text.length,
    );
  }

  EpubChapter chapterForProgress(double progress) {
    if (chapters.isEmpty) {
      throw StateError('EPUB has no readable chapters');
    }

    final target = (totalTextLength * progress.clamp(0, 1)).round();
    var offset = 0;
    for (final chapter in chapters) {
      offset += chapter.text.length;
      if (target < offset) {
        return chapter;
      }
    }
    return chapters.last;
  }

  double progressForChapterIndex(int chapterIndex) {
    return progressForChapter(chapterIndex: chapterIndex);
  }

  double progressForChapter({
    required int chapterIndex,
    int chapterOffset = 0,
  }) {
    if (chapters.isEmpty) {
      return 0;
    }
    final normalizedIndex = chapterIndex.clamp(0, chapters.length - 1);
    final total = totalTextLength;
    if (total <= 0) {
      return normalizedIndex / chapters.length;
    }
    var offset = 0;
    for (final chapter in chapters) {
      if (chapter.index == normalizedIndex) {
        final local = chapterOffset.clamp(0, chapter.text.length);
        return ((offset + local) / total).clamp(0, 1).toDouble();
      }
      if (chapter.index > normalizedIndex) {
        return (offset / total).clamp(0, 1).toDouble();
      }
      offset += chapter.text.length;
    }
    return 1;
  }
}

final class EpubTocItem {
  const EpubTocItem({
    required this.title,
    required this.href,
    this.chapterIndex,
    this.fragment,
    this.chapterOffset,
    this.children = const [],
  });

  final String title;
  final String href;
  final int? chapterIndex;
  final String? fragment;
  final int? chapterOffset;
  final List<EpubTocItem> children;
}

final class EpubChapter {
  const EpubChapter({
    required this.index,
    required this.href,
    required this.title,
    required this.text,
    this.blocks = const [],
    this.anchors = const {},
  });

  final int index;
  final String href;
  final String title;

  /// The chapter's text, and only its text.
  ///
  /// A picture takes no characters here: it sits in the flow between two
  /// runs of text, so every offset into this string still means what it
  /// meant before pictures existed. Search, progress and jump all work on
  /// this string, and none of them have to know a picture was there.
  final String text;

  /// The chapter's flow: text runs and pictures in document order.
  ///
  /// Empty for a chapter that was not parsed from markup — those fall back
  /// to splitting [text] into blocks.
  final List<EpubBlock> blocks;

  /// Character offset into [text] for each element that carries an id.
  ///
  /// A table of contents that points at `#s1` needs to land on that
  /// element, and the only honest way to know where it is is to have
  /// walked the markup and counted.
  final Map<String, int> anchors;
}

/// What a run of text in a chapter is.
enum EpubBlockType {
  paragraph,
  heading,
  code,
  caption,
  image,
  quote,
  table,
  divider,
  math,
  diagram,
}

/// How part of a text block is set.
///
/// The text stays the book's text, character for character; this says only
/// that some of it was written bold, italic, in code, struck through or as a
/// link. Keeping it beside the text rather than inside it is what lets the
/// same string serve search, progress and selection.
enum EpubInlineStyle {
  strong,
  emphasis,
  code,
  strike,
  link,
  footnote,
  math,
  underline,
  highlight,
  superscript,
  subscript,
}

/// What a run inside a fenced code block means, for the reader's quiet
/// syntax colours.
///
/// This is only a visual category. It travels beside the code's characters,
/// so search, selection, progress and page splitting still use one string.
enum EpubCodeTokenType { keyword, type, string, number, comment, literal }

/// A syntax-coloured stretch of a fenced code block.
///
/// It is kept apart from [EpubInlineRun] because keywords and strings are not
/// links, annotations or emphasis. Both still use chapter character offsets.
final class EpubCodeRun {
  const EpubCodeRun({
    required this.start,
    required this.end,
    required this.type,
  });

  final int start;
  final int end;
  final EpubCodeTokenType type;

  @override
  bool operator ==(Object other) {
    return other is EpubCodeRun &&
        other.start == start &&
        other.end == end &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(start, end, type);

  @override
  String toString() => 'EpubCodeRun($start-$end, ${type.name})';
}

/// A stretch of a text block set in [style].
///
/// Offsets are chapter offsets, the same space as [EpubBlock.startOffset], so
/// a fragment of a block can carry the runs that reach into it.
final class EpubInlineRun {
  const EpubInlineRun({
    required this.start,
    required this.end,
    required this.style,
    this.target,
    this.mathSource,
  });

  final int start;
  final int end;
  final EpubInlineStyle style;

  /// Where a link run points, when the document says so.
  ///
  /// It travels beside the words rather than replacing them, so a fragment
  /// split across pages still knows which of its words are clickable.
  final String? target;

  /// The TeX expression this run draws, when [style] is [EpubInlineStyle.math].
  ///
  /// Chapter text still holds the readable expression for search and selection;
  /// this source is only the renderer's local, non-executable input.
  final String? mathSource;

  @override
  bool operator ==(Object other) {
    return other is EpubInlineRun &&
        other.start == start &&
        other.end == end &&
        other.style == style &&
        other.target == target &&
        other.mathSource == mathSource;
  }

  @override
  int get hashCode => Object.hash(start, end, style, target, mathSource);

  @override
  String toString() => 'EpubInlineRun($start-$end, ${style.name}, $target)';
}

/// One piece of a chapter's flow.
sealed class EpubBlock {
  const EpubBlock();

  int get startOffset;
  int get endOffset;

  /// How many blockquote levels enclose this block.
  int get quoteDepth;
}

/// A run of text.
final class EpubTextBlock extends EpubBlock {
  const EpubTextBlock({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.type,
    this.runs = const <EpubInlineRun>[],
    this.headingLevel,
    this.listMarker,
    this.listIndent = 0,
    this.quoteDepth = 0,
    this.taskChecked,
    this.codeLanguage,
    this.codeRuns = const <EpubCodeRun>[],
    this.mathSource,
    this.diagramSource,
  });

  @override
  final int startOffset;
  @override
  final int endOffset;
  final String text;
  final EpubBlockType type;

  /// The styled stretches of [text], in chapter offsets.
  final List<EpubInlineRun> runs;

  /// 1 to 6 when this block is a heading, so it can be set at its level's
  /// size. A heading block without one is set like a book heading.
  final int? headingLevel;

  /// The marker at the front of a list item, including its following space.
  ///
  /// It remains part of [text] so selection, search and progress keep one
  /// coordinate system; the renderer uses this to hang the wrapped lines.
  final String? listMarker;

  /// How deep the item sits in nested lists.
  final int listIndent;

  /// How many blockquote levels enclose this block.
  ///
  /// It is presentation metadata: the quote markers take no chapter
  /// characters, so search, selection and saved offsets stay unchanged.
  @override
  final int quoteDepth;

  /// Whether a task-list item is checked.
  ///
  /// Null for every other kind of block. The checkbox glyph still sits at
  /// the front of [text], so search, progress and selection keep one
  /// coordinate system; this only tells the renderer to draw a real
  /// checkbox instead of the glyph.
  final bool? taskChecked;

  /// The language named after a fenced code fence, such as `dart`.
  ///
  /// It is a label for the code block, not part of [text]; keeping it out
  /// of the chapter text means search and selection never see the fence.
  final String? codeLanguage;

  /// Syntax-colour ranges over [text], in chapter offsets.
  ///
  /// They are presentation metadata: [text] and all existing locator offsets
  /// remain character-for-character identical to the source code.
  final List<EpubCodeRun> codeRuns;

  /// The TeX expression to draw when this is a display math block.
  final String? mathSource;

  /// Raw diagram source for the native renderer; chapter text stays intact.
  final String? diagramSource;
}

/// A table, kept as rows of cells.
///
/// Its words are part of the chapter's text, exactly like a paragraph's, so
/// search, progress and selection need to know nothing about tables. The
/// rows are what the renderer draws as a grid instead of as lines of pipes.
enum EpubTableAlignment { none, left, center, right }

/// One table cell's text and the styling inside it.
///
/// A cell is drawn on its own line of the grid, so its runs use offsets local
/// to [text] rather than chapter offsets. The cell's words are still a slice
/// of the chapter text, which keeps search and progress in one coordinate
/// system.
final class EpubTableCell {
  const EpubTableCell({
    required this.text,
    this.runs = const <EpubInlineRun>[],
    this.chapterOffset = -1,
  });

  final String text;
  final List<EpubInlineRun> runs;

  /// Where this cell's first character sits in the chapter text.
  ///
  /// It is -1 for cells assembled by callers that only need layout metadata.
  /// Parsed Markdown tables set it so search hits and annotations can map a
  /// cell-local selection back to the chapter's one coordinate system.
  final int chapterOffset;
}

final class EpubTableBlock extends EpubBlock {
  const EpubTableBlock({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.cells,
    this.hasHeader = false,
    this.alignments = const <EpubTableAlignment>[],
    this.quoteDepth = 0,
  });

  @override
  final int startOffset;
  @override
  final int endOffset;

  /// The cells laid out as text, one row per line, for search and progress.
  final String text;

  /// Every row padded to the same width; the first row is the header when
  /// [hasHeader] is true.
  final List<List<EpubTableCell>> cells;

  /// The cell text without styling, for callers that only need the words.
  List<List<String>> get rows => <List<String>>[
    for (final row in cells)
      List<String>.unmodifiable(<String>[for (final cell in row) cell.text]),
  ];

  final bool hasHeader;

  /// The alignment each column asks for, from its Markdown delimiter row.
  ///
  /// Missing entries mean the column has no explicit alignment.
  final List<EpubTableAlignment> alignments;

  @override
  final int quoteDepth;

  int get columnCount => cells.isEmpty ? 0 : cells.first.length;
}

/// A horizontal rule.
///
/// Like a picture it occupies no characters: its position is the number where
/// it sits between two runs of text.
final class EpubDividerBlock extends EpubBlock {
  const EpubDividerBlock({required this.startOffset, this.quoteDepth = 0});

  @override
  final int startOffset;
  @override
  int get endOffset => startOffset;

  @override
  final int quoteDepth;
}

/// A picture.
///
/// It occupies no characters: [startOffset] and [endOffset] are the same
/// number, and that number is where the picture sits in the text flow.
final class EpubImageBlock extends EpubBlock {
  const EpubImageBlock({
    required this.startOffset,
    required this.image,
    this.quoteDepth = 0,
  });

  @override
  final int startOffset;
  @override
  int get endOffset => startOffset;

  final EpubImage image;

  @override
  final int quoteDepth;
}

/// A picture from the book.
final class EpubImage {
  const EpubImage({
    required this.archivePath,
    required this.bytes,
    required this.pixelWidth,
    required this.pixelHeight,
    this.alt,
    this.unavailableReason,
    this.sourcePath,
  });

  /// Where the picture came from inside the book, for the record.
  final String archivePath;

  /// The picture's bytes, or empty when it could not be loaded — and always
  /// empty for a picture that lives in a file, which is described by
  /// [sourcePath] instead.
  ///
  /// A book of images that are read from disk is the difference between a
  /// folder of notes opening in a second and it exhausting memory: the bytes
  /// of every screenshot must not be sitting in the document.
  final Uint8List bytes;

  /// Where the picture's bytes are on disk, when they are not in [bytes].
  ///
  /// The reader loads the picture when it draws it, and the platform image
  /// cache decides what stays decoded.
  final String? sourcePath;

  final int pixelWidth;
  final int pixelHeight;

  /// The book's own description of the picture, for a reader who cannot
  /// see it and for a picture that failed to load.
  final String? alt;

  /// Why the picture is not there, when it is not there.
  final String? unavailableReason;

  bool get isAvailable => bytes.isNotEmpty || sourcePath != null;

  /// Width over height. A picture whose size could not be read falls back
  /// to a shape that at least looks like a picture rather than a stripe.
  double get aspectRatio {
    if (pixelWidth <= 0 || pixelHeight <= 0) {
      return 4 / 3;
    }
    return pixelWidth / pixelHeight;
  }
}
