import 'dart:convert';

import 'book.dart';

enum ReadingLocatorType {
  epub('epub'),
  pdf('pdf'),

  /// A position in a reflowable text document that is not an EPUB.
  ///
  /// It carries the same fields as [epub] because the two are read the same
  /// way — by chapter and by character offset. It is a separate type so a
  /// stored locator still says which kind of book it came from.
  markdown('md');

  const ReadingLocatorType(this.value);

  final String value;

  static ReadingLocatorType? fromValue(String value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

final class ReadingLocator {
  const ReadingLocator({
    required this.type,
    this.cfi,
    this.href,
    this.chapterIndex,
    this.chapterOffset,
    this.chapterEndOffset,
    this.page,
    this.scrollOffset,
    this.pageOffsetFraction,
    this.zoom,
    this.progress = 0,
    this.excerpt,
    this.selectionRects = const [],
    this.folderFileLocal = false,
  });

  factory ReadingLocator.epub({
    String? cfi,
    String? href,
    int? chapterIndex,
    int? chapterOffset,
    int? chapterEndOffset,
    double progress = 0,
    String? excerpt,
    List<ReaderRect> selectionRects = const [],
  }) {
    return ReadingLocator(
      type: ReadingLocatorType.epub,
      cfi: cfi,
      href: href,
      chapterIndex: chapterIndex,
      chapterOffset: chapterOffset,
      chapterEndOffset: chapterEndOffset,
      progress: progress,
      excerpt: excerpt,
      selectionRects: selectionRects,
    );
  }

  factory ReadingLocator.markdown({
    String? href,
    int? chapterIndex,
    int? chapterOffset,
    int? chapterEndOffset,
    double progress = 0,
    String? excerpt,
    List<ReaderRect> selectionRects = const [],
    bool folderFileLocal = false,
  }) {
    return ReadingLocator(
      type: ReadingLocatorType.markdown,
      href: href,
      chapterIndex: chapterIndex,
      chapterOffset: chapterOffset,
      chapterEndOffset: chapterEndOffset,
      progress: progress,
      excerpt: excerpt,
      selectionRects: selectionRects,
      folderFileLocal: folderFileLocal,
    );
  }

  factory ReadingLocator.pdf({
    int page = 1,
    double scrollOffset = 0,
    double? pageOffsetFraction,
    double zoom = 1,
    double progress = 0,
    String? excerpt,
    List<ReaderRect> selectionRects = const [],
  }) {
    return ReadingLocator(
      type: ReadingLocatorType.pdf,
      page: page,
      scrollOffset: scrollOffset,
      pageOffsetFraction: pageOffsetFraction,
      zoom: zoom,
      progress: progress,
      excerpt: excerpt,
      selectionRects: selectionRects,
    );
  }

  factory ReadingLocator.fromJson(Map<String, Object?> json) {
    final type = ReadingLocatorType.fromValue(json['type'] as String? ?? '');
    final selectionRects = _rectsFromJson(json['selectionRects']);
    if (type == ReadingLocatorType.pdf) {
      return ReadingLocator.pdf(
        page: _asInt(json['page']) ?? 1,
        scrollOffset: _asDouble(json['scrollOffset']) ?? 0,
        pageOffsetFraction: _asDouble(json['pageOffsetFraction']),
        zoom: _asDouble(json['zoom']) ?? 1,
        progress: _asDouble(json['progress']) ?? 0,
        excerpt: json['excerpt'] as String?,
        selectionRects: selectionRects,
      );
    }

    if (type == ReadingLocatorType.markdown) {
      return ReadingLocator.markdown(
        href: json['href'] as String?,
        chapterIndex: _asInt(json['chapterIndex']),
        chapterOffset: _asInt(json['chapterOffset']),
        chapterEndOffset: _asInt(json['chapterEndOffset']),
        progress: _asDouble(json['progress']) ?? 0,
        excerpt: json['excerpt'] as String?,
        selectionRects: selectionRects,
        folderFileLocal: json['folderFileLocal'] == true,
      );
    }

    return ReadingLocator.epub(
      cfi: json['cfi'] as String?,
      href: json['href'] as String?,
      chapterIndex: _asInt(json['chapterIndex']),
      chapterOffset: _asInt(json['chapterOffset']),
      chapterEndOffset: _asInt(json['chapterEndOffset']),
      progress: _asDouble(json['progress']) ?? 0,
      excerpt: json['excerpt'] as String?,
      selectionRects: selectionRects,
    );
  }

  factory ReadingLocator.fromJsonText(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return ReadingLocator.fromJson(decoded.cast<String, Object?>());
      }
    } on Object {
      // Corrupt progress data should not prevent the book from opening.
    }
    return ReadingLocator.epub();
  }

  final ReadingLocatorType type;
  final String? cfi;
  final String? href;
  final int? chapterIndex;
  final int? chapterOffset;
  final int? chapterEndOffset;
  final int? page;
  final double? scrollOffset;

