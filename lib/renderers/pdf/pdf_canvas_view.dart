import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../domain/annotations/annotation.dart';
import '../../domain/books/book.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import '../common/renderer_event.dart';
import '../epub/epub_jump.dart';
import 'pdf_canvas_renderer.dart';
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
/// Sits beside the WebView-backed [PdfRendererView] and can replace it once
/// panning, text selection and annotation overlays are ported; see
/// `docs/10-pdf-renderer-migration.md`.
///
/// S1 makes zoom a single resolved scale: the page slot, the picture transform
/// and `locator.zoom` all derive from [resolvePdfZoom], so a page is never
/// fitted twice and a rotated page is laid out at its rotated size.
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
    this.onZoomChanged,
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

  /// Pinch, Ctrl+wheel and double-click zoom. The host persists the result;
  /// the renderer keeps painting the transient scale until the new settings
  /// arrive, so the page never jumps back for a frame.
  final PdfZoomChanged? onZoomChanged;

  @override
  ConsumerState<PdfCanvasView> createState() => _PdfCanvasViewState();
}

final class _PdfCanvasViewState extends ConsumerState<PdfCanvasView> {
  final _pageController = PageController();
  Timer? _locationTimer;

  PdfCanvasRenderer? _renderer;
  String? _error;
  int _currentPage = 0;
  bool _readySent = false;
  String _lastReportedSearchQuery = '';

  /// Page index -> quads in page space; each page widget converts these
  /// to widget coordinates using its own painted box.
  final Map<int, List<PdfTextQuad>> _searchHighlights = {};

  /// Layout scale of the current page, in logical pixels per PDF point.
  ///
  /// The page widget reports the scale it actually laid out at; `locator.zoom`
  /// must carry this value (what the WebView renderer exposed as
  /// `dataset.scale`), not the raw `pdfScale` setting.
  double _layoutScale = 1;

  /// Result of the text-layer probe, or null while it is still running.
  bool? _nativeTextLayer;

  /// Whether the user has zoomed in this session.
  ///
  /// The bridge coerced a saved custom scale to fit-width when a document
  /// opened on a phone; without this flag that coercion would also undo the
  /// user's own pinch on the next rebuild.
  bool _userAdjustedScale = false;

  @override
  void initState() {
    super.initState();
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
    // The host puts the jump target in `initialProgress`: `_jumpProgress`
    // carries the enriched locator, while `focusLocator` is only set when the
    // target can be flashed. Reading focusLocator dropped every page-number
    // and outline jump that had no excerpt.
    if (oldWidget.jumpToken != widget.jumpToken) {
      unawaited(_jumpToLocator(widget.initialProgress?.locator));
    }
    if (oldWidget.ocrOverlayToken != widget.ocrOverlayToken ||
        oldWidget.ocrOverlayPage != widget.ocrOverlayPage) {
      _emitCapabilities();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final file = File(widget.book.libraryFilePath);
      if (!file.existsSync()) {
        throw StateError('文件不存在: ${widget.book.libraryFilePath}');
      }
      final doc = PdfDocument.open(await file.readAsBytes());
      if (!mounted) return;

      final renderer = PdfCanvasRenderer(doc);
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
      unawaited(_detectCapabilities(renderer));

      // PageView only exists once the build above has run, so a jump issued
      // here has no clients and is silently dropped. Restore on the first
      // frame instead; without it the reader opens on page 1 while reporting
      // the saved page, and the first swipe rewrites progress to page 2.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        if ((_pageController.page ?? 0).round() != _currentPage) {
          _pageController.jumpToPage(_currentPage);
        }
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
    final hasOcr =
        widget.ocrOverlayPage != null && widget.ocrOverlayBlocks.isNotEmpty;
    final reason = native
        ? null
        : hasOcr
        ? '已叠加 OCR 文本层，划词暂未启用。'
        : '此 PDF 没有文本层，划词、高亮与搜索不可用。可使用「识别可见页」提取文字。';
    widget.onEvent(
      RendererCapabilityChanged(
        // OCR block selection lands in S5; until then only native text is
        // selectable. Search never covers OCR text in v1
        // (`v1-experience-freeze.md` §5), so it follows the native flag.
        textSelection: native,
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
    final page = _currentPage + 1;
    // progress is page-based; the WebView renderer used the same convention.
    final progress = pageCount <= 1 ? 1.0 : (page - 1) / (pageCount - 1);
    // The WebView renderer skipped excerpts on phones: scanning the text layer
    // is a layout-heavy pass and the excerpt is only used to flash a phrase
    // after a jump. Capture the width now; reading MediaQuery from the timer
    // would register an inherited-widget dependency outside build.
    final includeExcerpt = MediaQuery.sizeOf(context).width >= 900;

    _locationTimer?.cancel();
    _locationTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      String? excerpt;
      if (includeExcerpt) {
        try {
          excerpt = compactLocatorExcerpt(
            _renderer?.textOf(_currentPage).text,
            maxChars: 120,
          );
        } on Object {
          excerpt = null;
        }
      }
      widget.onEvent(
        RendererLocationChanged(
          locator: ReadingLocator.pdf(
            page: page,
            // scrollOffset stays 0 until continuous scrolling lands (S2).
            zoom: _layoutScale,
            progress: progress.clamp(0.0, 1.0),
            excerpt: excerpt,
          ),
          progress: progress.clamp(0.0, 1.0),
          pageNumber: page,
          totalPages: pageCount,
        ),
      );
    });
  }

