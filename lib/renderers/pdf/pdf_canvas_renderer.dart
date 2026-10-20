import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

/// Renders a PDF page onto a Flutter [Canvas] with `pdf_graphics`.
///
/// Wraps `dart_pdf_editor`'s `CanvasPdfDevice`, so the page paints without any
/// WebView, WebKit, or WPE dependency — which is what makes the PDF reader work
/// on Linux (see `docs/10-pdf-renderer-migration.md`).
final class PdfCanvasRenderer {
  PdfCanvasRenderer(this._doc);

  final PdfDocument _doc;

  int get pageCount => _doc.pageCount;

  PdfPage pageAt(int index) => _doc.page(index);

  /// Renders [pageIndex] into a picture in page space.
  ///
  /// The picture is recorded at 1 unit = 1 PDF point in the page's *displayed*
  /// space (after /Rotate), and the caller scales it to the on-screen page
  /// box. Recording in point space rather than at a raster density means a
  /// zoom change only re-lays-out and re-paints — the vector picture replays
  /// sharp at every scale, and no page has to be re-rendered when the reader
  /// zooms.
  ///
  /// Rotation is applied by `PdfPageRenderer`'s own transform. Never apply
  /// /Rotate here as well: doing both turns 90° pages by 180°
  /// (`docs/11-pdf-canvas-implementation-plan.md` §4.1).
  Future<PdfRenderedPage> renderPage(int pageIndex) async {
    final page = _doc.page(pageIndex);
    // The renderer's default includes the page's own annotations. The canvas
    // host paints the reader's stored annotations itself, and S0 never drew
    // the document's, so keep the raster to the page content only.
    final picture = await PdfPageRenderer.renderPicture(
      page,
      annotations: false,
      // Null lets the library use the page's own /Rotate.
      rotation: null,
    );
    return PdfRenderedPage(
      picture: picture,
      displaySize: displaySizeOf(pageIndex),
    );
  }

  /// Text of [pageIndex] with geometry, for selection and search.
  ///
  /// Extraction runs the page content stream through the interpreter, so
  /// results are cached per page: the location reporter, the selection
  /// controller and search all ask for the same page within a few frames.
  PdfPageText textOf(int pageIndex) {
    final cached = _textCache.remove(pageIndex);
    if (cached != null) {
      // Re-insert so the map stays in least-recently-used order.
      _textCache[pageIndex] = cached;
      return cached;
    }
    final extracted = PdfTextExtractor.extract(_doc, pageIndex);
    _textCache[pageIndex] = extracted;
    while (_textCache.length > _textCachePages) {
      _textCache.remove(_textCache.keys.first);
    }
    return extracted;
  }

  static const _textCachePages = 8;
  final Map<int, PdfPageText> _textCache = <int, PdfPageText>{};

  /// Whether the document has an extractable text layer at all.
  ///
  /// Samples the first [maxSamplePages] pages, then one middle page, matching
  /// the WebView renderer's `detectDocumentTextLayer` (`bridge.js:2914`):
  /// scanning every page blocks the UI on large books, while front-matter-only
  /// scans would wrongly disable selection for the whole document.
  ///
  /// Text extraction is synchronous, so the probe yields between pages.
  Future<bool> hasTextLayerAsync({int maxSamplePages = 8}) async {
    final limit = math.min(pageCount, maxSamplePages);
    for (var page = 0; page < limit; page += 1) {
      if (_pageHasText(page)) return true;
      await Future<void>.delayed(Duration.zero);
    }
    if (pageCount > limit) {
      final middle = math.max(0, pageCount ~/ 2);
      if (_pageHasText(middle)) return true;
    }
    return false;
  }

  bool _pageHasText(int pageIndex) {
    try {
      return textOf(pageIndex).text.trim().isNotEmpty;
    } on Object {
      // A page that cannot be parsed says nothing about the document.
      return false;
    }
  }

  /// The page's rotation-aware display size, in PDF points.
  ///
  /// `PdfPageRenderer.pageSize` applies /Rotate, matching what
  /// `PdfPageGeometry` expects as its `viewSize` basis. Layout, selection and
  /// annotation projection must all start from this instead of `cropBox`.
  Size displaySizeOf(int pageIndex) =>
      PdfPageRenderer.pageSize(_doc.page(pageIndex));
}

/// A rendered page: the point-space picture plus the display size it covers.
final class PdfRenderedPage {
  const PdfRenderedPage({required this.picture, required this.displaySize});

  /// Page-space picture, one unit per PDF point, rotation already applied.
  final ui.Picture picture;

  /// Rotation-aware page size in PDF points; the picture spans exactly this.
  final Size displaySize;

  void dispose() => picture.dispose();
}
