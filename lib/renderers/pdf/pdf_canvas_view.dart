import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../domain/annotations/annotation.dart';
import '../../domain/annotations/image_anchor.dart';
import '../../domain/books/book.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import '../../domain/ocr/ocr_models.dart';
import '../common/renderer_event.dart';
import '../../features/ocr/application/ocr_providers.dart';
import '../../domain/books/locator_excerpt.dart';
import 'pdf_annotation_colors.dart';
import 'pdf_annotation_lines.dart';
import 'pdf_image_detector.dart';
import 'pdf_canvas_renderer.dart';
import 'pdf_layout.dart';
import 'pdf_page_image_source.dart';
import 'pdf_links.dart';
import 'pdf_ocr_selection_controller.dart';
import 'pdf_outline.dart';
import 'pdf_page_tint.dart';
import 'pdf_selection.dart';
import 'pdf_selection_controller.dart';
import 'pdf_zoom.dart';

/// Reports a zoom the user performed inside the renderer.
///
/// The scale is in logical pixels per PDF point; [mode] tells the host whether
/// to persist it as a custom scale or as a named mode (fit-width after a
/// double-click).
typedef PdfZoomChanged = void Function(double scale, PdfZoomMode mode);

/// PDF renderer built on `pdf_graphics` painting straight to a Flutter Canvas.
///
/// S1 makes zoom a single resolved scale: the page slot, the picture transform
/// and `locator.zoom` all derive from [resolvePdfZoom], so a page is never
/// fitted twice and a rotated page is laid out at its rotated size.
///
/// S2 replaces the horizontal `PageView` with a continuous vertical list and
/// adds paged single/double display, both driven by the shared `readerMode`
/// setting through [preferredPdfDisplayMode]. Position reporting, restoring a
/// saved `scrollOffset` and spread pairing all go through [pdf_layout.dart].
final class PdfCanvasView extends ConsumerStatefulWidget {
  const PdfCanvasView({
    required this.book,
    required this.settings,
    required this.initialProgress,
    required this.onEvent,
    required this.annotations,
    this.ocrOverlayPage,
    this.ocrOverlayBlocks = const [],
    this.ocrOverlayToken = 0,
    this.searchQuery,
    this.focusLocator,
    this.jumpToken = 0,
    this.clearSearchHighlightsVersion = 0,
    this.clearSelectionVersion = 0,
    this.onZoomChanged,
    this.imageDragMode = false,
    this.onImageAreaSelected,
    super.key,
  });

  final Book book;
  final ReaderSettings settings;
  final ReadingProgressSnapshot? initialProgress;
  final ValueChanged<RendererEvent> onEvent;

  /// Stored highlights and notes to paint over the page.
  final List<Annotation> annotations;

  /// 1-based page carrying a recognised text layer (scanned PDFs).
  final int? ocrOverlayPage;
  final List<Map<String, Object?>> ocrOverlayBlocks;

  /// Bumped by the host when a new OCR overlay should be painted.
  final int ocrOverlayToken;
  final String? searchQuery;
  final ReadingLocator? focusLocator;

  /// Bumped by the host to jump to [focusLocator] without remounting.
  final int jumpToken;

  /// Bumped by the host to drop search highlights.
  final int clearSearchHighlightsVersion;

  /// Bumped by the host when the selection should go away.
  ///
  /// The host owns the action menu, so it is also the one that knows when the
  /// selection is finished with; without this the highlight and handles would
  /// stay painted after the menu closes.
  final int clearSelectionVersion;

  /// Pinch, Ctrl+wheel and double-click zoom. The host persists the result;
  /// the renderer keeps painting the transient scale until the new settings
  /// arrive, so the page never jumps back for a frame.
  final PdfZoomChanged? onZoomChanged;

  /// Whether a drag draws a box for an image annotation instead of selecting
  /// text. Turned on by the reader's toolbar; false by default so the existing
  /// text gesture is untouched.
  ///
  /// When it is on the page stops offering itself for text selection: the same
  /// drag cannot mean both, and a highlight left painted under the box would
  /// make the reader think both happened.
  final bool imageDragMode;

  /// A box was drawn over an image.
  final ValueChanged<RendererImageAreaSelected>? onImageAreaSelected;

  @override
  ConsumerState<PdfCanvasView> createState() => _PdfCanvasViewState();
}

final class _PdfCanvasViewState extends ConsumerState<PdfCanvasView> {
  /// Drives the continuous list.
  final _scrollController = ScrollController();

  /// Drives the horizontal paged layout. Rebuilt when the display mode or the
  /// page count changes, because `initialPage` is only honoured on creation.
  PageController? _pageController;

  Timer? _locationTimer;

  /// Whether the first frame has restored the saved scroll position.
  ///
  /// Restoring is a post-frame job: before the first layout there is no
  /// viewport to scroll, so a jump issued from `_open` would be dropped.
  bool _restored = false;

  PdfCanvasRenderer? _renderer;
  String? _error;
  int _currentPage = 0;
  bool _readySent = false;
  String _lastReportedSearchQuery = '';

  /// Page index -> quads in page space; each page widget converts these
  /// to widget coordinates using its own painted box.
  final Map<int, List<PdfTextQuad>> _searchHighlights = {};

  /// Page index -> the hit the reader just jumped to, as page-space quads.
  ///
  /// Painted in a stronger colour for a couple of seconds so choosing a search
  /// result shows *where* on the page the phrase sits. All hits stay in a
  /// faint tint, so the flash is a focus cue rather than the only highlight.
  final Map<int, List<PdfTextQuad>> _focusQuads = {};

  /// Image boxes to pulse after a jump, as display-box fractions.
  ///
  /// Kept apart from [_focusQuads]: those are point-space text quads run
  /// through `PdfPageGeometry`, while an image box is already in the space
  /// annotations use. Mixing them would project one of the two twice on a
  /// rotated page.
  final Map<int, List<ReaderRect>> _imageFocus = {};

  /// Whether the current search was triggered from the reader, which decides
  /// whether a hit may scroll the page into view.
  Timer? _focusClearTimer;

  /// Layout scale of the current page, in logical pixels per PDF point.
  ///
  /// The page widget reports the scale it actually laid out at; `locator.zoom`
  /// must carry this value (what the WebView renderer exposed as
  /// `dataset.scale`), not the raw `pdfScale` setting.
  double _layoutScale = 1;

  /// How far into the current page the reader is, as a fraction of that
  /// page's height (continuous display only).
  ///
  /// A zoom or a window resize changes every page's height in the list, so
  /// holding the raw scroll position would slide the reader through the
  /// document. Re-anchoring on this ratio keeps the same line under the same
  /// place on screen, which is what plan step 3 asks for.
  double? _anchorRatio;

  /// Result of the text-layer probe, or null while it is still running.
  bool? _nativeTextLayer;
  final FocusNode _readerFocusNode = FocusNode(debugLabel: 'PDF reader');

  final Map<int, List<OcrTextBlock>> _ocrBlocksByPage = {};
  final Map<int, PdfOcrTextLayout> _ocrLayoutsByPage = {};

  void _cacheOcrOverlay() {
    final page = widget.ocrOverlayPage;
    if (page == null || page < 1) return;
    final blocks = parseOcrOverlayBlocks(widget.ocrOverlayBlocks);
    if (blocks.isEmpty) {
      _ocrBlocksByPage.remove(page);
      _ocrLayoutsByPage.remove(page);
      return;
    }
    _ocrBlocksByPage[page] = blocks;
    _ocrLayoutsByPage[page] = PdfOcrTextLayout.fromBlocks(blocks);
  }

  List<OcrTextBlock> _ocrBlocksForPage(int pageIndex) {
    return _ocrBlocksByPage[pageIndex + 1] ?? const [];
  }

  PdfOcrTextLayout? _ocrLayoutForPage(int pageIndex) {
    return _ocrLayoutsByPage[pageIndex + 1];
  }

  /// Exposes the renderer to the reader's OCR path.
  ///
  /// Resolved lazily per call rather than captured, so a renderer replaced on
  /// reopen exports from the document that is actually open.
  late final _imageSource = _CanvasPageImageSource(this);

  /// Whether the user has zoomed in this session.
  ///
  /// The bridge coerced a saved custom scale to fit-width when a document
  /// opened on a phone; without this flag that coercion would also undo the
  /// user's own pinch on the next rebuild.
  bool _userAdjustedScale = false;

  /// The live text selection, as two carets in extracted-text coordinates.
  ///
  /// S3 moved this out of the page widgets: a drag may start on one page and
  /// end on another, and only the view knows every page's caret geometry.
  /// Pages ask for their own slice with [_rangeForPage] and paint it.
  PdfCaret? _selectionAnchor;
  PdfCaret? _selectionFocus;

  /// True while a pointer is down and extending the selection.
  bool _selectionDragging = false;

  /// The last selection handed to the host, so a rebuild does not re-emit a
  /// menu for the same selection.
  String? _emittedSelectionKey;

  final Map<int, GlobalKey> _pageKeys = {};

  Map<int, Rect> get _pageGlobalRects {
    final rects = <int, Rect>{};
    for (final entry in _pageKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      rects[entry.key] = box.localToGlobal(Offset.zero) & box.size;
    }
    return rects;
  }

  /// The current selection as per-page ranges, keyed by page index.
  Map<int, ({int start, int end})> get _selectionRanges {
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (anchor == null || focus == null) return const {};
    final out = <int, ({int start, int end})>{};
    for (final segment in pdfSelectionSegments(
      anchor: anchor,
      focus: focus,
      textLengthOf: _textLengthForPage,
    )) {
      out[segment.page] = (start: segment.start, end: segment.end);
    }
    return out;
  }

  int _textLengthForPage(int pageIndex) {
    final ocr = _ocrLayoutForPage(pageIndex);
    if (ocr != null && !ocr.isEmpty) return ocr.text.length;
    return _renderer?.textOf(pageIndex).text.length ?? 0;
  }

  ({int start, int end})? _rangeForPage(int pageIndex) =>
      _selectionRanges[pageIndex];

  @override
  void initState() {
    super.initState();
    _cacheOcrOverlay();
    unawaited(_open());
  }

