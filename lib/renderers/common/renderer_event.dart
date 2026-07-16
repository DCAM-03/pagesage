import '../../domain/books/reading_position.dart';

sealed class RendererEvent {
  const RendererEvent();
}

final class RendererReady extends RendererEvent {
  const RendererReady();
}

final class RendererLocationChanged extends RendererEvent {
  const RendererLocationChanged({
    required this.locator,
    required this.progress,
    this.chapterTitle,
    this.pageNumber,
    this.totalPages,
  });

  final ReadingLocator locator;
  final double progress;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;
}

final class RendererTextSelected extends RendererEvent {
  const RendererTextSelected({
    required this.text,
    required this.locator,
    this.sourceRect,
    this.selectionRects = const [],
  });

  final String text;
  final ReadingLocator locator;
  final ReaderRect? sourceRect;
  final List<ReaderRect> selectionRects;
}

final class RendererSearchResult {
  const RendererSearchResult({
    required this.title,
    required this.snippet,
    required this.locator,
  });

  final String title;
  final String snippet;
  final ReadingLocator locator;
}

final class RendererSearchResults extends RendererEvent {
  const RendererSearchResults(this.results);

  final List<RendererSearchResult> results;
}

final class RendererOutlineItem {
  const RendererOutlineItem({
    required this.title,
    required this.page,
    this.level = 0,
  });

  final String title;
  final int page;
  final int level;
}

final class RendererOutlineChanged extends RendererEvent {
  const RendererOutlineChanged(this.items);

  final List<RendererOutlineItem> items;
}

final class RendererBookmarkRequested extends RendererEvent {
  const RendererBookmarkRequested(this.locator);

  final ReadingLocator locator;
}

final class RendererCapabilityChanged extends RendererEvent {
  const RendererCapabilityChanged({
    required this.textSelection,
    required this.search,
    this.reason,
  });

  final bool textSelection;
  final bool search;
  final String? reason;
}

final class RendererNotice extends RendererEvent {
  const RendererNotice(this.message);

  final String message;
}

final class RendererAnnotationSelected extends RendererEvent {
  const RendererAnnotationSelected(this.annotationId, {this.sourceRect});

  final String annotationId;
  final ReaderRect? sourceRect;
}

final class RendererFailed extends RendererEvent {
  const RendererFailed(this.message);

  final String message;
}
