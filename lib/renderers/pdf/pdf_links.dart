import 'package:pdf_document/pdf_document.dart';

/// A clickable `/Link` annotation on a page, with its target resolved.
///
/// The canvas renderer parsed no annotations from the document, so links in a
/// PDF were dead: a tap fell through to word selection. This collects them
/// once per page and separates the two cases the reader can act on — another
/// position in the same document, and an external URI — from the ones it
/// cannot (`/Launch`, `/GoToR`, JavaScript), which are dropped rather than
/// offered as a control that does nothing.
final class PdfDocumentLink {
  const PdfDocumentLink._({
    required this.rect,
    this.destinationPage,
    this.destinationTop,
    this.uri,
  });

  /// The link's rectangle in PDF user space (y up), as the document states it.
  final PdfRect rect;

  /// 1-based page for an in-document `/GoTo` link, or null.
  final int? destinationPage;

  /// The `/GoTo` destination's vertical position in user space, when given.
  final double? destinationTop;

  /// Absolute URI for a `/URI` link, or null.
  final String? uri;

  bool get isExternal => uri != null;

  /// Reads every actionable link on [page].
  ///
  /// A link's `/Rect` is in the page's own unscaled user space; the caller
  /// projects it with the same rotation-aware geometry the page paints with,
  /// so a link on a /Rotate 90 page still lines up with what the reader sees.
  static List<PdfDocumentLink> of(PdfPage page) {
    final targets = <PdfDocumentLink>[];
    for (final annotation in page.annotations) {
      if (annotation is! PdfLinkAnnotation) continue;
      final rect = annotation.rect;
      if (rect.width <= 0 || rect.height <= 0) continue;
      // /F bit 2 marks hidden, bit 6 no-view: neither is clickable on screen.
      if (annotation.flags & 0x2 != 0 || annotation.flags & 0x20 != 0) {
        continue;
      }
      switch (annotation.action) {
        case PdfGoToAction(:final destination):
          targets.add(
            PdfDocumentLink._(
              rect: rect,
              destinationPage: destination.pageIndex + 1,
              destinationTop: destination.top,
            ),
          );
        case PdfUriAction(:final uri):
          final scheme = _schemeOf(uri);
          // Only open what a browser, mail client or the OS can handle;
          // app-defined schemes from an untrusted PDF are not launched.
          if (!_allowedSchemes.contains(scheme)) continue;
          targets.add(PdfDocumentLink._(rect: rect, uri: uri));
        default:
          continue;
      }
    }
    return targets;
  }

  static String _schemeOf(String uri) {
    final colon = uri.indexOf(':');
    if (colon <= 0) return '';
    return uri.substring(0, colon).toLowerCase();
  }

  static const _allowedSchemes = {'http', 'https', 'mailto'};
}