  @override
  void didUpdateWidget(covariant PdfCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      unawaited(_runSearch());
    }
    if (oldWidget.clearSearchHighlightsVersion !=
        widget.clearSearchHighlightsVersion) {
      setState(() => _searchHighlights.clear());
    }
    if (oldWidget.clearSelectionVersion != widget.clearSelectionVersion) {
      _clearSelection();
    }
    if (oldWidget.imageDragMode != widget.imageDragMode) {
      // Entering the mode with a text selection still painted would leave a
      // highlight under the box the reader is about to draw, and the next tap
      // would hit that highlight instead of starting a box.
      _clearSelection();
    }
    // The host puts the jump target in `initialProgress`: `_jumpProgress`
    // carries the enriched locator, while `focusLocator` is only set when the
    // target can be flashed. Reading focusLocator dropped every page-number
    // and outline jump that had no excerpt.
    if (oldWidget.jumpToken != widget.jumpToken) {
      unawaited(_jumpToLocator(widget.initialProgress?.locator));
    }
    if (oldWidget.ocrOverlayToken != widget.ocrOverlayToken ||
        oldWidget.ocrOverlayPage != widget.ocrOverlayPage) {
      _cacheOcrOverlay();
      // Carets index the previous overlay's text; a new recognition result
      // makes them meaningless.
      _clearSelection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emitCapabilities();
      });
    }
  }

  /// The OCR provider's notifier, captured while the widget is alive.
  ///
  /// Riverpod refuses `ref` inside `dispose` — the element is already
  /// deactivated and reading a provider there throws. Registration has to be
  /// undone, or the reader keeps a dangling source for a closed book, so the
  /// notifier is held from `_open` instead.
  StateController<PdfPageImageSource?>? _imageSourceNotifier;

  @override
  void dispose() {
    _readerFocusNode.dispose();
    _focusClearTimer?.cancel();
    final notifier = _imageSourceNotifier;
    if (notifier != null && identical(notifier.state, _imageSource)) {
      notifier.state = null;
    }
    _locationTimer?.cancel();
    _scrollController.dispose();
    _pageController?.dispose();
    // The renderer owns the background interpreter; leaving it alive would
    // keep an isolate and a full copy of the document per opened book.
    _renderer?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final file = File(widget.book.libraryFilePath);
      if (!file.existsSync()) {
        throw StateError('文件不存在: ${widget.book.libraryFilePath}');
      }
      final bytes = await file.readAsBytes();
      final doc = PdfDocument.open(bytes);
      if (!mounted) return;

      // Hand the worker the same bytes the document was opened from, so page
      // interpretation can run off the UI thread. The buffer is transferred
      // into the isolate, which keeps its own copy.
      final renderer = PdfCanvasRenderer(doc, sourceBytes: bytes);
      // Assign before setState: _runSearch reads _renderer synchronously, and
      // setState does not run its body synchronously, so assigning inside it
      // would make the first search see a null renderer and bail out.
      _renderer = renderer;
      setState(() {
        _currentPage = _initialPage(doc.pageCount);
        _error = null;
        _readySent = true;
      });

      // Capability first: the host enables selection/search UI from this, so a
      // silent selection path would leave the reader offering dead buttons.
      // Assume text until the probe finishes, so a document that does have a
      // text layer never flickers its controls off and on.
      widget.onEvent(
        const RendererCapabilityChanged(textSelection: true, search: true),
      );
      widget.onEvent(RendererReady());
      _reportLocation(doc.pageCount);
      _emitOutline(doc);
      // Register for display-space export so "识别本页" works here too; the
      // reader only ever holds this through the renderer-agnostic interface.
      ref.read(activePdfRendererControllerProvider.notifier).state =
          _imageSource;
      unawaited(_detectCapabilities(renderer));

      // The scroll surface only exists once the build above has run, so a
      // jump issued here has no clients and is silently dropped. Restore on
      // the first frame instead; without it the reader opens on page 1 while
      // reporting the saved page, and the first scroll rewrites progress to
      // page 2.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restoreSavedPosition();
      });
      unawaited(_runSearch());
    } on Object catch (error) {
      if (!mounted) return;
      final message = _openErrorMessage(error);
      setState(() => _error = message);
      // The host owns retry and error details; a local string alone leaves the
      // reader with a dead page and no recovery path.
      widget.onEvent(RendererFailed(message));
    }
  }

  /// Reads the document's `/Outlines` and hands the reader a flat list.
  ///
  /// Emitted once per open: the tree is a document property, and re-reading it
  /// on every rebuild would re-resolve the whole COS tree for nothing. An
  /// empty list is still reported so a host that kept a previous document's
  /// outline clears it.
  void _emitOutline(PdfDocument doc) {
    List<RendererOutlineItem> items;
    try {
      final outline = PdfOutline.of(doc);
      final entries = pdfOutlineEntries(
        outline,
        pageHeight: (page) {
          if (page < 1 || page > doc.pageCount) return 0;
          return PdfPageRenderer.pageSize(doc.page(page - 1)).height;
        },
      );
      items = [for (final entry in entries) entry.toRendererItem()];
    } on Object {
      // A malformed outline must not stop the book from opening; the host
      // falls back to its page-number list when the outline is empty.
      items = const [];
    }
    widget.onEvent(RendererOutlineChanged(items));
  }

  /// Probes the text layer, then reports what the renderer can actually do.
  Future<void> _detectCapabilities(PdfCanvasRenderer renderer) async {
    final hasText = await renderer.hasTextLayerAsync();
    if (!mounted) return;
    _nativeTextLayer = hasText;
    _emitCapabilities();
  }

  void _emitCapabilities() {
    final native = _nativeTextLayer;
    if (native == null) return;
    final hasOcr = _ocrLayoutsByPage.isNotEmpty;
    final canSelect = native || hasOcr;
    final reason = canSelect ? null : '此 PDF 没有原生文本层，可使用「识别文字」提取文字后划词，并加入搜索。';
    widget.onEvent(
      RendererCapabilityChanged(
        // OCR search uses the stored-text index outside this native viewer.
        textSelection: canSelect,
        search: native,
        nativeTextLayer: native,
        ocrTextLayer: hasOcr,
        reason: reason,
      ),
    );
  }

  String _openErrorMessage(Object error) {
    return switch (error) {
      CosPasswordException() => '此 PDF 需要密码（当前版本不支持输入密码）',
      UnsupportedEncryptionException() => '此 PDF 使用了不支持的加密方式',
      CosParseException() => '文件可能已损坏',
      StateError(:final message) => message,
      _ => '无法打开 PDF: $error',
    };
  }

  int _initialPage(int pageCount) {
    final saved = widget.initialProgress?.locator.page;
    if (saved == null || saved < 1 || saved > pageCount) return 0;
    return saved - 1;
  }

  void _reportLocation(int pageCount) {
    if (pageCount <= 0) return;
    // A jump can finish after the reader closed (the scroll animation outlives
    // the widget); reading MediaQuery from a defunct context throws.
    if (!mounted) return;
    // The WebView renderer skipped excerpts on phones: scanning the text layer
    // is a layout-heavy pass and the excerpt is only used to flash a phrase
    // after a jump. Capture the width now; reading MediaQuery from the timer
    // would register an inherited-widget dependency outside build.
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final includeExcerpt = viewportWidth >= pdfNarrowViewportWidth;
    // The bridge throttles phone scroll reporting at 420 ms and desktop at
    // 120 ms (`bridge.js:296`); continuous scrolling fires far more often than
    // page turns, and every report writes progress.
    final delay = Duration(
      milliseconds: viewportWidth < pdfNarrowViewportWidth ? 420 : 120,
    );

    _locationTimer?.cancel();
    _locationTimer = Timer(delay, () {
      if (!mounted) return;
      // Resolve the page and offset when the timer fires, not when it was
      // scheduled: a burst of scroll events must report where the reader
      // ended up, and the state may have advanced since.
      final page = _currentPage + 1;
      final progress = pageCount <= 1 ? 1.0 : (page - 1) / (pageCount - 1);
      final offset = _scrollOffsetForCurrentPage();
      final pageOffsetFraction = _pageOffsetFractionForCurrentPage();

      void emit(String? excerpt) {
        if (!mounted) return;
        // An async excerpt can land after the reader scrolled on. A newer
        // report is already queued for that position; emitting this older one
        // would write a stale page back into progress.
        if (_currentPage + 1 != page) return;
        widget.onEvent(
          RendererLocationChanged(
            locator: ReadingLocator.pdf(
              page: page,
              // Zero outside continuous display, matching the bridge: a paged
              // layout has no meaningful sub-page position to restore into.
              scrollOffset: offset,
              pageOffsetFraction: pageOffsetFraction,
              zoom: _layoutScale,
              progress: progress.clamp(0.0, 1.0),
              excerpt: excerpt,
            ),
            progress: progress.clamp(0.0, 1.0),
            pageNumber: page,
            totalPages: pageCount,
          ),
        );
      }

      if (!includeExcerpt) {
        emit(null);
        return;
      }
      // The excerpt is cosmetic (it lights up the phrase after a jump), while
      // extracting it is a full content walk. Use the cached text when the
      // page has already been read, and otherwise defer the report by one
      // worker extraction instead of stalling the scroll on the UI thread.
      final renderer = _renderer;
      if (renderer == null) {
        emit(null);
        return;
      }
      final cached = renderer.cachedTextOf(_currentPage);
      if (cached != null) {
        emit(_excerptOf(cached.text));
        return;
      }
      unawaited(
        renderer
            .textOfAsync(_currentPage)
            .then((text) => _excerptOf(text?.text))
            .catchError((Object _) => null)
            .then(emit, onError: (Object _) => emit(null)),
      );
    });
  }

  String? _excerptOf(String? text) {
    if (text == null) return null;
    try {
      return compactLocatorExcerpt(text, maxChars: 120);
    } on Object {
      return null;
    }
  }

  /// Upper bound on reported hits.
  ///
  /// Rendered a page at a time into the highlight map, so the ceiling protects
  /// a scan of a large book rather than the list itself; 200 matches the plan
  /// and is well past what the reader can pick from a side panel.
  static const _maxSearchResults = 200;

  Future<void> _runSearch() async {
    final renderer = _renderer;
    final query = widget.searchQuery?.trim() ?? '';
    if (renderer == null || query == _lastReportedSearchQuery) return;
    _lastReportedSearchQuery = query;

    if (query.isEmpty) {
      setState(() => _searchHighlights.clear());
      widget.onEvent(const RendererSearchResults([]));
      return;
    }

    final results = <RendererSearchResult>[];
    final highlights = <int, List<PdfTextQuad>>{};

    for (var page = 0; page < renderer.pageCount; page++) {
      if (results.length >= _maxSearchResults) break;
      // A newer query, or leaving the reader, abandons this walk: a long book
      // would otherwise keep extracting pages for a search nobody wants.
      if (!mounted || widget.searchQuery?.trim() != query) return;

      final PdfPageText? pageText;
      try {
        // Off the UI thread when the render worker is available; the fallback
        // extracts in-process, so this stays correct without a worker.
        pageText = await renderer.textOfAsync(page);
      } on Object {
        continue; // A page that cannot be parsed should not abort the search.
      }
      if (pageText == null || pageText.text.isEmpty) continue;

      for (final match in pageText.findAll(query)) {
        if (results.length >= _maxSearchResults) break;
        final start = match.start.clamp(0, pageText.text.length);
        final end = match.end.clamp(start, pageText.text.length);
        final snippet = compactLocatorExcerpt(
          pageText.text.substring(start, end),
          maxChars: 120,
        );
        results.add(
          RendererSearchResult(
            title: '第 ${page + 1} 页',
            snippet: snippet ?? query,
            locator: ReadingLocator.pdf(
              page: page + 1,
              // Search results are rendered at whatever scale the reader has
              // when the user opens them, so record the current layout scale.
              zoom: _layoutScale,
              progress: renderer.pageCount <= 1
                  ? 0
                  : page / (renderer.pageCount - 1),
              excerpt: snippet,
            ),
          ),
        );
        highlights.putIfAbsent(page, () => <PdfTextQuad>[]).addAll(match.quads);
      }
    }

    if (!mounted) return;
    setState(() {
      _searchHighlights
        ..clear()
        ..addAll(highlights);
    });
    widget.onEvent(RendererSearchResults(results));
  }

  Future<void> _jumpToLocator(ReadingLocator? locator) async {
    final renderer = _renderer;
    if (renderer == null || locator == null) return;
    final page = locator.page;
    if (page == null || page < 1 || page > renderer.pageCount) return;

    // An outline destination names a fraction of the page, which survives a
    // zoom; a search hit carries pixels for the scale in force when the search
    // ran. Prefer the fraction, then the pixel offset.
    final fraction = locator.pageOffsetFraction;
    final offset = fraction == null
        ? (locator.scrollOffset ?? 0)
        : fraction * renderer.displaySizeOf(page - 1).height * _layoutScale;

    await _scrollToPage(page - 1, offset: offset, animate: true);
    if (mounted) setState(() => _currentPage = page - 1);
    _reportLocation(renderer.pageCount);
    unawaited(_flashFocusHit(page - 1, locator.excerpt));
  }

  /// Lights up the phrase a jump aimed at, then fades it.
  ///
  /// The host sets `excerpt` whenever the target can be described by text — a
  /// search hit, a saved note, a TOC entry that quotes its heading. Locating
  /// the phrase gives the reader the same cue the WebView got from its
  /// `focusHit` spans: the page scrolls to the result, and the words inside it
  /// are marked for a moment instead of leaving the reader to scan the page.
  Future<void> _flashFocusHit(int pageIndex, String? excerpt) async {
    final renderer = _renderer;
    if (renderer == null) return;
    // An image annotation has no words to find. It carries its own box in the
    // locator's `selectionRects` instead, so jump-back lights up the frame
    // rather than dropping the reader on a page to hunt for it.
    final boxes = _imageFocusFractions(pageIndex);
    if (boxes.isNotEmpty) {
      _focusClearTimer?.cancel();
      if (!mounted) return;
      setState(() => _imageFocus[pageIndex] = boxes);
      _focusClearTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) _clearFocusHit();
      });
      return;
    }
    final needle = excerpt?.trim();
    if (needle == null || needle.isEmpty) {
      _clearFocusHit();
      return;
    }
    // The excerpt is a compacted snippet: repeated whitespace in the page text
    // is what most often stops a literal match, so search for the longest
    // whitespace-free prefix too.
    final probe = needle.length > 48 ? needle.substring(0, 48) : needle;
    List<PdfTextQuad> quads;
    try {
      final text = await renderer.textOfAsync(pageIndex);
      if (text == null || text.text.isEmpty) return;
      var matches = text.findAll(probe);
      if (matches.isEmpty) {
        final compact = probe.split(RegExp(r'\s+')).first;
        if (compact.length >= 2) matches = text.findAll(compact);
      }
      if (matches.isEmpty) {
        _clearFocusHit();
        return;
      }
      quads = [for (final match in matches.take(4)) ...match.quads];
    } on Object {
      return; // Best-effort: a flash must never break navigation.
    }
    if (!mounted) return;
    _focusClearTimer?.cancel();
    setState(() => _focusQuads[pageIndex] = quads);
    _focusClearTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) _clearFocusHit();
    });
  }

  /// The stored box of a jumped-to image annotation, if this jump has one.
  ///
  /// Fractions of the displayed page box, so they are painted directly. Only a
  /// locator pointing at [pageIndex] qualifies; a rect stored for another page
  /// would light up the wrong place.
  List<ReaderRect> _imageFocusFractions(int pageIndex) {
    final locator = widget.initialProgress?.locator;
    if (locator == null || locator.type != ReadingLocatorType.pdf) {
      return const [];
    }
    if (locator.page != pageIndex + 1) return const [];
    return [
      for (final rect in locator.selectionRects)
        if (rect.width > 0 && rect.height > 0) rect,
    ];
  }

  void _jumpToPageFromLink(int page) {
    unawaited(_jumpToLocator(ReadingLocator.pdf(page: page)));
  }

  void _clearFocusHit() {
    _focusClearTimer?.cancel();
    _focusClearTimer = null;
    if ((_focusQuads.isEmpty && _imageFocus.isEmpty) || !mounted) return;
    setState(() {
      _focusQuads.clear();
      _imageFocus.clear();
    });
  }

  /// Forwards a zoom the user performed on the page to the host.
  void _handleZoomChanged(double scale, PdfZoomMode mode) {
    _userAdjustedScale = true;
    widget.onZoomChanged?.call(
      scale.clamp(pdfZoomMin, pdfZoomMax).toDouble(),
      mode,
    );
  }

  void _turnPage(int delta) {
    final renderer = _renderer;
    if (renderer == null) return;
    final mode = _displayMode(renderer.pageCount);
    if (mode == PdfDisplayMode.continuous) {
      // A wheel notch means "scroll a screenful" here, like the bridge: in a
      // continuous list the user reads past a page instead of turning it.
      final position = _scrollController.hasClients
          ? _scrollController.position
          : null;
      if (position == null) return;
      final viewport = position.viewportDimension;
      final target = (position.pixels + delta * viewport * 0.9).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
      return;
    }

    // Paged: turn by whole spreads so the left/right page stays in the pair.
    final target = mode == PdfDisplayMode.double
        ? pdfSpreadStart(
            pageIndex: _currentPage + delta * 2,
            pageCount: renderer.pageCount,
          )
        : _currentPage + delta;
    if (target < 0 || target >= renderer.pageCount) return;
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      setState(() => _currentPage = target);
      _reportLocation(renderer.pageCount);
      return;
    }
    unawaited(
      controller.animateToPage(
        _spreadIndexFor(target, renderer.pageCount),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderer = _renderer;
    if (_error != null) {
      return Center(child: Text('无法打开 PDF: $_error'));
    }
    if (renderer == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_readySent) {
      return const Center(child: CircularProgressIndicator());
    }

    // Window width, not the page box: the bridge's phone heuristic keys off
    // `window.innerWidth < 900` (`bridge.js` `isNarrowViewport`).
    final narrow = MediaQuery.sizeOf(context).width < pdfNarrowViewportWidth;
    final zoomMode = effectivePdfZoomMode(
      mode: widget.settings.pdfZoomMode,
      narrow: narrow,
      userAdjustedScale: _userAdjustedScale,
    );
    final mode = _displayMode(renderer.pageCount);

    return CallbackShortcuts(
      bindings: _shortcutsFor(mode),
      child: Focus(
        autofocus: true,
        focusNode: _readerFocusNode,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            final pageSize = _layoutPageSize(renderer, mode, viewport);
            // Resolve this here rather than inside each page so continuous
            // page heights (and therefore the saved scrollOffset) agree with
            // what the pages actually paint.
            final scale = _scaleFor(renderer, mode, viewport, zoomMode, narrow);
            final previousScale = _layoutScale;
            _layoutScale = scale;
            if (mode == PdfDisplayMode.continuous &&
                previousScale != scale &&
                _scrollController.hasClients) {
              _reanchorAfterScaleChange(renderer, pageSize, scale);
            }
            return switch (mode) {
              PdfDisplayMode.continuous => _buildContinuous(
                renderer,
                viewport,
                pageSize: pageSize,
                scale: scale,
                narrow: narrow,
              ),
              PdfDisplayMode.single || PdfDisplayMode.double => _buildPaged(
                renderer,
                viewport,
                pageSize: pageSize,
                scale: scale,
                narrow: narrow,
                mode: mode,
              ),
            };
          },
        ),
      ),
    );
  }

  /// Theme adjustment for the page, resolved per layout.
  ///
  /// Narrow viewports skip the colour matrix: a full-page filter forces the
  /// page into its own layer on every frame, which is a real heat cost while
  /// scrolling. The paper colour still follows the theme there.
  PdfPageTint _tint(bool narrow) =>
      PdfPageTint.forPreset(widget.settings.themePreset, narrow: narrow);

  // --- layout -----------------------------------------------------------

  PdfDisplayMode _displayMode(int pageCount) {
    final wide = MediaQuery.sizeOf(context).width >= pdfNarrowViewportWidth;
    return preferredPdfDisplayMode(
      readerMode: widget.settings.readerMode,
      narrow: !wide,
    );
  }

  /// The point size a page is laid out from.
  ///
  /// Every page must share one scale in continuous mode or the page tops drift
  /// from where the pages paint. Pages therefore resolve against the document's
  /// first page (or, in double mode, the left page of the spread), exactly like
  /// the bridge, which sizes every page from `resolveZoomForPage(first)`
  /// (`bridge.js:670`).
  Size _layoutPageSize(
    PdfCanvasRenderer renderer,
    PdfDisplayMode mode,
    Size viewport,
  ) => renderer.displaySizeOf(0);

  double _scaleFor(
    PdfCanvasRenderer renderer,
    PdfDisplayMode mode,
    Size viewport,
    PdfZoomMode zoomMode,
    bool narrow,
  ) {
    final columns = mode == PdfDisplayMode.double ? 2 : 1;
    final gap = mode == PdfDisplayMode.double ? _spreadGap : 0.0;
    return resolvePdfZoom(
      mode: zoomMode,
      customScale: widget.settings.pdfScale,
      pageSize: _layoutPageSize(renderer, mode, viewport),
      viewport: viewport,
      narrow: narrow,
      pageMargin: widget.settings.pageMargin,
      columns: columns,
      columnGap: gap,
    ).scale;
  }

  static const _gap = 12.0;
  static const _spreadGap = 16.0;

  /// Continuous layout: one vertical list, no page turns.
  Widget _buildContinuous(
    PdfCanvasRenderer renderer,
    Size viewport, {
    required Size pageSize,
    required double scale,
    required bool narrow,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification ||
            notification is ScrollUpdateNotification) {
          _syncPageFromScroll(renderer, pageSize, scale, viewport);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        // Never let the list bounce past a page top on overscroll: the
        // reported scrollOffset would then jump to the next page.
        physics: const ClampingScrollPhysics(),
        itemCount: renderer.pageCount,
        // The gap is part of the item extent, so the tops used for position
        // reporting and the painted positions cannot disagree.
        itemExtentBuilder: (index, _) => pageSize.height * scale + _gap,
        itemBuilder: (context, index) {
          return Padding(
            key: ValueKey('pdf-page-$index'),
            padding: EdgeInsets.only(top: _gap),
            child: _CanvasPage(
              renderer: renderer,
              pageIndex: index,
              settings: widget.settings,
              scale: scale,
              layoutPageSize: pageSize,
              turnOnWheel: false,
              searchQuads: _searchHighlights[index] ?? const [],
              focusQuads: _focusQuads[index] ?? const [],
              imageFocus: _imageFocus[index] ?? const [],
              tint: _tint(narrow),
              annotations: widget.annotations,
              ocrBlocks: _ocrBlocksForPage(index),
              selectionRange: _rangeForPage(index),
              selectionStartsHere: _selectionStartsAt(index),
              selectionEndsHere: _selectionEndsAt(index),
              onImageAreaSelected: (area) =>
                  widget.onImageAreaSelected?.call(area),
              imageDragMode: widget.imageDragMode,
              onSelectionStart: _beginSelection,
              onSelectionMove: _moveSelection,
              onSelectionEnd: _endSelection,
              onSelectionTap: _tapSelection,
              onSelectionHandleDrag: _dragSelectionHandle,
              onSelectionHandleDragEnd: _endSelectionHandleDrag,
              onPageMounted: _registerPage,
              onPageUnmounted: _unregisterPage,
              onAnnotationSelected: widget.onEvent,
              onExternalLink: widget.onEvent,
              onJumpToPage: _jumpToPageFromLink,
              onZoomChanged: _handleZoomChanged,
              onPageTurn: _turnPage,
            ),
          );
        },
      ),
    );
  }

  /// Paged layout: one spread per horizontal page.
  Widget _buildPaged(
    PdfCanvasRenderer renderer,
    Size viewport, {
    required Size pageSize,
    required double scale,
    required bool narrow,
    required PdfDisplayMode mode,
  }) {
    final doubleMode = mode == PdfDisplayMode.double;
    final spreads = doubleMode
        ? ((renderer.pageCount - 1) ~/ 2 + 1)
        : renderer.pageCount;
    final controller = _ensurePageController(renderer, mode);
    return PageView.builder(
      controller: controller,
      itemCount: spreads,
      onPageChanged: (index) {
        final pageIndex = doubleMode ? _pageForSpread(index) : index;
        if (pageIndex == _currentPage) return;
        setState(() => _currentPage = pageIndex);
        _reportLocation(renderer.pageCount);
      },
      itemBuilder: (context, spread) {
        final start = doubleMode ? _pageForSpread(spread) : spread;
        final end = doubleMode
            ? pdfSpreadFor(
                pageIndex: start,
                pageCount: renderer.pageCount,
                mode: PdfDisplayMode.double,
              ).end
            : start;
        final indices = [for (var i = start; i <= end; i++) i];
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < indices.length; i++) ...[
              if (i > 0) const SizedBox(width: _spreadGap),
              Flexible(
                child: _CanvasPage(
                  key: ValueKey('pdf-page-${indices[i]}'),
                  renderer: renderer,
                  pageIndex: indices[i],
                  settings: widget.settings,
                  scale: scale,
                  layoutPageSize: pageSize,
                  turnOnWheel: true,
                  searchQuads: _searchHighlights[indices[i]] ?? const [],
                  focusQuads: _focusQuads[indices[i]] ?? const [],
                  imageFocus: _imageFocus[indices[i]] ?? const [],
                  tint: _tint(narrow),
                  annotations: widget.annotations,
                  ocrBlocks: _ocrBlocksForPage(indices[i]),
                  selectionRange: _rangeForPage(indices[i]),
                  selectionStartsHere: _selectionStartsAt(indices[i]),
                  selectionEndsHere: _selectionEndsAt(indices[i]),
                  onImageAreaSelected: (area) =>
                      widget.onImageAreaSelected?.call(area),
                  imageDragMode: widget.imageDragMode,
                  onSelectionStart: _beginSelection,
                  onSelectionMove: _moveSelection,
                  onSelectionEnd: _endSelection,
                  onSelectionTap: _tapSelection,
                  onSelectionHandleDrag: _dragSelectionHandle,
                  onSelectionHandleDragEnd: _endSelectionHandleDrag,
                  onPageMounted: _registerPage,
                  onPageUnmounted: _unregisterPage,
                  onAnnotationSelected: widget.onEvent,
                  onExternalLink: widget.onEvent,
                  onJumpToPage: _jumpToPageFromLink,
                  onZoomChanged: _handleZoomChanged,
                  onPageTurn: _turnPage,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// The `PageController` for the current paged layout.
  ///
  /// `PageController.initialPage` is only honoured on creation, so it is
  /// rebuilt whenever the mode or the page count changes; otherwise switching
  /// modes would reopen the PDF at the start.
  PageController _ensurePageController(
    PdfCanvasRenderer renderer,
    PdfDisplayMode mode,
  ) {
    final initial = _spreadIndexFor(_currentPage, renderer.pageCount);
    final existing = _pageController;
    if (existing != null && _pageControllerMode == mode) return existing;
    existing?.dispose();
    _pageControllerMode = mode;
    return _pageController = PageController(initialPage: initial);
  }

  PdfDisplayMode? _pageControllerMode;

  /// Spread index that shows [pageIndex].
  int _spreadIndexFor(int pageIndex, int pageCount) {
    if (_displayMode(pageCount) != PdfDisplayMode.double) return pageIndex;
    if (pageIndex <= 0) return 0;
    return (pdfSpreadStart(pageIndex: pageIndex, pageCount: pageCount) + 1) ~/
        2;
  }

  /// First page of the spread at [spread].
  int _pageForSpread(int spread) {
    if (spread <= 0) return 0;
    return spread * 2 - 1;
  }

  // --- selection --------------------------------------------------------

  /// Page and caret under a global pointer, or null off every page.
  ///
  /// A pointer outside a page's box clamps to that page's nearest text rather
  /// than resolving to nothing: dragging past the bottom of a page to the end
  /// of a paragraph is normal, and the browser selection this replaces did the
  /// same.
  PdfCaret? _caretAtGlobal(
    Offset global, {
    int? preferPage,
    bool snapToNearest = true,
  }) {
    final renderer = _renderer;
    if (renderer == null) return null;
    final preferred = preferPage == null ? null : _pageGlobalRects[preferPage];
    final page = preferred == null
        ? _pageAtGlobal(global)
        : (preferred.inflate(8).contains(global)
              ? preferPage
              : _pageAtGlobal(global));
    if (page == null) return null;
    final rect = _pageGlobalRects[page];
    if (rect == null) return null;
    return _selectionControllerFor(
      page,
    )?.caretAt(global - rect.topLeft, snapToNearest: snapToNearest);
  }

  int? _pageAtGlobal(Offset global) {
    int? best;
    var bestDistance = double.infinity;
    for (final entry in _pageGlobalRects.entries) {
      final rect = entry.value;
      if (rect.contains(global)) {
        // A spread can have two pages side by side; only one contains it.
        return entry.key;
      }
      // Off every page (pointer in the margin between pages): the nearest one
      // is the page the reader is dragging toward.
      final dx = math.max(
        0.0,
        math.max(rect.left - global.dx, global.dx - rect.right),
      );
      final dy = math.max(
        0.0,
        math.max(rect.top - global.dy, global.dy - rect.bottom),
      );
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry.key;
      }
    }
    return best;
  }

  PdfTextSelectionSource? _selectionControllerFor(int pageIndex) {
    final renderer = _renderer;
    final rect = _pageGlobalRects[pageIndex];
    if (renderer == null || rect == null) return null;
    final ocr = _ocrLayoutForPage(pageIndex);
    if (ocr != null && !ocr.isEmpty) {
      final pageSize = renderer.displaySizeOf(pageIndex);
      return PdfOcrSelectionController(
        pageIndex: pageIndex,
        layout: ocr,
        displayedSize: rect.size,
        layoutScale: pageSize.width <= 0
            ? _layoutScale
            : rect.width / pageSize.width,
      );
    }
    // This page's own size, not the document's first page. A book whose
    // front matter is a different size from its body (CSAPP's pages 1-65 are
    // 489pt wide against 483pt for the rest; the samples' cover pages differ
    // by up to 2pt) would otherwise map every pointer position through the
    // wrong scale, which offsets the caret by a growing amount down the page.
    final pageSize = renderer.displaySizeOf(pageIndex);
    return PdfSelectionController(
      renderer: renderer,
      pageIndex: pageIndex,
      box: renderer.pageAt(pageIndex).cropBox,
      rotation: renderer.pageAt(pageIndex).rotation,
      paintSize: rect.size,
      displayedSize: rect.size,
      globalOrigin: rect.topLeft,
      pageSize: pageSize,
    );
  }

  /// Pointer down: start a new selection, or keep the current one when the
  /// press lands inside it (a press inside a selection would otherwise kill
  /// it before a copy action could use it).
  void _beginSelection(Offset global, PointerDeviceKind kind) {
    _readerFocusNode.requestFocus();
    final caret = _caretAtGlobal(global);
    if (caret == null) {
      _noticeNoText();
      _clearSelection();
      return;
    }
    // Touch selects a word first, like every mobile reader; a later drag
    // extends from that word's far edge instead of from the touched
    // character. The whole word is selected, not the part before the caret.
    final word = kind == PointerDeviceKind.touch ? _wordAt(caret) : null;
    setState(() {
      _selectionAnchor = word?.anchor ?? caret;
      _selectionFocus = word?.focus ?? caret;
      _selectionDragging = true;
      _emittedSelectionKey = null;
    });
    // A long-press word selection is already meaningful, so the host should
    // show its menu without waiting for a drag.
    if (kind == PointerDeviceKind.touch) {
      _emitSelectionIfChanged(commit: false);
    }
  }

  void _moveSelection(Offset global, PointerDeviceKind kind) {
    if (!_selectionDragging) return;
    final anchor = _selectionAnchor;
    if (anchor == null) return;
    // Scroll first, caret second. Dragging past the page edge is exactly when
    // the view should follow, and at that moment the pointer is over no text,
    // so a caret-first order returns before scrolling ever runs and the drag
    // can never reach the next page. Resolving the caret again on the next
    // move event picks up the page that has just scrolled under the pointer.
    _ensureSelectionVisible(global);
    final caret = _caretAtGlobal(global, preferPage: anchor.page);
    if (caret == null) return;
    if (caret.page == _selectionFocus?.page &&
        caret.index == _selectionFocus?.index) {
      return;
    }
    setState(() => _selectionFocus = caret);
  }

  void _endSelection(Offset global, PointerDeviceKind kind) {
    if (!_selectionDragging) return;
    _selectionDragging = false;
    _moveSelection(global, kind);
    _emitSelectionIfChanged(commit: true);
  }

  /// A tap that did not hit an annotation: a plain tap selects the word under
  /// the pointer.
  ///
  /// A live selection is dismissed first, but the tap still selects: clicking
  /// a second word with a selection up is how a reader moves the selection,
  /// and every desktop reader treats it that way. Tapping inside the current
  /// selection keeps it, so the toolbar can act on it.
  void _tapSelection(Offset global) {
    _readerFocusNode.requestFocus();
    if (_selectionAnchor != null) {
      if (_selectionGlobalRects().any((r) => r.contains(global))) return;
      _clearSelection();
    }
    final caret = _caretAtGlobal(global, snapToNearest: false);
    if (caret == null) return;
    // Desktop tap selects the whole word under the pointer, matching the
    // previous behaviour.
    final word = _wordAt(caret);
    if (word == null) return;
    setState(() {
      _selectionAnchor = word.anchor;
      _selectionFocus = word.focus;
      _emittedSelectionKey = null;
    });
    _emitSelectionIfChanged(commit: true);
  }

  /// The selection's page rectangles in global coordinates.
  List<Rect> _selectionGlobalRects() {
    final out = <Rect>[];
    for (final entry in _selectionRanges.entries) {
      final rect = _pageGlobalRects[entry.key];
      final controller = _selectionControllerFor(entry.key);
      if (rect == null || controller == null) continue;
      for (final local in controller.viewRectsFor(
        entry.value.start,
        entry.value.end,
      )) {
        out.add(local.shift(rect.topLeft));
      }
    }
    return out;
  }

  /// Builds and emits [RendererTextSelected] for the current selection.
  ///
  /// Emitting is deduplicated by page + text, exactly like the bridge's
  /// `lastReportedSelectionKey`: rebuilding the reader on every drag update
  /// would otherwise reopen the host's menu forever.
  void _emitSelectionIfChanged({required bool commit}) {
    final renderer = _renderer;
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (renderer == null || anchor == null || focus == null) return;
    final ranges = _selectionRanges;
    if (ranges.isEmpty) return;

    final texts = <String>[];
    final rects = <ReaderRect>[];
    Rect? anchorGlobal;
    for (final entry in ranges.entries) {
      final page = entry.key;
      final controller = _selectionControllerFor(page);
      final pageRect = _pageGlobalRects[page];
      if (controller == null || pageRect == null) continue;
      texts.add(
        controller.pageText.substring(entry.value.start, entry.value.end),
      );
      final pageRects = controller.readerRectsFor(
        entry.value.start,
        entry.value.end,
      );
      rects.addAll(pageRects);
      if (anchorGlobal == null && pageRects.isNotEmpty) {
        final first = pageRects.first;
        anchorGlobal = Rect.fromLTWH(
          pageRect.left + first.x * pageRect.width,
          pageRect.top + first.y * pageRect.height,
          first.width * pageRect.width,
          first.height * pageRect.height,
        );
      }
    }
    final text = pdfSelectionText(texts);
    if (text.isEmpty) return;
    final key = '${anchor.page}\n$text';
    if (key == _emittedSelectionKey) return;
    _emittedSelectionKey = key;

    final locatorPage = anchor.page + 1;
    widget.onEvent(
      RendererTextSelected(
        text: text,
        locator: ReadingLocator.pdf(
          page: locatorPage,
          zoom: _layoutScale,
          scrollOffset: _scrollOffsetForCurrentPage(),
          progress: renderer.pageCount <= 1
              ? 1.0
              : (locatorPage - 1) / (renderer.pageCount - 1),
          excerpt: text,
          selectionRects: rects,
        ),
        sourceRect: anchorGlobal == null
            ? null
            : ReaderRect(
                page: locatorPage,
                x: anchorGlobal.left,
                y: anchorGlobal.top,
                width: anchorGlobal.width,
                height: anchorGlobal.height,
              ),
        selectionRects: rects,
      ),
    );
  }

  void _registerPage(int pageIndex, GlobalKey key) {
    _pageKeys[pageIndex] = key;
  }

  void _unregisterPage(int pageIndex, GlobalKey key) {
    if (identical(_pageKeys[pageIndex], key)) {
      _pageKeys.remove(pageIndex);
    }
  }

  /// Whether [pageIndex] holds the start of the current selection.
  bool _selectionStartsAt(int pageIndex) {
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (anchor == null || focus == null) return false;
    return pdfOrderCarets(anchor, focus).start.page == pageIndex;
  }

  /// Whether [pageIndex] holds the end of the current selection.
  bool _selectionEndsAt(int pageIndex) {
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (anchor == null || focus == null) return false;
    return pdfOrderCarets(anchor, focus).end.page == pageIndex;
  }

  /// Extends the selection from a dragged handle.
  ///
  /// The start handle moves the anchor and the end handle the focus, so
  /// dragging either end shrinks and grows the selection from that side, the
  /// way a native text selection does.
  void _dragSelectionHandle(Offset global, {required bool isStart}) {
    final caret = _caretAtGlobal(global);
    if (caret == null) return;
    _ensureSelectionVisible(global);
    setState(() {
      if (isStart) {
        _selectionAnchor = caret;
      } else {
        _selectionFocus = caret;
      }
      _emittedSelectionKey = null;
    });
  }

  void _endSelectionHandleDrag() {
    _emitSelectionIfChanged(commit: true);
  }

  /// Says why selection did nothing, instead of leaving the gesture silent.
  ///
  /// The host drops the sticky capability copy but shows this one, matching
  /// the interaction spec's "long-press or drag does nothing" notice.
  void _noticeNoText() {
    if (_nativeTextLayer == false) {
      widget.onEvent(const RendererNotice('此 PDF 没有可选择文本'));
    }
  }

  /// Scrolls the view when a drag is held outside it.
  ///
  /// A drag that starts on one page and runs past the bottom of the window has
  /// to keep working, or cross-page selection is impossible in continuous
  /// mode. The scroll is applied directly rather than animated: a drag emits a
  /// move event every frame, and an animation restarted on each one advances a
  /// few pixels at most before being cancelled, so the view crawls and the
  /// page the reader is dragging toward never arrives. The step grows with how
  /// far outside the viewport the pointer is and is capped, so a pointer
  /// parked below the window scrolls steadily instead of jumping pages.
  void _ensureSelectionVisible(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final viewport = box.globalToLocal(global);
    final height = box.size.height;
    final top = 56.0;
    final bottom = height - 56;
    if (viewport.dy > top && viewport.dy < bottom) return;
    final below = viewport.dy > bottom;
    final overshoot = below ? viewport.dy - bottom : top - viewport.dy;
    final step = math.min(overshoot, 64.0) + 8.0;
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final target = (below ? position.pixels + step : position.pixels - step)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target != position.pixels) _scrollController.jumpTo(target);
      return;
    }
    final controller = _pageController;
    if (controller != null && controller.hasClients) {
      if (below) {
        unawaited(
          controller.nextPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      } else {
        unawaited(
          controller.previousPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    }
  }

  void _clearSelection() {
    if (_selectionAnchor == null && _selectionFocus == null) return;
    setState(() {
      _selectionAnchor = null;
      _selectionFocus = null;
      _selectionDragging = false;
      _emittedSelectionKey = null;
    });
  }

  /// The whole word at [caret], as anchor and focus carets.
  ///
  /// Returns null when the caret sits on a separator or the page has no text
  /// there, so callers can decide between doing nothing and selecting a
  /// single character.
  ({PdfCaret anchor, PdfCaret focus})? _wordAt(PdfCaret caret) {
    final text = _selectionControllerFor(caret.page)?.pageText;
    if (text == null) return null;
    final range = pdfWordRangeAt(text, caret.index);
    if (range == null) return null;
    return (
      anchor: (page: caret.page, index: range.$1),
      focus: (page: caret.page, index: range.$2),
    );
  }

  // --- scrolling --------------------------------------------------------

  /// Scrolls so that [pageIndex] is at [offset] inside the page.
  Future<void> _scrollToPage(
    int pageIndex, {
    double offset = 0,
    bool animate = true,
  }) async {
    final renderer = _renderer;
    if (renderer == null) return;
    final mode = _displayMode(renderer.pageCount);

    if (mode != PdfDisplayMode.continuous) {
      final controller = _pageController;
      final target = _spreadIndexFor(pageIndex, renderer.pageCount);
      if (controller != null && controller.hasClients) {
        if (animate) {
          await controller.animateToPage(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        } else {
          controller.jumpToPage(target);
        }
      }
      return;
    }

    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final pageSize = renderer.displaySizeOf(0);
    // Use the scale the last build actually laid the pages out at. Resolving
    // it again here would need the layout's width, which the scroll position
    // does not expose, and a mismatched scale lands the jump on the wrong page.
    final height = pageSize.height * _layoutScale;
    final tops = pdfPageTops(
      pageHeights: List.filled(renderer.pageCount, height),
      gap: _gap,
    );
    final target = pdfScrollTarget(
      pageTops: tops,
      pageHeights: List.filled(renderer.pageCount, height),
      pageIndex: pageIndex,
      offset: offset,
      viewportHeight: viewport,
    );
    if (animate) {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  /// Re-anchors the reader after every page's height changed.
  ///
  /// A zoom or a window resize changes the list's item extent, so a fixed
  /// `pixels` value would land on a different line. Restoring `pageTop +
  /// ratio * height` keeps the same fraction of the same page on screen.
  void _reanchorAfterScaleChange(
    PdfCanvasRenderer renderer,
    Size pageSize,
    double scale,
  ) {
    final ratio = _anchorRatio;
    final controller = _scrollController;
    if (ratio == null) return;
    final page = _currentPage;
    final height = pageSize.height * scale;
    // The list still has the previous extent during this frame, so the jump
    // must wait for the layout that uses the new scale. A second scale change
    // before then supersedes this one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients || _layoutScale != scale) return;
      final heights = List.filled(renderer.pageCount, height);
      final tops = pdfPageTops(pageHeights: heights, gap: _gap);
      final position = controller.position;
      final target = pdfScrollTarget(
        pageTops: tops,
        pageHeights: heights,
        pageIndex: page,
        offset: ratio * height,
        viewportHeight: position.viewportDimension,
      ).clamp(position.minScrollExtent, position.maxScrollExtent);
      controller.jumpTo(target.toDouble());
    });
  }

  /// Recomputes the page and offset from the scroll position.
  void _syncPageFromScroll(
    PdfCanvasRenderer renderer,
    Size pageSize,
    double scale,
    Size viewport,
  ) {
    if (!_scrollController.hasClients) return;
    final height = pageSize.height * scale;
    final tops = pdfPageTops(
      pageHeights: List.filled(renderer.pageCount, height),
      gap: _gap,
    );
    final scrollY = _scrollController.position.pixels;
    final page = pdfPageAtScroll(
      scrollY: scrollY,
      pageTops: tops,
      pageHeights: List.filled(renderer.pageCount, height),
      viewportHeight: viewport.height,
    );
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
    // Remember how far into the page the reader is; a later zoom uses it to
    // stay on the same line instead of the same raw pixels.
    _anchorRatio = height <= 0
        ? null
        : ((scrollY - tops[page]) / height).clamp(0.0, 1.0);
    // Report on every scroll, not only on a page change: the locator's
    // scrollOffset is what makes reopening land mid-page. The 120/420 ms
    // debounce inside `_reportLocation` keeps this off the scroll hot path.
    _reportLocation(renderer.pageCount);
  }

  double _scrollOffsetForCurrentPage() {
    final renderer = _renderer;
    if (renderer == null) return 0;
    final mode = _displayMode(renderer.pageCount);
    if (mode != PdfDisplayMode.continuous) return 0;
    if (!_scrollController.hasClients) return 0;
    final pageSize = renderer.displaySizeOf(0);
    final tops = pdfPageTops(
      pageHeights: List.filled(
        renderer.pageCount,
        pageSize.height * _layoutScale,
      ),
      gap: _gap,
    );
    return pdfScrollOffset(
      scrollY: _scrollController.position.pixels,
      pageTops: tops,
      pageIndex: _currentPage,
      mode: mode,
    );
  }

  double? _pageOffsetFractionForCurrentPage() {
    final renderer = _renderer;
    if (renderer == null) {
      return null;
    }
    if (_displayMode(renderer.pageCount) != PdfDisplayMode.continuous) {
      return null;
    }
    return _anchorRatio?.clamp(0.0, 1.0);
  }

  /// Restores the saved position once the layout exists.
  void _restoreSavedPosition() {
    final renderer = _renderer;
    if (renderer == null || _restored) return;
    if (!_scrollController.hasClients && _pageController == null) return;
    _restored = true;
    final locator = widget.initialProgress?.locator;
    if (locator == null) return;
    unawaited(
      _scrollToPage(
        _initialPage(renderer.pageCount),
        offset: locator.scrollOffset ?? 0,
        animate: false,
      ),
    );
  }

  /// Keyboard paging, mirroring the EPUB renderer plus the bridge's
  /// PageUp/PageDown handling. Continuous mode scrolls, paged mode turns.
  Map<ShortcutActivator, VoidCallback> _shortcutsFor(PdfDisplayMode mode) {
    void scrollBy(double screens) {
      final position = _scrollController.hasClients
          ? _scrollController.position
          : null;
      if (position == null) return;
      final target = (position.pixels + screens * position.viewportDimension)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    }

    if (mode == PdfDisplayMode.continuous) {
      return {
        const SingleActivator(LogicalKeyboardKey.pageDown): () => scrollBy(0.9),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => scrollBy(-0.9),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            scrollBy(0.12),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            scrollBy(-0.12),
        const SingleActivator(LogicalKeyboardKey.space): () => scrollBy(0.9),
        const SingleActivator(LogicalKeyboardKey.home): () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.minScrollExtent,
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.end): () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        },
      };
    }
    return {
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _turnPage(1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _turnPage(-1),
      const SingleActivator(LogicalKeyboardKey.pageDown): () => _turnPage(1),
      const SingleActivator(LogicalKeyboardKey.pageUp): () => _turnPage(-1),
      const SingleActivator(LogicalKeyboardKey.space): () => _turnPage(1),
    };
  }
}

/// One page, laid out at the resolved zoom and panned inside the viewport.
final class _CanvasPage extends StatefulWidget {
  const _CanvasPage({
    required this.renderer,
    required this.pageIndex,
    required this.settings,
    required this.scale,
    required this.layoutPageSize,
    required this.turnOnWheel,
    required this.searchQuads,
    required this.focusQuads,
    this.imageFocus = const [],
    required this.tint,
    required this.annotations,
    required this.ocrBlocks,
    required this.selectionRange,
    required this.selectionStartsHere,
    required this.selectionEndsHere,
    required this.onSelectionStart,
    required this.onSelectionMove,
    required this.onSelectionEnd,
    required this.onSelectionTap,
    required this.onSelectionHandleDrag,
    required this.onSelectionHandleDragEnd,
    required this.onPageMounted,
    required this.onPageUnmounted,
    required this.onAnnotationSelected,
    required this.onImageAreaSelected,
    required this.imageDragMode,
    required this.onExternalLink,
    required this.onJumpToPage,
    required this.onZoomChanged,
    required this.onPageTurn,
    super.key,
  });

  final PdfCanvasRenderer renderer;
  final int pageIndex;
  final ReaderSettings settings;

  /// Logical pixels per PDF point, resolved once for the whole layout.
  ///
  /// Pages must not resolve their own zoom: in continuous mode the list gives
  /// each item an extent derived from the scale, so a page that re-resolved
  /// against its own constraints would feed back into that extent.
  final double scale;

  /// Point size every page in the layout resolves its scale from.
  ///
  /// Sharing one basis across pages keeps the continuous page tops identical
  /// to where the pages actually paint; resolving per page would drift on a
  /// document with mixed page sizes.
  final Size layoutPageSize;

  /// Whether a plain wheel notch turns a page.
  ///
  /// True in the paged layouts. Continuous scrolling leaves the notch to the
  /// list, so swallowing it here would stop the reader from scrolling.
  final bool turnOnWheel;
  final List<PdfTextQuad> searchQuads;

  /// Quads of the one hit the reader just jumped to, painted brighter than the
  /// rest for a couple of seconds.
  final List<PdfTextQuad> focusQuads;

  /// Image boxes to pulse after a jump, as display-box fractions.
  final List<ReaderRect> imageFocus;

  /// Theme adjustment resolved once for the whole layout.
  final PdfPageTint tint;
  final List<Annotation> annotations;
  final List<OcrTextBlock> ocrBlocks;

  /// The part of the current selection that falls on this page, or null.
  ///
  /// The selection itself lives in the view: a drag may run across pages, and
  /// only the view knows every page's caret geometry. The page paints its own
  /// share and reports pointer positions upward in global coordinates.
  final ({int start, int end})? selectionRange;

  /// Whether this page holds the start / end of the selection.
  ///
  /// Only those two pages get a handle: with a three-page selection the
  /// interior page has no end to grab.
  final bool selectionStartsHere;
  final bool selectionEndsHere;

  /// Pointer-down with a selecting device (mouse, stylus, touch long-press).
  final void Function(Offset global, PointerDeviceKind kind) onSelectionStart;

  /// Pointer moved while selecting; [global] may be outside the page box.
  final void Function(Offset global, PointerDeviceKind kind) onSelectionMove;

  /// Pointer released.
  final void Function(Offset global, PointerDeviceKind kind) onSelectionEnd;

  /// A tap that did not land on an annotation.
  final ValueChanged<Offset> onSelectionTap;

  /// A handle was dragged; [isStart] says which end.
  final void Function(Offset global, {required bool isStart})
  onSelectionHandleDrag;

  /// A handle drag ended and the selection should be reported.
  final VoidCallback onSelectionHandleDragEnd;

  final void Function(int pageIndex, GlobalKey key) onPageMounted;
  final void Function(int pageIndex, GlobalKey key) onPageUnmounted;
  final ValueChanged<RendererAnnotationSelected> onAnnotationSelected;

  /// A box was drawn over an image with image-drag mode on.
  final ValueChanged<RendererImageAreaSelected> onImageAreaSelected;

  /// Whether a drag draws an image box instead of selecting text.
  final bool imageDragMode;

  /// An external `/URI` link was tapped; the host confirms and opens it.
  final ValueChanged<RendererExternalLinkRequested> onExternalLink;

  /// An in-document link to [page] (1-based) was tapped.
  final ValueChanged<int> onJumpToPage;
  final PdfZoomChanged onZoomChanged;
  final ValueChanged<int> onPageTurn;

  @override
  State<_CanvasPage> createState() => _CanvasPageState();
}

final class _CanvasPageState extends State<_CanvasPage> {
  Future<PdfRenderedPage?>? _future;

  /// Set when a render came back null because the page's record was cancelled.
  ///
  /// Null is not an error: it means the page left the screen while it was
  /// queued. If the widget is in fact still mounted (a cached list slot, a
  /// paging rebuild), the page needs one more request or it would show a
  /// spinner forever.
  bool _retriedAfterCancel = false;

  /// The page box, in logical pixels, before panning.
  Size _viewport = Size.zero;

  /// Parsed OCR text for this page, rebuilt only when the overlay changes.
  List<OcrTextBlock>? _ocrLayoutSource;
  PdfOcrTextLayout? _ocrLayout;

  PdfOcrTextLayout? get _ocrTextLayout {
    if (widget.ocrBlocks.isEmpty) return null;
    if (!identical(_ocrLayoutSource, widget.ocrBlocks)) {
      _ocrLayoutSource = widget.ocrBlocks;
      _ocrLayout = PdfOcrTextLayout.fromBlocks(widget.ocrBlocks);
    }
    return _ocrLayout;
  }

  /// Live zoom while the fingers are down, in logical pixels per PDF point.
  ///
  /// Kept after the gesture ends until the host's saved settings catch up, so
  /// persisting a pinch does not flash the old scale for a frame.
  double? _transientScale;

  /// Content offset from the centred position, when zoomed past the viewport.
  Offset _pan = Offset.zero;

  double? _gestureStartScale;
  Offset _gestureAnchor = Offset.zero;
  bool _pinchMoved = false;

  DateTime _lastWheelTurn = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastTapAt;
  Offset? _lastTapGlobal;

  /// Touch long-press selects the word under the finger, then a drag extends
  /// it. The recognizer arms on touch down; this flag remembers that it fired.
  bool _longPressSelecting = false;

  /// The page's rotation-aware display size, in PDF points.
  ///
  /// `PdfPageRenderer.pageSize` applies /Rotate, so a 90° page lays out and
  /// paints as landscape instead of being cropped to its unrotated box.
  Size get _pageSize => widget.layoutPageSize;

  int get _rotation => widget.renderer.pageAt(widget.pageIndex).rotation;

  double get _displayScale => _transientScale ?? widget.scale;

  /// Size the page occupies on screen at the current scale.
  Size get _paintedSize =>
      Size(_pageSize.width * _displayScale, _pageSize.height * _displayScale);

  @override
  void initState() {
    super.initState();
    widget.onPageMounted(widget.pageIndex, _selectableKey);
    // The picture is recorded in page space (one unit per PDF point) and
    // replayed at whatever size the page is laid out at, so it never has to
    // be re-rendered for a zoom change. S1 therefore has no page cache to
    // clear on `didUpdateWidget`; theme work in S6 will add one.
    _future = widget.renderer.renderPage(widget.pageIndex);
    _prefetchNeighbours();
  }

  /// Warms the pages on either side of this one.
  ///
  /// Continuous scrolling touches a new page every screenful; recording the
  /// neighbours at background priority means the page arriving under the
  /// viewport is usually a cheap replay instead of a fresh interpretation.
  void _prefetchNeighbours() {
    final renderer = widget.renderer;
    _prefetched.clear();
    for (final page in [widget.pageIndex - 1, widget.pageIndex + 1]) {
      if (page < 0 || page >= renderer.pageCount) continue;
      _prefetched.add(page);
      renderer.prefetch(page);
    }
  }

  /// Neighbours this page asked the renderer to warm.
  ///
  /// Tracking them lets a recycled slot cancel the prefetch for the page it
  /// used to be, which would otherwise decode a page nobody is near.
  final Set<int> _prefetched = <int>{};

  void _cancelPrefetches() {
    for (final page in _prefetched) {
      widget.renderer.cancelPrefetch(page);
    }
    _prefetched.clear();
  }

  @override
  void didUpdateWidget(covariant _CanvasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.renderer != widget.renderer) {
      oldWidget.onPageUnmounted(oldWidget.pageIndex, _selectableKey);
      widget.onPageMounted(widget.pageIndex, _selectableKey);
      // A recycled list slot now shows another page: drop the request for the
      // page that left (its result would be thrown away anyway and only delay
      // the page arriving), release whatever it did produce, then start the
      // new page.
      final abandoned = _future;
      _cancelPrefetches();
      oldWidget.renderer.cancelPage(oldWidget.pageIndex);
      abandoned?.then((page) => page?.dispose(), onError: (Object _) {});
      _retriedAfterCancel = false;
      _future = widget.renderer.renderPage(widget.pageIndex);
      _prefetchNeighbours();
      return;
    }
    if (oldWidget.settings.pdfScale == widget.settings.pdfScale &&
        oldWidget.settings.pdfZoomMode == widget.settings.pdfZoomMode) {
      return;
    }
    // Drop the transient scale once the persisted settings match it. Until
    // then the transient stays authoritative so the page does not flicker.
    final transient = _transientScale;
    if (transient != null &&
        widget.settings.pdfZoomMode == PdfZoomMode.custom &&
        (widget.settings.pdfScale - transient).abs() < 0.005) {
      _transientScale = null;
    }
  }

  @override
  void dispose() {
    widget.onPageUnmounted(widget.pageIndex, _selectableKey);
    // Tell the worker this page is no longer wanted: a queued record left
    // behind would make the isolate interpret a page nobody is looking at
    // while the page arriving under the viewport waits its turn.
    _cancelPrefetches();
    widget.renderer.cancelPage(widget.pageIndex);
    _future?.then((page) => page?.dispose(), onError: (Object _) {});
    super.dispose();
  }

  final GlobalKey _selectableKey = GlobalKey();

  /// Selection rectangles for this page's share of the live selection.
  ///
  /// Painted inside the page box, in the same view coordinates the pointers
  /// arrive in; the view owns the carets and hands each page its own range.
  List<Rect> get _selectionHighlights {
    final range = widget.selectionRange;
    if (range == null || range.end <= range.start) return const [];
    return _textSelectionSource().viewRectsFor(range.start, range.end);
  }

  Widget _selectablePageFor(PdfRenderedPage page) {
    return _SelectablePage(
      key: _selectableKey,
      page: page,
      pageSize: _pageSize,
      highlightedRects: [
        for (final q in widget.searchQuads) _quadToRect(q, _pageSize),
        ..._selectionHighlights,
      ],
      focusedRects: [
        for (final q in widget.focusQuads) _quadToRect(q, _pageSize),
      ],
      imageFocusRects: [
        for (final r in widget.imageFocus)
          Rect.fromLTWH(
            r.x * _pageSize.width,
            r.y * _pageSize.height,
            r.width * _pageSize.width,
            r.height * _pageSize.height,
          ),
      ],
      tint: widget.tint,
      annotations: [
        ..._annotationBoxes(_paintedSize),
        if (_imageDragStart != null && _imageDragCurrent != null)
          _AnnotationBox(
            annotationId: '__image_drag__',
            rect: Rect.fromPoints(_imageDragStart!, _imageDragCurrent!),
            color: AnnotationColor.blue,
            underline: false,
            imageFrame: true,
          ),
      ],
      onStart: _onDragStart,
      onUpdate: _onDragUpdate,
      onEnd: _onDragEnd,
      onTap: _handleTap,
      onLongPressStart: _onLongPressStart,
      onLongPressMove: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      imageBoxMode: widget.imageDragMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _viewport = viewport;
        final scale = _transientScale ?? widget.scale;
        final content = Size(_pageSize.width * scale, _pageSize.height * scale);
        final pan = _clampPan(_pan, content, viewport);
        // Centre when the page fits; anchor to the top-left when it does not.
        // Centring an overflowing page would open the reader mid-page with
        // the first lines scrolled out of sight.
        final origin =
            Offset(
              math.max(0.0, (viewport.width - content.width) / 2),
              math.max(0.0, (viewport.height - content.height) / 2),
            ) +
            pan;

        // Only an overflowing page has to manage dragging itself; a page that
        // fits leaves the drag to the list or pager, otherwise it would
        // swallow scrolling and horizontal swipes. The wheel listener is
        // always attached because Ctrl+wheel zooms at any scale.
        final ownsGestures = _overflows(content, viewport);
        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: ownsGestures
                ? <Type, GestureRecognizerFactory>{
                    _TouchScaleGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _TouchScaleGestureRecognizer
                        >(
                          () => _TouchScaleGestureRecognizer(debugOwner: this),
                          (recognizer) => recognizer
                            ..onStart = _onScaleStart
                            ..onUpdate = _onScaleUpdate
                            ..onEnd = _onScaleEnd,
                        ),
                  }
                : const <Type, GestureRecognizerFactory>{},
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: origin.dx,
                    top: origin.dy,
                    width: content.width,
                    height: content.height,
                    child: FutureBuilder<PdfRenderedPage?>(
                      future: _future,
                      builder: (context, snapshot) {
                        final page = snapshot.data;
                        if (snapshot.hasError) {
                          // A page the interpreter rejected must not leave a
                          // spinner behind it forever: the reader would sit on
                          // a page that never arrives. Show a placeholder the
                          // user can retry, and tell the host once.
                          return _PageFailure(
                            pageNumber: widget.pageIndex + 1,
                            onRetry: () => setState(
                              () => _future = widget.renderer.renderPage(
                                widget.pageIndex,
                              ),
                            ),
                          );
                        }
                        if (page == null) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              !_retriedAfterCancel) {
                            // The record was cancelled while the page was in
                            // the queue. Nothing else will ask for it again,
                            // so re-request once rather than spin forever.
                            _retriedAfterCancel = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(
                                () => _future = widget.renderer.renderPage(
                                  widget.pageIndex,
                                ),
                              );
                            });
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _selectablePageFor(page);
                      },
                    ),
                  ),
                  // Touch selection handles sit above the page so they are
                  // reachable even at the very edge of the text.
                  if (widget.selectionRange != null)
                    ..._buildSelectionHandles(origin),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Touch selection handles: one at each end of this page's selection band.
  ///
  /// Handles are only painted for the page the selection starts on and the
  /// page it ends on; an interior page of a three-page selection has no end
  /// to grab. The hit area is 44 px even though the knob is 16 px, which is
  /// the smallest comfortable touch target in the design system.
  List<Widget> _buildSelectionHandles(Offset origin) {
    final range = widget.selectionRange;
    if (range == null) return const [];
    final rects = _selectionHighlights;
    if (rects.isEmpty) return const [];
    final pageRect = _paintedSize;
    final first = rects.first;
    final last = rects.last;
    final widgets = <Widget>[];
    // Start handle sits above the first line's start, end handle below the
    // last line's end, like a native text selection.
    if (widget.selectionStartsHere) {
      final startAt = Offset(
        first.left.clamp(0.0, pageRect.width - 1) + origin.dx,
        first.top.clamp(0.0, pageRect.height - 1) + origin.dy,
      );
      widgets.add(
        _SelectionHandle(
          key: const ValueKey('pdf-selection-handle-start'),
          anchor: startAt,
          above: true,
          onDrag: (global) =>
              widget.onSelectionHandleDrag(global, isStart: true),
          onDragEnd: widget.onSelectionHandleDragEnd,
        ),
      );
    }
    if (widget.selectionEndsHere) {
      final endAt = Offset(
        last.right.clamp(0.0, pageRect.width - 1) + origin.dx,
        last.bottom.clamp(0.0, pageRect.height - 1) + origin.dy,
      );
      widgets.add(
        _SelectionHandle(
          key: const ValueKey('pdf-selection-handle-end'),
          anchor: endAt,
          above: false,
          onDrag: (global) =>
              widget.onSelectionHandleDrag(global, isStart: false),
          onDragEnd: widget.onSelectionHandleDragEnd,
        ),
      );
    }
    return widgets;
  }

  /// Whether the page is larger than the box it sits in on either axis.
  bool _overflows(Size content, Size viewport) =>
      content.width > viewport.width + 0.5 ||
      content.height > viewport.height + 0.5;

  /// Keeps the content from being dragged away from the viewport edges.
  Offset _clampPan(Offset pan, Size content, Size viewport) {
    final maxX = math.max(0.0, (content.width - viewport.width) / 2);
    final maxY = math.max(0.0, (content.height - viewport.height) / 2);
    return Offset(pan.dx.clamp(-maxX, maxX), pan.dy.clamp(-maxY, maxY));
  }

  // --- zoom -------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    final viewport = _viewport;
    if (viewport.isEmpty) return;
    final scale = _transientScale ?? widget.scale;
    final content = Size(_pageSize.width * scale, _pageSize.height * scale);
    final pan = _clampPan(_pan, content, viewport);
    final center = Offset(viewport.width / 2, viewport.height / 2);
    _gestureStartScale = scale;
    // The page-space point under the fingers, held in place while zooming.
    _gestureAnchor =
        (details.localFocalPoint - center - pan) / math.max(scale, 0.0001);
    _pinchMoved = false;
    if (_pan != pan) setState(() => _pan = pan);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final viewport = _viewport;
    final start = _gestureStartScale;
    if (viewport.isEmpty || start == null) return;

    var scale = start;
    // Trackpad pan/zoom events always report at least two pointers; only a
    // real span change counts as a pinch.
    if (details.pointerCount >= 2) {
      scale = (start * details.scale).clamp(pdfZoomMin, pdfZoomMax).toDouble();
      if ((scale - start).abs() > 0.001) _pinchMoved = true;
    }

    final center = Offset(viewport.width / 2, viewport.height / 2);
    final content = Size(_pageSize.width * scale, _pageSize.height * scale);
    final pan = _clampPan(
      details.localFocalPoint - center - _gestureAnchor * scale,
      content,
      viewport,
    );
    setState(() {
      if (_pinchMoved) _transientScale = scale;
      _pan = pan;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final transient = _transientScale;
    if (_pinchMoved && transient != null) {
      widget.onZoomChanged(transient, PdfZoomMode.custom);
    }
    _pinchMoved = false;
    _gestureStartScale = null;
  }

  /// Ctrl+wheel zooms; plain wheel pans a zoomed page or turns pages.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final viewport = _viewport;
    if (viewport.isEmpty) return;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      final notches = event.scrollDelta.dy;
      if (notches == 0) return;
      // One notch is one 10% step, like the bridge's Ctrl+wheel handler.
      // Zoom is ours wherever it happens, so claim the signal before an
      // ancestor Scrollable scrolls on it too.
      _claimSignal(event);
      _applyZoom(_displayScale + (notches < 0 ? pdfZoomStep : -pdfZoomStep));
      return;
    }

    final content = _paintedSize;
    // A page wider than its box can only happen past fit-width. There the
    // wheel has to pan or the page would be unreachable: mouse drags select
    // text, so the wheel is the only pointer way to move it.
    if (content.width > viewport.width + 0.5) {
      _claimSignal(event);
      // Shift maps the vertical wheel to horizontal, since a mouse has no
      // horizontal wheel.
      final delta = keyboard.isShiftPressed
          ? Offset(event.scrollDelta.dy + event.scrollDelta.dx, 0)
          : event.scrollDelta;
      setState(() {
        _pan = _clampPan(_pan - delta, content, viewport);
      });
      return;
    }

    // Nothing to pan. In continuous mode the list owns the notch, so stop
    // here; in the paged layouts a notch turns a spread, as the bridge did.
    if (!widget.turnOnWheel) return;
    final vertical = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (vertical.abs() < 4) return;
    final now = DateTime.now();
    if (now.difference(_lastWheelTurn) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastWheelTurn = now;
    _claimSignal(event);
    widget.onPageTurn(vertical > 0 ? 1 : -1);
  }

  /// Stops the signal from reaching an ancestor Scrollable.
  ///
  /// Pointer signals travel to every hit-test entry; the resolver lets the
  /// deepest interested widget claim one and drop the rest.
  void _claimSignal(PointerScrollEvent event) {
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
  }

  /// Sets the zoom for the session and hands it to the host to persist.
  void _applyZoom(double target, {PdfZoomMode mode = PdfZoomMode.custom}) {
    final scale = target.clamp(pdfZoomMin, pdfZoomMax).toDouble();
    setState(() => _transientScale = mode == PdfZoomMode.custom ? scale : null);
    widget.onZoomChanged(scale, mode);
  }

  // --- selection gestures ----------------------------------------------

  /// Global origin of the painted page box.
  ///
  /// Selection carets are resolved by the view from global positions, so this
  /// page only converts its own local pointer positions outward.
  Offset get _globalOrigin {
    final box = _selectableKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(Offset.zero);
  }

  Offset _toGlobal(Offset local) => _globalOrigin + local;

  Offset? _imageDragStart;
  Offset? _imageDragCurrent;

  void _onDragStart(Offset local) {
    if (widget.imageDragMode) {
      _imageDragStart = local;
      _imageDragCurrent = local;
      setState(() {});
      return;
    }
    widget.onSelectionStart(_toGlobal(local), PointerDeviceKind.mouse);
  }

  void _onDragUpdate(Offset local) {
    if (widget.imageDragMode) {
      _imageDragCurrent = local;
      setState(() {});
      return;
    }
    // The view holds the carets and rebuilds every page with its new
    // `selectionRange`, so the highlight follows the drag without the page
    // tracking selection state of its own.
    widget.onSelectionMove(_toGlobal(local), PointerDeviceKind.mouse);
  }

  void _onDragEnd(Offset local, Offset globalOrigin) {
    if (widget.imageDragMode) {
      final start = _imageDragStart;
      _imageDragStart = null;
      _imageDragCurrent = null;
      setState(() {});
      if (start != null) {
        _emitImageSelection(start, local, globalOrigin);
      }
      return;
    }
    widget.onSelectionEnd(_toGlobal(local), PointerDeviceKind.mouse);
  }

  /// Converts the drawn box into an anchor, snapping to a detected image.
  void _emitImageSelection(Offset start, Offset end, Offset globalOrigin) {
    final painted = _paintedSize;
    if (painted.width <= 0 || painted.height <= 0) return;
    final left = math.min(start.dx, end.dx) / painted.width;
    final top = math.min(start.dy, end.dy) / painted.height;
    final width = (end.dx - start.dx).abs() / painted.width;
    final height = (end.dy - start.dy).abs() / painted.height;
    if (width <= 0.003 || height <= 0.003) return;
    final drawn = ReaderRect(
      x: left.clamp(0.0, 1.0),
      y: top.clamp(0.0, 1.0),
      width: width.clamp(0.0, 1.0 - left),
      height: height.clamp(0.0, 1.0 - top),
    );
    final image = snapToDetectedImage(
      drawn,
      widget.renderer.imagesOnPage(widget.pageIndex),
    );
    final page = widget.pageIndex + 1;
    final anchor = PdfImageAnchor(
      page: page,
      ordinal: image?.ordinal,
      resourceName: image?.resourceName,
      rect: image?.rect ?? drawn,
    );
    widget.onImageAreaSelected(
      RendererImageAreaSelected(
        anchor: anchor,
        sourceRect: ReaderRect(
          page: page,
          x: globalOrigin.dx + left * painted.width,
          y: globalOrigin.dy + top * painted.height,
          width: width * painted.width,
          height: height * painted.height,
        ),
      ),
    );
  }

  /// Touch long-press selects the word under the finger.
  ///
  /// Desktop browsers select by dragging; touch devices have no hover and no
  /// cursor, so the platform convention is press-and-hold on a word. The
  /// recognizer arms on press-down but only wins after the hold timer, so a
  /// quick swipe still reaches the pan and pinch recognizers.
  void _onLongPressStart(LongPressStartDetails details) {
    _longPressSelecting = true;
    widget.onSelectionStart(details.globalPosition, PointerDeviceKind.touch);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_longPressSelecting) return;
    widget.onSelectionMove(details.globalPosition, PointerDeviceKind.touch);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_longPressSelecting) return;
    _longPressSelecting = false;
    widget.onSelectionEnd(details.globalPosition, PointerDeviceKind.touch);
  }

  /// Tap on the page: a link or an annotation under the pointer wins, then the
  /// view decides between selecting a word and double-click zoom.
  void _handleTap(Offset globalPosition) {
    final local = globalPosition - _globalOrigin;
    if (_emitLinkTap(local, _paintedSize)) return;
    if (_emitAnnotationTap(local, _paintedSize, _globalOrigin)) return;

    final now = DateTime.now();
    final lastAt = _lastTapAt;
    final lastPosition = _lastTapGlobal;
    _lastTapAt = now;
    _lastTapGlobal = globalPosition;
    if (lastAt != null &&
        lastPosition != null &&
        now.difference(lastAt) <= const Duration(milliseconds: 300) &&
        (globalPosition - lastPosition).distance <= 24) {
      // Mouse double-click toggles fit-width and 2x, per the plan's S1 step 7.
      _lastTapAt = null;
      _lastTapGlobal = null;
      if (widget.settings.pdfZoomMode == PdfZoomMode.fitWidth) {
        _applyZoom(2.0);
      } else {
        // Fit-width is a mode, not a scale; the host resolves it from the
        // viewport, so the scale we pass is ignored.
        _applyZoom(_displayScale, mode: PdfZoomMode.fitWidth);
      }
      return;
    }
    widget.onSelectionTap(globalPosition);
  }

  // --- geometry and overlays -------------------------------------------

  /// Geometry for this page in its own painted box.
  ///
  /// [PdfPageGeometry] is the same helper dart_pdf_editor hands to
  /// `PdfViewer.pageOverlayBuilder`; it already accounts for the crop box
  /// origin, /Rotate and the painted size.
  PdfPageGeometry _geometryFor(Size viewSize) {
    final page = widget.renderer.pageAt(widget.pageIndex);
    return PdfPageGeometry(
      cropBox: page.cropBox,
      rotation: page.rotation,
      viewSize: viewSize,
    );
  }

  /// Stored annotations for this page, in view coordinates.
  ///
  /// `annotation.locator.selectionRects` are 0..1 fractions of the displayed
  /// (post-rotation) page box, exactly like `RendererTextSelected`
  /// `selectionRects`. They are therefore multiplied by the view size
  /// directly — routing them through page space would apply /Rotate a second
  /// time on rotated pages.
  List<_AnnotationBox> _annotationBoxes(Size viewSize) {
    final bands = _lineBands();
    final out = <_AnnotationBox>[];
    for (final annotation in widget.annotations) {
      if (annotation.locator.page != widget.pageIndex + 1) continue;
      final anchor = annotation.imageAnchor;
      if (annotation.target == AnnotationTarget.image && anchor != null) {
        // An image is marked with a frame, not a wash: a translucent fill over
        // artwork changes what the reader sees, which is the one thing a
        // highlight of an image must not do.
        out.add(
          _AnnotationBox(
            annotationId: annotation.id,
            rect: Rect.fromLTWH(
              anchor.rect.x * viewSize.width,
              anchor.rect.y * viewSize.height,
              anchor.rect.width * viewSize.width,
              anchor.rect.height * viewSize.height,
            ),
            color: annotation.color,
            underline: false,
            imageFrame: true,
          ),
        );
        continue;
      }
      final raw = <PdfLineRect>[
        for (final rect in annotation.locator.selectionRects)
          if (rect.width > 0 && rect.height > 0)
            PdfLineRect(
              page: widget.pageIndex + 1,
              x: rect.x,
              y: rect.y,
              width: rect.width,
              height: rect.height,
            ),
      ];
      if (raw.isEmpty) continue;
      // F-02: trim every band to the text line it belongs to. A stored box
      // outlives the geometry that produced it, so a note saved as one tall
      // rectangle would otherwise paint over the line below it. Runs per
      // annotation so each painted band keeps its own colour and id.
      final rects = prepareAnnotationRects(raw, lineBands: (_) => bands);
      for (final rect in rects) {
        out.add(
          _AnnotationBox(
            annotationId: annotation.id,
            rect: Rect.fromLTWH(
              rect.x * viewSize.width,
              rect.y * viewSize.height,
              rect.width * viewSize.width,
              rect.height * viewSize.height,
            ),
            color: annotation.color,
            underline: annotation.style == AnnotationStyle.underline,
          ),
        );
      }
    }
    return out;
  }

  /// This page's text lines as 0..1 bands, from text already in hand.
  ///
  /// Deliberately does not extract: painting runs on the frame path, and a
  /// full content walk there would stall the scroll. Without cached text the
  /// bands are empty and the pipeline falls back to its single-line cap, which
  /// is what the bridge does when it has no line reference either.
  List<PdfLineBand> _lineBands() {
    final ocrBands = <({double top, double bottom})>[
      for (final block in widget.ocrBlocks)
        if (block.hasGeometry)
          (
            top: block.top!.clamp(0.0, 1.0).toDouble(),
            bottom: (block.top! + block.height!).clamp(0.0, 1.0).toDouble(),
          ),
    ];
    if (ocrBands.isNotEmpty) return lineBandsForPage(ocrBands);

    final text = widget.renderer.cachedTextOf(widget.pageIndex);
    if (text == null || text.runs.isEmpty) return const [];
    final geometry = _geometryFor(_pageSize);
    final height = _pageSize.height;
    if (height <= 0) return const [];
    return lineBandsForPage([
      for (final run in text.runs)
        if (run.bounds.width > 0 && run.bounds.height > 0)
          () {
            final rect = geometry.toViewRect(run.bounds);
            return (top: rect.top / height, bottom: rect.bottom / height);
          }(),
    ]);
  }

  PdfSelectionController _selectionFor(Offset globalOrigin) {
    final painted = _paintedSize;
    return PdfSelectionController(
      renderer: widget.renderer,
      pageIndex: widget.pageIndex,
      box: widget.renderer.pageAt(widget.pageIndex).cropBox,
      rotation: _rotation,
      paintSize: painted,
      displayedSize: painted,
      globalOrigin: globalOrigin,
      pageSize: _pageSize,
    );
  }

  PdfTextSelectionSource _textSelectionSource() {
    final ocr = _ocrTextLayout;
    if (ocr != null && !ocr.isEmpty) {
      return PdfOcrSelectionController(
        pageIndex: widget.pageIndex,
        layout: ocr,
        displayedSize: _paintedSize,
        layoutScale: _displayScale,
      );
    }
    return _selectionFor(Offset.zero);
  }

  /// Page-space quad -> view rectangle.
  ///
  /// Search quads are page-space (y-up, crop-box origin), so they need the
  /// rotation-aware projection [PdfPageGeometry] provides.
  Rect _quadToRect(PdfTextQuad quad, Size viewSize) {
    final geometry = _geometryFor(viewSize);
    var rect = Rect.fromPoints(
      geometry.toViewOffset(quad.corners[0].$1, quad.corners[0].$2),
      geometry.toViewOffset(quad.corners[0].$1, quad.corners[0].$2),
    );
    for (final corner in quad.corners.skip(1)) {
      final offset = geometry.toViewOffset(corner.$1, corner.$2);
      rect = rect.expandToInclude(Rect.fromLTWH(offset.dx, offset.dy, 0, 0));
    }
    return rect;
  }

  /// Handles a tap on a `/Link` annotation.
  ///
  /// An in-document `/GoTo` jumps immediately, the way a page-internal
  /// reference works in any reader. An external URI leaves the decision to the
  /// host: opening a browser is visible outside PageSage, and the interaction
  /// spec asks the user to confirm the address first.
  bool _emitLinkTap(Offset local, Size displayed) {
    final links = _linksFor(displayed);
    // Last drawn wins, matching the annotation hit test.
    for (final link in links.reversed) {
      if (!link.rect.contains(local)) continue;
      final page = link.target.destinationPage;
      final uri = link.target.uri;
      if (page != null) {
        widget.onJumpToPage(page);
      } else if (uri != null) {
        widget.onExternalLink(RendererExternalLinkRequested(uri));
      }
      return true;
    }
    return false;
  }

  /// This page's actionable links, projected into view coordinates.
  ///
  /// Read once per page and cached: hitting `/Annots` on every tap would
  /// re-resolve the array, and a link layer is a document property that does
  /// not change while the page is open.
  List<_LinkBox> _linksFor(Size viewSize) {
    final links = _linkQuads.putIfAbsent(
      widget.pageIndex,
      () => PdfDocumentLink.of(widget.renderer.pageAt(widget.pageIndex)),
    );
    if (links.isEmpty) return const [];
    final geometry = _geometryFor(viewSize);
    return [
      for (final link in links)
        _LinkBox(
          target: link,
          // A link's /Rect often wraps just the glyphs, which at fit-width is
          // a couple of millimetres tall; inflate it to a comfortable target
          // so a tap on the words hits the link and not the selection word.
          rect: geometry
              .toViewRect(link.rect)
              .inflate(_linkTouchSlop)
              .intersect(Offset.zero & viewSize),
        ),
    ];
  }

  /// Vertical and horizontal slack around a link's rectangle, in logical
  /// pixels.
  static const _linkTouchSlop = 3.0;

  /// Page-space links per page, read on first tap.
  final Map<int, List<PdfDocumentLink>> _linkQuads = {};

  /// Emits [RendererAnnotationSelected] when a tap lands on a painted
  /// annotation, mirroring the WebView renderer's clickable `<mark>`.
  ///
  /// `sourceRect` is the annotation's band in global logical pixels — the
  /// same units `RendererTextSelected.sourceRect` uses, because the host
  /// places both menus with `_toOverlayLocalRect`.
  bool _emitAnnotationTap(Offset local, Size displayed, Offset globalOrigin) {
    // Topmost first: later boxes paint over earlier ones.
    for (final box in _annotationBoxes(displayed).reversed) {
      if (!box.rect.contains(local)) continue;
      widget.onAnnotationSelected(
        RendererAnnotationSelected(
          box.annotationId,
          sourceRect: ReaderRect(
            page: widget.pageIndex + 1,
            x: globalOrigin.dx + box.rect.left,
            y: globalOrigin.dy + box.rect.top,
            width: box.rect.width,
            height: box.rect.height,
          ),
        ),
      );
      return true;
    }
    return false;
  }
}