  /// Upper bound on reported hits, matching the EPUB renderer. Without it a
  /// query common to a large document would walk every page synchronously.
  static const _maxSearchResults = 100;

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

    // Text extraction is synchronous per page, so yield between pages to keep
    // the UI responsive on long documents.
    for (var page = 0; page < renderer.pageCount; page++) {
      if (results.length >= _maxSearchResults) break;
      if (page % 4 == 0) await Future<void>.delayed(Duration.zero);

      final PdfPageText pageText;
      try {
        pageText = renderer.textOf(page);
      } on Object {
        continue; // A page that cannot be parsed should not abort the search.
      }
      if (pageText.text.isEmpty) continue;

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

    final target = page - 1;
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    if (mounted && target != _currentPage) {
      setState(() => _currentPage = target);
    }
    _reportLocation(renderer.pageCount);
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
    final target = _currentPage + delta;
    if (target < 0 || target >= renderer.pageCount) return;
    unawaited(
      _pageController.animateToPage(
        target,
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

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: renderer.pageCount,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _reportLocation(renderer.pageCount);
            },
            itemBuilder: (context, index) => _CanvasPage(
              renderer: renderer,
              pageIndex: index,
              settings: widget.settings,
              zoomMode: zoomMode,
              narrow: narrow,
              searchQuads: _searchHighlights[index] ?? const [],
              annotations: widget.annotations,
              ocrBlocks: widget.ocrOverlayPage == index + 1
                  ? widget.ocrOverlayBlocks
                  : const [],
              onSelection: widget.onEvent,
              onAnnotationSelected: widget.onEvent,
              onZoomChanged: _handleZoomChanged,
              onPageTurn: _turnPage,
              onLayoutScaleChanged: index == _currentPage
                  ? (scale) {
                      _layoutScale = scale;
                    }
                  : null,
            ),
          ),
        ),
        _PdfCanvasPager(
          page: _currentPage + 1,
          total: renderer.pageCount,
          onPrev: _currentPage > 0
              ? () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                )
              : null,
          onNext: _currentPage < renderer.pageCount - 1
              ? () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                )
              : null,
        ),
      ],
    );
  }
}

/// One page, laid out at the resolved zoom and panned inside the viewport.
final class _CanvasPage extends StatefulWidget {
  const _CanvasPage({
    required this.renderer,
    required this.pageIndex,
    required this.settings,
    required this.zoomMode,
    required this.narrow,
    required this.searchQuads,
    required this.annotations,
    required this.ocrBlocks,
    required this.onSelection,
    required this.onAnnotationSelected,
    required this.onZoomChanged,
    required this.onPageTurn,
    this.onLayoutScaleChanged,
  });

