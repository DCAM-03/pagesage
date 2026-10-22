import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../domain/books/reading_position.dart';
import 'pdf_image_detector.dart';

/// Renders a PDF page onto a Flutter [Canvas] with `pdf_graphics`.
///
/// Wraps `dart_pdf_editor`'s `CanvasPdfDevice`, so the page paints without any
/// WebView, WebKit, or WPE dependency — which is what makes the PDF reader work
/// on Linux (see `docs/10-pdf-renderer-migration.md`).
///
/// Page interpretation is the expensive half of a render (roughly a second on
/// a dense page of a large book). When the document's bytes are available it
/// runs on a `PdfRenderWorker` isolate and only the cheap command replay stays
/// on the UI thread; without bytes (unit tests, the contract probes) the
/// renderer falls back to interpreting in-process, which is pixel-identical
/// but blocks the frame.
final class PdfCanvasRenderer {
  PdfCanvasRenderer(this._doc, {Uint8List? sourceBytes})
    : _worker = sourceBytes == null ? null : _startWorker(sourceBytes);

  final PdfDocument _doc;

  /// Background interpreter, or null when the caller did not supply bytes.
  ///
  /// Owned here: the worker opens its own copy of the document, so it must be
  /// disposed with the renderer instead of leaking an isolate per open book.
  PdfRenderWorker? _worker;

  /// Per-page request generations, bumped when a page leaves the screen.
  ///
  /// A worker `record` that resolves to null is ambiguous: the page declined
  /// (inline images, an unsupported platform), no worker exists, or its queued
  /// request was cancelled. Only the first two may fall back to a local
  /// interpret — a cancelled request means nobody is looking at the page any
  /// more, and interpreting it on the UI thread would stall the frame for a
  /// picture that is thrown away. The generation tells the two apart.
  final Map<int, int> _renderGenerations = <int, int>{};

  /// Bytes each render lane may hold before the pool is narrowed.
  ///
  /// Each lane opens its own copy of the document, so the library default of
  /// three would hold three copies of a large book in memory. One lane already
  /// moves interpretation off the UI thread, which is the point here; the extra
  /// lanes only buy parallel prefetch on books small enough to afford them.
  static const _bytesPerLane = 96 << 20;

  static PdfRenderWorker _startWorker(Uint8List bytes) {
    final lanes =
        (bytes.isEmpty
                ? pdfRenderWorkerPoolSize
                : _bytesPerLane ~/ bytes.length)
            .clamp(1, pdfRenderWorkerPoolSize);
    // The cache above the pool is what makes a revisited page a replay instead
    // of a re-interpretation; without it scrolling back would pay the record
    // cost again.
    return PdfCachingRenderWorker(
      PdfPooledRenderWorker(bytes, lanes, copySource: false),
    );
  }

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
  /// Rotation is applied by the page transform inside the replay, exactly as
  /// `PdfPageRenderer.renderPicture` does it. Never apply /Rotate here as well:
  /// doing both turns 90° pages by 180°
  /// (`docs/11-pdf-canvas-implementation-plan.md` §4.1).
  ///
  /// Returns null when the page's record was cancelled because it left the
  /// screen; callers must not retry a null result, the page is going away.
  Future<PdfRenderedPage?> renderPage(int pageIndex, {int priority = 0}) async {
    if (_disposed) return null;
    final worker = _worker;
    if (worker != null && worker.isActive) {
      final generation = _renderGenerations[pageIndex] ?? 0;
      List<PdfRenderCommand>? commands;
      try {
        commands = await worker.record(
          pageIndex,
          // The canvas host paints the reader's stored annotations itself, and
          // S0 never drew the document's, so keep the picture to page content.
          annotations: false,
          priority: priority,
        );
      } on Object {
        // A worker that throws is a failed optimization, not a failed render:
        // fall through to the in-process path below.
        commands = null;
      }
      // A cancellation since dispatch means the page left the screen: its
      // record may resolve to null, and interpreting it here would stall the
      // frame for a picture nobody will paint. The same holds once the view is
      // closing — disposal resolves every pending record to null.
      if (_disposed || generation != (_renderGenerations[pageIndex] ?? 0)) {
        return null;
      }
      if (commands != null) {
        // The record parsed the page, so the worker's text cache already has
        // this page's text; warming the local copy is a cache hit there. It
        // runs at prefetch priority so the next page's render preempts it.
        _warmText(pageIndex, _prefetchPriority);
        final picture = await PdfPageRenderer.pictureFromCommands(
          _doc.page(pageIndex),
          commands,
          rotation: null,
        );
        return PdfRenderedPage(
          picture: picture,
          displaySize: displaySizeOf(pageIndex),
        );
      }
    }
    return _renderLocally(pageIndex);
  }