final class _PicturePainter extends CustomPainter {
  _PicturePainter(
    this.page, {
    this.highlights = const [],
    this.focusHighlights = const [],
    this.imageFocus = const [],
    this.annotations = const [],
    this.pxPerPoint = 1,
    this.tint = const PdfPageTint.plain(Color(0xFFFFFFFF)),
  });

  final PdfRenderedPage page;
  final List<Rect> highlights;
  final List<Rect> focusHighlights;

  /// Image boxes the jump landed on: framed, never filled.
  final List<Rect> imageFocus;
  final List<_AnnotationBox> annotations;

  /// Painted pixels per PDF point. The canvas is sized in painted pixels, so
  /// overlays land directly; only the point-space picture needs scaling.
  final double pxPerPoint;

  /// Theme adjustment for the page's own colours.
  final PdfPageTint tint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tint.paper);

    // The picture is in PDF point space; scale it into the page box. Because
    // it is recorded as vectors, a zoom change replays it sharply instead of
    // stretching a raster.
    //
    // The theme filter wraps only the picture: highlights, annotations and OCR
    // text are painted afterwards so a night-mode inversion cannot flip their
    // colours into something unreadable.
    final filter = tint.filter;
    if (filter != null) {
      canvas.saveLayer(Offset.zero & size, Paint()..colorFilter = filter);
    }
    canvas.save();
    canvas.scale(pxPerPoint);
    canvas.drawPicture(page.picture);
    canvas.restore();
    if (filter != null) canvas.restore();

    // Over the page: search hits and stored highlights. These must be painted
    // after the picture — anything drawn first is hidden behind the raster.
    final searchFill = Paint()..color = const Color(0x553F8CFF);
    for (final rect in highlights) {
      canvas.drawRect(rect, searchFill);
    }
    // The jumped-to hit gets the amber the WebView used for `focusHit`, so the
    // reader can tell which of the tinted hits the jump landed on.
    final focusFill = Paint()..color = const Color(0x8CFFB300);
    for (final rect in focusHighlights) {
      canvas.drawRect(rect, focusFill);
    }
    for (final rect in imageFocus) {
      _paintImageFrame(canvas, rect, const Color(0xCCFFB300));
    }
    for (final box in annotations) {
      final fill = Paint()
        ..color = pdfAnnotationColor(box.color, night: tint.inverted);
      if (box.imageFrame) {
        _paintImageFrame(canvas, box.rect, fill.color);
        continue;
      }
      if (box.underline) {
        canvas.drawRect(
          Rect.fromLTRB(
            box.rect.left,
            box.rect.bottom - box.rect.height * 0.15,
            box.rect.right,
            box.rect.bottom,
          ),
          fill,
        );
      } else {
        canvas.drawRect(box.rect, fill);
      }
    }
  }

  /// Four corners plus a hairline, so the mark reads as "this picture" without
  /// tinting the picture itself.
  void _paintImageFrame(Canvas canvas, Rect rect, Color color) {
    if (rect.isEmpty) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, stroke);
    final corner = math.min(rect.width, rect.height) * 0.18;
    final heavy = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    // Top-left, top-right, bottom-right, bottom-left.
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(corner, 0), heavy);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, corner), heavy);
    canvas.drawLine(rect.topRight, rect.topRight - Offset(corner, 0), heavy);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, corner), heavy);
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight - Offset(corner, 0),
      heavy,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight - Offset(0, corner),
      heavy,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + Offset(corner, 0),
      heavy,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft - Offset(0, corner),
      heavy,
    );
  }

  @override
  bool shouldRepaint(_PicturePainter old) =>
      old.page != page ||
      old.highlights != highlights ||
      old.focusHighlights != focusHighlights ||
      old.annotations != annotations ||
      old.pxPerPoint != pxPerPoint ||
      old.tint != tint;
}

