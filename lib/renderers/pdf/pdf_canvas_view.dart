import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import '../../domain/books/book.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import '../common/renderer_event.dart';
import '../epub/epub_jump.dart';
import 'pdf_canvas_renderer.dart';
import 'pdf_selection_controller.dart';

/// PDF renderer built on `pdf_graphics` painting straight to a Flutter Canvas.
///
/// Sits beside the WebView-backed [PdfRendererView] and can replace it once
/// panning, text selection and annotation overlays are ported; see
/// `docs/10-pdf-renderer-migration.md`.
///
/// This first slice covers page display, zoom modes, paging, and the
/// location/ready events the reader host needs to persist progress. Selection
/// and search are reported as unsupported for now.
final class PdfCanvasView extends ConsumerStatefulWidget {
  const PdfCanvasView({
    required this.book,
    required this.settings,
    required this.initialProgress,
    required this.onEvent,
    this.searchQuery,
    this.focusLocator,
    this.jumpToken = 0,
    this.clearSearchHighlightsVersion = 0,
    super.key,
  });

  final Book book;
  final ReaderSettings settings;
  final ReadingProgressSnapshot? initialProgress;
  final ValueChanged<RendererEvent> onEvent;
  final String? searchQuery;
  final ReadingLocator? focusLocator;

  /// Bumped by the host to jump to [focusLocator] without remounting.
  final int jumpToken;

  /// Bumped by the host to drop search highlights.
  final int clearSearchHighlightsVersion;

  @override
  ConsumerState<PdfCanvasView> createState() => _PdfCanvasViewState();
}

final class _PdfCanvasViewState extends ConsumerState<PdfCanvasView> {
  final _pageController = PageController();
  Timer? _locationTimer;

  PdfCanvasRenderer? _renderer;
  Object? _error;
  int _currentPage = 0;
  bool _readySent = false;
  String _lastReportedSearchQuery = '';
  /// Page index -> quads in page space; each page widget converts these
  /// to widget coordinates using its own painted box.
  final Map<int, List<PdfTextQuad>> _searchHighlights = {};

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
    if (oldWidget.jumpToken != widget.jumpToken ||
        oldWidget.focusLocator != widget.focusLocator) {
      unawaited(_jumpToFocus());
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
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }

      // Capability first: the host enables selection/search UI from this, so a
      // silent selection path would leave the reader offering dead buttons.
      widget.onEvent(
        const RendererCapabilityChanged(
          textSelection: true,
          search: true,
        ),
      );
      widget.onEvent(RendererReady());
      _readySent = true;
      _reportLocation(doc.pageCount);
      unawaited(_runSearch());
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
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