  /// Interprets and paints [pageIndex] on the calling isolate.
  Future<PdfRenderedPage> _renderLocally(int pageIndex) async {
    final page = _doc.page(pageIndex);
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

  /// Warms [pageIndex]'s command record without painting it.
  ///
  /// The worker's record cache turns the later paint into a replay, which is
  /// what keeps a fast scroll from queueing a full interpretation per page.
  /// Background priority keeps the page on screen ahead of the prefetch.
  void prefetch(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pageCount) return;
    final worker = _worker;
    if (worker == null || !worker.isActive) return;
    unawaited(
      worker
          .record(pageIndex, annotations: false, priority: _prefetchPriority)
          .then<void>((_) {}, onError: (Object _) {}),
    );
    _warmText(pageIndex, _prefetchPriority);
  }

  /// Extracts [pageIndex]'s text off the UI thread into the per-page cache.
  ///
  /// The location reporter asks for the current page's text on every scroll
  /// stop, and the worker's record already parsed those operations, so warming
  /// it here turns that call into a cache hit instead of a content walk. The
  /// extractor is a no-op for pages already cached.
  void _warmText(int pageIndex, int priority) {
    if (_textCache.containsKey(pageIndex)) return;
    final worker = _worker;
    if (worker == null || !worker.isActive) return;
    unawaited(
      worker.extractText(pageIndex, priority: priority).then<void>((text) {
        if (text == null) return;
        // A concurrent synchronous extraction may have won the race; keep it.
        _textCache.putIfAbsent(pageIndex, () => text);
        while (_textCache.length > _textCachePages) {
          _textCache.remove(_textCache.keys.first);
        }
      }, onError: (Object _) {}),
    );
  }

  /// Drops a queued prefetch for a page the reader has scrolled past.
  ///
  /// Only the background request is cancelled: a page that also has a visible
  /// render in flight must keep it, or the page on screen would paint nothing.
  void cancelPrefetch(int pageIndex) {
    _worker?.cancel(pageIndex, priority: _prefetchPriority);
  }

  static const _prefetchPriority = 1;

  /// Drops [pageIndex]'s queued record and abandons its in-flight result.
  ///
  /// Bumping the page's generation is what tells [renderPage] that a null
  /// record means "nobody is looking at this page any more", so it must not
  /// rescue the page with a blocking local interpret.
  void cancelPage(int pageIndex, {int priority = 0}) {
    _renderGenerations[pageIndex] = (_renderGenerations[pageIndex] ?? 0) + 1;
    _worker?.cancel(pageIndex, priority: priority);
  }

  /// Terminates the background interpreter.
  ///
  /// Must run when the view closes; otherwise every opened book leaves an
  /// isolate holding a full copy of the document alive for the app's lifetime.
  /// Pending records resolve to null, which [renderPage] turns into "abandon"
  /// rather than a local interpret.
  void dispose() {
    _disposed = true;
    _worker?.dispose();
    _worker = null;
  }