/// Paints the rasterised page and turns pointer gestures into selection events.
///
/// The widget is laid out at the page's on-screen size and its coordinate
/// space is that same box, so pointer positions and overlay rects need no
/// origin offset or fitted-box compensation.
final class _SelectablePage extends StatefulWidget {
  const _SelectablePage({
    required this.page,
    required this.pageSize,
    required this.highlightedRects,
    required this.focusedRects,
    this.imageFocusRects = const [],
    required this.tint,
    required this.annotations,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
    this.imageBoxMode = false,
    super.key,
  });

  final PdfRenderedPage page;

  /// The page's rotation-aware size in PDF points; the picture is recorded in
  /// this space, so it is what the raster is scaled from.
  final Size pageSize;
  final List<Rect> highlightedRects;

  /// The jumped-to hit, drawn in a stronger colour than [highlightedRects].
  final List<Rect> focusedRects;

  /// Image boxes the jump landed on, painted as a pulsing frame rather than a
  /// wash: a tint over artwork would change what the reader sees.
  final List<Rect> imageFocusRects;
  final PdfPageTint tint;
  final List<_AnnotationBox> annotations;

  final void Function(Offset local) onStart;
  final void Function(Offset local) onUpdate;
  final void Function(Offset local, Offset globalOrigin) onEnd;
  final void Function(Offset globalPosition) onTap;
  final void Function(LongPressStartDetails details) onLongPressStart;
  final void Function(LongPressMoveUpdateDetails details) onLongPressMove;
  final void Function(LongPressEndDetails details) onLongPressEnd;

