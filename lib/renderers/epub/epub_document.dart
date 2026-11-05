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
enum EpubBlockType { paragraph, heading, code, caption, image, quote }

/// One piece of a chapter's flow.
sealed class EpubBlock {
  const EpubBlock();

  int get startOffset;
  int get endOffset;
}

/// A run of text.
final class EpubTextBlock extends EpubBlock {
  const EpubTextBlock({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.type,
  });

  @override
  final int startOffset;
  @override
  final int endOffset;
  final String text;
  final EpubBlockType type;
}

/// A picture.
///
/// It occupies no characters: [startOffset] and [endOffset] are the same
/// number, and that number is where the picture sits in the text flow.
final class EpubImageBlock extends EpubBlock {
  const EpubImageBlock({required this.startOffset, required this.image});

  @override
  final int startOffset;
  @override
  int get endOffset => startOffset;

  final EpubImage image;
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
  });

  /// Where the picture came from inside the book, for the record.
  final String archivePath;

  /// The picture's bytes, or empty when it could not be loaded.
  final Uint8List bytes;

  final int pixelWidth;
  final int pixelHeight;

  /// The book's own description of the picture, for a reader who cannot
  /// see it and for a picture that failed to load.
  final String? alt;

  /// Why the picture is not there, when it is not there.
  final String? unavailableReason;

  bool get isAvailable => bytes.isNotEmpty;

  /// Width over height. A picture whose size could not be read falls back
  /// to a shape that at least looks like a picture rather than a stripe.
  double get aspectRatio {
    if (pixelWidth <= 0 || pixelHeight <= 0) {
      return 4 / 3;
    }
    return pixelWidth / pixelHeight;
  }
}