  bool _disposed = false;

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
    _storeText(pageIndex, extracted);
    return extracted;
  }

  /// Images on [pageIndex], in the annotation coordinate space.
  ///
  /// Cached per page like [textOf]: the host asks on every hit test while the
  /// reader drags a box, and parsing a graphics-rich page's content stream per
  /// pointer move would drop frames. An empty list is a real answer — the page
  /// draws no images, or its stream cannot be parsed — so it is cached too.
  List<PdfDetectedImage> imagesOnPage(int pageIndex) {
    final cached = _imageCache.remove(pageIndex);
    if (cached != null) {
      _imageCache[pageIndex] = cached;
      return cached;
    }
    final detected = pageIndex < 0 || pageIndex >= _doc.pageCount
        ? const <PdfDetectedImage>[]
        : PdfImageDetector.detect(_doc, pageIndex);
    _imageCache[pageIndex] = detected;
    while (_imageCache.length > _imageCachePages) {
      _imageCache.remove(_imageCache.keys.first);
    }
    return detected;
  }

  /// [textOf] without blocking the UI thread when a worker is available.
  ///
  /// Returns null only when the page has no extractable text and the worker
  /// could not produce one either; callers treat that as "no text layer".
  Future<PdfPageText?> textOfAsync(int pageIndex) async {
    final cached = _textCache.remove(pageIndex);
    if (cached != null) {
      _textCache[pageIndex] = cached;
      return cached;
    }
    final worker = _worker;
    if (worker != null && worker.isActive) {
      try {
        final extracted = await worker.extractText(pageIndex);
        if (extracted != null) {
          _storeText(pageIndex, extracted);
          return extracted;
        }
      } on Object {
        // Fall through to the in-process extraction below.
      }
    }
    return textOf(pageIndex);
  }

  /// The cached text of [pageIndex], or null when it has not been read yet.
  ///
  /// Lets hot paths (the location reporter's excerpt) use text that is already
  /// in hand without triggering an extraction on the calling thread.
  PdfPageText? cachedTextOf(int pageIndex) {
    final cached = _textCache.remove(pageIndex);
    if (cached == null) return null;
    _textCache[pageIndex] = cached;
    return cached;
  }

  void _storeText(int pageIndex, PdfPageText text) {
    _textCache[pageIndex] = text;
    while (_textCache.length > _textCachePages) {
      _textCache.remove(_textCache.keys.first);
    }
  }

  static const _textCachePages = 8;

  /// Image geometry is a few dozen doubles per page; caching a screenful costs
  /// nothing next to the text cache beside it.
  final Map<int, List<PdfDetectedImage>> _imageCache =
      <int, List<PdfDetectedImage>>{};
  static const _imageCachePages = 12;
  final Map<int, PdfPageText> _textCache = <int, PdfPageText>{};

  /// Whether the document has an extractable text layer at all.
  ///
  /// Samples the first [maxSamplePages] pages, then one middle page, matching
  /// the WebView renderer's `detectDocumentTextLayer` (`bridge.js:2914`):
  /// scanning every page blocks the UI on large books, while front-matter-only
  /// scans would wrongly disable selection for the whole document.
  ///
  /// Text extraction is synchronous in the fallback path, so the probe yields
  /// between pages; with a worker it runs off the UI thread entirely.
  Future<bool> hasTextLayerAsync({int maxSamplePages = 8}) async {
    final limit = math.min(pageCount, maxSamplePages);
    for (var page = 0; page < limit; page += 1) {
      if (await _pageHasText(page)) return true;
      if (_worker == null) await Future<void>.delayed(Duration.zero);
    }
    if (pageCount > limit) {
      final middle = math.max(0, pageCount ~/ 2);
      if (await _pageHasText(middle)) return true;
    }
    return false;
  }

  Future<bool> _pageHasText(int pageIndex) async {
    try {
      final text = await textOfAsync(pageIndex);
      return text != null && text.text.trim().isNotEmpty;
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

  /// Rasterises [pageIndex] into PNG bytes for OCR.
  ///
  /// Renders at [targetWidth] logical pixels regardless of the reader's zoom:
  /// OCR reads glyphs, so the image has to be big enough for the recogniser's
  /// own threshold rather than matching whatever is on screen. The page
  /// transform inside the replay already applies /Rotate, so the output has the
  /// same orientation as the reader's view and OCR geometry needs no extra
  /// correction.
  ///
  /// PNG rather than JPEG: the encoder is the only one available without a
  /// platform channel, and lossless output avoids feeding compression
  /// artefacts to a text recogniser.
  Future<Uint8List?> exportPageImage(
    int pageIndex, {
    double targetWidth = 1600,
  }) async {
    if (_disposed) return null;
    if (pageIndex < 0 || pageIndex >= pageCount) return null;
    final size = displaySizeOf(pageIndex);
    if (size.isEmpty) return null;
    final ratio = (targetWidth / size.width).clamp(0.5, 6.0).toDouble();
    ui.Image? image;
    try {
      final page = await renderPage(pageIndex);
      if (page == null) return null;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(ratio);
      canvas.drawPicture(page.picture);
      page.dispose();
      final picture = recorder.endRecording();
      image = await picture.toImage(
        (size.width * ratio).round(),
        (size.height * ratio).round(),
      );
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } on Object {
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// Crops part of a rendered page to a PNG.
  ///
  /// [rect] is a fraction of the displayed page box, the same basis image
  /// annotations store, so what was annotated is exactly what comes out.
  ///
  /// Cropping the page raster rather than decoding the image XObject keeps the
  /// result faithful for free: soft masks, CMYK colour spaces, inline images
  /// and images drawn by form XObjects all come out as the reader sees them.
  /// The cost is rendering the whole page for one picture, which is why the
  /// output is capped rather than exported at native resolution.
  ///
  /// Returns null when the page cannot be rendered or [rect] is empty.
  Future<Uint8List?> exportPageRegion(
    int pageIndex,
    ReaderRect rect, {
    int maxPixels = 4096,
  }) async {
    if (_disposed) return null;
    if (pageIndex < 0 || pageIndex >= pageCount) return null;
    final size = displaySizeOf(pageIndex);
    if (size.isEmpty || rect.width <= 0 || rect.height <= 0) return null;
    // Two source pixels per output pixel keeps the crop sharp when it is shown
    // next to the page, and the cap stops a whole-page selection of a large
    // page from allocating a giant raster.
    var ratio = 2.0;
    final regionWidth = rect.width * size.width;
    final regionHeight = rect.height * size.height;
    final widest = math.max(regionWidth, regionHeight);
    if (widest * ratio > maxPixels) {
      ratio = (maxPixels / widest).clamp(0.1, 2.0).toDouble();
    }
    final outWidth = (regionWidth * ratio).round();
    final outHeight = (regionHeight * ratio).round();
    if (outWidth <= 0 || outHeight <= 0) return null;

    ui.Image? image;
    try {
      final page = await renderPage(pageIndex);
      if (page == null) return null;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Move the crop to the origin, then scale in one step: the page draws at
      // 1 unit = 1 point, so this both selects the region and resamples it.
      canvas.translate(
        -rect.x * size.width * ratio,
        -rect.y * size.height * ratio,
      );
      canvas.scale(ratio);
      canvas.drawPicture(page.picture);
      page.dispose();
      final picture = recorder.endRecording();
      image = await picture.toImage(outWidth, outHeight);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } on Object {
      return null;
    } finally {
      image?.dispose();
    }
  }
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