  /// A drag draws an image box, from a finger as well as a mouse.
  final bool imageBoxMode;

  @override
  State<_SelectablePage> createState() => _SelectablePageState();
}

final class _SelectablePageState extends State<_SelectablePage> {
  final _key = GlobalKey();
  Offset? _lastLocal;

  /// Converts a global pointer position into this widget's local space.
  Offset _toLocal(Offset global) {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    final local = renderBox == null ? global : renderBox.globalToLocal(global);
    _lastLocal = local;
    return local;
  }

  Offset get _globalOrigin {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return Offset.zero;
    return renderBox.localToGlobal(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            // Desktop drag-selection. Touch drags are rejected here so the
            // page-level scale recognizer can pan a zoomed page and pinch to
            // zoom; touch selection is the long-press path below, which only
            // wins after the platform's hold timer so a swipe still scrolls.
            _MousePanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _MousePanGestureRecognizer
                >(
                  () => _MousePanGestureRecognizer(
                    debugOwner: this,
                    allowTouch: widget.imageBoxMode,
                  ),
                  (recognizer) {
                    // Browsers anchor a drag-selection at the pointer-down
                    // position. With the default `start`, the anchor is
                    // wherever the pointer was when the pan was recognised
                    // (past the slop), so the first word under the press is
                    // silently dropped.
                    recognizer.dragStartBehavior = DragStartBehavior.down;
                    recognizer.onStart = (details) =>
                        widget.onStart(_toLocal(details.globalPosition));
                    recognizer.onUpdate = (details) =>
                        widget.onUpdate(_toLocal(details.globalPosition));
                    recognizer.onEnd = (_) {
                      final last = _lastLocal;
                      if (last != null) {
                        widget.onEnd(last, _globalOrigin);
                      }
                    };
                  },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (recognizer) {
                    recognizer.onTapUp = (details) {
                      widget.onTap(details.globalPosition);
                    };
                  },
                ),
            // Long-press selects a word on touch; the subsequent drag before
            // release extends it. `dragStartBehavior` is irrelevant here: the
            // recognizer is armed at press-down and wins only after ~500 ms,
            // so a quick swipe never reaches it.
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(() => LongPressGestureRecognizer(debugOwner: this), (
                  recognizer,
                ) {
                  recognizer
                    ..onLongPressStart = widget.onLongPressStart
                    ..onLongPressMoveUpdate = widget.onLongPressMove
                    ..onLongPressEnd = widget.onLongPressEnd;
                }),
          },
          child: CustomPaint(
            key: _key,
            size: size,
            painter: _PicturePainter(
              widget.page,
              highlights: widget.highlightedRects,
              focusHighlights: widget.focusedRects,
              imageFocus: widget.imageFocusRects,
              annotations: widget.annotations,
              tint: widget.tint,
              pxPerPoint: widget.pageSize.width <= 0
                  ? 1
                  : size.width / widget.pageSize.width,
            ),
          ),
        );
      },
    );
  }
}