  final PdfCanvasRenderer renderer;
  final int pageIndex;
  final ReaderSettings settings;

  /// Already coerced for narrow viewports by [effectivePdfZoomMode].
  final PdfZoomMode zoomMode;
  final bool narrow;
  final List<PdfTextQuad> searchQuads;
  final List<Annotation> annotations;
  final List<Map<String, Object?>> ocrBlocks;
  final ValueChanged<RendererTextSelected> onSelection;
  final ValueChanged<RendererAnnotationSelected> onAnnotationSelected;
  final PdfZoomChanged onZoomChanged;
  final ValueChanged<int> onPageTurn;

  /// Reports the page's logical-pixels-per-point after layout, for
  /// `locator.zoom`. Only the current page passes a callback.
  final ValueChanged<double>? onLayoutScaleChanged;

  @override
  State<_CanvasPage> createState() => _CanvasPageState();
}

final class _CanvasPageState extends State<_CanvasPage> {
  Future<PdfRenderedPage>? _future;

  /// The page box, in logical pixels, before panning.
  Size _viewport = Size.zero;

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

  Offset? _dragAnchor;
  bool _dragSelecting = false;
  List<Rect> _selectionHighlights = const [];

  /// The page's rotation-aware display size, in PDF points.
  ///
  /// `PdfPageRenderer.pageSize` applies /Rotate, so a 90° page lays out and
  /// paints as landscape instead of being cropped to its unrotated box.
  Size get _pageSize => widget.renderer.displaySizeOf(widget.pageIndex);

  int get _rotation => widget.renderer.pageAt(widget.pageIndex).rotation;

  PdfZoomGeometry? get _geometry =>
      _viewport.isEmpty ? null : _resolveGeometry(_viewport);

  PdfZoomGeometry _resolveGeometry(Size viewport) => resolvePdfZoom(
    mode: widget.zoomMode,
    customScale: widget.settings.pdfScale,
    pageSize: _pageSize,
    viewport: viewport,
    narrow: widget.narrow,
    pageMargin: widget.settings.pageMargin,
  );

  double get _displayScale =>
      _transientScale ?? _geometry?.scale ?? widget.settings.pdfScale;

  /// Size the page occupies on screen at the current scale.
  Size get _paintedSize =>
      Size(_pageSize.width * _displayScale, _pageSize.height * _displayScale);

  @override
  void initState() {
    super.initState();
    // The picture is recorded in page space (one unit per PDF point) and
    // replayed at whatever size the page is laid out at, so it never has to
    // be re-rendered for a zoom change. S1 therefore has no page cache to
    // clear on `didUpdateWidget`; theme work in S6 will add one.
    _future = widget.renderer.renderPage(widget.pageIndex);
  }

