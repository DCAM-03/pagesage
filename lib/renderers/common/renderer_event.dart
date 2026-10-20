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
    this.offsetFraction,
  });

  final String title;
  final int page;
  final int level;

  /// Where in the page the heading sits, as 0..1 from the page's top edge.
  ///
  /// A PDF outline destination commonly names a y coordinate (`/XYZ`,
  /// `/FitH`); without it a chapter with several sections on one page always
  /// lands at the page top. Null for fits that name no position (`/Fit`).
  final double? offsetFraction;
}

final class RendererOutlineChanged extends RendererEvent {
  const RendererOutlineChanged(this.items);

  final List<RendererOutlineItem> items;
}

/// A `/URI` link in the document was clicked.
///
/// The renderer does not open anything itself: opening a browser is a visible
/// side effect on the user's machine, and the interaction spec requires the
/// user to confirm the address first. The host owns that dialog and the
/// launch; the destination is passed here.
final class RendererExternalLinkRequested extends RendererEvent {
  const RendererExternalLinkRequested(this.uri);

  final String uri;
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
    this.nativeTextLayer,
    this.ocrTextLayer,
  });

  final bool textSelection;
  final bool search;
  final String? reason;

  /// True when the PDF itself has extractable text (not OCR overlay).
  /// Null means the renderer did not report the field (legacy).
  final bool? nativeTextLayer;

  /// True when at least one OCR overlay is active in this viewer session.
  final bool? ocrTextLayer;
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