    _locationTimer?.cancel();
    _locationTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      widget.onEvent(
        RendererLocationChanged(
          locator: ReadingLocator.pdf(
            page: page,
            zoom: widget.settings.pdfScale,
            progress: progress.clamp(0.0, 1.0),
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
              zoom: widget.settings.pdfScale,
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

  Future<void> _jumpToFocus() async {
    final renderer = _renderer;
    final focus = widget.focusLocator;
    if (renderer == null || focus == null) return;
    final page = focus.page;
    if (page == null || page < 1 || page > renderer.pageCount) return;

    final target = page - 1;
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    if (mounted && target != _currentPage) setState(() => _currentPage = target);
    _reportLocation(renderer.pageCount);
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
              searchQuads: _searchHighlights[index] ?? const [],
              onSelection: widget.onEvent,
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

/// One rasterised page, fitted into the available box.
final class _CanvasPage extends StatefulWidget {
  const _CanvasPage({
    required this.renderer,
    required this.pageIndex,
    required this.settings,
    required this.searchQuads,
    required this.onSelection,
  });

  final PdfCanvasRenderer renderer;
  final int pageIndex;
  final ReaderSettings settings;

  /// Page-space quads to paint as search highlights.
  final List<PdfTextQuad> searchQuads;
  final ValueChanged<RendererTextSelected> onSelection;

  @override
  State<_CanvasPage> createState() => _CanvasPageState();
}

final class _CanvasPageState extends State<_CanvasPage> {
  Future<PdfRenderedPage>? _future;

  Size _lastBox = Size.zero;
  Offset? _dragAnchor;
  bool _dragSelecting = false;
  List<Rect> _selectionHighlights = const [];
  Rect _paintOrigin = Rect.zero;

  // Rendering waits for LayoutBuilder: the fit-width and fit-page zoom modes
  // resolve against the real paint box, which is not known until layout. A
  // zero-size or MediaQuery-derived guess would rasterise at the wrong scale
  // and then have to be redone.

  /// Device-pixel scale to rasterise the page at.
  ///
  /// Layout is handled by the FittedBox below, which scales the whole page to
  /// fit the viewport. So this must only control raster density: multiplying
  /// here by the viewport/page ratio would apply that fit twice and crop the
  /// page. `custom` still honours the user's explicit scale.
  double _resolveScale(Size viewport) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (widget.settings.pdfZoomMode != PdfZoomMode.custom) return dpr;
    return widget.settings.pdfScale <= 0 ? dpr : widget.settings.pdfScale * dpr;
  }

  void _render(Size viewport) {
    _lastBox = viewport;
    _future = widget.renderer.renderPage(
      widget.pageIndex,
      zoom: _resolveScale(viewport),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport != _lastBox) _render(viewport);

        // FittedBox centres the page inside the slot; search quads arrive in
        // page points, so they need the same origin the selection controller
        // uses. Recomputed here rather than stored by the parent because only
        // this widget knows its own constraints.
        _paintOrigin = _computePaintOrigin(constraints);

        return Center(
          child: FutureBuilder<PdfRenderedPage>(
            future: _future,
            builder: (context, snapshot) {
              final page = snapshot.data;
              if (page == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final box = widget.renderer.pageAt(widget.pageIndex).cropBox;
              return SizedBox(
                width: box.width,
                height: box.height,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _SelectablePage(
                    page: page,
                    box: box,
                    highlights: [
                      for (final q in widget.searchQuads) _quadToRect(q),
                      ..._selectionHighlights,
                    ],
                    onStart: _onDragStart,
                    onUpdate: _onDragUpdate,
                    onEnd: _onDragEnd,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Where FittedBox lands the page inside [constraints], in the page widget's
  /// own coordinate space. Selection and search highlights both need it, so it
  /// is derived once per layout rather than in two places.
  Rect _computePaintOrigin(BoxConstraints constraints) {
    final box = widget.renderer.pageAt(widget.pageIndex).cropBox;
    final scale = math.min(
      constraints.maxWidth / box.width,
      constraints.maxHeight / box.height,
    );
    final painted = Size(box.width * scale, box.height * scale);
    return Rect.fromLTWH(
      (constraints.maxWidth - painted.width) / 2,
      (constraints.maxHeight - painted.height) / 2,
      painted.width,
      painted.height,
    );
  }

  PdfSelectionController? _selectionFor(BoxConstraints constraints) {
    final box = widget.renderer.pageAt(widget.pageIndex).cropBox;
    final paint = _computePaintOrigin(constraints);
    return PdfSelectionController(
      renderer: widget.renderer,
      pageIndex: widget.pageIndex,
      box: box,
      rasterScale: 1,
      paintOrigin: paint.topLeft,
      paintSize: paint.size,
    );
  }

  /// Page-space quad -> widget rectangle, using the same origin as selection.
  Rect _quadToRect(PdfTextQuad quad) {
    final box = widget.renderer.pageAt(widget.pageIndex).cropBox;
    final paint = _paintOrigin;
    if (paint.width <= 0 || paint.height <= 0) return Rect.zero;

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final corner in quad.corners) {
      final x = paint.left + (corner.$1 - box.left) / box.width * paint.width;
      final y = paint.top + (box.top - corner.$2) / box.height * paint.height;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    if (!minX.isFinite || !minY.isFinite) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _onDragStart(Offset local, BoxConstraints constraints) {
    final controller = _selectionFor(constraints);
    if (controller == null || !controller.hasText) return;
    setState(() {
      _dragAnchor = local;
      _dragSelecting = true;
      _selectionHighlights = const [];
    });
  }

  void _onDragUpdate(Offset local, BoxConstraints constraints) {
    if (!_dragSelecting) return;
    final controller = _selectionFor(constraints);
    final anchor = _dragAnchor;
    if (controller == null || anchor == null) {
        return;
    }

    // Live highlight feedback; the selection is only committed on drag end.
    final rect = controller.selectionBetween(anchor, local);
    setState(() {
      _selectionHighlights = rect == null
          ? const []
          : [
              for (final r in rect.selectionRects)
                Rect.fromLTWH(r.x, r.y, r.width, r.height),
            ];
    });
  }

  void _onDragEnd(Offset local, BoxConstraints constraints) {
    if (!_dragSelecting) return;
    setState(() => _dragSelecting = false);

    final controller = _selectionFor(constraints);
    final anchor = _dragAnchor;
    if (controller == null || anchor == null) return;

    final drag = (local - anchor).distance;
    final selection = drag < 6
        // A tap selects the word under it.
        ? controller.selectionAtWord(local)
        : controller.selectionBetween(anchor, local);

    if (selection == null || selection.selectionRects.isEmpty) {
      setState(() => _selectionHighlights = const []);
      return;
    }
    setState(() {
      _selectionHighlights = [
        for (final r in selection.selectionRects)
          Rect.fromLTWH(r.x, r.y, r.width, r.height),
      ];
    });
    widget.onSelection(selection);
  }

  @override
  void dispose() {
    _future?.then((page) => page.dispose());
    super.dispose();
  }
}

final class _PicturePainter extends CustomPainter {
  _PicturePainter(this.page, {this.highlights = const []});

  final PdfRenderedPage page;
  final List<Rect> highlights;

  @override
  void paint(Canvas canvas, Size size) {
    // Paper white: PDF pages assume an opaque background.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));

    // Selection highlight sits under the page content, matching how the
    // WebView renderer layered highlights beneath the text.
    if (highlights.isNotEmpty) {
      final fill = Paint()..color = const Color(0x553F8CFF);
      for (final rect in highlights) {
        canvas.drawRect(rect, fill);
      }
    }

    canvas.drawPicture(page.picture);
  }

  @override
  bool shouldRepaint(_PicturePainter old) =>
      old.page != page || old.highlights != highlights;
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
/// Gesture positions arrive in the window's coordinate space; this converts
/// them into the page box's own space so [PdfSelectionController] can map them
/// onto PDF page coordinates.
final class _SelectablePage extends StatefulWidget {
  const _SelectablePage({
    required this.page,
    required this.box,
    required this.highlights,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final PdfRenderedPage page;
  final PdfRect box;
  final List<Rect> highlights;
  final void Function(Offset local, BoxConstraints constraints) onStart;
  final void Function(Offset local, BoxConstraints constraints) onUpdate;
  final void Function(Offset local, BoxConstraints constraints) onEnd;

  @override
  State<_SelectablePage> createState() => _SelectablePageState();
}

final class _SelectablePageState extends State<_SelectablePage> {
  final _key = GlobalKey();
  Offset? _lastLocal;

  /// Converts a global pointer position into the page box's local space,
  /// accounting for the FittedBox centring the page inside its slot.
  Offset _toLocal(Offset global, BoxConstraints constraints) {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    final local = renderBox == null ? global : renderBox.globalToLocal(global);
    _lastLocal = local;
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.box.width, widget.box.height);
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) =>
              widget.onStart(_toLocal(d.globalPosition, constraints), constraints),
          onPanUpdate: (d) =>
              widget.onUpdate(_toLocal(d.globalPosition, constraints), constraints),
          onPanEnd: (_) {
            final last = _lastLocal;
            if (last != null) widget.onEnd(last, constraints);
          },
          onTapUp: (d) =>
              widget.onEnd(_toLocal(d.globalPosition, constraints), constraints),
          child: CustomPaint(
            key: _key,
            size: size,
            painter: _PicturePainter(widget.page, highlights: widget.highlights),
          ),
        );
      },
    );
  }
}