  @override
  void didUpdateWidget(covariant _CanvasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _future?.then((page) => page.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _viewport = viewport;
        final geometry = _resolveGeometry(viewport);
        final scale = _transientScale ?? geometry.scale;
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

        // Report the layout scale once per frame; the parent stores it for
        // `locator.zoom`. Doing it in the builder (not in a post-frame hook)
        // keeps the value in sync with what the user is actually looking at.
        final onScale = widget.onLayoutScaleChanged;
        if (onScale != null && _pageSize.width > 0) {
          onScale(scale);
        }

        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
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
            },
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: origin.dx,
                    top: origin.dy,
                    width: content.width,
                    height: content.height,
                    child: FutureBuilder<PdfRenderedPage>(
                      future: _future,
                      builder: (context, snapshot) {
                        final page = snapshot.data;
                        if (page == null) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _SelectablePage(
                          key: ValueKey(page),
                          page: page,
                          pageSize: _pageSize,
                          highlightedRects: [
                            for (final q in widget.searchQuads)
                              _quadToRect(q, _pageSize),
                            ..._selectionHighlights,
                          ],
                          annotations: _annotationBoxes(_paintedSize),
                          ocrBoxes: _ocrBoxes(_paintedSize),
                          onStart: _onDragStart,
                          onUpdate: _onDragUpdate,
                          onEnd: _onDragEnd,
                          onTap: _handleTap,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
    final geometry = _resolveGeometry(viewport);
    final scale = _transientScale ?? geometry.scale;
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
      _applyZoom(_displayScale + (notches < 0 ? pdfZoomStep : -pdfZoomStep));
      return;
    }

    final content = _paintedSize;
    // A page wider than the viewport can only happen past fit-width, and
    // there the wheel has to pan or the page would be unreachable: mouse
    // drags select text, so the wheel is the only pointer way to move it.
    // A page that is only taller (fit-width on a portrait page) still turns
    // pages, matching the bridge's single/double display behaviour.
    if (content.width > viewport.width + 0.5) {
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

    // Bridge behaviour for single/double display: the wheel turns pages.
    // S2 replaces this with real scrolling in continuous mode.
    final vertical = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (vertical.abs() < 4) return;
    final now = DateTime.now();
    if (now.difference(_lastWheelTurn) < const Duration(milliseconds: 180)) {
      return;
    }
    _lastWheelTurn = now;
    widget.onPageTurn(vertical > 0 ? 1 : -1);
  }

  /// Sets the zoom for the session and hands it to the host to persist.
  void _applyZoom(double target, {PdfZoomMode mode = PdfZoomMode.custom}) {
    final scale = target.clamp(pdfZoomMin, pdfZoomMax).toDouble();
    setState(() => _transientScale = mode == PdfZoomMode.custom ? scale : null);
    widget.onZoomChanged(scale, mode);
  }

  /// Mouse double-click toggles fit-width and 2x, per the plan's S1 step 7.
  void _handleTap(Offset globalPosition) {
    final now = DateTime.now();
    final lastAt = _lastTapAt;
    final lastPosition = _lastTapGlobal;
    _lastTapAt = now;
    _lastTapGlobal = globalPosition;
    if (lastAt == null ||
        lastPosition == null ||
        now.difference(lastAt) > const Duration(milliseconds: 300) ||
        (globalPosition - lastPosition).distance > 24) {
      return;
    }
    _lastTapAt = null;
    _lastTapGlobal = null;
    if (widget.zoomMode == PdfZoomMode.fitWidth) {
      _applyZoom(2.0);
    } else {
      // Fit-width is a mode, not a scale; the host resolves it from the
      // viewport, so the scale we pass is ignored.
      _applyZoom(_displayScale, mode: PdfZoomMode.fitWidth);
    }
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
    final out = <_AnnotationBox>[];
    for (final annotation in widget.annotations) {
      if (annotation.locator.page != widget.pageIndex + 1) continue;
      for (final rect in annotation.locator.selectionRects) {
        if (rect.width <= 0 || rect.height <= 0) continue;

        // A multi-line selection can persist as one tall box; collapse it to a
        // single readable band, matching the WebView renderer. F-02 lands in
        // S5; until then this is the same approximation the WebView uses.
        final height = rect.height > 0.055 ? 0.022 : rect.height;
        out.add(
          _AnnotationBox(
            annotationId: annotation.id,
            rect: Rect.fromLTWH(
              rect.x * viewSize.width,
              rect.y * viewSize.height,
              rect.width * viewSize.width,
              height * viewSize.height,
            ),
            color: annotation.color,
            underline: annotation.style == AnnotationStyle.underline,
          ),
        );
      }
    }
    return out;
  }

  /// OCR text-layer boxes for a scanned page, in view coordinates.
  ///
  /// OCR blocks are 0..1 fractions of the displayed page box (the OCR pipeline
  /// rasterises exactly what is on screen), so they use the same direct
  /// projection as annotations.
  List<_OcrBox> _ocrBoxes(Size viewSize) {
    final out = <_OcrBox>[];
    for (final block in widget.ocrBlocks) {
      final text = block['text'];
      final left = block['left'];
      final top = block['top'];
      final width = block['width'];
      final height = block['height'];
      if (text is! String || text.trim().isEmpty) continue;
      if (left is! num || top is! num || width is! num || height is! num) {
        continue;
      }
      if (width <= 0 || height <= 0) continue;

      out.add(
        _OcrBox(
          rect: Rect.fromLTWH(
            left.toDouble() * viewSize.width,
            top.toDouble() * viewSize.height,
            width.toDouble() * viewSize.width,
            height.toDouble() * viewSize.height,
          ),
          text: text,
        ),
      );
    }
    return out;
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

  void _onDragStart(Offset local) {
    final controller = _selectionFor(Offset.zero);
    if (!controller.hasText) return;
    setState(() {
      _dragAnchor = local;
      _dragSelecting = true;
      _selectionHighlights = const [];
    });
  }

  void _onDragUpdate(Offset local) {
    if (!_dragSelecting) return;
    final controller = _selectionFor(Offset.zero);
    final anchor = _dragAnchor;
    if (anchor == null) return;

    // Live highlight feedback in view coordinates; the selection itself is
    // only committed on drag end.
    final displayed = _paintedSize;
    final rect = controller.selectionBetween(anchor, local);
    setState(() {
      _selectionHighlights = rect == null
          ? const []
          : [
              for (final r in rect.selectionRects)
                Rect.fromLTWH(
                  r.x * displayed.width,
                  r.y * displayed.height,
                  r.width * displayed.width,
                  r.height * displayed.height,
                ),
            ];
    });
  }

  void _onDragEnd(Offset local, Offset globalOrigin) {
    final controller = _selectionFor(globalOrigin);
    final anchor = _dragAnchor;
    final wasDragging = _dragSelecting;
    _dragAnchor = null;
    if (wasDragging) {
      setState(() => _dragSelecting = false);
    }
    if (!wasDragging) {
      // A tap never sets _dragSelecting, so bailing out here made tap-to-select
      // a no-op. A tap on a painted annotation opens its actions menu; a tap
      // anywhere else selects the word under the pointer. The drag threshold
      // only exists to tell the two gestures apart when a pan did start.
      if (_emitAnnotationTap(local, _paintedSize, globalOrigin)) return;
      final tapped = controller.selectionAtWord(local);
      _applySelection(tapped);
      return;
    }
    if (anchor == null) return;

    final drag = (local - anchor).distance;
    final selection = drag < 6
        // A tap selects the word under it.
        ? controller.selectionAtWord(local)
        : controller.selectionBetween(anchor, local);
    _applySelection(selection);
  }

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

  /// Paints the highlight for [selection] and hands it to the host.
  void _applySelection(RendererTextSelected? selection) {
    final displayed = _paintedSize;
    if (selection == null || selection.selectionRects.isEmpty) {
      setState(() => _selectionHighlights = const []);
      return;
    }
    setState(() {
      _selectionHighlights = [
        for (final r in selection.selectionRects)
          Rect.fromLTWH(
            r.x * displayed.width,
            r.y * displayed.height,
            r.width * displayed.width,
            r.height * displayed.height,
          ),
      ];
    });
    widget.onSelection(selection);
  }
}

final class _PicturePainter extends CustomPainter {
  _PicturePainter(
    this.page, {
    this.highlights = const [],
    this.annotations = const [],
    this.ocrBoxes = const [],
    this.pxPerPoint = 1,
  });

  final PdfRenderedPage page;
  final List<Rect> highlights;
  final List<_AnnotationBox> annotations;
  final List<_OcrBox> ocrBoxes;

  /// Painted pixels per PDF point. The canvas is sized in painted pixels, so
  /// overlays land directly; only the point-space picture needs scaling.
  final double pxPerPoint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // The picture is in PDF point space; scale it into the page box. Because
    // it is recorded as vectors, a zoom change replays it sharply instead of
    // stretching a raster.
    canvas.save();
    canvas.scale(pxPerPoint);
    canvas.drawPicture(page.picture);
    canvas.restore();

    // Over the page: search hits and stored highlights. These must be painted
    // after the picture — anything drawn first is hidden behind the raster.
    final searchFill = Paint()..color = const Color(0x553F8CFF);
    for (final rect in highlights) {
      canvas.drawRect(rect, searchFill);
    }
    for (final box in annotations) {
      final fill = Paint()..color = _annotationColor(box.color);
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

    // Also over the page: recognised text on scanned pages.
    for (final box in ocrBoxes) {
      if (!box.rect.isEmpty) _paintOcrText(canvas, box);
    }
  }

  void _paintOcrText(Canvas canvas, _OcrBox box) {
    final fontSize = math.max(4.0, box.rect.height * 0.8);
    final painter = TextPainter(
      text: TextSpan(
        text: box.text,
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF1A1A1A),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: box.rect.width);
    painter.paint(canvas, box.rect.topLeft);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_PicturePainter old) =>
      old.page != page ||
      old.highlights != highlights ||
      old.annotations != annotations ||
      old.ocrBoxes != ocrBoxes ||
      old.pxPerPoint != pxPerPoint;
}

final class _PdfCanvasPager extends StatelessWidget {
  const _PdfCanvasPager({
    required this.page,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  final int page;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一页',
            onPressed: onPrev,
          ),
          Text('第 $page / $total 页'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一页',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
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
    required this.annotations,
    required this.ocrBoxes,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onTap,
    super.key,
  });

  final PdfRenderedPage page;

  /// The page's rotation-aware size in PDF points; the picture is recorded in
  /// this space, so it is what the raster is scaled from.
  final Size pageSize;
  final List<Rect> highlightedRects;
  final List<_AnnotationBox> annotations;
  final List<_OcrBox> ocrBoxes;

  final void Function(Offset local) onStart;
  final void Function(Offset local) onUpdate;
  final void Function(Offset local, Offset globalOrigin) onEnd;
  final void Function(Offset globalPosition) onTap;

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
            // Selection is a mouse gesture, like a desktop PDF viewer. Touch
            // drags are rejected here so the page-level scale recognizer can
            // pan a zoomed page and pinch to zoom; mobile word selection
            // arrives with long-press handles in S3.
            _MousePanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _MousePanGestureRecognizer
                >(() => _MousePanGestureRecognizer(debugOwner: this), (
                  recognizer,
                ) {
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
                }),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (recognizer) {
                    recognizer.onTapUp = (details) {
                      widget.onTap(details.globalPosition);
                      widget.onEnd(
                        _toLocal(details.globalPosition),
                        _globalOrigin,
                      );
                    };
                  },
                ),
          },
          child: CustomPaint(
            key: _key,
            size: size,
            painter: _PicturePainter(
              widget.page,
              highlights: widget.highlightedRects,
              annotations: widget.annotations,
              ocrBoxes: widget.ocrBoxes,
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
  _MousePanGestureRecognizer({super.debugOwner});

  @override
  bool isPointerAllowed(PointerEvent event) {
    final allowed = super.isPointerAllowed(event);
    if (event is! PointerDownEvent) return allowed;
    if (!_selectionPointerKinds.contains(event.kind)) return false;
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

/// A stored annotation projected into view coordinates.
final class _AnnotationBox {
  const _AnnotationBox({
    required this.annotationId,
    required this.rect,
    required this.color,
    required this.underline,
  });

  final String annotationId;
  final Rect rect;
  final AnnotationColor color;
  final bool underline;
}

/// One OCR text block projected into view coordinates.
final class _OcrBox {
  const _OcrBox({required this.rect, required this.text});

  final Rect rect;
  final String text;
}

Color _annotationColor(AnnotationColor color) => switch (color) {
  AnnotationColor.yellow => const Color(0x66FFD54F),
  AnnotationColor.blue => const Color(0x664FC3F7),
  AnnotationColor.green => const Color(0x6681C784),
  AnnotationColor.red => const Color(0x66E57373),
  AnnotationColor.purple => const Color(0x66BA68C8),
};