/// Pointer kinds that select text on the page.
///
/// The recognizer itself rejects everything else, so a touch drag never
/// competes with (and never wins over) the page-level pan/pinch recognizer.
const Set<PointerDeviceKind> _selectionPointerKinds = {
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
};

final class _MousePanGestureRecognizer extends PanGestureRecognizer {
  _MousePanGestureRecognizer({super.debugOwner, this.allowTouch = false});

  /// While drawing an image box, a finger drags the box too.
  ///
  /// Text selection on touch is long-press, not drag, so there is no conflict
  /// to resolve: a drag means the box and the page-level pinch/pan stays out
  /// of the way because this recognizer is the inner one.
  final bool allowTouch;

  @override
  bool isPointerAllowed(PointerEvent event) {
    final allowed = super.isPointerAllowed(event);
    if (event is! PointerDownEvent) return allowed;
    if (!allowTouch && !_selectionPointerKinds.contains(event.kind)) {
      return false;
    }
    return allowed;
  }
}

/// Pinch and two-axis pan for the page.
///
/// Mouse pointers are rejected: on desktop a mouse drag selects text, and the
/// wheel handles panning and zoom.
final class _TouchScaleGestureRecognizer extends ScaleGestureRecognizer {
  _TouchScaleGestureRecognizer({super.debugOwner});

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return false;
    return super.isPointerAllowed(event);
  }
}

