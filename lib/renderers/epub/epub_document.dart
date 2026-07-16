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
  });

  final int index;
  final String href;
  final String title;
  final String text;
}