  /// Where in the page a target sits, 0..1 from its top edge.
  ///
  /// PDF outline destinations usually name a y coordinate inside the page
  /// (`/XYZ`, `/FitH`). `scrollOffset` cannot carry it: that is measured in
  /// logical pixels, which change with zoom and window size, while an outline
  /// is read once from the document. Keeping the position as a fraction of the
  /// page keeps a TOC jump on the heading at any scale, and leaves
  /// `scrollOffset` meaning what progress reporting writes into it.
  final double? pageOffsetFraction;
  final double? zoom;
  final double progress;
  final String? excerpt;
  final List<ReaderRect> selectionRects;

  /// Whether a Markdown locator's chapter index belongs to the file named by
  /// [href], rather than to a whole merged folder.
  ///
  /// P7 changed folder books from one flattened document to one open file at
  /// a time. The marker is what lets the reader tell a new file-local position
  /// from an old merged one without guessing.
  final bool folderFileLocal;

  Map<String, Object?> toJson() {
    return {
      'type': type.value,
      if (cfi != null) 'cfi': cfi,
      if (href != null) 'href': href,
      if (chapterIndex != null) 'chapterIndex': chapterIndex,
      if (chapterOffset != null) 'chapterOffset': chapterOffset,
      if (chapterEndOffset != null) 'chapterEndOffset': chapterEndOffset,
      if (page != null) 'page': page,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
      if (pageOffsetFraction != null) 'pageOffsetFraction': pageOffsetFraction,
      if (zoom != null) 'zoom': zoom,
      'progress': progress.clamp(0, 1),
      if (excerpt != null) 'excerpt': excerpt,
      if (folderFileLocal) 'folderFileLocal': true,
      if (selectionRects.isNotEmpty)
        'selectionRects': selectionRects
            .map((rect) => rect.toJson())
            .toList(growable: false),
    };
  }

  String toJsonText() => jsonEncode(toJson());

  bool matches(ReadingLocator other) {
    if (type != other.type) {
      return false;
    }
    return switch (type) {
      ReadingLocatorType.epub ||
      ReadingLocatorType.markdown => _matchesEpub(other),
      ReadingLocatorType.pdf => _matchesPdf(other),
    };
  }

  String get displayLabel {
    return switch (type) {
      ReadingLocatorType.pdf => '第 ${page ?? 1} 页',
      ReadingLocatorType.epub =>
        chapterIndex == null ? 'EPUB 位置' : '章节 ${chapterIndex! + 1}',
      ReadingLocatorType.markdown =>
        chapterIndex == null ? 'Markdown 位置' : '章节 ${chapterIndex! + 1}',
    };
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static List<ReaderRect> _rectsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    final rects = <ReaderRect>[];
    for (final item in value.whereType<Map>()) {
      try {
        rects.add(ReaderRect.fromJson(item.cast<String, Object?>()));
      } on Object {
        // Ignore malformed legacy or renderer-provided rects.
      }
    }
    return rects;
  }

  bool _matchesEpub(ReadingLocator other) {
    if (cfi != null && other.cfi != null) {
      return cfi == other.cfi;
    }
    if (href != null && other.href != null) {
      if (href != other.href || chapterIndex != other.chapterIndex) {
        return false;
      }
      return _chapterOffsetsMatch(other);
    }
    if (chapterIndex != null && other.chapterIndex != null) {
      if (chapterIndex != other.chapterIndex) {
        return false;
      }
      return _chapterOffsetsMatch(other);
    }
    return (progress - other.progress).abs() <= 0.001;
  }

  bool _chapterOffsetsMatch(ReadingLocator other) {
    final offset = chapterOffset;
    final otherOffset = other.chapterOffset;
    if (offset == null || otherOffset == null) {
      return true;
    }
    final end = chapterEndOffset ?? offset;
    final otherEnd = other.chapterEndOffset ?? otherOffset;
    return offset <= otherEnd && otherOffset <= end;
  }

  bool _matchesPdf(ReadingLocator other) {
    if ((page ?? 1) != (other.page ?? 1)) {
      return false;
    }
    final offset = scrollOffset;
    final otherOffset = other.scrollOffset;
    if (offset != null && otherOffset != null) {
      return (offset - otherOffset).abs() <= 24;
    }
    return true;
  }
}

final class ReaderRect {
  const ReaderRect({
    this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ReaderRect.fromJson(Map<String, Object?> json) {
    final x = ReadingLocator._asDouble(json['x']);
    final y = ReadingLocator._asDouble(json['y']);
    final width = ReadingLocator._asDouble(json['width']);
    final height = ReadingLocator._asDouble(json['height']);
    if (x == null || y == null || width == null || height == null) {
      throw const FormatException('Reader rect is invalid');
    }
    return ReaderRect(
      page: ReadingLocator._asInt(json['page']),
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  final int? page;
  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() {
    return {
      if (page != null) 'page': page,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

final class ReadingProgressSnapshot {
  const ReadingProgressSnapshot({
    required this.bookId,
    required this.locator,
    required this.progress,
    required this.updatedAt,
    this.chapterTitle,
    this.pageNumber,
  });

  final String bookId;
  final ReadingLocator locator;
  final double progress;
  final int updatedAt;
  final String? chapterTitle;
  final int? pageNumber;
}

final class LibraryBook {
  const LibraryBook({required this.book, this.progress});

  final Book book;
  final ReadingProgressSnapshot? progress;
}