/// A draggable touch handle at one end of the selection.
///
/// The visible knob is small so it does not cover text, but the gesture area
/// is inflated to the 44 px touch minimum. Dragging a handle extends the
/// selection from that end; the page reports pointer positions, and the view
/// decides which caret they mean.
final class _SelectionHandle extends StatelessWidget {
  const _SelectionHandle({
    required this.anchor,
    required this.above,
    required this.onDrag,
    required this.onDragEnd,
    super.key,
  });

  /// The point the handle points at, in the page's view coordinates.
  final Offset anchor;

  /// Whether the knob hangs above the anchor (start) or below it (end).
  final bool above;

  /// Called with the global pointer position while dragging.
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  static const _touchSize = 44.0;
  static const _knob = 12.0;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Positioned(
      left: anchor.dx - _touchSize / 2,
      top: (above ? anchor.dy - _touchSize : anchor.dy) + _knob / 2,
      width: _touchSize,
      height: _touchSize,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          _HandleDragRecognizer:
              GestureRecognizerFactoryWithHandlers<_HandleDragRecognizer>(
                () => _HandleDragRecognizer(debugOwner: this),
                (recognizer) {
                  recognizer.dragStartBehavior = DragStartBehavior.down;
                  recognizer.onStart = (details) =>
                      onDrag(details.globalPosition);
                  recognizer.onUpdate = (details) =>
                      onDrag(details.globalPosition);
                  recognizer.onEnd = (_) => onDragEnd();
                  recognizer.onCancel = onDragEnd;
                },
              ),
        },
        child: Center(
          child: CustomPaint(
            size: const Size(_knob, _knob),
            painter: _HandlePainter(color: accent),
          ),
        ),
      ),
    );
  }
}

