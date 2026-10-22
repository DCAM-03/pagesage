import '../../domain/annotations/image_anchor.dart';
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

/// An image the renderer found on a page, in display-box fractions.
///
/// Carries geometry only: the renderer never holds or writes annotations, and
/// the host is the one that decides what to do with a hit.
final class RendererDetectedImage {
  const RendererDetectedImage({
    required this.page,
    required this.ordinal,
    required this.rect,
    this.resourceName,
    this.pixelWidth,
    this.pixelHeight,
  });

  /// 1-based; null for a renderer whose images are not page-based (EPUB).
  final int? page;
  final int ordinal;
  final String? resourceName;
  final ReaderRect rect;
  final int? pixelWidth;
  final int? pixelHeight;
}

/// The images detected so far, replaced wholesale per page.
///
/// Not emitted today. Snapping happens inside the canvas view, where the
/// renderer is already in hand, so the host never needs the list to place a
/// box. The type stays because B2 needs captions and thumbnails on the host
/// side (Notebook's 图片 group), and that is exactly this payload.
final class RendererImagesDetected extends RendererEvent {
  const RendererImagesDetected({required this.page, required this.images});

  /// 1-based page the list covers.
  final int page;
  final List<RendererDetectedImage> images;
}

/// The reader drew a box over an image (or over an area it believes holds
/// one) and wants to annotate it.
///
/// [anchor] may carry no ordinal: when detection missed the image — form
/// XObjects are not listed by `PdfPageElements` — the box itself is all there
/// is, and it still has to work.
final class RendererImageAreaSelected extends RendererEvent {
  const RendererImageAreaSelected({
    required this.anchor,
    required this.sourceRect,
  });

  final ImageAnchor anchor;

  /// The box in window coordinates, for positioning the action menu next to
  /// what the reader just drew.
  final ReaderRect sourceRect;
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