/// Claims a handle drag before the reading list does.
///
/// A plain pan recognizer loses the arena to the continuous list's vertical
/// drag, so dragging a handle scrolled the page and never extended the
/// selection. Accepting at pointer-down — the handle is the innermost
/// recognizer, so it wins outright — makes a 44 px handle box behave like a
/// native selection grip: it owns the pointer for the whole drag.
final class _HandleDragRecognizer extends PanGestureRecognizer {
  _HandleDragRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

final class _HandlePainter extends CustomPainter {
  const _HandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.shortestSide / 2, Paint()..color = color);
    canvas.drawCircle(
      center,
      size.shortestSide / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_HandlePainter old) => old.color != color;
}

/// A document link projected into view coordinates.
final class _LinkBox {
  const _LinkBox({required this.target, required this.rect});

  final PdfDocumentLink target;

  /// The link's clickable area in view coordinates.
  final Rect rect;
}

/// A stored annotation projected into view coordinates.
final class _AnnotationBox {
  const _AnnotationBox({
    required this.annotationId,
    required this.rect,
    required this.color,
    required this.underline,
    this.imageFrame = false,
  });

  final String annotationId;
  final Rect rect;
  final AnnotationColor color;
  final bool underline;

  /// Draw brackets around the box instead of filling it (image annotations).
  final bool imageFrame;
}

/// [PdfPageImageSource] over an open [PdfCanvasView].
///
/// Holds the view, not the renderer: the view replaces its renderer when the
/// document is reopened, and the reader must keep exporting from whatever is
/// open now. All page math is 1-based here because that is what OCR reports.
final class _CanvasPageImageSource implements PdfPageImageSource {
  _CanvasPageImageSource(this._view);

  final _PdfCanvasViewState _view;

  @override
  Future<Uint8List?> exportPageImage({
    required int pageNumber,
    double quality = 0.86,
  }) {
    final renderer = _view._renderer;
    if (renderer == null) return Future<Uint8List?>.value();
    return renderer.exportPageImage(pageNumber - 1);
  }

  @override
  Future<Uint8List?> exportPageRegion({
    required int pageNumber,
    required ReaderRect rect,
  }) {
    final renderer = _view._renderer;
    if (renderer == null) return Future<Uint8List?>.value();
    return renderer.exportPageRegion(pageNumber - 1, rect);
  }

  @override
  Future<List<int>> getVisiblePages({int? fallbackPage}) async {
    final renderer = _view._renderer;
    final fallback = fallbackPage == null || fallbackPage < 1
        ? _view._currentPage + 1
        : fallbackPage;
    if (renderer == null) return [fallback];
    // One page is on screen at a time in continuous mode; a spread shows two
    // and OCR should cover both, matching what the reader is looking at.
    if (_view._displayMode(renderer.pageCount) != PdfDisplayMode.double) {
      return [fallback];
    }
    final start = _view._currentPage + 1;
    final end = pdfSpreadFor(
      pageIndex: _view._currentPage,
      pageCount: renderer.pageCount,
      mode: PdfDisplayMode.double,
    ).end;
    return [for (var page = start; page <= end + 1; page += 1) page];
  }
}

/// Placeholder for a page the interpreter could not produce.
///
/// A single unreadable page is a property of that page, not of the book: the
/// reader must be able to keep reading the rest and retry just this one. The
/// WebView renderer had no equivalent because pdf.js drew its own error, and
/// without this the canvas renderer left a spinner running for a page that was
/// never coming.
final class _PageFailure extends StatelessWidget {
  const _PageFailure({required this.pageNumber, required this.onRetry});

  final int pageNumber;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                '第 $pageNumber 页无法显示',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
