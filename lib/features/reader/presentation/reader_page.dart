import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/bookmark.dart';
import '../../../domain/books/reader_fonts.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import '../../../domain/search/search_models.dart';
import '../../../features/settings/application/settings_providers.dart';
import '../../../renderers/common/renderer_event.dart';
import '../../../renderers/epub/epub_document.dart';
import '../../../renderers/epub/epub_document_loader.dart';
import '../../../renderers/pdf/pdf_canvas_view.dart';
import '../../../renderers/epub/epub_jump.dart';
import '../../../renderers/epub/epub_renderer_view.dart';
import '../../../renderers/pdf/pdf_renderer_view.dart';
import '../../ai/presentation/ai_panel.dart';
import '../../import/application/import_intent.dart';
import '../../ocr/application/ocr_page_controller.dart';
import '../../ocr/application/ocr_providers.dart';
import '../../../domain/ocr/ocr_models.dart';
import '../application/in_book_search_controller.dart';
import '../application/reader_providers.dart';

final readerRendererHostProvider =
    Provider<Widget Function(ReaderRendererHostConfig)>((ref) {
      return (config) => _DefaultRendererHost(config: config);
    });

final class ReaderRendererHostConfig {
  const ReaderRendererHostConfig({
    required this.book,
    required this.progress,
    required this.settings,
    required this.annotations,
    required this.version,
    required this.jumpToken,
    required this.searchQuery,
    required this.focusLocator,
    required this.clearSearchHighlightsVersion,
    required this.onEvent,
    this.ocrOverlayToken = 0,
    this.ocrOverlayPage,
    this.ocrOverlayBlocks = const [],
  });

  final Book book;
  final ReadingProgressSnapshot? progress;
  final ReaderSettings settings;
  final List<Annotation> annotations;

  /// Hard remount token (error retry, format re-open).
  final int version;

  /// Soft jump token (TOC / in-book search) without remounting the renderer.
  final int jumpToken;
  final String? searchQuery;

  /// Temporary source focus after note/bookmark/search jumps.
  final ReadingLocator? focusLocator;
  final int clearSearchHighlightsVersion;
  final ValueChanged<RendererEvent> onEvent;

  /// Bumped when a new OCR overlay should be painted onto the PDF page.
  final int ocrOverlayToken;
  final int? ocrOverlayPage;
  final List<Map<String, Object?>> ocrOverlayBlocks;
}

final class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.bookId, this.initialLocator, super.key});

  final String bookId;
  final ReadingLocator? initialLocator;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

final class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  String? _statusText;
  final ValueNotifier<String?> _statusNotifier = ValueNotifier<String?>(null);
  String? _renderError;
  bool? _rendererSearchAvailable;
  bool? _rendererTextSelectionAvailable;

  /// Native PDF text layer (not OCR). OCR entry stays visible when this is false.
  bool? _rendererNativeTextLayerAvailable;
  bool _rendererOcrTextLayerAvailable = false;
  String? _rendererSearchUnavailableReason;
  String? _rendererSearchQuery;
  int _clearSearchHighlightsVersion = 0;
  List<RendererOutlineItem> _pdfOutline = const [];
  bool _markedOpened = false;
  int _ocrOverlayToken = 0;
  int? _ocrOverlayPage;
  List<Map<String, Object?>> _ocrOverlayBlocks = const [];

  /// Pending multi-page OCR overlays (double-page spread). Applied one-by-one
  /// via successive [ocrOverlayToken] bumps after each page is recognized.
  final List<({int page, List<Map<String, Object?>> blocks})>
  _pendingOcrOverlays = [];

  /// Pages whose OCR overlay is already painted in the current WebView session.
  final Set<int> _restoredOcrPages = <int>{};
  int _ocrRestoreGeneration = 0;
  RendererLocationChanged? _currentLocation;
  final ValueNotifier<RendererLocationChanged?> _locationNotifier =
      ValueNotifier<RendererLocationChanged?>(null);
  RendererTextSelected? _selectedText;
  ReadingProgressSnapshot? _jumpProgress;
  int _rendererVersion = 0;
  int _jumpToken = 0;
  ReadingLocator? _focusLocator;
  Timer? _focusClearTimer;
  bool _selectionActionsOpen = false;
  String? _lastSelectionActionKey;
  OverlayEntry? _selectionOverlayEntry;
  Completer<void>? _selectionOverlayCompleter;
  bool _annotationActionsOpen = false;
  String? _lastAnnotationActionId;
  DateTime _lastAnnotationActionAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _desktopTocOpen = true;
  bool _desktopContextOpen = false;
  double _desktopTocWidth = 300;
  double _desktopContextWidth = 420;
  bool _desktopChromePrefsLoaded = false;
  bool _mobileChromeVisible = true;
  Timer? _mobileChromeTimer;
  Timer? _statusClearTimer;
  Timer? _locationChromeTimer;
  _ReaderContextTab _desktopContextTab = _ReaderContextTab.search;
  ReaderSessionController? _sessionController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialLocator = widget.initialLocator;
    if (initialLocator != null) {
      final canFlash = jumpPrecisionFor(initialLocator) == JumpPrecision.phrase;
      _jumpProgress = ReadingProgressSnapshot(
        bookId: widget.bookId,
        locator: initialLocator,
        progress: initialLocator.progress,
        pageNumber: initialLocator.page,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _focusLocator = canFlash ? initialLocator : null;
      if (canFlash) {
        _scheduleFocusClear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final textLayer =
            _rendererTextSelectionAvailable ?? _rendererSearchAvailable ?? true;
        _setTransientStatus(
          jumpStatusLabelFor(initialLocator, pdfTextLayerAvailable: textLayer),
          clearAfter: canFlash
              ? const Duration(milliseconds: 1600)
              : const Duration(milliseconds: 2800),
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _scheduleMobileChromeAutoHide();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefer watch in build; keep a fallback for early lifecycle callbacks.
    _sessionController ??= ref.read(
      readerSessionControllerProvider(widget.bookId),
    );
  }

  @override
  void didUpdateWidget(covariant ReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same book route reused with a new locator (notes/search jump).
    final next = widget.initialLocator;
    final previous = oldWidget.initialLocator;
    if (next == null) {
      return;
    }
    if (previous != null && previous.toJsonText() == next.toJsonText()) {
      return;
    }
    if (oldWidget.bookId != widget.bookId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpTo(next);
    });
  }

  @override
  void dispose() {
    _closeSelectionOverlay();
    _mobileChromeTimer?.cancel();
    _statusClearTimer?.cancel();
    _locationChromeTimer?.cancel();
    _focusClearTimer?.cancel();
    _locationNotifier.dispose();
    _statusNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sessionController?.flush());
    super.dispose();
  }

  void _setTransientStatus(String? message, {Duration? clearAfter}) {
    _statusClearTimer?.cancel();
    _statusText = message;
    _statusNotifier.value = message;
    if (message == null) {
      return;
    }
    final duration = clearAfter ?? const Duration(seconds: 2);
    _statusClearTimer = Timer(duration, () {
      if (!mounted || _statusText != message) {
        return;
      }
      _statusText = null;
      _statusNotifier.value = null;
    });
  }

  void _scheduleLocationChromeUpdate(RendererLocationChanged event) {
    // Update immediately first so status bar never lags a full second, then
    // coalesce bursty scroll/page events.
    if (_locationNotifier.value == null) {
      _locationNotifier.value = event;
      return;
    }
    _locationChromeTimer?.cancel();
    _locationChromeTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      _locationNotifier.value = _currentLocation;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_sessionController?.flush());
      case AppLifecycleState.resumed:
        return;
    }
  }

  void _showMobileChrome({bool autoHide = true}) {
    if (!context.appBreakpoint.isCompact) {
      return;
    }
    if (!_mobileChromeVisible) {
      setState(() => _mobileChromeVisible = true);
    }
    if (autoHide) {
      _scheduleMobileChromeAutoHide();
    } else {
      _mobileChromeTimer?.cancel();
    }
  }

  void _hideMobileChrome() {
    if (!context.appBreakpoint.isCompact || !_mobileChromeVisible) {
      return;
    }
    _mobileChromeTimer?.cancel();
    setState(() => _mobileChromeVisible = false);
  }

  void _toggleMobileChrome({bool autoHide = true}) {
    if (!context.appBreakpoint.isCompact) {
      return;
    }
    if (_mobileChromeVisible) {
      _hideMobileChrome();
    } else {
      _showMobileChrome(autoHide: autoHide);
    }
  }

  void _scheduleMobileChromeAutoHide() {
    _mobileChromeTimer?.cancel();
    if (!mounted || !context.appBreakpoint.isCompact) {
      return;
    }
    // Kindle-like: chrome stays long enough to hit actions, then recedes.
    _mobileChromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_selectionActionsOpen) {
        setState(() => _mobileChromeVisible = false);
      }
    });
  }

  Future<void> _showMobileMoreSheet({
    required BuildContext context,
    required Book book,
    required ReaderSettings settings,
    required Bookmark? currentBookmark,
  }) async {
    _showMobileChrome(autoHide: false);
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          final isPdf = book.format == BookFormat.pdf;
          return SafeArea(
            child: _MobileReaderMoreSheet(
              book: book,
              settings: settings,
              bookmarked: currentBookmark != null,
              searchAvailable: _rendererSearchAvailable != false,
              textLayerAvailable: _rendererTextSelectionAvailable != false,
              capabilityReason: _rendererSearchUnavailableReason,
              onPageJump: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_showPageJump(context));
                    }
                  : null,
              onZoomOut: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_adjustReaderScale(-1));
                    }
                  : null,
              onZoomIn: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_adjustReaderScale(1));
                    }
                  : null,
              onFitWidth: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_setPdfZoomMode(PdfZoomMode.fitWidth));
                    }
                  : null,
              onFitPage: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_setPdfZoomMode(PdfZoomMode.fitPage));
                    }
                  : null,
              onSearch: () {
                Navigator.of(sheetContext).pop();
                unawaited(_showInBookSearch(context));
              },
              onBookmark: () {
                Navigator.of(sheetContext).pop();
                _toggleBookmark(context, currentBookmark);
              },
              onNotebook: () {
                Navigator.of(sheetContext).pop();
                unawaited(_showNotebook(context));
              },
              onAi: () {
                Navigator.of(sheetContext).pop();
                unawaited(_showAiPanel(context));
              },
              onOcrPage: isPdf && _rendererNativeTextLayerAvailable == false
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_runOcrCurrentPage(context, book));
                    }
                  : null,
              onSettings: () {
                Navigator.of(sheetContext).pop();
                unawaited(_showReaderSettings(context, settings));
              },
              onQuickTheme: () {
                Navigator.of(sheetContext).pop();
                unawaited(_showQuickThemeSheet(context, settings));
              },
              onToggleReaderMode: () {
                Navigator.of(sheetContext).pop();
                unawaited(_toggleReaderMode(settings));
              },
            ),
          );
        },
      );
    } finally {
      _scheduleMobileChromeAutoHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pin the session controller for the full page lifetime so autoDispose
    // cannot replace the instance that receives location events.
    final sessionController = ref.watch(
      readerSessionControllerProvider(widget.bookId),
    );
    _sessionController = sessionController;
    final book = ref.watch(readerBookProvider(widget.bookId));
    final progress = ref.watch(readerProgressProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider);
    final bookmarks = ref.watch(bookmarksByBookProvider(widget.bookId));
    final currentLocator = _currentLocation?.locator ?? progress.value?.locator;
    final currentBookmark = _bookmarkAtLocator(
      bookmarks.value ?? const [],
      currentLocator,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          context.go('/library');
          requestBookImport(ref);
        },
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          control: true,
          shift: true,
        ): () =>
            context.go('/search'),
        const CharacterActivator('F', control: true): () =>
            context.go('/search'),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _showInBookSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _toggleBookmark(context, currentBookmark),
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () =>
            _showPageJump(context),
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _adjustReaderScale(1),
        const SingleActivator(
          LogicalKeyboardKey.numpadAdd,
          control: true,
        ): () =>
            _adjustReaderScale(1),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _adjustReaderScale(-1),
        const SingleActivator(
          LogicalKeyboardKey.numpadSubtract,
          control: true,
        ): () =>
            _adjustReaderScale(-1),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
            _resetReaderScale(),
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyF &&
              HardwareKeyboard.instance.isControlPressed &&
              HardwareKeyboard.instance.isShiftPressed) {
            context.go('/search');
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          appBar: context.appBreakpoint.isCompact
              ? null
              : AppBar(
                  leading: IconButton(
                    tooltip: '返回书库',
                    onPressed: () async {
                      await ref
                          .read(readerSessionControllerProvider(widget.bookId))
                          .flush();
                      if (context.mounted) {
                        context.go('/library');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: Text(
                    book.value?.title ?? '阅读器',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    _ReaderToolbarButton(
                      icon: Icons.toc,
                      label: context.supportsSidePanel && _desktopTocOpen
                          ? '收起目录'
                          : '目录',
                      onPressed: book.value == null
                          ? null
                          : () {
                              if (context.supportsSidePanel) {
                                _setDesktopTocOpen(!_desktopTocOpen);
                                return;
                              }
                              unawaited(
                                _showTableOfContents(context, book.value!),
                              );
                            },
                    ),
                    _ReaderToolbarButton(
                      icon: Icons.search,
                      label: '搜索',
                      onPressed: () => _showInBookSearch(context),
                    ),
                    _ReaderToolbarButton(
                      icon: currentBookmark == null
                          ? Icons.bookmark_add_outlined
                          : Icons.bookmark,
                      label: currentBookmark == null ? '加书签' : '取消书签',
                      onPressed: () =>
                          _toggleBookmark(context, currentBookmark),
                    ),
                    _ReaderToolbarButton(
                      icon: Icons.library_books_outlined,
                      label: '笔记',
                      onPressed: () => _showContextOrSheet(
                        context,
                        _ReaderContextTab.notebook,
                        () => _showNotebook(context),
                      ),
                    ),
                    _ReaderToolbarButton(
                      icon: Icons.auto_awesome_outlined,
                      label: 'AI',
                      onPressed: () => unawaited(_showAiPanel(context)),
                    ),
                    _ReaderToolbarButton(
                      icon: Icons.tune,
                      label: '设置',
                      onPressed: settings.value == null
                          ? null
                          : () => _showReaderSettings(context, settings.value!),
                    ),
                    if (settings.value != null)
                      _ReaderToolbarButton(
                        icon: Icons.brightness_4_outlined,
                        label: '主题',
                        onPressed: () =>
                            _showQuickThemeSheet(context, settings.value!),
                      ),
                    PopupMenuButton<_ReaderMoreAction>(
                      tooltip: '更多阅读操作',
                      onSelected: (action) => _handleReaderMoreAction(
                        context,
                        action,
                        book.value,
                        settings.value,
                      ),
                      itemBuilder: (context) =>
                          _readerMoreMenuItems(book.value, settings.value),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
          body: book.when(
            data: (book) {
              if (book == null) {
                return const _ReaderMessage(message: '找不到这本书');
              }

              if (!_markedOpened) {
                _markedOpened = true;
                unawaited(
                  ref
                      .read(readerSessionControllerProvider(widget.bookId))
                      .markOpened(),
                );
              }

              return progress.when(
                data: (snapshot) {
                  final readerSettings =
                      settings.value ?? const ReaderSettings();
                  // Only lock chrome prefs after settings have actually loaded.
                  if (settings.hasValue && settings.value != null) {
                    _syncDesktopChromePrefs(settings.value!);
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      const desktopStatusBarHeight = 34.0;
                      final showDesktopContext =
                          _desktopContextOpen &&
                          AppBreakpoint.supportsSidePanelWidth(
                            constraints.maxWidth,
                          );
                      final showDesktopToc =
                          _desktopTocOpen &&
                          AppBreakpoint.supportsSidePanelWidth(
                            constraints.maxWidth,
                          );
                      final showDesktopChrome =
                          AppBreakpoint.supportsSidePanelWidth(
                            constraints.maxWidth,
                          );
                      final tocWidth = _clampPanelWidth(
                        _desktopTocWidth,
                        min: 220,
                        max: 420,
                        availableWidth: constraints.maxWidth,
                      );
                      final contextWidth = _clampPanelWidth(
                        _desktopContextWidth,
                        min: 340,
                        max: 600,
                        availableWidth: constraints.maxWidth,
                        maxFraction: 0.48,
                      );
                      return Stack(
                        children: [
                          if (showDesktopToc)
                            Positioned(
                              top: 0,
                              left: 0,
                              bottom: showDesktopChrome
                                  ? desktopStatusBarHeight
                                  : 0,
                              width: tocWidth,
                              child: _DesktopTocPane(
                                book: book,
                                pdfOutline: _pdfOutline,
                                totalPages: _currentLocation?.totalPages,
                                currentLocator:
                                    _currentLocation?.locator ??
                                    snapshot?.locator,
                                locationListenable: _locationNotifier,
                                onSelected: _jumpTo,
                                onClose: () => _setDesktopTocOpen(false),
                              ),
                            ),
                          if (showDesktopToc)
                            Positioned(
                              top: 0,
                              left: tocWidth - 3,
                              bottom: showDesktopChrome
                                  ? desktopStatusBarHeight
                                  : 0,
                              width: 6,
                              child: _PanelResizeHandle(
                                semanticLabel: '调整目录宽度',
                                onDrag: (delta) => _setDesktopTocWidth(
                                  _desktopTocWidth + delta.delta.dx,
                                ),
                              ),
                            ),
                          Positioned.fill(
                            left: showDesktopToc ? tocWidth : 0,
                            right: showDesktopContext ? contextWidth : 0,
                            bottom: showDesktopChrome
                                ? desktopStatusBarHeight
                                : 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: readerSettings.themePreset.background,
                              ),
                              // Annotations are watched in a leaf widget so
                              // highlight updates do not rebuild the whole reader chrome.
                              child: _ReaderAnnotationsHost(
                                bookId: widget.bookId,
                                book: book,
                                progress: _jumpProgress ?? snapshot,
                                settings: readerSettings,
                                version: _rendererVersion,
                                jumpToken: _jumpToken,
                                searchQuery: _rendererSearchQuery,
                                focusLocator: _focusLocator,
                                clearSearchHighlightsVersion:
                                    _clearSearchHighlightsVersion,
                                onEvent: _handleRendererEvent,
                                ocrOverlayToken: _ocrOverlayToken,
                                ocrOverlayPage: _ocrOverlayPage,
                                ocrOverlayBlocks: _ocrOverlayBlocks,
                              ),
                            ),
                          ),
                          if (book.format == BookFormat.pdf &&
                              !context.appBreakpoint.isCompact)
                            Positioned(
                              top: 12,
                              left: showDesktopToc ? tocWidth + 16 : 16,
                              right: showDesktopContext
                                  ? contextWidth + 16
                                  : 16,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 760,
                                  ),
                                  child: ValueListenableBuilder<RendererLocationChanged?>(
                                    valueListenable: _locationNotifier,
                                    builder: (context, location, _) {
                                      return _PdfQuickToolbar(
                                        pageNumber: location?.pageNumber,
                                        totalPages: location?.totalPages,
                                        settings: readerSettings,
                                        bookmarked: currentBookmark != null,
                                        searchAvailable:
                                            _rendererSearchAvailable != false,
                                        textLayerAvailable:
                                            // After OCR, selection works, but "native" may still be false.
                                            // Treat either native or OCR overlay as selection-capable UI.
                                            (_rendererNativeTextLayerAvailable ==
                                                true) ||
                                            _rendererOcrTextLayerAvailable ||
                                            (_rendererTextSelectionAvailable !=
                                                false),
                                        capabilityReason:
                                            _rendererSearchUnavailableReason,
                                        onPageJump: () =>
                                            unawaited(_showPageJump(context)),
                                        onZoomOut: () =>
                                            unawaited(_adjustReaderScale(-1)),
                                        onZoomIn: () =>
                                            unawaited(_adjustReaderScale(1)),
                                        onFitWidth: () => unawaited(
                                          _setPdfZoomMode(PdfZoomMode.fitWidth),
                                        ),
                                        onFitPage: () => unawaited(
                                          _setPdfZoomMode(PdfZoomMode.fitPage),
                                        ),
                                        onSearch: () => unawaited(
                                          _showInBookSearch(context),
                                        ),
                                        onBookmark: () => _toggleBookmark(
                                          context,
                                          currentBookmark,
                                        ),
                                        onOcrPage:
                                            _rendererNativeTextLayerAvailable ==
                                                false
                                            ? () => unawaited(
                                                _runOcrCurrentPage(
                                                  context,
                                                  book,
                                                ),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          if (showDesktopContext)
                            Positioned(
                              top: 0,
                              right: 0,
                              bottom: showDesktopChrome
                                  ? desktopStatusBarHeight
                                  : 0,
                              width: contextWidth,
                              child: _DesktopContextPane(
                                bookId: widget.bookId,
                                activeTab: _desktopContextTab,
                                searchQuery: _rendererSearchQuery,
                                currentLocator:
                                    _currentLocation?.locator ??
                                    snapshot?.locator,
                                selectedText: _selectedText?.text,
                                selectedLocator: _selectedText?.locator,
                                onQueryChanged: _applyRendererSearchQuery,
                                onPreviewResult: _jumpTo,
                                onClear: _clearRendererSearchHighlights,
                                onClose: _closeDesktopContext,
                                onTabChanged: _setDesktopContextTab,
                                onAction: _handleInBookSearchAction,
                                onAskAi: _showAiPanel,
                                onNoteSaved: () {
                                  ref.invalidate(
                                    notesByBookProvider(widget.bookId),
                                  );
                                },
                              ),
                            ),
                          if (showDesktopContext)
                            Positioned(
                              top: 0,
                              right: contextWidth - 3,
                              bottom: showDesktopChrome
                                  ? desktopStatusBarHeight
                                  : 0,
                              width: 6,
                              child: _PanelResizeHandle(
                                semanticLabel: '调整上下文栏宽度',
                                onDrag: (delta) => _setDesktopContextWidth(
                                  _desktopContextWidth - delta.delta.dx,
                                ),
                              ),
                            ),
                          // Status banner must keep Positioned as a *direct* Stack child.
                          // Wrapping Positioned in ValueListenableBuilder breaks the
                          // Stack and blanks the whole reader body.
                          Positioned(
                            left: showDesktopToc ? tocWidth + 16 : 16,
                            right: showDesktopContext ? contextWidth + 16 : 16,
                            bottom: showDesktopChrome
                                ? desktopStatusBarHeight + 10
                                : 16,
                            child: ValueListenableBuilder<String?>(
                              valueListenable: _statusNotifier,
                              builder: (context, status, _) {
                                if (status == null) {
                                  return const SizedBox.shrink();
                                }
                                return _ReaderStatusBanner(message: status);
                              },
                            ),
                          ),
                          if (_renderError != null)
                            Positioned.fill(
                              left: showDesktopToc ? tocWidth : 0,
                              right: showDesktopContext ? contextWidth : 0,
                              child: _ReaderErrorPanel(
                                message: _renderError!,
                                onRetry: _retryRenderer,
                                onShowDetails: () => _showRenderErrorDetails(
                                  context,
                                  _renderError!,
                                ),
                              ),
                            ),
                          if (showDesktopChrome)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: desktopStatusBarHeight,
                              child:
                                  ValueListenableBuilder<
                                    RendererLocationChanged?
                                  >(
                                    valueListenable: _locationNotifier,
                                    builder: (context, location, _) {
                                      return _ReaderStatusBar(
                                        book: book,
                                        locator:
                                            location?.locator ??
                                            snapshot?.locator,
                                        progress:
                                            location?.progress ??
                                            snapshot?.progress,
                                        chapterTitle:
                                            location?.chapterTitle ??
                                            snapshot?.chapterTitle,
                                        pageNumber: location?.pageNumber,
                                        totalPages: location?.totalPages,
                                        settings: readerSettings,
                                        tocOpen: showDesktopToc,
                                        contextOpen: showDesktopContext,
                                        tocWidth: tocWidth,
                                        contextWidth: contextWidth,
                                      );
                                    },
                                  ),
                            ),
                          if (context.appBreakpoint.isCompact) ...[
                            // Center-band toggle (Apple Books / Kindle style).
                            // Kept as a short middle strip so vertical scroll and
                            // edge page-turns still work.
                            Positioned(
                              left: 72,
                              right: 72,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: SizedBox(
                                  height: 120,
                                  width: double.infinity,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () =>
                                        _toggleMobileChrome(autoHide: true),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                            // Animated immersive chrome.
                            Positioned(
                              left: AppSpacing.x2,
                              right: AppSpacing.x2,
                              top: AppSpacing.x2,
                              child: IgnorePointer(
                                ignoring: !_mobileChromeVisible,
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  offset: _mobileChromeVisible
                                      ? Offset.zero
                                      : const Offset(0, -0.35),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: _mobileChromeVisible ? 1 : 0,
                                    child: SafeArea(
                                      bottom: false,
                                      child: _MobileReaderTopBar(
                                        title: book.title,
                                        progress:
                                            _currentLocation?.progress ??
                                            snapshot?.progress,
                                        locationLabel: _readerLocationText(
                                          book: book,
                                          locator:
                                              _currentLocation?.locator ??
                                              snapshot?.locator,
                                          chapterTitle:
                                              _currentLocation?.chapterTitle ??
                                              snapshot?.chapterTitle,
                                          pageNumber:
                                              _currentLocation?.pageNumber,
                                          totalPages:
                                              _currentLocation?.totalPages,
                                        ),
                                        onBack: () async {
                                          await ref
                                              .read(
                                                readerSessionControllerProvider(
                                                  widget.bookId,
                                                ),
                                              )
                                              .flush();
                                          if (context.mounted) {
                                            context.go('/library');
                                          }
                                        },
                                        onToc: () => unawaited(
                                          _showTableOfContents(context, book),
                                        ),
                                        onMore: () => unawaited(
                                          _showMobileMoreSheet(
                                            context: context,
                                            book: book,
                                            settings: readerSettings,
                                            currentBookmark: currentBookmark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: AppSpacing.x2,
                              right: AppSpacing.x2,
                              bottom: AppSpacing.x2,
                              child: IgnorePointer(
                                ignoring: !_mobileChromeVisible,
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  offset: _mobileChromeVisible
                                      ? Offset.zero
                                      : const Offset(0, 0.35),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: _mobileChromeVisible ? 1 : 0,
                                    child: SafeArea(
                                      top: false,
                                      child:
                                          ValueListenableBuilder<
                                            RendererLocationChanged?
                                          >(
                                            valueListenable: _locationNotifier,
                                            builder: (context, location, _) {
                                              return _MobileReaderBottomBar(
                                                book: book,
                                                locator:
                                                    location?.locator ??
                                                    snapshot?.locator,
                                                progress:
                                                    location?.progress ??
                                                    snapshot?.progress,
                                                chapterTitle:
                                                    location?.chapterTitle ??
                                                    snapshot?.chapterTitle,
                                                pageNumber:
                                                    location?.pageNumber,
                                                totalPages:
                                                    location?.totalPages,
                                                bookmarked:
                                                    currentBookmark != null,
                                                searchAvailable:
                                                    _rendererSearchAvailable !=
                                                    false,
                                                onToc: () => unawaited(
                                                  _showTableOfContents(
                                                    context,
                                                    book,
                                                  ),
                                                ),
                                                onSearch: () => unawaited(
                                                  _showInBookSearch(context),
                                                ),
                                                onBookmark: () =>
                                                    _toggleBookmark(
                                                      context,
                                                      currentBookmark,
                                                    ),
                                                onProgressTap:
                                                    book.format ==
                                                        BookFormat.pdf
                                                    ? () => unawaited(
                                                        _showPageJump(context),
                                                      )
                                                    : null,
                                                onMore: () => unawaited(
                                                  _showMobileMoreSheet(
                                                    context: context,
                                                    book: book,
                                                    settings: readerSettings,
                                                    currentBookmark:
                                                        currentBookmark,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!_mobileChromeVisible)
                              Positioned(
                                right: AppSpacing.x3,
                                bottom: AppSpacing.x3,
                                child: SafeArea(
                                  top: false,
                                  child: _ReaderChromeRevealButton(
                                    onPressed: () =>
                                        _showMobileChrome(autoHide: true),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const _ReaderMessage(message: '无法读取阅读进度'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const _ReaderMessage(message: '无法打开书籍'),
          ),
        ),
      ),
    );
  }

  void _handleRendererEvent(RendererEvent event) {
    if (!mounted) {
      return;
    }
    _sessionController?.handleEvent(event);
    switch (event) {
      case RendererReady():
        _statusClearTimer?.cancel();
        _statusText = null;
        _statusNotifier.value = null;
        if (_renderError != null) {
          setState(() => _renderError = null);
        }
      case RendererLocationChanged():
        _jumpProgress = null;
        _currentLocation = event;
        // Keep location chrome off the full-page rebuild path so scrolling /
        // page turns stay responsive.
        _scheduleLocationChromeUpdate(event);
        // Restore saved OCR overlays for the pages now on screen.
        unawaited(_restoreOcrOverlaysForVisiblePages());
        // Immersive: hide chrome after the first deliberate navigation while
        // reading (Kindle / Apple Books style), but keep it if the user just
        // revealed tools.
        if (context.appBreakpoint.isCompact &&
            _mobileChromeVisible &&
            !_selectionActionsOpen) {
          _scheduleMobileChromeAutoHide();
        }
        // Selection actions become stale after the reader moves.
        if (_selectionActionsOpen || _selectionOverlayEntry != null) {
          _closeSelectionOverlay();
          _selectionActionsOpen = false;
          _lastSelectionActionKey = null;
        }
        if (_statusText != null) {
          _statusClearTimer?.cancel();
          _statusText = null;
          _statusNotifier.value = null;
        }
        if (_renderError != null) {
          setState(() => _renderError = null);
        }
      case RendererTextSelected():
        // Avoid setState on every selection event — rebuilding the whole reader
        // (and WebView host) while the native ::selection is active makes the
        // highlight jump. Only rebuild when the desktop AI pane needs the text.
        final previousText = _selectedText?.text;
        _selectedText = event;
        if (_desktopContextOpen) {
          final needAiTab = _desktopContextTab != _ReaderContextTab.ai;
          final textChanged = previousText != event.text;
          if (needAiTab || textChanged) {
            setState(() {
              _desktopContextTab = _ReaderContextTab.ai;
            });
          }
        }
        // Selection is already obvious via the action menu — no toast.
        _showSelectionActionsOnce(event);
      case RendererSearchResults(:final results):
        if (results.isNotEmpty) {
          _setTransientStatus(
            '找到 ${results.length} 个结果',
            clearAfter: const Duration(seconds: 2),
          );
        }
      case RendererOutlineChanged(:final items):
        setState(() => _pdfOutline = items);
      case RendererBookmarkRequested(:final locator):
        _saveBookmarkAt(locator);
      case RendererCapabilityChanged(
        :final search,
        :final textSelection,
        :final reason,
        :final nativeTextLayer,
        :final ocrTextLayer,
      ):
        setState(() {
          _rendererSearchAvailable = search;
          _rendererTextSelectionAvailable = textSelection;
          // Prefer explicit native flag; fall back to textSelection for legacy.
          _rendererNativeTextLayerAvailable = nativeTextLayer ?? textSelection;
          _rendererOcrTextLayerAvailable = ocrTextLayer ?? false;
          _rendererSearchUnavailableReason = reason;
        });
      // No floating toast for missing text layer — it is a lasting property
      // of the document, shown only in toolbars/menus when relevant.
      case RendererNotice(:final message):
        // Soft notices only when actionable/transient; skip sticky capability copy.
        final lower = message.toLowerCase();
        final isCapabilityNoise =
            message.contains('没有文本层') ||
            message.contains('没有可搜索文本') ||
            lower.contains('no text');
        if (!isCapabilityNoise) {
          _setTransientStatus(message, clearAfter: const Duration(seconds: 3));
        }
      case RendererAnnotationSelected(:final annotationId, :final sourceRect):
        _showAnnotationActionsById(annotationId, sourceRect: sourceRect);
      case RendererFailed(:final message):
        _statusClearTimer?.cancel();
        setState(() {
          _statusText = null;
          _renderError = _readableRenderError(message);
        });
    }
  }

  void _retryRenderer() {
    setState(() {
      _renderError = null;
      _rendererVersion += 1;
    });
    _setTransientStatus('正在重新打开', clearAfter: const Duration(seconds: 4));
  }

  Future<void> _showRenderErrorDetails(
    BuildContext context,
    String message,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('渲染错误详情'),
        content: SelectableText(message),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<_ReaderMoreAction>> _readerMoreMenuItems(
    Book? book,
    ReaderSettings? settings,
  ) {
    // Flat items only. Nested ListTiles inside PopupMenuItem look broken.
    // Notebook/AI already have toolbar buttons, so keep this menu focused.
    final isPdf = book?.format == BookFormat.pdf;
    return [
      if (isPdf) ...[
        const PopupMenuItem(
          value: _ReaderMoreAction.pageJump,
          child: Text('跳转页码'),
        ),
        CheckedPopupMenuItem(
          value: _ReaderMoreAction.pdfFitWidth,
          checked: settings?.pdfZoomMode == PdfZoomMode.fitWidth,
          child: const Text('适合宽度'),
        ),
        CheckedPopupMenuItem(
          value: _ReaderMoreAction.pdfFitPage,
          checked: settings?.pdfZoomMode == PdfZoomMode.fitPage,
          child: const Text('适合页面'),
        ),
        const PopupMenuItem(
          value: _ReaderMoreAction.pdfZoomOut,
          child: Text('缩小'),
        ),
        const PopupMenuItem(
          value: _ReaderMoreAction.pdfZoomIn,
          child: Text('放大'),
        ),
        const PopupMenuDivider(),
      ],
      PopupMenuItem(
        value: _ReaderMoreAction.readerMode,
        enabled: settings != null,
        child: Text(
          settings?.readerMode == ReaderMode.paged ? '切换为连续滚动' : '切换为分页阅读',
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: _ReaderMoreAction.addAnnotation,
        child: Text('给选中文本添加标注'),
      ),
      const PopupMenuItem(
        value: _ReaderMoreAction.createNote,
        child: Text('保存摘录笔记'),
      ),
    ];
  }

  Future<void> _handleReaderMoreAction(
    BuildContext context,
    _ReaderMoreAction action,
    Book? book,
    ReaderSettings? settings,
  ) async {
    switch (action) {
      case _ReaderMoreAction.pageJump:
        await _showPageJump(context);
      case _ReaderMoreAction.pdfFitWidth:
        await _setPdfZoomMode(PdfZoomMode.fitWidth);
      case _ReaderMoreAction.pdfFitPage:
        await _setPdfZoomMode(PdfZoomMode.fitPage);
      case _ReaderMoreAction.pdfZoomOut:
        await _adjustReaderScale(-1);
      case _ReaderMoreAction.pdfZoomIn:
        await _adjustReaderScale(1);
      case _ReaderMoreAction.readerMode:
        if (settings != null) {
          await _toggleReaderMode(settings);
        }
      case _ReaderMoreAction.notebook:
        _showContextOrSheet(
          context,
          _ReaderContextTab.notebook,
          () => _showNotebook(context),
        );
      case _ReaderMoreAction.ai:
        _showContextOrSheet(
          context,
          _ReaderContextTab.ai,
          () => _showAiPanel(context),
        );
      case _ReaderMoreAction.addAnnotation:
        await _addAnnotation(context);
      case _ReaderMoreAction.createNote:
        await _createExcerptNote(context);
    }
  }

  String _readableRenderError(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return '阅读器渲染失败';
    }
    if (trimmed.length > 240) {
      return '${trimmed.substring(0, 240)}...';
    }
    return trimmed;
  }

  void _showAnnotationActionsById(
    String annotationId, {
    ReaderRect? sourceRect,
  }) {
    final now = DateTime.now();
    // Drop duplicate annotation-selected events that fire within a short window
    // (WebView click + selection side-effects can multi-fire).
    if (_annotationActionsOpen) {
      return;
    }
    if (_lastAnnotationActionId == annotationId &&
        now.difference(_lastAnnotationActionAt) <
            const Duration(milliseconds: 500)) {
      return;
    }
    final annotations = ref
        .read(annotationsByBookProvider(widget.bookId))
        .value;
    if (annotations == null) {
      return;
    }
    Annotation? match;
    for (final annotation in annotations) {
      if (annotation.id == annotationId) {
        match = annotation;
        break;
      }
    }
    if (match == null) {
      return;
    }
    _lastAnnotationActionId = annotationId;
    _lastAnnotationActionAt = now;
    // Show immediately; no post-frame delay.
    unawaited(
      _presentAnnotationActions(context, match, sourceRect: sourceRect),
    );
  }

  Future<void> _presentAnnotationActions(
    BuildContext context,
    Annotation annotation, {
    ReaderRect? sourceRect,
  }) async {
    if (!mounted || _annotationActionsOpen) {
      return;
    }
    _annotationActionsOpen = true;
    // Close any open selection menu so only one action surface is visible.
    _closeSelectionOverlay();
    try {
      if (context.supportsSidePanel) {
        await _showDesktopAnnotationMenu(
          context,
          annotation,
          sourceRect: sourceRect,
        );
        return;
      }
      await _showAnnotationActions(context, ref, annotation);
    } finally {
      _annotationActionsOpen = false;
    }
  }

  Future<void> _showDesktopAnnotationMenu(
    BuildContext context,
    Annotation annotation, {
    ReaderRect? sourceRect,
  }) async {
    _closeSelectionOverlay();
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    const overlayWidth = 300.0;
    const estimatedHeight = 168.0;
    final placement = _placeFloatingMenu(
      overlaySize: overlaySize,
      target: _toOverlayLocalRect(sourceRect, overlayBox),
      menuWidth: overlayWidth,
      menuHeight: estimatedHeight,
      gap: 10,
    );
    final completer = Completer<void>();
    _selectionOverlayCompleter = completer;
    void dismiss() {
      _closeSelectionOverlay();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final linkedNote = annotation.noteId == null
        ? null
        : await ref.read(noteRepositoryProvider).getNote(annotation.noteId!);
    if (!mounted) {
      return;
    }
    final hasNote = linkedNote != null;
    _selectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: dismiss,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
          Positioned(
            left: placement.left,
            top: placement.top,
            width: overlayWidth,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): dismiss,
              },
              child: Focus(
                autofocus: true,
                child: Material(
                  elevation: 12,
                  shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  color: colorScheme.surface,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _annotationUiColor(annotation.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasNote ? '标注 · 已有笔记' : '标注',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: '关闭',
                                visualDensity: VisualDensity.compact,
                                onPressed: dismiss,
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                          Text(
                            annotation.selectedText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                          if (hasNote) ...[
                            const SizedBox(height: 8),
                            Text(
                              linkedNote.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurface),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    dismiss();
                                    unawaited(
                                      _editAnnotation(context, ref, annotation),
                                    );
                                  },
                                  child: const Text('样式'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    dismiss();
                                    if (hasNote) {
                                      unawaited(
                                        _openLinkedAnnotationNote(
                                          context,
                                          linkedNote,
                                        ),
                                      );
                                    } else {
                                      unawaited(
                                        _saveAnnotationAsNote(
                                          context,
                                          ref,
                                          annotation,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(hasNote ? '查看笔记' : '添加笔记'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    dismiss();
                                    unawaited(
                                      _deleteAnnotation(
                                        context,
                                        ref,
                                        annotation,
                                      ),
                                    );
                                  },
                                  child: const Text('删除标注'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlayState.insert(_selectionOverlayEntry!);
    await completer.future;
  }

  void _showSelectionActionsOnce(RendererTextSelected event) {
    // Stable key: text + page/chapter only. Do NOT include selectionRects —
    // they jitter a few pixels across events and used to thrash the menu.
    final pageOrChapter =
        event.locator.page?.toString() ??
        event.locator.chapterIndex?.toString() ??
        '';
    final key = '${event.text.trim()}@$pageOrChapter';
    // Ignore duplicate events while the same selection menu is open.
    if (_selectionActionsOpen && _lastSelectionActionKey == key) {
      return;
    }
    if (_selectionActionsOpen && _lastSelectionActionKey != key) {
      // Meaningful selection change while menu open: replace it.
      _closeSelectionOverlay();
      _selectionActionsOpen = false;
    }
    _lastSelectionActionKey = key;
    // Show immediately so the menu doesn't lag the selection gesture.
    if (!mounted || _selectionActionsOpen) {
      return;
    }
    unawaited(_showTextSelectionActions(context, event));
  }

  Future<void> _showReaderSettings(
    BuildContext context,
    ReaderSettings currentSettings,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReaderBottomSheetFrame(
        child: _ReaderSettingsSheet(initialSettings: currentSettings),
      ),
    );
  }

  Future<void> _showQuickThemeSheet(
    BuildContext context,
    ReaderSettings currentSettings,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x2,
              AppSpacing.x5,
              AppSpacing.x5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '快速主题',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '立即切换白昼 / 夜间 / 护眼，无需进入完整设置。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final preset in const [
                      ReaderThemePreset.day,
                      ReaderThemePreset.night,
                      ReaderThemePreset.green,
                      ReaderThemePreset.paper,
                      ReaderThemePreset.warm,
                    ])
                      _QuickThemeChip(
                        preset: preset,
                        selected: currentSettings.themePreset == preset,
                        onSelected: () async {
                          Navigator.of(sheetContext).pop();
                          await _applyThemePreset(currentSettings, preset);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  'EPUB 字体',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final font in ReaderFonts.options)
                      ChoiceChip(
                        label: Text(font.label),
                        selected:
                            ReaderFonts.resolve(
                              currentSettings.fontFamily,
                            ).id ==
                            font.id,
                        onSelected: (_) async {
                          Navigator.of(sheetContext).pop();
                          await _applyFontFamily(currentSettings, font.id);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_showReaderSettings(context, currentSettings));
                    },
                    child: const Text('更多设置'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyThemePreset(
    ReaderSettings currentSettings,
    ReaderThemePreset preset,
  ) async {
    await ref
        .read(readerSettingsControllerProvider)
        .saveNow(currentSettings.copyWith(themePreset: preset));
    if (!mounted) {
      return;
    }
    _setTransientStatus('主题：${preset.label}');
  }

  Future<void> _applyFontFamily(
    ReaderSettings currentSettings,
    String fontFamily,
  ) async {
    await ref
        .read(readerSettingsControllerProvider)
        .saveNow(currentSettings.copyWith(fontFamily: fontFamily));
    if (!mounted) {
      return;
    }
    final label = ReaderFonts.resolve(fontFamily).label;
    _setTransientStatus('字体：$label');
  }

  Future<void> _toggleReaderMode(ReaderSettings currentSettings) async {
    final nextMode = currentSettings.readerMode == ReaderMode.paged
        ? ReaderMode.continuous
        : ReaderMode.paged;
    await ref
        .read(readerSettingsControllerProvider)
        .saveNow(currentSettings.copyWith(readerMode: nextMode));
    if (!mounted) {
      return;
    }
    _setTransientStatus(nextMode == ReaderMode.paged ? '分页阅读' : '连续滚动');
  }

  void _handleEscape() {
    if (_selectionOverlayEntry != null) {
      _closeSelectionOverlay();
      return;
    }
    if (_desktopContextOpen) {
      _closeDesktopContext();
      return;
    }
    if (_desktopTocOpen) {
      _setDesktopTocOpen(false);
    }
  }

  Future<void> _adjustReaderScale(int direction) async {
    final settings = ref.read(readerSettingsProvider).value;
    if (settings == null) {
      return;
    }
    final book = ref.read(readerBookProvider(widget.bookId)).value;
    final next = book?.format == BookFormat.pdf
        ? settings.copyWith(
            pdfScale: (settings.pdfScale + direction * 0.1)
                .clamp(0.7, 2.4)
                .toDouble(),
            pdfZoomMode: PdfZoomMode.custom,
          )
        : settings.copyWith(
            fontSize: (settings.fontSize + direction).clamp(14, 32).toDouble(),
          );
    await ref.read(readerSettingsControllerProvider).saveNow(next);
    if (!mounted) {
      return;
    }
    _setTransientStatus(
      book?.format == BookFormat.pdf
          ? '缩放 ${(next.pdfScale * 100).round()}%'
          : '字号 ${next.fontSize.round()}',
    );
  }

  Future<void> _resetReaderScale() async {
    final settings = ref.read(readerSettingsProvider).value;
    if (settings == null) {
      return;
    }
    final book = ref.read(readerBookProvider(widget.bookId)).value;
    final next = book?.format == BookFormat.pdf
        ? settings.copyWith(pdfScale: 1, pdfZoomMode: PdfZoomMode.actual)
        : settings.copyWith(fontSize: 18);
    await ref.read(readerSettingsControllerProvider).saveNow(next);
    if (!mounted) {
      return;
    }
    _setTransientStatus('已恢复默认阅读比例');
  }

  Future<void> _setPdfZoomMode(PdfZoomMode mode) async {
    final settings = ref.read(readerSettingsProvider).value;
    if (settings == null) {
      return;
    }
    final next = settings.copyWith(
      pdfZoomMode: mode,
      pdfScale: mode == PdfZoomMode.actual ? 1 : settings.pdfScale,
    );
    await ref.read(readerSettingsControllerProvider).saveNow(next);
    if (!mounted) {
      return;
    }
    _setTransientStatus(mode.label);
  }

  Future<void> _showTableOfContents(BuildContext context, Book book) async {
    if (book.format == BookFormat.pdf) {
      await _showPdfTableOfContents(context);
      return;
    }
    try {
      final document = await EpubDocumentLoader().load(book.libraryFilePath);
      if (!context.mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _ReaderBottomSheetFrame(
          child: _EpubTocSheet(
            document: document,
            currentChapterIndex: _currentLocation?.locator.chapterIndex,
            onSelected: (item) {
              final chapterIndex = (item.chapterIndex ?? 0)
                  .clamp(0, document.chapters.length - 1)
                  .toInt();
              final chapter = document.chapters[chapterIndex];
              final locator = ReadingLocator.epub(
                href: item.href,
                chapterIndex: chapter.index,
                chapterOffset: item.chapterOffset,
                progress: document.progressForChapter(
                  chapterIndex: chapter.index,
                  chapterOffset: item.chapterOffset ?? 0,
                ),
              );
              setState(() {
                _jumpProgress = ReadingProgressSnapshot(
                  bookId: widget.bookId,
                  locator: locator,
                  progress: locator.progress,
                  chapterTitle: item.title,
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
                _jumpToken += 1;
              });
              _setTransientStatus(item.title);
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法读取目录')));
    }
  }

  Future<void> _showPdfTableOfContents(BuildContext context) async {
    final totalPages = _currentLocation?.totalPages;
    if (_pdfOutline.isEmpty && (totalPages == null || totalPages <= 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF 页码尚未准备好')));
      return;
    }
    final locator = await showModalBottomSheet<ReadingLocator>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReaderBottomSheetFrame(
        child: _PdfTocSheet(
          outline: _pdfOutline,
          totalPages: totalPages ?? 0,
          currentPage: _currentLocation?.pageNumber,
        ),
      ),
    );
    if (locator != null) {
      _jumpTo(locator);
    }
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    Bookmark? currentBookmark,
  ) async {
    if (currentBookmark != null) {
      await _deleteBookmarkWithUndo(context, ref, currentBookmark);
      return;
    }
    final location = _currentLocation;
    final progress = ref.read(readerProgressProvider(widget.bookId)).value;
    final locator = location?.locator ?? progress?.locator;
    if (locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没有可保存的位置')));
      return;
    }
    final bookmark = await ref
        .read(bookmarkRepositoryProvider)
        .saveBookmark(
          bookId: widget.bookId,
          locator: locator,
          title: location?.chapterTitle ?? progress?.chapterTitle,
          excerpt: locator.excerpt,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已添加书签'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '添加备注',
          onPressed: () => unawaited(_editBookmarkNote(context, ref, bookmark)),
        ),
      ),
    );
  }

  Future<void> _saveBookmarkAt(ReadingLocator locator) async {
    await ref
        .read(bookmarkRepositoryProvider)
        .saveBookmark(
          bookId: widget.bookId,
          locator: locator,
          title: _currentLocation?.chapterTitle ?? locator.displayLabel,
          excerpt: locator.excerpt,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已添加书签'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showNotebook(BuildContext context) async {
    final locator = await showModalBottomSheet<ReadingLocator>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ReaderBottomSheetFrame(child: _NotebookSheet(bookId: widget.bookId)),
    );
    if (locator != null) {
      _jumpTo(locator);
    }
  }

  void _syncDesktopChromePrefs(ReaderSettings settings) {
    if (_desktopChromePrefsLoaded) {
      return;
    }
    _desktopChromePrefsLoaded = true;
    _desktopTocOpen = settings.desktopTocOpen;
    _desktopContextOpen = settings.desktopContextOpen;
    _desktopTocWidth = settings.desktopTocWidth;
    _desktopContextWidth = settings.desktopContextWidth;
  }

  void _showContextOrSheet(
    BuildContext context,
    _ReaderContextTab tab,
    Future<void> Function() fallback,
  ) {
    if (context.supportsSidePanel) {
      _openDesktopContext(tab);
      return;
    }
    unawaited(fallback());
  }

  void _openDesktopContext(_ReaderContextTab tab) {
    setState(() {
      _desktopContextOpen = true;
      _desktopContextTab = tab;
    });
    _saveDesktopChromePrefs();
  }

  void _setDesktopContextTab(_ReaderContextTab tab) {
    setState(() => _desktopContextTab = tab);
  }

  void _setDesktopTocOpen(bool value) {
    setState(() => _desktopTocOpen = value);
    _saveDesktopChromePrefs();
  }

  void _setDesktopTocWidth(double value) {
    setState(() => _desktopTocWidth = value.clamp(220, 420).toDouble());
    _saveDesktopChromePrefs(debounced: true);
  }

  void _setDesktopContextWidth(double value) {
    setState(() => _desktopContextWidth = value.clamp(340, 600).toDouble());
    _saveDesktopChromePrefs(debounced: true);
  }

  double _clampPanelWidth(
    double value, {
    required double min,
    required double max,
    required double availableWidth,
    double maxFraction = 0.42,
  }) {
    final widthBudget = (availableWidth * maxFraction)
        .clamp(min, max)
        .toDouble();
    return value.clamp(min, widthBudget).toDouble();
  }

  void _saveDesktopChromePrefs({bool debounced = false}) {
    final settings = ref.read(readerSettingsProvider).value;
    if (settings == null) {
      return;
    }
    final next = settings.copyWith(
      desktopTocOpen: _desktopTocOpen,
      desktopContextOpen: _desktopContextOpen,
      desktopTocWidth: _desktopTocWidth,
      desktopContextWidth: _desktopContextWidth,
    );
    if (debounced) {
      unawaited(ref.read(readerSettingsControllerProvider).save(next));
      return;
    }
    unawaited(ref.read(readerSettingsControllerProvider).saveNow(next));
  }

  Future<void> _showInBookSearch(BuildContext context) async {
    if (_rendererSearchAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_rendererSearchUnavailableReason ?? '当前书籍不可搜索')),
      );
      return;
    }
    if (context.supportsSidePanel) {
      _openDesktopContext(_ReaderContextTab.search);
      return;
    }
    final action = await showModalBottomSheet<_InBookSearchAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _InBookSearchSheet(
        bookId: widget.bookId,
        initialQuery: _rendererSearchQuery,
        currentLocator: _currentLocation?.locator,
        onQueryChanged: _applyRendererSearchQuery,
        onPreviewResult: _jumpTo,
        onClear: _clearRendererSearchHighlights,
      ),
    );
    // Keep renderer highlights after the sheet closes so users can still see
    // matches while reading. Explicit clear is available in the search UI.
    if (action == null) {
      return;
    }
    await _handleInBookSearchAction(action);
  }

  void _closeDesktopContext() {
    // Closing the context pane should not wipe an active search highlight.
    setState(() => _desktopContextOpen = false);
    _saveDesktopChromePrefs();
  }

  Future<void> _handleInBookSearchAction(_InBookSearchAction action) async {
    _jumpTo(action.locator);
    if (!mounted) {
      return;
    }
    if (action.intent == _InBookSearchIntent.askAi) {
      await _showAiPanel(
        context,
        locatorOverride: action.locator,
        initialContextOverride: action.sourceText,
      );
    }
  }

  void _applyRendererSearchQuery(String query) {
    if (!mounted) {
      return;
    }
    final trimmed = query.trim();
    setState(() {
      _rendererSearchQuery = trimmed.isEmpty ? null : trimmed;
      if (trimmed.isEmpty) {
        _clearSearchHighlightsVersion += 1;
      }
    });
  }

  void _clearRendererSearchHighlights() {
    if (!mounted) {
      return;
    }
    setState(() {
      _rendererSearchQuery = null;
      _clearSearchHighlightsVersion += 1;
    });
  }

  Future<void> _showPageJump(BuildContext context) async {
    final book = ref.read(readerBookProvider(widget.bookId)).value;
    if (book?.format != BookFormat.pdf) {
      return;
    }
    final currentLocator =
        _currentLocation?.locator ??
        ref.read(readerProgressProvider(widget.bookId)).value?.locator;
    final controller = TextEditingController(
      text: (currentLocator?.page ?? 1).toString(),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转页码'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '页码',
            hintText: '输入 PDF 页码',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    controller.dispose();
    final page = int.tryParse(value?.trim() ?? '');
    if (page == null || page <= 0) {
      return;
    }
    _jumpTo(
      ReadingLocator.pdf(
        page: page,
        zoom: currentLocator?.zoom ?? 1,
        progress: currentLocator?.progress ?? 0,
      ),
    );
  }

  Future<void> _addAnnotation(BuildContext context) async {
    final locator =
        _selectedText?.locator ??
        _currentLocation?.locator ??
        ref.read(readerProgressProvider(widget.bookId)).value?.locator;
    if (locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没有可标注的位置')));
      return;
    }
    final result = await _showAnnotationEditor(
      context,
      initialText: _selectedText?.text ?? locator.excerpt ?? '',
    );
    if (result == null || result.selectedText.trim().isEmpty) {
      return;
    }
    await ref
        .read(annotationRepositoryProvider)
        .saveAnnotation(
          bookId: widget.bookId,
          locator: locator,
          selectedText: result.selectedText.trim(),
          color: result.color,
          style: result.style,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已添加标注'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveQuickAnnotation(
    BuildContext context,
    RendererTextSelected selection, {
    required AnnotationColor color,
    required AnnotationStyle style,
  }) async {
    await ref
        .read(annotationRepositoryProvider)
        .saveAnnotation(
          bookId: widget.bookId,
          locator: selection.locator,
          selectedText: selection.text,
          color: color,
          style: style,
        );
    if (!context.mounted) {
      return;
    }
    // v1 freeze F-03: scan/OCR pages are approximate — be honest in UI.
    final approximate =
        _rendererNativeTextLayerAvailable == false ||
        _rendererOcrTextLayerAvailable;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approximate
              ? (style == AnnotationStyle.underline
                    ? '已添加下划线（扫描/OCR 页为近似定位）'
                    : '已添加高亮（扫描/OCR 页为近似定位）')
              : '已添加标注',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: approximate ? 3 : 2),
      ),
    );
  }

  Future<void> _showTextSelectionActions(
    BuildContext context,
    RendererTextSelected selection,
  ) async {
    _selectionActionsOpen = true;
    _showMobileChrome(autoHide: false);
    try {
      if (context.supportsSidePanel) {
        await _showDesktopSelectionMenu(context, selection);
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: _SelectionActionSurface(
            selection: selection,
            compact: true,
            onAction: (action) {
              Navigator.of(sheetContext).pop();
              unawaited(_handleSelectionAction(context, selection, action));
            },
            onDismiss: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      );
    } finally {
      _selectionActionsOpen = false;
      _lastSelectionActionKey = null;
      _scheduleMobileChromeAutoHide();
    }
  }

  Future<void> _showDesktopSelectionMenu(
    BuildContext context,
    RendererTextSelected selection,
  ) async {
    _closeSelectionOverlay();
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    // Toolbar is icon-only; keep intrinsic width and avoid fixed-width overflow.
    const estimatedWidth = 520.0;
    const estimatedHeight = 56.0;
    final localTarget = _toOverlayLocalRect(selection.sourceRect, overlayBox);
    final placement = _placeFloatingMenu(
      overlaySize: overlaySize,
      target: localTarget,
      menuWidth: estimatedWidth,
      menuHeight: estimatedHeight,
      gap: 10,
    );
    final completer = Completer<void>();
    _selectionOverlayCompleter = completer;
    void dismiss() {
      _closeSelectionOverlay();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    _selectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: dismiss,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
          Positioned(
            left: placement.left,
            top: placement.top,
            // Cap width so the menu never paints past the overlay edge.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (overlaySize.width - placement.left - 12).clamp(
                  180.0,
                  overlaySize.width - 24,
                ),
              ),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): dismiss,
                },
                child: Focus(
                  autofocus: true,
                  child: _DesktopSelectionOverlay(
                    selection: selection,
                    onAction: (action) async {
                      dismiss();
                      await _handleSelectionAction(context, selection, action);
                    },
                    onDismiss: dismiss,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlayState.insert(_selectionOverlayEntry!);
    await completer.future;
  }

  /// Convert global/page rects into the Overlay's local coordinate space.
  ReaderRect? _toOverlayLocalRect(ReaderRect? rect, RenderBox? overlayBox) {
    if (rect == null || overlayBox == null || !overlayBox.hasSize) {
      return rect;
    }
    final origin = overlayBox.localToGlobal(Offset.zero);
    return ReaderRect(
      page: rect.page,
      x: rect.x - origin.dx,
      y: rect.y - origin.dy,
      width: rect.width,
      height: rect.height,
    );
  }

  /// Places a floating menu near [target] without covering it when possible.
  ///
  /// Preference: above → below → right → left → least-overlap fallback.
  _FloatingMenuPlacement _placeFloatingMenu({
    required Size overlaySize,
    required ReaderRect? target,
    required double menuWidth,
    required double menuHeight,
    double gap = 10,
    double margin = 12,
  }) {
    final maxLeft = (overlaySize.width - menuWidth - margin).clamp(
      margin,
      overlaySize.width,
    );
    final maxTop = (overlaySize.height - menuHeight - margin).clamp(
      margin,
      overlaySize.height,
    );

    if (target == null || target.width <= 0 || target.height <= 0) {
      // No geometry: park near the top of the reading area, not over mid-page.
      return _FloatingMenuPlacement(
        left: (overlaySize.width * 0.5 - menuWidth / 2).clamp(margin, maxLeft),
        top: margin + 56,
        side: _FloatingMenuSide.fallback,
      );
    }

    final selection = Rect.fromLTWH(
      target.x,
      target.y,
      target.width,
      target.height,
    );
    final centerX = selection.center.dx;

    double clampLeft(double raw) => raw.clamp(margin, maxLeft).toDouble();
    double clampTop(double raw) => raw.clamp(margin, maxTop).toDouble();

    Rect menuRect(double left, double top) =>
        Rect.fromLTWH(left, top, menuWidth, menuHeight);

    bool fits(Rect menu) {
      if (menu.left < margin - 0.5 ||
          menu.top < margin - 0.5 ||
          menu.right > overlaySize.width - margin + 0.5 ||
          menu.bottom > overlaySize.height - margin + 0.5) {
        return false;
      }
      // Keep a small gap so the bar never sits on the highlight.
      final padded = selection.inflate(gap * 0.35);
      return !menu.overlaps(padded);
    }

    final candidates = <({double left, double top, _FloatingMenuSide side})>[
      (
        left: clampLeft(centerX - menuWidth / 2),
        top: clampTop(selection.top - gap - menuHeight),
        side: _FloatingMenuSide.above,
      ),
      (
        left: clampLeft(centerX - menuWidth / 2),
        top: clampTop(selection.bottom + gap),
        side: _FloatingMenuSide.below,
      ),
      (
        left: clampLeft(selection.right + gap),
        top: clampTop(selection.center.dy - menuHeight / 2),
        side: _FloatingMenuSide.right,
      ),
      (
        left: clampLeft(selection.left - gap - menuWidth),
        top: clampTop(selection.center.dy - menuHeight / 2),
        side: _FloatingMenuSide.left,
      ),
    ];

    for (final candidate in candidates) {
      final rect = menuRect(candidate.left, candidate.top);
      if (fits(rect)) {
        return _FloatingMenuPlacement(
          left: candidate.left,
          top: candidate.top,
          side: candidate.side,
        );
      }
    }

    // Last resort: pick the candidate with minimal overlap area.
    var best = candidates.first;
    var bestOverlap = double.infinity;
    for (final candidate in candidates) {
      final rect = menuRect(candidate.left, candidate.top);
      final overlap = rect.intersect(selection);
      final area = overlap.isEmpty ? 0.0 : overlap.width * overlap.height;
      final offscreen =
          (rect.left < margin ? margin - rect.left : 0) +
          (rect.top < margin ? margin - rect.top : 0) +
          (rect.right > overlaySize.width - margin
              ? rect.right - (overlaySize.width - margin)
              : 0) +
          (rect.bottom > overlaySize.height - margin
              ? rect.bottom - (overlaySize.height - margin)
              : 0);
      final score = area + offscreen * 40;
      if (score < bestOverlap) {
        bestOverlap = score;
        best = candidate;
      }
    }
    return _FloatingMenuPlacement(
      left: best.left,
      top: best.top,
      side: best.side,
    );
  }

  void _closeSelectionOverlay() {
    _selectionOverlayEntry?.remove();
    _selectionOverlayEntry = null;
    final completer = _selectionOverlayCompleter;
    _selectionOverlayCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _handleSelectionAction(
    BuildContext context,
    RendererTextSelected selection,
    _SelectionAction action,
  ) async {
    switch (action) {
      case _SelectionAction.highlight:
        await _saveQuickAnnotation(
          context,
          selection,
          color: AnnotationColor.yellow,
          style: AnnotationStyle.highlight,
        );
      case _SelectionAction.underline:
        await _saveQuickAnnotation(
          context,
          selection,
          color: AnnotationColor.blue,
          style: AnnotationStyle.underline,
        );
      case _SelectionAction.note:
        await _createExcerptNote(context);
      case _SelectionAction.search:
        _applyRendererSearchQuery(selection.text);
        if (context.supportsSidePanel) {
          _openDesktopContext(_ReaderContextTab.search);
        } else {
          unawaited(_showInBookSearch(context));
        }
      case _SelectionAction.copy:
        await Clipboard.setData(ClipboardData(text: selection.text));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已复制选中文本')));
        }
      case _SelectionAction.ai:
        await _showAiPanel(context);
    }
  }

  Future<void> _createExcerptNote(BuildContext context) async {
    final selectedText = _selectedText;
    final location = _currentLocation;
    final progress = ref.read(readerProgressProvider(widget.bookId)).value;
    final locator =
        selectedText?.locator ?? location?.locator ?? progress?.locator;
    final sourceText =
        selectedText?.text ??
        location?.locator.excerpt ??
        progress?.locator.excerpt;
    if (locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没有可保存的位置')));
      return;
    }
    final contentController = TextEditingController();
    final titleController = TextEditingController(
      text:
          location?.chapterTitle ??
          progress?.chapterTitle ??
          locator.displayLabel,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建摘录笔记'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sourceText?.isNotEmpty == true) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '原文摘录',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 6),
                Text(sourceText!, maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '笔记',
                  helperText: '纯文本显示；可使用 **加粗**、*斜体*、`代码` 简单标记',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    titleController.dispose();
    contentController.dispose();
    if (saved != true || content.isEmpty) {
      return;
    }
    await ref
        .read(noteRepositoryProvider)
        .saveNote(
          bookId: widget.bookId,
          title: title.isEmpty ? null : title,
          content: content,
          sourceText: sourceText,
          locator: locator,
          noteType: NoteType.excerpt,
        );
    ref.invalidate(notesByBookProvider(widget.bookId));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存为笔记'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _jumpTo(
    ReadingLocator locator, {
    String? fallbackExcerpt,
    bool? pdfTextLayerAvailable,
  }) {
    final enriched = enrichLocatorForJump(
      locator,
      fallbackExcerpt: fallbackExcerpt,
    );
    final textLayer =
        pdfTextLayerAvailable ??
        (_rendererTextSelectionAvailable ?? _rendererSearchAvailable ?? true);
    final canFlash =
        jumpPrecisionFor(enriched) == JumpPrecision.phrase &&
        (enriched.type != ReadingLocatorType.pdf || textLayer);
    setState(() {
      _jumpProgress = ReadingProgressSnapshot(
        bookId: widget.bookId,
        locator: enriched,
        progress: enriched.progress,
        pageNumber: enriched.page,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      // Soft jump: keep the open document/renderer alive.
      _jumpToken += 1;
      // Only keep focus paint when we can actually flash a phrase.
      _focusLocator = canFlash ? enriched : null;
    });
    if (canFlash) {
      _scheduleFocusClear();
    } else {
      _focusClearTimer?.cancel();
    }
    final label = jumpStatusLabelFor(
      enriched,
      pdfTextLayerAvailable: textLayer,
    );
    final clearAfter = canFlash
        ? const Duration(milliseconds: 1600)
        : const Duration(milliseconds: 2800);
    _setTransientStatus(label, clearAfter: clearAfter);
  }

  void _scheduleFocusClear() {
    _focusClearTimer?.cancel();
    _focusClearTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted || _focusLocator == null) {
        return;
      }
      setState(() {
        _focusLocator = null;
      });
    });
  }

  Future<void> _runOcrCurrentPage(BuildContext context, Book book) async {
    if (book.format != BookFormat.pdf) {
      return;
    }
    final fallbackPage = _currentLocation?.pageNumber;
    if (fallbackPage == null || fallbackPage < 1) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前页码未知，请稍后再试')));
      return;
    }

    final pdfController = ref.read(activePdfRendererControllerProvider);
    // Double-page: OCR both pages of the visible spread.
    List<int> pages = [fallbackPage];
    if (pdfController != null) {
      try {
        pages = await pdfController.getVisiblePages(fallbackPage: fallbackPage);
      } on Object {
        pages = [fallbackPage];
      }
    }
    if (pages.isEmpty) {
      pages = [fallbackPage];
    }

    final controller = ref.read(ocrPageControllerProvider(book.id).notifier);
    final statusLabel = pages.length > 1
        ? '正在识别第 ${pages.first}–${pages.last} 页…'
        : '正在识别第 ${pages.first} 页…';
    _setTransientStatus(statusLabel, clearAfter: const Duration(seconds: 12));

    final completed = await controller.recognizePages(
      book: book,
      pageNumbers: pages,
      // Reuse session + disk cache; only re-OCR when user force-refreshes later.
      forceRefresh: false,
      exportPage: pdfController == null
          ? null
          : (page) async {
              try {
                var exported = await pdfController.exportPageImage(
                  pageNumber: page,
                );
                if (exported == null || exported.bytes.isEmpty) {
                  await Future<void>.delayed(const Duration(milliseconds: 180));
                  exported = await pdfController.exportPageImage(
                    pageNumber: page,
                  );
                }
                return exported?.bytes;
              } on Object {
                return null;
              }
            },
    );
    if (!mounted) {
      return;
    }
    final state = ref.read(ocrPageControllerProvider(book.id));
    final messenger = ScaffoldMessenger.of(this.context);
    if (completed.isEmpty) {
      final message = state.errorMessage;
      if (message != null && message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      } else if (!state.isRunning) {
        messenger.showSnackBar(const SnackBar(content: Text('已取消识别')));
      }
      return;
    }

    final withGeometry = completed
        .where((item) => item.result.hasGeometry)
        .toList(growable: false);
    final combinedText = completed
        .map((item) => item.result.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');

    if (withGeometry.isNotEmpty) {
      final overlays = withGeometry
          .map(
            (item) => (
              page: item.page,
              blocks: item.result.blocks
                  .where((block) => block.hasGeometry)
                  .map((block) => block.toJson())
                  .toList(growable: false),
            ),
          )
          .toList(growable: false);
      _pendingOcrOverlays
        ..clear()
        ..addAll(overlays.skip(1));
      setState(() {
        _ocrOverlayPage = overlays.first.page;
        _ocrOverlayBlocks = overlays.first.blocks;
        _ocrOverlayToken += 1;
      });
      for (final item in withGeometry) {
        _restoredOcrPages.add(item.page);
      }
      _flushPendingOcrOverlays();

      // Overlay is the primary feedback; keep status brief and auto-clear.
      // Avoid sticky SnackBars for successful OCR — they linger over the page.
      final pageLabel = pages.length > 1
          ? '第 ${pages.first}–${pages.last} 页'
          : '第 ${pages.first} 页';
      messenger.hideCurrentSnackBar();
      _setTransientStatus(
        '$pageLabel 可划词',
        clearAfter: const Duration(milliseconds: 1600),
      );
      return;
    }

    final first = completed.first;
    _setTransientStatus(
      '第 ${first.page} 页识别完成',
      clearAfter: const Duration(seconds: 2),
    );
    await _showOcrResultSheet(
      this.context,
      book: book,
      pageNumber: first.page,
      result: OcrPageResult(
        text: combinedText.isEmpty ? first.result.text : combinedText,
        language: first.result.language,
        engine: first.result.engine,
        confidence: first.result.confidence,
        blocks: first.result.blocks,
      ),
    );
  }

  void _flushPendingOcrOverlays() {
    if (_pendingOcrOverlays.isEmpty || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingOcrOverlays.isEmpty) {
        return;
      }
      final next = _pendingOcrOverlays.removeAt(0);
      setState(() {
        _ocrOverlayPage = next.page;
        _ocrOverlayBlocks = next.blocks;
        _ocrOverlayToken += 1;
      });
      if (_pendingOcrOverlays.isNotEmpty) {
        _flushPendingOcrOverlays();
      }
    });
  }

  /// Re-apply OCR overlays from session/disk cache when the user returns
  /// to a previously recognized page — no re-OCR, no toast.
  Future<void> _restoreOcrOverlaysForVisiblePages() async {
    final bookAsync = ref.read(readerBookProvider(widget.bookId));
    final book = bookAsync.asData?.value;
    if (book == null || book.format != BookFormat.pdf) {
      return;
    }
    if (_rendererTextSelectionAvailable == true) {
      // Native text layer exists; OCR overlays are only for scan pages.
      // Still allow restore if we already painted OCR this session.
    }
    final fallbackPage = _currentLocation?.pageNumber;
    if (fallbackPage == null || fallbackPage < 1) {
      return;
    }
    final generation = ++_ocrRestoreGeneration;
    final pdfController = ref.read(activePdfRendererControllerProvider);
    List<int> pages = [fallbackPage];
    if (pdfController != null) {
      try {
        pages = await pdfController.getVisiblePages(fallbackPage: fallbackPage);
      } on Object {
        pages = [fallbackPage];
      }
    }
    if (!mounted || generation != _ocrRestoreGeneration) {
      return;
    }
    final controller = ref.read(ocrPageControllerProvider(book.id).notifier);
    final toRestore = <({int page, List<Map<String, Object?>> blocks})>[];
    for (final page in pages) {
      if (_restoredOcrPages.contains(page)) {
        continue;
      }
      final cached = await controller.peekCached(pageNumber: page);
      if (!mounted || generation != _ocrRestoreGeneration) {
        return;
      }
      if (cached == null || !cached.hasGeometry) {
        continue;
      }
      final blocks = cached.blocks
          .where((block) => block.hasGeometry)
          .map((block) => block.toJson())
          .toList(growable: false);
      if (blocks.isEmpty) {
        continue;
      }
      toRestore.add((page: page, blocks: blocks));
    }
    if (toRestore.isEmpty || !mounted || generation != _ocrRestoreGeneration) {
      return;
    }
    _pendingOcrOverlays
      ..clear()
      ..addAll(toRestore.skip(1));
    setState(() {
      _ocrOverlayPage = toRestore.first.page;
      _ocrOverlayBlocks = toRestore.first.blocks;
      _ocrOverlayToken += 1;
    });
    for (final item in toRestore) {
      _restoredOcrPages.add(item.page);
    }
    _flushPendingOcrOverlays();
  }

  Future<void> _showOcrResultSheet(
    BuildContext context, {
    required Book book,
    required int pageNumber,
    required OcrPageResult result,
  }) async {
    final locator = ReadingLocator.pdf(
      page: pageNumber,
      progress: _currentLocation?.progress ?? 0,
      excerpt: result.text.length > 120
          ? '${result.text.substring(0, 120)}…'
          : result.text,
    );

    if (context.supportsSidePanel) {
      // Desktop: inject into AI panel as the primary "ask" path, and also show
      // a lightweight dialog for copy / review.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('本页文本（OCR · 第 $pageNumber 页）'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文本识别在本地完成，不会上传书籍页面。',
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: SelectableText(result.text),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: result.text));
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(const SnackBar(content: Text('已复制本页文本')));
                  }
                },
                child: const Text('复制'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(
                    _showAiPanel(
                      context,
                      locatorOverride: locator,
                      initialContextOverride: result.text,
                    ),
                  );
                },
                child: const Text('问 AI'),
              ),
            ],
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ReaderBottomSheetFrame(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本页文本（OCR · 第 $pageNumber 页）',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '文本识别在本地完成，不会上传书籍页面。',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(result.text),
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: result.text),
                          );
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(content: Text('已复制本页文本')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('复制'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(
                            _showAiPanel(
                              context,
                              locatorOverride: locator,
                              initialContextOverride: result.text,
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('问 AI'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAiPanel(
    BuildContext context, {
    ReadingLocator? locatorOverride,
    String? initialContextOverride,
  }) async {
    // Desktop: open the right-rail AI tab only — never stack a second sheet.
    if (context.supportsSidePanel) {
      final overrideText = initialContextOverride?.trim();
      if (overrideText != null && overrideText.isNotEmpty) {
        final locator =
            locatorOverride ??
            _selectedText?.locator ??
            _currentLocation?.locator ??
            ref.read(readerProgressProvider(widget.bookId)).value?.locator;
        if (locator != null) {
          setState(() {
            _selectedText = RendererTextSelected(
              text: overrideText,
              locator: locator,
            );
          });
        }
      }
      _openDesktopContext(_ReaderContextTab.ai);
      return;
    }

    final location = _currentLocation;
    final progress = ref.read(readerProgressProvider(widget.bookId)).value;
    final selectedText = _selectedText;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReaderBottomSheetFrame(
        child: AiPanel(
          bookId: widget.bookId,
          locator:
              locatorOverride ??
              selectedText?.locator ??
              location?.locator ??
              progress?.locator,
          initialContext:
              initialContextOverride ??
              selectedText?.text ??
              location?.locator.excerpt ??
              progress?.locator.excerpt,
          onJumpTo: _jumpTo,
          onNoteSaved: () {
            ref.invalidate(notesByBookProvider(widget.bookId));
          },
        ),
      ),
    );
  }
}

final class _InBookSearchSheet extends ConsumerStatefulWidget {
  const _InBookSearchSheet({
    required this.bookId,
    required this.onQueryChanged,
    required this.onPreviewResult,
    required this.onClear,
    this.initialQuery,
    this.currentLocator,
    this.onClose,
    this.onAction,
    this.embedded = false,
  });

  final String bookId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ReadingLocator> onPreviewResult;
  final VoidCallback onClear;
  final String? initialQuery;
  final ReadingLocator? currentLocator;
  final VoidCallback? onClose;
  final ValueChanged<_InBookSearchAction>? onAction;
  final bool embedded;

  @override
  ConsumerState<_InBookSearchSheet> createState() => _InBookSearchSheetState();
}

final class _InBookSearchSheetState extends ConsumerState<_InBookSearchSheet> {
  final _queryController = TextEditingController();
  late final InBookSearchController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = InBookSearchController(
      bookId: widget.bookId,
      repository: ref.read(searchRepositoryProvider),
      currentLocator: widget.currentLocator,
    )..addListener(_handleSearchStateChanged);
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _queryController.text = initialQuery;
      _searchController.updateQuery(initialQuery);
      unawaited(_searchController.searchNow(initialQuery));
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchStateChanged)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InBookSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery?.trim() ?? '';
    final oldQuery = oldWidget.initialQuery?.trim() ?? '';
    if (nextQuery.isNotEmpty &&
        nextQuery != oldQuery &&
        nextQuery != _queryController.text.trim()) {
      _queryController.text = nextQuery;
      _searchController.updateQuery(nextQuery);
      unawaited(_searchController.searchNow(nextQuery));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _searchController.state;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _selectNextAndPreview,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            _selectPreviousAndPreview,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: Padding(
            padding: widget.embedded
                ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                : EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                  ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '本书搜索',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭搜索',
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SearchBar(
                  controller: _queryController,
                  hintText: '搜索当前书籍',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_queryController.text.isNotEmpty)
                      IconButton(
                        tooltip: '清空搜索',
                        onPressed: _clear,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  onChanged: _updateQuery,
                  onSubmitted: (_) => _selectNextAndPreview(),
                ),
                const SizedBox(height: 12),
                if (state.results.isNotEmpty)
                  _SearchNavigationBar(
                    state: state,
                    onPrevious: _selectPreviousAndPreview,
                    onNext: _selectNextAndPreview,
                    onJump: () => _previewSearchResult(state.selectedResult),
                  ),
                const SizedBox(height: 8),
                _buildSearchBody(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectNextAndPreview() {
    final state = _searchController.state;
    if (state.results.isEmpty) {
      unawaited(_searchController.searchNow(_queryController.text));
      return;
    }
    _searchController.selectNext();
    _previewSearchResult(_searchController.state.selectedResult);
  }

  void _selectPreviousAndPreview() {
    final state = _searchController.state;
    if (state.results.isEmpty) {
      unawaited(_searchController.searchNow(_queryController.text));
      return;
    }
    _searchController.selectPrevious();
    _previewSearchResult(_searchController.state.selectedResult);
  }

  void _close() {
    widget.onClear();
    widget.onClose?.call();
    if (!widget.embedded) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildSearchBody(BuildContext context, InBookSearchState state) {
    if (state.query.isEmpty) {
      return const Center(child: Text('输入关键词搜索当前书籍'));
    }
    if (state.isSearching) {
      return const LinearProgressIndicator();
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _searchController.retry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (state.results.isEmpty) {
      return const Center(child: Text('没有找到匹配内容'));
    }
    return Column(
      children: [
        for (var index = 0; index < state.results.length; index++)
          _SearchResultTile(
            result: state.results[index],
            selected: index == state.selectedIndex,
            onSelected: () {
              _searchController.select(index);
              _previewSearchResult(state.results[index]);
            },
            onSaveNote: () => _saveSearchResultAsNote(state.results[index]),
            onAskAi: () => _popSearchAction(
              state.results[index],
              intent: _InBookSearchIntent.askAi,
            ),
          ),
      ],
    );
  }

  void _handleSearchStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    _queryController.clear();
    _searchController.clear();
    widget.onClear();
  }

  void _updateQuery(String value) {
    _searchController.updateQuery(value);
    widget.onQueryChanged(value);
  }

  void _popSearchAction(
    SearchResult? result, {
    _InBookSearchIntent intent = _InBookSearchIntent.jump,
  }) {
    final locator = result?.locator;
    if (result == null || locator == null) {
      return;
    }
    final action = _InBookSearchAction(
      locator: locator,
      sourceText: _plainSearchSnippet(result.snippet),
      intent: intent,
    );
    if (widget.onAction != null) {
      widget.onAction!(action);
      return;
    }
    Navigator.of(context).pop(action);
  }

  void _previewSearchResult(SearchResult? result) {
    final locator = result?.locator;
    if (locator == null) {
      return;
    }
    widget.onPreviewResult(locator);
  }

  Future<void> _saveSearchResultAsNote(SearchResult result) async {
    final text = _plainSearchSnippet(result.snippet);
    if (text.isEmpty) {
      return;
    }
    await ref
        .read(noteRepositoryProvider)
        .saveNote(
          bookId: widget.bookId,
          title: result.title,
          content: text,
          sourceText: text,
          locator: result.locator,
          noteType: NoteType.excerpt,
        );
    ref.invalidate(notesByBookProvider(widget.bookId));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存为笔记'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

enum _ReaderContextTab {
  search('搜索', Icons.search),
  notebook('笔记', Icons.library_books_outlined),
  ai('AI', Icons.auto_awesome_outlined);

  const _ReaderContextTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _ReaderMoreAction {
  pageJump,
  pdfFitWidth,
  pdfFitPage,
  pdfZoomOut,
  pdfZoomIn,
  readerMode,
  notebook,
  ai,
  addAnnotation,
  createNote,
}

final class _ReaderToolbarButton extends StatelessWidget {
  const _ReaderToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = MediaQuery.sizeOf(context).width >= 980;
    if (!showLabel) {
      return IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

final class _MobileReaderTopBar extends StatelessWidget {
  const _MobileReaderTopBar({
    required this.title,
    required this.progress,
    required this.locationLabel,
    required this.onBack,
    required this.onToc,
    required this.onMore,
  });

  final String title;
  final double? progress;
  final String locationLabel;
  final Future<void> Function() onBack;
  final VoidCallback onToc;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = ((progress ?? 0).clamp(0.0, 1.0) * 100).round();
    return _ReaderFloatingChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回书库',
                  onPressed: () => unawaited(onBack()),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$locationLabel · $percentage%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '目录',
                  onPressed: onToc,
                  icon: const Icon(Icons.toc),
                ),
                IconButton(
                  tooltip: '更多',
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.lg),
            ),
            child: LinearProgressIndicator(
              value: (progress ?? 0).clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

final class _MobileReaderBottomBar extends StatelessWidget {
  const _MobileReaderBottomBar({
    required this.book,
    required this.locator,
    required this.progress,
    required this.chapterTitle,
    required this.pageNumber,
    required this.totalPages,
    required this.bookmarked,
    required this.onToc,
    required this.onSearch,
    required this.onBookmark,
    required this.onMore,
    this.onProgressTap,
    this.searchAvailable = true,
  });

  final Book book;
  final ReadingLocator? locator;
  final double? progress;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;
  final bool bookmarked;
  final VoidCallback onToc;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onMore;
  final VoidCallback? onProgressTap;
  final bool searchAvailable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = ((progress ?? locator?.progress ?? 0).clamp(0, 1) * 100)
        .round();
    final location = _readerLocationText(
      book: book,
      locator: locator,
      chapterTitle: chapterTitle,
      pageNumber: pageNumber,
      totalPages: totalPages,
    );

    return _ReaderFloatingChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProgressTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onProgressTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x1,
              0,
              AppSpacing.x1,
              AppSpacing.x1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MobileReaderActionButton(
                    icon: Icons.toc,
                    label: '目录',
                    onPressed: onToc,
                  ),
                ),
                Expanded(
                  child: _MobileReaderActionButton(
                    icon: Icons.search,
                    label: '搜索',
                    onPressed: searchAvailable ? onSearch : () {},
                    enabled: searchAvailable,
                  ),
                ),
                Expanded(
                  child: _MobileReaderActionButton(
                    icon: bookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_add_outlined,
                    label: bookmarked ? '已书签' : '书签',
                    selected: bookmarked,
                    onPressed: onBookmark,
                  ),
                ),
                Expanded(
                  child: _MobileReaderActionButton(
                    icon: Icons.more_horiz,
                    label: '更多',
                    onPressed: onMore,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _MobileReaderMoreSheet extends StatelessWidget {
  const _MobileReaderMoreSheet({
    required this.book,
    required this.settings,
    required this.bookmarked,
    required this.searchAvailable,
    required this.textLayerAvailable,
    required this.onSearch,
    required this.onBookmark,
    required this.onNotebook,
    required this.onAi,
    required this.onSettings,
    required this.onQuickTheme,
    required this.onToggleReaderMode,
    this.capabilityReason,
    this.onPageJump,
    this.onZoomOut,
    this.onZoomIn,
    this.onFitWidth,
    this.onFitPage,
    this.onOcrPage,
  });

  final Book book;
  final ReaderSettings settings;
  final bool bookmarked;
  final bool searchAvailable;
  final bool textLayerAvailable;
  final String? capabilityReason;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onNotebook;
  final VoidCallback onAi;
  final VoidCallback onSettings;
  final VoidCallback onQuickTheme;
  final VoidCallback onToggleReaderMode;
  final VoidCallback? onPageJump;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onFitWidth;
  final VoidCallback? onFitPage;
  final VoidCallback? onOcrPage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPdf = book.format == BookFormat.pdf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读操作',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (isPdf && (!textLayerAvailable || !searchAvailable)) ...[
            const SizedBox(height: AppSpacing.x3),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: colorScheme.statusWarning,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        capabilityReason ??
                            (!textLayerAvailable
                                ? '无文本层 · 可用「识别可见页」；标注为近似定位'
                                : '不支持书内搜索'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onOcrPage != null) ...[
              const SizedBox(height: AppSpacing.x2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onOcrPage,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('识别可见页'),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.x3),
          if (isPdf) ...[
            Text(
              'PDF',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                if (onPageJump != null)
                  _MobileMoreChip(
                    icon: Icons.pin_outlined,
                    label: '跳转页码',
                    onTap: onPageJump!,
                  ),
                if (onZoomOut != null)
                  _MobileMoreChip(
                    icon: Icons.zoom_out,
                    label: '缩小',
                    onTap: onZoomOut!,
                  ),
                if (onZoomIn != null)
                  _MobileMoreChip(
                    icon: Icons.zoom_in,
                    label: '放大',
                    onTap: onZoomIn!,
                  ),
                if (onFitWidth != null)
                  _MobileMoreChip(
                    icon: Icons.fit_screen_outlined,
                    label: '适合宽度',
                    selected: settings.pdfZoomMode == PdfZoomMode.fitWidth,
                    onTap: onFitWidth!,
                  ),
                if (onFitPage != null)
                  _MobileMoreChip(
                    icon: Icons.fullscreen_outlined,
                    label: '适合页面',
                    selected: settings.pdfZoomMode == PdfZoomMode.fitPage,
                    onTap: onFitPage!,
                  ),
                if (onOcrPage != null)
                  _MobileMoreChip(
                    icon: Icons.document_scanner_outlined,
                    label: '识别可见页',
                    onTap: onOcrPage!,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          Text(
            '常用',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.search),
            title: const Text('书内搜索'),
            enabled: searchAvailable,
            onTap: searchAvailable ? onSearch : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              bookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
            ),
            title: Text(bookmarked ? '取消书签' : '添加书签'),
            onTap: onBookmark,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('笔记与标注'),
            onTap: onNotebook,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI 助手'),
            onTap: onAi,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.brightness_4_outlined),
            title: const Text('快速主题'),
            subtitle: Text(settings.themePreset.label),
            onTap: onQuickTheme,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_day_outlined),
            title: Text(
              settings.readerMode == ReaderMode.paged ? '切换连续滚动' : '切换分页阅读',
            ),
            onTap: onToggleReaderMode,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('阅读设置'),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

final class _MobileMoreChip extends StatelessWidget {
  const _MobileMoreChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.secondaryContainer,
    );
  }
}

final class _PdfQuickToolbar extends StatelessWidget {
  const _PdfQuickToolbar({
    required this.pageNumber,
    required this.totalPages,
    required this.settings,
    required this.bookmarked,
    required this.onPageJump,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFitWidth,
    required this.onFitPage,
    required this.onSearch,
    required this.onBookmark,
    this.searchAvailable = true,
    this.textLayerAvailable = true,
    this.capabilityReason,
    this.onOcrPage,
  });

  final int? pageNumber;
  final int? totalPages;
  final ReaderSettings settings;
  final bool bookmarked;
  final VoidCallback onPageJump;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final bool searchAvailable;
  final bool textLayerAvailable;
  final String? capabilityReason;
  final VoidCallback? onOcrPage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pageLabel = _pdfPageLabel(pageNumber, totalPages);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!textLayerAvailable || !searchAvailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x2,
              AppSpacing.x1,
              AppSpacing.x2,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                // Compact status, not a sticky warning paragraph.
                !textLayerAvailable
                    ? (onOcrPage != null ? '无文本层 · 可识别（标注为近似）' : '无文本层')
                    : '搜索不可用',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x2,
            AppSpacing.x2,
            AppSpacing.x2,
            AppSpacing.x2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PdfToolbarChip(
                icon: Icons.pin_outlined,
                label: pageLabel,
                tooltip: '跳转页码',
                onPressed: onPageJump,
              ),
              const SizedBox(width: AppSpacing.x1),
              _PdfToolbarIconButton(
                icon: Icons.zoom_out,
                tooltip: '缩小 PDF',
                onPressed: onZoomOut,
              ),
              _PdfToolbarIconButton(
                icon: Icons.zoom_in,
                tooltip: '放大 PDF',
                onPressed: onZoomIn,
              ),
              const SizedBox(width: AppSpacing.x1),
              _PdfToolbarIconButton(
                icon: Icons.fit_screen_outlined,
                tooltip: '适合宽度',
                selected: settings.pdfZoomMode == PdfZoomMode.fitWidth,
                onPressed: onFitWidth,
              ),
              _PdfToolbarIconButton(
                icon: Icons.fullscreen_outlined,
                tooltip: '适合页面',
                selected: settings.pdfZoomMode == PdfZoomMode.fitPage,
                onPressed: onFitPage,
              ),
              const SizedBox(width: AppSpacing.x1),
              _PdfToolbarIconButton(
                icon: Icons.search,
                tooltip: searchAvailable ? '搜索 PDF' : '此 PDF 不可搜索',
                onPressed: searchAvailable ? onSearch : null,
              ),
              if (onOcrPage != null) ...[
                const SizedBox(width: AppSpacing.x1),
                _PdfToolbarChip(
                  icon: Icons.document_scanner_outlined,
                  label: '识别可见页',
                  tooltip: '识别当前可见页（双页模式会识别对开两页）',
                  onPressed: onOcrPage!,
                ),
              ],
              _PdfToolbarIconButton(
                icon: bookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
                tooltip: bookmarked ? '取消书签' : '添加书签',
                selected: bookmarked,
                onPressed: onBookmark,
              ),
            ],
          ),
        ),
      ],
    );

    return _ReaderFloatingChrome(child: content);
  }
}

final class _PdfToolbarChip extends StatelessWidget {
  const _PdfToolbarChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PdfToolbarIconButton extends StatelessWidget {
  const _PdfToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: selected,
          label: tooltip,
          child: IconButton.filledTonal(
            tooltip: tooltip,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              fixedSize: const Size(40, 40),
              backgroundColor: selected
                  ? colorScheme.secondaryContainer
                  : colorScheme.surfaceSubtle,
              foregroundColor: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
          ),
        ),
      ),
    );
  }
}

String _pdfPageLabel(int? pageNumber, int? totalPages) {
  if (pageNumber != null && totalPages != null && totalPages > 0) {
    return '$pageNumber / $totalPages';
  }
  if (pageNumber != null) {
    return '第 $pageNumber 页';
  }
  return '页码';
}

final class _MobileReaderActionButton extends StatelessWidget {
  const _MobileReaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? colorScheme.primary
        : colorScheme.onSurface;
    final secondary = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: secondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ReaderChromeRevealButton extends StatelessWidget {
  const _ReaderChromeRevealButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.96),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(
                '菜单',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReaderFloatingChrome extends StatelessWidget {
  const _ReaderFloatingChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colorScheme.appBorder),
        ),
        child: child,
      ),
    );
  }
}

final class _ReaderBottomSheetFrame extends StatelessWidget {
  const _ReaderBottomSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: child,
    );
  }
}

enum _SelectionAction { highlight, underline, note, search, copy, ai }

enum _FloatingMenuSide { above, below, left, right, fallback }

final class _FloatingMenuPlacement {
  const _FloatingMenuPlacement({
    required this.left,
    required this.top,
    required this.side,
  });

  final double left;
  final double top;
  final _FloatingMenuSide side;
}

final class _DesktopSelectionOverlay extends StatelessWidget {
  const _DesktopSelectionOverlay({
    required this.selection,
    required this.onAction,
    required this.onDismiss,
  });

  final RendererTextSelected selection;
  final ValueChanged<_SelectionAction> onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = selection.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shortPreview = preview.length <= 18
        ? preview
        : '${preview.substring(0, 18).trim()}…';

    Widget action({
      required IconData icon,
      required String label,
      required _SelectionAction value,
      bool accent = false,
    }) {
      final fg = accent ? colorScheme.primary : colorScheme.onSurface;
      final bg = accent
          ? colorScheme.primaryContainer.withValues(alpha: 0.85)
          : Colors.transparent;
      return Tooltip(
        message: label,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onAction(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      elevation: 14,
      color: colorScheme.surface,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.95),
          ),
          color: colorScheme.surface.withValues(alpha: 0.99),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shortPreview.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Tooltip(
                    message: preview,
                    child: Text(
                      shortPreview,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colorScheme.outlineVariant,
                ),
              ],
              action(
                icon: Icons.format_color_fill_outlined,
                label: '高亮',
                value: _SelectionAction.highlight,
              ),
              action(
                icon: Icons.format_underlined,
                label: '下划线',
                value: _SelectionAction.underline,
              ),
              action(
                icon: Icons.note_add_outlined,
                label: '笔记',
                value: _SelectionAction.note,
              ),
              action(
                icon: Icons.copy_outlined,
                label: '复制',
                value: _SelectionAction.copy,
              ),
              action(
                icon: Icons.search,
                label: '搜索',
                value: _SelectionAction.search,
              ),
              action(
                icon: Icons.auto_awesome_outlined,
                label: 'AI',
                value: _SelectionAction.ai,
                accent: true,
              ),
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SelectionActionSurface extends StatelessWidget {
  const _SelectionActionSurface({
    required this.selection,
    required this.onAction,
    required this.onDismiss,
    this.compact = false,
  });

  final RendererTextSelected selection;
  final ValueChanged<_SelectionAction> onAction;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = selection.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.x4 : AppSpacing.x3,
        compact ? AppSpacing.x2 : AppSpacing.x3,
        compact ? AppSpacing.x4 : AppSpacing.x3,
        compact ? AppSpacing.x4 : AppSpacing.x3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '选中文本',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭选择操作',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            Text(
              preview,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              _SelectionChipAction(
                icon: Icons.format_color_fill_outlined,
                label: '高亮',
                onTap: () => onAction(_SelectionAction.highlight),
              ),
              _SelectionChipAction(
                icon: Icons.note_add_outlined,
                label: '笔记',
                onTap: () => onAction(_SelectionAction.note),
              ),
              _SelectionChipAction(
                icon: Icons.copy_outlined,
                label: '复制',
                onTap: () => onAction(_SelectionAction.copy),
              ),
              _SelectionChipAction(
                icon: Icons.auto_awesome_outlined,
                label: 'AI',
                accent: true,
                onTap: () => onAction(_SelectionAction.ai),
              ),
              // Secondary actions last — keep the first row thumb-friendly.
              _SelectionChipAction(
                icon: Icons.format_underlined,
                label: '下划线',
                onTap: () => onAction(_SelectionAction.underline),
              ),
              _SelectionChipAction(
                icon: Icons.search,
                label: '搜索',
                onTap: () => onAction(_SelectionAction.search),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SelectionChipAction extends StatelessWidget {
  const _SelectionChipAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = accent ? colorScheme.primary : colorScheme.onSurface;
    final background = accent
        ? colorScheme.primaryContainer
        : colorScheme.surfaceSubtle;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: accent
                    ? colorScheme.primary.withValues(alpha: 0.28)
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ContextTabChip extends StatelessWidget {
  const _ContextTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _ReaderContextTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      elevation: selected ? 0.4 : 0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 16,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                tab.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DesktopContextPane extends StatelessWidget {
  const _DesktopContextPane({
    required this.bookId,
    required this.activeTab,
    required this.searchQuery,
    required this.currentLocator,
    required this.selectedText,
    required this.selectedLocator,
    required this.onQueryChanged,
    required this.onPreviewResult,
    required this.onClear,
    required this.onClose,
    required this.onTabChanged,
    required this.onAction,
    required this.onAskAi,
    this.onNoteSaved,
  });

  final String bookId;
  final _ReaderContextTab activeTab;
  final String? searchQuery;
  final ReadingLocator? currentLocator;
  final String? selectedText;
  final ReadingLocator? selectedLocator;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ReadingLocator> onPreviewResult;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final ValueChanged<_ReaderContextTab> onTabChanged;
  final ValueChanged<_InBookSearchAction> onAction;
  final Future<void> Function(BuildContext context) onAskAi;
  final VoidCallback? onNoteSaved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.appBorder.withValues(alpha: 0.95),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x2,
                AppSpacing.x2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          switch (activeTab) {
                            _ReaderContextTab.search => '在本书内查找并跳转',
                            _ReaderContextTab.notebook => '书签、标注与笔记',
                            _ReaderContextTab.ai => '对选中文本提问',
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '收起侧栏',
                    onPressed: onClose,
                    icon: const Icon(Icons.keyboard_tab),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x3,
                0,
                AppSpacing.x3,
                AppSpacing.x3,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceSubtle.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: colorScheme.appBorder.withValues(alpha: 0.85),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      for (final tab in _ReaderContextTab.values)
                        Expanded(
                          child: _ContextTabChip(
                            tab: tab,
                            selected: activeTab == tab,
                            onTap: () => onTabChanged(tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.appBorder.withValues(alpha: 0.9),
            ),
            Expanded(child: _buildTab(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context) {
    return switch (activeTab) {
      _ReaderContextTab.search => _InBookSearchSheet(
        bookId: bookId,
        initialQuery: searchQuery,
        currentLocator: currentLocator,
        onQueryChanged: onQueryChanged,
        onPreviewResult: onPreviewResult,
        onClear: onClear,
        onClose: onClose,
        onAction: onAction,
        embedded: true,
      ),
      _ReaderContextTab.notebook => _DesktopNotebookPane(
        bookId: bookId,
        onSelected: onPreviewResult,
      ),
      _ReaderContextTab.ai => AiPanel(
        bookId: bookId,
        locator: selectedLocator ?? currentLocator,
        initialContext: selectedText ?? currentLocator?.excerpt,
        onJumpTo: onPreviewResult,
        onNoteSaved: onNoteSaved,
        embedded: true,
      ),
    };
  }
}

final class _SearchNavigationBar extends StatelessWidget {
  const _SearchNavigationBar({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
  });

  final InBookSearchState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('${state.selectedIndex + 1}/${state.results.length}'),
        const Spacer(),
        IconButton(
          tooltip: '上一条',
          onPressed: onPrevious,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: '下一条',
          onPressed: onNext,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        FilledButton.icon(
          onPressed: state.selectedResult?.locator == null ? null : onJump,
          icon: const Icon(Icons.near_me_outlined),
          label: const Text('跳转'),
        ),
      ],
    );
  }
}

final class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.selected,
    required this.onSelected,
    required this.onSaveNote,
    required this.onAskAi,
  });

  final SearchResult result;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onSaveNote;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    final snippet = _plainSearchSnippet(result.snippet);
    return ListTile(
      selected: selected,
      leading: Icon(
        selected ? Icons.arrow_right_outlined : Icons.article_outlined,
      ),
      title: Text(result.title),
      subtitle: Text(snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '保存搜索结果为笔记',
            onPressed: result.locator == null ? null : onSaveNote,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: '对搜索结果片段提问',
            onPressed: result.locator == null ? null : onAskAi,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      onTap: result.locator == null ? null : onSelected,
    );
  }
}

enum _InBookSearchIntent { jump, askAi }

final class _InBookSearchAction {
  const _InBookSearchAction({
    required this.locator,
    required this.sourceText,
    required this.intent,
  });

  final ReadingLocator locator;
  final String sourceText;
  final _InBookSearchIntent intent;
}

String _plainSearchSnippet(String value) {
  return value.replaceAll(RegExp('<[^>]+>'), '').trim();
}

final bookmarksByBookProvider = StreamProvider.family<List<Bookmark>, String>((
  ref,
  bookId,
) {
  return ref.watch(bookmarkRepositoryProvider).watchByBook(bookId);
});

final notesByBookProvider = FutureProvider.family<List<Note>, String>((
  ref,
  bookId,
) {
  return ref.watch(noteRepositoryProvider).getByBook(bookId);
});

final class _DesktopNotebookPane extends ConsumerWidget {
  const _DesktopNotebookPane({required this.bookId, required this.onSelected});

  final String bookId;
  final ValueChanged<ReadingLocator> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _NotebookContent(bookId: bookId, onSelected: onSelected);
  }
}

final class _NotebookSheet extends ConsumerWidget {
  const _NotebookSheet({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notebook',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭 Notebook',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _NotebookContent(
                bookId: bookId,
                onSelected: (locator) => Navigator.of(context).pop(locator),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NotebookContent extends ConsumerWidget {
  const _NotebookContent({required this.bookId, required this.onSelected});

  final String bookId;
  final ValueChanged<ReadingLocator> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksByBookProvider(bookId));
    final annotations = ref.watch(annotationsByBookProvider(bookId));
    final notes = ref.watch(notesByBookProvider(bookId));
    if (bookmarks.isLoading || annotations.isLoading || notes.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bookmarks.hasError || annotations.hasError || notes.hasError) {
      return const Center(child: Text('无法读取 Notebook'));
    }
    return StreamBuilder<List<AiConversation>>(
      stream: ref.watch(aiConversationRepositoryProvider).watchConversations(),
      builder: (context, snapshot) {
        final entries = _buildNotebookEntries(
          bookmarks.value ?? const [],
          annotations.value ?? const [],
          notes.value ?? const [],
          (snapshot.data ?? const <AiConversation>[])
              .where((conversation) => conversation.bookId == bookId)
              .toList(growable: false),
        );
        if (entries.isEmpty) {
          return const _ContextEmptyState(
            icon: Icons.library_books_outlined,
            message: '这本书还没有 Notebook 条目',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x6,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _NotebookEntryTile(entry: entries[index], onSelected: onSelected),
        );
      },
    );
  }
}

final class _NotebookEntryTile extends ConsumerWidget {
  const _NotebookEntryTile({required this.entry, required this.onSelected});

  final _NotebookEntry entry;
  final ValueChanged<ReadingLocator> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = entry.color ?? _notebookTypeColor(context, entry.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: entry.locator == null
              ? null
              : () => onSelected(entry.locator!),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: accent.withValues(alpha: 0.30)),
                  ),
                  child: Icon(entry.icon, size: 19, color: accent),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _NotebookMetaChip(label: entry.label, color: accent),
                          const SizedBox(width: AppSpacing.x2),
                          Expanded(
                            child: Text(
                              _formatNotebookTime(entry.timestamp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colorScheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (entry.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          entry.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.textSecondary),
                        ),
                      ],
                      if (entry.locator != null) ...[
                        const SizedBox(height: AppSpacing.x2),
                        _NotebookMetaChip(
                          label: entry.locator!.displayLabel,
                          color: colorScheme.primary,
                          subtle: true,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_NotebookAction>(
                  tooltip: 'Notebook 条目操作',
                  itemBuilder: (context) => _notebookMenuItems(entry),
                  onSelected: (action) => _handleNotebookAction(
                    context,
                    ref,
                    entry,
                    action,
                    onSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _NotebookMetaChip extends StatelessWidget {
  const _NotebookMetaChip({
    required this.label,
    required this.color,
    this.subtle = false,
  });

  final String label;
  final Color color;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: subtle ? 0.07 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _NotebookEntryType { bookmark, annotation, note, ai }

enum _NotebookAction { jump, edit, note, copy, delete, openNotes }

final class _NotebookEntry {
  const _NotebookEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.source,
    this.locator,
    this.color,
  });

  final _NotebookEntryType type;
  final String title;
  final String subtitle;
  final int timestamp;
  final Object source;
  final ReadingLocator? locator;
  final Color? color;

  String get label {
    return switch (type) {
      _NotebookEntryType.bookmark => '书签',
      _NotebookEntryType.annotation => '标注',
      _NotebookEntryType.note => '笔记',
      _NotebookEntryType.ai => 'AI',
    };
  }

  IconData get icon {
    return switch (type) {
      _NotebookEntryType.bookmark => Icons.bookmark_border,
      _NotebookEntryType.annotation => Icons.border_color_outlined,
      _NotebookEntryType.note => Icons.sticky_note_2_outlined,
      _NotebookEntryType.ai => Icons.auto_awesome_outlined,
    };
  }
}

List<_NotebookEntry> _buildNotebookEntries(
  List<Bookmark> bookmarks,
  List<Annotation> annotations,
  List<Note> notes,
  List<AiConversation> conversations,
) {
  final entries = <_NotebookEntry>[
    for (final bookmark in bookmarks)
      _NotebookEntry(
        type: _NotebookEntryType.bookmark,
        title: bookmark.title ?? bookmark.locator.displayLabel,
        subtitle: bookmark.note?.isNotEmpty == true
            ? bookmark.note!
            : bookmark.excerpt ?? bookmark.locator.displayLabel,
        timestamp: bookmark.updatedAt,
        locator: bookmark.locator,
        source: bookmark,
      ),
    for (final annotation in annotations)
      _NotebookEntry(
        type: _NotebookEntryType.annotation,
        title: annotation.selectedText,
        subtitle: annotation.locator.displayLabel,
        timestamp: annotation.updatedAt,
        locator: annotation.locator,
        source: annotation,
        color: _annotationUiColor(annotation.color),
      ),
    for (final note in notes)
      _NotebookEntry(
        type: _NotebookEntryType.note,
        title: note.title?.isNotEmpty == true ? note.title! : '无标题笔记',
        subtitle: note.sourceText?.isNotEmpty == true
            ? note.sourceText!
            : note.content,
        timestamp: note.updatedAt,
        locator: note.locator,
        source: note,
      ),
    for (final conversation in conversations)
      _NotebookEntry(
        type: _NotebookEntryType.ai,
        title: conversation.prompt,
        subtitle: conversation.answer,
        timestamp: conversation.createdAt,
        locator: conversation.locator,
        source: conversation,
      ),
  ];
  entries.sort((a, b) {
    final aKey = _notebookLocatorSortKey(a.locator);
    final bKey = _notebookLocatorSortKey(b.locator);
    if (aKey != null && bKey != null && aKey != bKey) {
      return aKey.compareTo(bKey);
    }
    if (aKey != null && bKey == null) {
      return -1;
    }
    if (aKey == null && bKey != null) {
      return 1;
    }
    return b.timestamp.compareTo(a.timestamp);
  });
  return entries;
}

double? _notebookLocatorSortKey(ReadingLocator? locator) {
  if (locator == null) {
    return null;
  }
  return switch (locator.type) {
    ReadingLocatorType.pdf => (locator.page ?? 1).toDouble(),
    ReadingLocatorType.epub =>
      ((locator.chapterIndex ?? 0) * 1000000000 + (locator.chapterOffset ?? 0))
          .toDouble(),
  };
}

Color _notebookTypeColor(BuildContext context, _NotebookEntryType type) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (type) {
    _NotebookEntryType.bookmark => colorScheme.statusWarning,
    _NotebookEntryType.annotation => colorScheme.primary,
    _NotebookEntryType.note => colorScheme.statusInfo,
    _NotebookEntryType.ai => colorScheme.aiAccent,
  };
}

List<PopupMenuEntry<_NotebookAction>> _notebookMenuItems(_NotebookEntry entry) {
  return [
    PopupMenuItem(
      value: _NotebookAction.jump,
      enabled: entry.locator != null,
      child: const ListTile(
        dense: true,
        leading: Icon(Icons.near_me_outlined),
        title: Text('跳回原文'),
      ),
    ),
    if (entry.type == _NotebookEntryType.bookmark)
      const PopupMenuItem(
        value: _NotebookAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_note_outlined),
          title: Text('编辑备注'),
        ),
      ),
    if (entry.type == _NotebookEntryType.annotation)
      const PopupMenuItem(
        value: _NotebookAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.palette_outlined),
          title: Text('修改样式'),
        ),
      ),
    if (entry.type == _NotebookEntryType.annotation ||
        entry.type == _NotebookEntryType.ai)
      const PopupMenuItem(
        value: _NotebookAction.note,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.note_add_outlined),
          title: Text('保存为笔记'),
        ),
      ),
    if (entry.type == _NotebookEntryType.note)
      const PopupMenuItem(
        value: _NotebookAction.openNotes,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.open_in_new),
          title: Text('打开笔记页'),
        ),
      ),
    const PopupMenuItem(
      value: _NotebookAction.copy,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.copy_outlined),
        title: Text('复制内容'),
      ),
    ),
    if (entry.type != _NotebookEntryType.ai)
      const PopupMenuItem(
        value: _NotebookAction.delete,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline),
          title: Text('删除'),
        ),
      ),
  ];
}

Future<void> _handleNotebookAction(
  BuildContext context,
  WidgetRef ref,
  _NotebookEntry entry,
  _NotebookAction action,
  ValueChanged<ReadingLocator> onSelected,
) async {
  switch (action) {
    case _NotebookAction.jump:
      final locator = entry.locator;
      if (locator != null) {
        final fallback = switch (entry.source) {
          final Note note => note.sourceText,
          final Annotation annotation => annotation.selectedText,
          final Bookmark bookmark => bookmark.excerpt ?? bookmark.note,
          final AiConversation conversation =>
            conversation.sourceText ?? conversation.contextText,
          _ => entry.subtitle,
        };
        onSelected(enrichLocatorForJump(locator, fallbackExcerpt: fallback));
      }
    case _NotebookAction.edit:
      switch (entry.source) {
        case final Bookmark bookmark:
          await _editBookmarkNote(context, ref, bookmark);
        case final Annotation annotation:
          await _editAnnotation(context, ref, annotation);
      }
    case _NotebookAction.note:
      switch (entry.source) {
        case final Annotation annotation:
          await _saveAnnotationAsNote(context, ref, annotation);
        case final AiConversation conversation:
          await _saveNotebookAiAsNote(context, ref, conversation);
      }
    case _NotebookAction.copy:
      await Clipboard.setData(ClipboardData(text: entry.subtitle));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制内容')));
      }
    case _NotebookAction.delete:
      switch (entry.source) {
        case final Bookmark bookmark:
          await _deleteBookmarkWithUndo(context, ref, bookmark);
        case final Annotation annotation:
          await _deleteAnnotation(context, ref, annotation);
        case final Note note:
          await _deleteNotebookNote(context, ref, note);
      }
    case _NotebookAction.openNotes:
      context.go('/notes');
  }
}

Future<void> _saveNotebookAiAsNote(
  BuildContext context,
  WidgetRef ref,
  AiConversation conversation,
) async {
  final note = await ref
      .read(noteRepositoryProvider)
      .saveNote(
        bookId: conversation.bookId,
        title: conversation.prompt,
        content: conversation.answer,
        sourceText: conversation.sourceText ?? conversation.contextText,
        locator: conversation.locator,
        noteType: NoteType.ai,
      );
  await ref
      .read(aiConversationRepositoryProvider)
      .linkNote(conversationId: conversation.id, noteId: note.id);
  if (conversation.bookId != null) {
    ref.invalidate(notesByBookProvider(conversation.bookId!));
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存为笔记'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

Future<void> _deleteNotebookNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除笔记？'),
      content: const Text('删除后不会影响书籍原文和已有标注。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  await ref.read(noteRepositoryProvider).deleteNote(note.id);
  if (note.bookId != null) {
    ref.invalidate(notesByBookProvider(note.bookId!));
  }
}

String _formatNotebookTime(int millis) {
  final value = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

Bookmark? _bookmarkAtLocator(
  List<Bookmark> bookmarks,
  ReadingLocator? locator,
) {
  if (locator == null) {
    return null;
  }
  for (final bookmark in bookmarks) {
    if (bookmark.locator.matches(locator)) {
      return bookmark;
    }
  }
  return null;
}

Future<void> _editBookmarkNote(
  BuildContext context,
  WidgetRef ref,
  Bookmark bookmark,
) async {
  final controller = TextEditingController(text: bookmark.note ?? '');
  final note = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('编辑书签备注'),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '备注',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (note == null) {
    return;
  }
  await ref
      .read(bookmarkRepositoryProvider)
      .saveBookmark(
        id: bookmark.id,
        bookId: bookmark.bookId,
        locator: bookmark.locator,
        title: bookmark.title,
        note: note.trim().isEmpty ? null : note.trim(),
        excerpt: bookmark.excerpt,
      );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('书签备注已保存')));
}

Future<void> _deleteBookmarkWithUndo(
  BuildContext context,
  WidgetRef ref,
  Bookmark bookmark,
) async {
  await ref.read(bookmarkRepositoryProvider).deleteBookmark(bookmark.id);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('已删除书签'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () => unawaited(
          ref
              .read(bookmarkRepositoryProvider)
              .saveBookmark(
                id: bookmark.id,
                bookId: bookmark.bookId,
                locator: bookmark.locator,
                title: bookmark.title,
                note: bookmark.note,
                excerpt: bookmark.excerpt,
              ),
        ),
      ),
    ),
  );
}

Future<_AnnotationEditorResult?> _showAnnotationEditor(
  BuildContext context, {
  required String initialText,
  AnnotationColor initialColor = AnnotationColor.yellow,
  AnnotationStyle initialStyle = AnnotationStyle.highlight,
  bool textEditable = true,
}) async {
  final textController = TextEditingController(text: initialText);
  var color = initialColor;
  var style = initialStyle;
  final result = await showDialog<_AnnotationEditorResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(textEditable ? '添加标注' : '修改标注样式'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                minLines: 3,
                maxLines: 8,
                readOnly: !textEditable,
                decoration: const InputDecoration(
                  labelText: '原文',
                  helperText: 'EPUB 中能匹配到的文本会被高亮显示',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('颜色', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AnnotationColor.values
                    .map((value) {
                      return ChoiceChip(
                        selected: color == value,
                        avatar: CircleAvatar(
                          backgroundColor: _annotationUiColor(value),
                        ),
                        label: Text(_annotationColorLabel(value)),
                        onSelected: (_) => setDialogState(() => color = value),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text('样式', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<AnnotationStyle>(
                segments: const [
                  ButtonSegment(
                    value: AnnotationStyle.highlight,
                    label: Text('高亮'),
                    icon: Icon(Icons.format_color_fill_outlined),
                  ),
                  ButtonSegment(
                    value: AnnotationStyle.underline,
                    label: Text('下划线'),
                    icon: Icon(Icons.format_underlined),
                  ),
                ],
                selected: {style},
                onSelectionChanged: (values) {
                  setDialogState(() => style = values.single);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _AnnotationEditorResult(
                selectedText: textController.text,
                color: color,
                style: style,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  textController.dispose();
  return result;
}

final class _AnnotationEditorResult {
  const _AnnotationEditorResult({
    required this.selectedText,
    required this.color,
    required this.style,
  });

  final String selectedText;
  final AnnotationColor color;
  final AnnotationStyle style;
}

Color _annotationUiColor(AnnotationColor color) {
  return switch (color) {
    AnnotationColor.yellow => const Color(0xFFFFD85A),
    AnnotationColor.blue => const Color(0xFF7CB7FF),
    AnnotationColor.green => const Color(0xFF74D18A),
    AnnotationColor.red => const Color(0xFFFF8A8A),
    AnnotationColor.purple => const Color(0xFFB79CFF),
  };
}

String _annotationColorLabel(AnnotationColor color) {
  return switch (color) {
    AnnotationColor.yellow => '黄色',
    AnnotationColor.blue => '蓝色',
    AnnotationColor.green => '绿色',
    AnnotationColor.red => '红色',
    AnnotationColor.purple => '紫色',
  };
}

final class _EpubTocSheet extends StatefulWidget {
  const _EpubTocSheet({
    required this.document,
    required this.currentChapterIndex,
    required this.onSelected,
  });

  final EpubDocument document;
  final int? currentChapterIndex;
  final ValueChanged<EpubTocItem> onSelected;

  @override
  State<_EpubTocSheet> createState() => _EpubTocSheetState();
}

final class _EpubTocSheetState extends State<_EpubTocSheet> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _expanded.addAll(
      _tocAncestorKeys(widget.document.toc, widget.currentChapterIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _flattenTocRows(
      widget.document.toc,
      expanded: _expanded,
      filter: '',
    );
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: rows.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text('目录', style: Theme.of(context).textTheme.titleLarge),
            );
          }
          final row = rows[index - 1];
          final item = row.item;
          final expandable = item.children.isNotEmpty;
          final expanded = _expanded.contains(row.key);
          return ListTile(
            selected: widget.currentChapterIndex == item.chapterIndex,
            contentPadding: EdgeInsets.only(
              left: 12.0 + row.level * 18,
              right: 12,
            ),
            leading: IconButton(
              tooltip: expanded ? '折叠' : '展开',
              onPressed: expandable
                  ? () => setState(() {
                      if (expanded) {
                        _expanded.remove(row.key);
                      } else {
                        _expanded.add(row.key);
                      }
                    })
                  : null,
              icon: Icon(
                expandable
                    ? (expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right)
                    : Icons.article_outlined,
              ),
            ),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.chapterIndex == null ? '目录项暂不可跳转' : item.href,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: item.chapterIndex != null,
            onTap: item.chapterIndex == null
                ? null
                : () => widget.onSelected(item),
          );
        },
      ),
    );
  }
}

final class _PdfTocSheet extends StatelessWidget {
  const _PdfTocSheet({
    required this.outline,
    required this.totalPages,
    required this.currentPage,
  });

  final List<RendererOutlineItem> outline;
  final int totalPages;
  final int? currentPage;

  @override
  Widget build(BuildContext context) {
    final items = outline.isEmpty ? _fallbackPageItems() : outline;
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                outline.isEmpty ? '页码' : 'PDF 目录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          final item = items[index - 1];
          return ListTile(
            selected: currentPage == item.page,
            contentPadding: EdgeInsets.only(
              left: 16.0 + item.level * 18.0,
              right: 16,
            ),
            leading: CircleAvatar(child: Text('${item.page}')),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('第 ${item.page} 页'),
            onTap: () => Navigator.of(context).pop(
              ReadingLocator.pdf(
                page: item.page,
                progress: _pageProgress(item.page),
              ),
            ),
          );
        },
      ),
    );
  }

  List<RendererOutlineItem> _fallbackPageItems() {
    return [
      for (var page = 1; page <= totalPages; page += 1)
        RendererOutlineItem(title: '第 $page 页', page: page),
    ];
  }

  double _pageProgress(int page) {
    if (totalPages <= 1) {
      return 1;
    }
    return ((page - 1) / (totalPages - 1)).clamp(0, 1).toDouble();
  }
}

final class _TocRow {
  const _TocRow({required this.item, required this.level, required this.key});

  final EpubTocItem item;
  final int level;
  final String key;
}

List<_TocRow> _flattenTocRows(
  List<EpubTocItem> items, {
  required Set<String> expanded,
  required String filter,
  int level = 0,
  String prefix = '',
}) {
  final rows = <_TocRow>[];
  for (var index = 0; index < items.length; index += 1) {
    final item = items[index];
    final key = prefix.isEmpty ? '$index' : '$prefix.$index';
    final titleMatches =
        filter.isEmpty ||
        item.title.toLowerCase().contains(filter) ||
        (item.chapterIndex != null &&
            '${item.chapterIndex! + 1}'.contains(filter));
    final childRows = _flattenTocRows(
      item.children,
      expanded: expanded,
      filter: filter,
      level: level + 1,
      prefix: key,
    );
    if (filter.isNotEmpty) {
      if (titleMatches) {
        rows.add(_TocRow(item: item, level: level, key: key));
      }
      rows.addAll(childRows);
      continue;
    }
    rows.add(_TocRow(item: item, level: level, key: key));
    if (expanded.contains(key)) {
      rows.addAll(childRows);
    }
  }
  return rows;
}

Set<String> _tocAncestorKeys(List<EpubTocItem> items, int? chapterIndex) {
  if (chapterIndex == null) {
    return {};
  }
  final path = <String>[];
  bool visit(List<EpubTocItem> nodes, String prefix) {
    for (var index = 0; index < nodes.length; index += 1) {
      final key = prefix.isEmpty ? '$index' : '$prefix.$index';
      final item = nodes[index];
      if (item.chapterIndex == chapterIndex) {
        return true;
      }
      if (visit(item.children, key)) {
        path.add(key);
        return true;
      }
    }
    return false;
  }

  visit(items, '');
  return path.toSet();
}

final class _DesktopTocPane extends StatefulWidget {
  const _DesktopTocPane({
    required this.book,
    required this.pdfOutline,
    required this.totalPages,
    required this.currentLocator,
    required this.locationListenable,
    required this.onSelected,
    required this.onClose,
  });

  final Book book;
  final List<RendererOutlineItem> pdfOutline;
  final int? totalPages;
  final ReadingLocator? currentLocator;
  final ValueListenable<RendererLocationChanged?> locationListenable;
  final ValueChanged<ReadingLocator> onSelected;
  final VoidCallback onClose;

  @override
  State<_DesktopTocPane> createState() => _DesktopTocPaneState();
}

final class _DesktopTocPaneState extends State<_DesktopTocPane> {
  Future<EpubDocument>? _epubDocumentFuture;
  final _filterController = TextEditingController();
  final _filterFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Set<String> _expandedTocKeys = {};
  String _filter = '';
  String _appliedFilter = '';
  Timer? _filterDebounce;
  int? _lastAutoScrolledChapter;
  int? _lastAutoScrolledPage;
  bool _seededExpanded = false;

  @override
  void initState() {
    super.initState();
    _updateDocumentFuture();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _filterController.dispose();
    _filterFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DesktopTocPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.libraryFilePath != widget.book.libraryFilePath) {
      _seededExpanded = false;
      _expandedTocKeys.clear();
      _lastAutoScrolledChapter = null;
      _lastAutoScrolledPage = null;
      _filterController.clear();
      _filter = '';
      _appliedFilter = '';
      _updateDocumentFuture();
    }
  }

  void _updateDocumentFuture() {
    _epubDocumentFuture = widget.book.format == BookFormat.epub
        ? EpubDocumentLoader().load(widget.book.libraryFilePath)
        : null;
  }

  void _onFilterChanged(String value) {
    final next = value.trim();
    // Keep raw text in the field; only rebuild the list after a short debounce
    // so typing stays responsive and the caret doesn't fight rebuilds.
    _filter = next;
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _appliedFilter == next) {
        return;
      }
      setState(() => _appliedFilter = next);
    });
    // Rebuild trailing clear button immediately when emptiness flips.
    final hadFilter = _appliedFilter.isNotEmpty || _filter.isNotEmpty;
    final hasFilter = next.isNotEmpty;
    if (hadFilter != hasFilter) {
      setState(() {});
    }
  }

  void _clearFilter() {
    _filterDebounce?.cancel();
    _filterController.clear();
    setState(() {
      _filter = '';
      _appliedFilter = '';
    });
    _filterFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFilter = _filter.isNotEmpty || _appliedFilter.isNotEmpty;
    return AppSidePanel(
      title: widget.book.format == BookFormat.pdf ? 'PDF 目录' : '目录',
      border: AppSidePanelBorder.right,
      trailing: IconButton(
        tooltip: '收起目录',
        onPressed: widget.onClose,
        icon: const Icon(Icons.chevron_left),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x3,
              AppSpacing.x2,
              AppSpacing.x3,
              AppSpacing.x2,
            ),
            child: TextField(
              controller: _filterController,
              focusNode: _filterFocusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onFilterChanged,
              onSubmitted: (value) {
                _filterDebounce?.cancel();
                final next = value.trim();
                if (_appliedFilter != next) {
                  setState(() {
                    _filter = next;
                    _appliedFilter = next;
                  });
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.book.format == BookFormat.pdf
                    ? '过滤标题或页码'
                    : '过滤章节标题',
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: hasFilter
                    ? IconButton(
                        tooltip: '清空',
                        onPressed: _clearFilter,
                        icon: const Icon(Icons.close, size: 18),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.book.format == BookFormat.pdf
                ? _buildPdfToc(context)
                : _buildEpubToc(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEpubToc(BuildContext context) {
    final future = _epubDocumentFuture;
    if (future == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<EpubDocument>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('无法读取目录'));
        }
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<RendererLocationChanged?>(
          valueListenable: widget.locationListenable,
          builder: (context, location, _) {
            final currentChapter =
                location?.locator.chapterIndex ??
                widget.currentLocator?.chapterIndex;
            final filter = _appliedFilter.toLowerCase();
            if (!_seededExpanded) {
              _seededExpanded = true;
              _expandedTocKeys.addAll(
                _tocAncestorKeys(document.toc, currentChapter),
              );
            } else if (filter.isEmpty && currentChapter != null) {
              // Expand ancestors of the current chapter without collapsing user state.
              _expandedTocKeys.addAll(
                _tocAncestorKeys(document.toc, currentChapter),
              );
            }
            final rows = _flattenTocRows(
              document.toc,
              expanded: _expandedTocKeys,
              filter: filter,
            );
            if (rows.isEmpty) {
              return const _ContextEmptyState(
                icon: Icons.toc,
                message: '没有匹配的章节',
              );
            }
            // Only auto-scroll when not filtering, and only when the chapter changes.
            if (filter.isEmpty &&
                currentChapter != null &&
                currentChapter != _lastAutoScrolledChapter &&
                !_filterFocusNode.hasFocus) {
              _lastAutoScrolledChapter = currentChapter;
              _scrollSelectedIntoView(
                rows.indexWhere(
                  (row) => row.item.chapterIndex == currentChapter,
                ),
              );
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final item = row.item;
                final selected = currentChapter == item.chapterIndex;
                final expandable = item.children.isNotEmpty && filter.isEmpty;
                final expanded = _expandedTocKeys.contains(row.key);
                return ListTile(
                  selected: selected,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  enabled: item.chapterIndex != null,
                  contentPadding: EdgeInsets.only(
                    left: 4.0 + row.level * 14,
                    right: 8,
                  ),
                  leading: IconButton(
                    tooltip: expandable ? (expanded ? '折叠' : '展开') : null,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: expandable
                        ? () => setState(() {
                            if (expanded) {
                              _expandedTocKeys.remove(row.key);
                            } else {
                              _expandedTocKeys.add(row.key);
                            }
                          })
                        : null,
                    icon: Icon(
                      item.children.isEmpty
                          ? Icons.article_outlined
                          : expanded || filter.isNotEmpty
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.chapterIndex == null
                        ? '目录项暂不可跳转'
                        : '${(document.progressForChapterIndex(item.chapterIndex!) * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: item.chapterIndex == null
                      ? null
                      : () {
                          widget.onSelected(
                            ReadingLocator.epub(
                              href: item.href,
                              chapterIndex: item.chapterIndex,
                              chapterOffset: item.chapterOffset,
                              progress: document.progressForChapter(
                                chapterIndex: item.chapterIndex!,
                                chapterOffset: item.chapterOffset ?? 0,
                              ),
                            ),
                          );
                        },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPdfToc(BuildContext context) {
    final totalPages = widget.totalPages ?? 0;
    final items = widget.pdfOutline.isEmpty
        ? [
            for (var page = 1; page <= totalPages; page += 1)
              RendererOutlineItem(title: '第 $page 页', page: page),
          ]
        : widget.pdfOutline;
    if (items.isEmpty) {
      return const Center(child: Text('页码准备中'));
    }
    return ValueListenableBuilder<RendererLocationChanged?>(
      valueListenable: widget.locationListenable,
      builder: (context, location, _) {
        final filter = _appliedFilter.toLowerCase();
        final filtered = items
            .where((item) {
              if (filter.isEmpty) {
                return true;
              }
              return item.title.toLowerCase().contains(filter) ||
                  '${item.page}'.contains(filter);
            })
            .toList(growable: false);
        if (filtered.isEmpty) {
          return const _ContextEmptyState(icon: Icons.toc, message: '没有匹配的目录项');
        }
        final currentPage =
            location?.pageNumber ??
            location?.locator.page ??
            widget.currentLocator?.page;
        if (filter.isEmpty &&
            currentPage != null &&
            currentPage != _lastAutoScrolledPage &&
            !_filterFocusNode.hasFocus) {
          _lastAutoScrolledPage = currentPage;
          _scrollSelectedIntoView(
            filtered.indexWhere((item) => item.page == currentPage),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return ListTile(
              selected: currentPage == item.page,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.only(
                left: 8.0 + item.level * 14.0,
                right: 8,
              ),
              leading: SizedBox(
                width: 36,
                child: Text(
                  '${item.page}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('第 ${item.page} 页'),
              onTap: () {
                widget.onSelected(
                  ReadingLocator.pdf(
                    page: item.page,
                    progress: _pdfPageProgress(item.page, totalPages),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  double _pdfPageProgress(int page, int totalPages) {
    if (totalPages <= 1) {
      return 1;
    }
    return ((page - 1) / (totalPages - 1)).clamp(0, 1).toDouble();
  }

  void _scrollSelectedIntoView(int index) {
    if (index < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      const estimatedTileHeight = 56.0;
      final target = (index * estimatedTileHeight - 96).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      if ((_scrollController.offset - target).abs() < estimatedTileHeight) {
        return;
      }
      _scrollController.jumpTo(target.toDouble());
    });
  }
}

/// Leaf host: only this subtree rebuilds when annotations change.
final class _ReaderAnnotationsHost extends ConsumerWidget {
  const _ReaderAnnotationsHost({
    required this.bookId,
    required this.book,
    required this.progress,
    required this.settings,
    required this.version,
    required this.jumpToken,
    required this.searchQuery,
    required this.focusLocator,
    required this.clearSearchHighlightsVersion,
    required this.onEvent,
    required this.ocrOverlayToken,
    required this.ocrOverlayPage,
    required this.ocrOverlayBlocks,
  });

  final String bookId;
  final Book book;
  final ReadingProgressSnapshot? progress;
  final ReaderSettings settings;
  final int version;
  final int jumpToken;
  final String? searchQuery;
  final ReadingLocator? focusLocator;
  final int clearSearchHighlightsVersion;
  final ValueChanged<RendererEvent> onEvent;
  final int ocrOverlayToken;
  final int? ocrOverlayPage;
  final List<Map<String, Object?>> ocrOverlayBlocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annotations =
        ref.watch(annotationsByBookProvider(bookId)).value ??
        const <Annotation>[];
    return ref.watch(readerRendererHostProvider)(
      ReaderRendererHostConfig(
        book: book,
        progress: progress,
        settings: settings,
        annotations: annotations,
        version: version,
        jumpToken: jumpToken,
        searchQuery: searchQuery,
        focusLocator: focusLocator,
        clearSearchHighlightsVersion: clearSearchHighlightsVersion,
        onEvent: onEvent,
        ocrOverlayToken: ocrOverlayToken,
        ocrOverlayPage: ocrOverlayPage,
        ocrOverlayBlocks: ocrOverlayBlocks,
      ),
    );
  }
}

final annotationsByBookProvider =
    StreamProvider.family<List<Annotation>, String>((ref, bookId) {
      return ref.watch(annotationRepositoryProvider).watchByBook(bookId);
    });

final class _ContextEmptyState extends StatelessWidget {
  const _ContextEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAnnotationActions(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text('标注', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            annotation.selectedText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          FutureBuilder<Note?>(
            future: annotation.noteId == null
                ? Future<Note?>.value(null)
                : ref.read(noteRepositoryProvider).getNote(annotation.noteId!),
            builder: (context, snapshot) {
              final note = snapshot.data;
              final hasNote = note != null;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _editAnnotation(context, ref, annotation);
                    },
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('修改样式'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (hasNote) {
                        _openLinkedAnnotationNote(context, note);
                      } else {
                        _saveAnnotationAsNote(context, ref, annotation);
                      }
                    },
                    icon: Icon(
                      hasNote
                          ? Icons.sticky_note_2_outlined
                          : Icons.note_add_outlined,
                    ),
                    label: Text(hasNote ? '查看笔记' : '添加笔记'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteAnnotation(context, ref, annotation);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除标注'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _openLinkedAnnotationNote(BuildContext context, Note note) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(note.title?.trim().isNotEmpty == true ? note.title! : '关联笔记'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note.sourceText?.trim().isNotEmpty == true) ...[
                Text('原文', style: Theme.of(dialogContext).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(note.sourceText!),
                const SizedBox(height: 12),
              ],
              Text('笔记', style: Theme.of(dialogContext).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(note.content),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.go('/notes');
          },
          child: const Text('打开笔记页'),
        ),
      ],
    ),
  );
}

Future<void> _saveAnnotationAsNote(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  if (annotation.noteId != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('这条标注已关联笔记')));
    return;
  }
  final note = await ref
      .read(noteRepositoryProvider)
      .saveNote(
        bookId: annotation.bookId,
        annotationId: annotation.id,
        title: '标注笔记',
        content: annotation.selectedText,
        sourceText: annotation.selectedText,
        locator: annotation.locator,
        noteType: NoteType.excerpt,
      );
  await ref
      .read(annotationRepositoryProvider)
      .linkNote(annotationId: annotation.id, noteId: note.id);
  ref.invalidate(notesByBookProvider(annotation.bookId));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('已保存为笔记'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}

Future<void> _editAnnotation(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  final result = await _showAnnotationEditor(
    context,
    initialText: annotation.selectedText,
    initialColor: annotation.color,
    initialStyle: annotation.style,
    textEditable: false,
  );
  if (result == null) {
    return;
  }
  await ref
      .read(annotationRepositoryProvider)
      .saveAnnotation(
        id: annotation.id,
        bookId: annotation.bookId,
        locator: annotation.locator,
        selectedText: annotation.selectedText,
        color: result.color,
        style: result.style,
      );
}

Future<void> _deleteAnnotation(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除标注？'),
      content: Text(
        annotation.noteId == null ? '删除后不会影响书籍原文。' : '只删除这条标注，关联笔记会保留。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref
        .read(annotationRepositoryProvider)
        .deleteAnnotation(annotation.id);
  }
}

final class _DefaultRendererHost extends StatelessWidget {
  const _DefaultRendererHost({required this.config});

  final ReaderRendererHostConfig config;

  @override
  Widget build(BuildContext context) {
    return switch (config.book.format) {
      BookFormat.epub => EpubRendererView(
        key: ValueKey('epub-${config.book.id}-${config.version}'),
        book: config.book,
        settings: config.settings,
        initialProgress: config.progress,
        annotations: config.annotations,
        searchQuery: config.searchQuery,
        focusLocator: config.focusLocator,
        jumpToken: config.jumpToken,
        onEvent: config.onEvent,
      ),
      // Linux has no flutter_inappwebview implementation (its separate Linux
      // package needs WPE WebKit, which desktop distros do not ship), so it
      // renders through pdf_graphics instead. Other platforms keep the WebView
      // renderer until selection, search and annotation overlays are ported.
      // See docs/10-pdf-renderer-migration.md.
      BookFormat.pdf => Platform.isLinux
          ? PdfCanvasView(
              key: ValueKey('pdf-canvas-${config.book.id}-${config.version}'),
              book: config.book,
              settings: config.settings,
              initialProgress: config.progress,
              onEvent: config.onEvent,
            )
          : PdfRendererView(
              key: ValueKey('pdf-${config.book.id}-${config.version}'),
              book: config.book,
              settings: config.settings,
              initialProgress: config.progress,
              annotations: config.annotations,
              searchQuery: config.searchQuery,
              focusLocator: config.focusLocator,
              clearSearchHighlightsVersion: config.clearSearchHighlightsVersion,
              jumpToken: config.jumpToken,
              ocrOverlayToken: config.ocrOverlayToken,
              ocrOverlayPage: config.ocrOverlayPage,
              ocrOverlayBlocks: config.ocrOverlayBlocks,
              onEvent: config.onEvent,
            ),
    };
  }
}

final class _ReaderSettingsSheet extends ConsumerStatefulWidget {
  const _ReaderSettingsSheet({required this.initialSettings});

  final ReaderSettings initialSettings;

  @override
  ConsumerState<_ReaderSettingsSheet> createState() =>
      _ReaderSettingsSheetState();
}

final class _ReaderSettingsSheetState
    extends ConsumerState<_ReaderSettingsSheet> {
  late ReaderSettings _settings = widget.initialSettings;
  late final TextEditingController _fontController = TextEditingController(
    text: _settings.fontFamily,
  );

  @override
  void dispose() {
    _fontController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          AppSpacing.x2,
          AppSpacing.x5,
          AppSpacing.x6,
        ),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '阅读设置',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () => _update(const ReaderSettings()),
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          _ReaderSettingsPreview(settings: _settings),
          const SizedBox(height: AppSpacing.x4),
          _ReaderSettingsSection(
            icon: Icons.auto_awesome_outlined,
            title: '常用预设',
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    _ReaderSettingsPresetChip(
                      label: '舒适阅读',
                      selected: _isComfortPreset,
                      onSelected: () => _applyPreset(
                        const ReaderSettings(
                          fontSize: 18,
                          lineHeight: 1.7,
                          paragraphSpacing: 12,
                          pageMargin: 24,
                          themePreset: ReaderThemePreset.day,
                        ),
                      ),
                    ),
                    _ReaderSettingsPresetChip(
                      label: '长时间阅读',
                      selected: _isLongReadingPreset,
                      onSelected: () => _applyPreset(
                        const ReaderSettings(
                          fontSize: 19,
                          lineHeight: 1.8,
                          paragraphSpacing: 14,
                          pageMargin: 30,
                          themePreset: ReaderThemePreset.green,
                        ),
                      ),
                    ),
                    _ReaderSettingsPresetChip(
                      label: '高密度',
                      selected: _isDensePreset,
                      onSelected: () => _applyPreset(
                        const ReaderSettings(
                          fontSize: 16,
                          lineHeight: 1.45,
                          paragraphSpacing: 8,
                          pageMargin: 18,
                          themePreset: ReaderThemePreset.day,
                        ),
                      ),
                    ),
                    _ReaderSettingsPresetChip(
                      label: '夜间',
                      selected:
                          _settings.themePreset == ReaderThemePreset.night,
                      onSelected: () => _update(
                        _settings.copyWith(
                          themePreset: ReaderThemePreset.night,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<ReaderMode>(
                    segments: ReaderMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(mode.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: {_settings.readerMode},
                    onSelectionChanged: (values) {
                      _update(_settings.copyWith(readerMode: values.single));
                    },
                  ),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.palette_outlined,
            title: '外观',
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: ReaderThemePreset.values.map((preset) {
                    final selected = _settings.themePreset == preset;
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: selected,
                      avatar: CircleAvatar(backgroundColor: preset.background),
                      onSelected: (_) =>
                          _update(_settings.copyWith(themePreset: preset)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  'EPUB 字体',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: ReaderFonts.options
                      .map((font) {
                        final selected =
                            ReaderFonts.resolve(_settings.fontFamily).id ==
                            font.id;
                        return ChoiceChip(
                          label: Text(font.label),
                          selected: selected,
                          onSelected: (_) {
                            _fontController.text = font.id;
                            _update(_settings.copyWith(fontFamily: font.id));
                          },
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  ReaderFonts.resolve(_settings.fontFamily).description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.article_outlined,
            title: 'EPUB 排版',
            child: Column(
              children: [
                _SliderSetting(
                  label: '字号',
                  value: _settings.fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  displayValue: _settings.fontSize.round().toString(),
                  onChanged: (value) =>
                      _update(_settings.copyWith(fontSize: value)),
                ),
                _SliderSetting(
                  label: '行高',
                  value: _settings.lineHeight,
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  displayValue: _settings.lineHeight.toStringAsFixed(1),
                  onChanged: (value) =>
                      _update(_settings.copyWith(lineHeight: value)),
                ),
                _SliderSetting(
                  label: '段距',
                  value: _settings.paragraphSpacing,
                  min: 0,
                  max: 32,
                  divisions: 16,
                  displayValue: _settings.paragraphSpacing.round().toString(),
                  onChanged: (value) =>
                      _update(_settings.copyWith(paragraphSpacing: value)),
                ),
                _SliderSetting(
                  label: '页边距',
                  value: _settings.pageMargin,
                  min: 12,
                  max: 72,
                  divisions: 20,
                  displayValue: _settings.pageMargin.round().toString(),
                  onChanged: (value) =>
                      _update(_settings.copyWith(pageMargin: value)),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF 缩放',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<PdfZoomMode>(
                    segments: const [
                      ButtonSegment(
                        value: PdfZoomMode.fitWidth,
                        label: Text('适宽'),
                        icon: Icon(Icons.fit_screen_outlined),
                      ),
                      ButtonSegment(
                        value: PdfZoomMode.fitPage,
                        label: Text('整页'),
                        icon: Icon(Icons.fullscreen_outlined),
                      ),
                      ButtonSegment(
                        value: PdfZoomMode.actual,
                        label: Text('实际'),
                        icon: Icon(Icons.center_focus_strong_outlined),
                      ),
                      ButtonSegment(
                        value: PdfZoomMode.custom,
                        label: Text('自定义'),
                        icon: Icon(Icons.tune),
                      ),
                    ],
                    selected: {_settings.pdfZoomMode},
                    onSelectionChanged: (values) {
                      final mode = values.single;
                      _update(
                        _settings.copyWith(
                          pdfZoomMode: mode,
                          pdfScale: mode == PdfZoomMode.actual
                              ? 1
                              : _settings.pdfScale,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _SliderSetting(
                  label: '自定义缩放',
                  value: _settings.pdfScale,
                  min: 0.7,
                  max: 2.4,
                  divisions: 17,
                  displayValue: '${(_settings.pdfScale * 100).round()}%',
                  onChanged: (value) => _update(
                    _settings.copyWith(
                      pdfScale: value,
                      pdfZoomMode: PdfZoomMode.custom,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ReaderSettingsSection(
            icon: Icons.settings_outlined,
            title: '高级',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('系统')),
                      ButtonSegment(value: ThemeMode.light, label: Text('亮色')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('暗色')),
                    ],
                    selected: {_settings.appThemeMode},
                    onSelectionChanged: (values) {
                      _update(_settings.copyWith(appThemeMode: values.single));
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('减少动画'),
                  subtitle: const Text('阅读器尽量减少过渡动画'),
                  value: _settings.reduceMotion,
                  onChanged: (value) =>
                      _update(_settings.copyWith(reduceMotion: value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isComfortPreset {
    return _settings.fontSize.round() == 18 &&
        _settings.lineHeight.toStringAsFixed(1) == '1.7' &&
        _settings.paragraphSpacing.round() == 12 &&
        _settings.pageMargin.round() == 24 &&
        _settings.themePreset == ReaderThemePreset.day;
  }

  bool get _isLongReadingPreset {
    return _settings.fontSize.round() == 19 &&
        _settings.lineHeight.toStringAsFixed(1) == '1.8' &&
        _settings.paragraphSpacing.round() == 14 &&
        _settings.pageMargin.round() == 30 &&
        _settings.themePreset == ReaderThemePreset.green;
  }

  bool get _isDensePreset {
    return _settings.fontSize.round() == 16 &&
        _settings.lineHeight.toStringAsFixed(2) == '1.45' &&
        _settings.paragraphSpacing.round() == 8 &&
        _settings.pageMargin.round() == 18 &&
        _settings.themePreset == ReaderThemePreset.day;
  }

  void _applyPreset(ReaderSettings preset) {
    _update(
      _settings.copyWith(
        fontSize: preset.fontSize,
        lineHeight: preset.lineHeight,
        paragraphSpacing: preset.paragraphSpacing,
        pageMargin: preset.pageMargin,
        themePreset: preset.themePreset,
      ),
    );
  }

  void _update(ReaderSettings settings) {
    setState(() => _settings = settings);
    ref.read(readerSettingsControllerProvider).save(settings);
  }
}

final class _QuickThemeChip extends StatelessWidget {
  const _QuickThemeChip({
    required this.preset,
    required this.selected,
    required this.onSelected,
  });

  final ReaderThemePreset preset;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(preset.label),
      selected: selected,
      avatar: CircleAvatar(
        backgroundColor: preset.background,
        foregroundColor: preset.foreground,
        child: selected
            ? Icon(Icons.check, size: 14, color: preset.foreground)
            : null,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

final class _ReaderSettingsPresetChip extends StatelessWidget {
  const _ReaderSettingsPresetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

final class _ReaderSettingsSection extends StatelessWidget {
  const _ReaderSettingsSection({
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Theme.of(context).colorScheme.appBorder),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x1,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          children: [child],
        ),
      ),
    );
  }
}

final class _ReaderSettingsPreview extends StatelessWidget {
  const _ReaderSettingsPreview({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final preset = settings.themePreset;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: preset.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: preset.foreground.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(settings.pageMargin.clamp(12, 28).toDouble()),
        child: DefaultTextStyle(
          style: TextStyle(
            color: preset.foreground,
            fontFamily: () {
              final family = ReaderFonts.renderFamilyFor(settings.fontFamily);
              return family.isEmpty ? null : family;
            }(),
            fontSize: settings.fontSize,
            height: settings.lineHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset.epubInk ? '墨水屏预览' : '阅读预览',
                style: TextStyle(
                  fontSize: settings.fontSize * 1.08,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: settings.paragraphSpacing.clamp(6, 20)),
              const Text('这是一段用于对照字号、行高、段距和页边距的样张。调整后会实时影响当前阅读页。'),
              SizedBox(height: settings.paragraphSpacing.clamp(6, 20)),
              Text(
                'PageSage 保持本地优先，标注、笔记和 AI 历史都可以沉淀到 Notebook。',
                style: TextStyle(
                  color: preset.foreground.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(displayValue, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

final class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

final class _ReaderErrorPanel extends StatelessWidget {
  const _ReaderErrorPanel({
    required this.message,
    required this.onRetry,
    required this.onShowDetails,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 42, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  '无法渲染书籍',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('重试'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onShowDetails,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('查看详情'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _PanelResizeHandle extends StatefulWidget {
  const _PanelResizeHandle({required this.semanticLabel, required this.onDrag});

  final String semanticLabel;
  final ValueChanged<DragUpdateDetails> onDrag;

  @override
  State<_PanelResizeHandle> createState() => _PanelResizeHandleState();
}

final class _PanelResizeHandleState extends State<_PanelResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.onDrag,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _hovered ? 3 : 1,
              color: _hovered
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

final class _ReaderStatusBar extends StatelessWidget {
  const _ReaderStatusBar({
    required this.book,
    required this.locator,
    required this.progress,
    required this.chapterTitle,
    required this.pageNumber,
    required this.totalPages,
    required this.settings,
    required this.tocOpen,
    required this.contextOpen,
    required this.tocWidth,
    required this.contextWidth,
  });

  final Book book;
  final ReadingLocator? locator;
  final double? progress;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;
  final ReaderSettings settings;
  final bool tocOpen;
  final bool contextOpen;
  final double tocWidth;
  final double contextWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = ((progress ?? locator?.progress ?? 0).clamp(0, 1) * 100)
        .round();
    final location = _readerLocationText(
      book: book,
      locator: locator,
      chapterTitle: chapterTitle,
      pageNumber: pageNumber,
      totalPages: totalPages,
    );
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(width: tocOpen ? tocWidth - 8 : 0),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBarPill(label: '$percentage%'),
              const SizedBox(width: 8),
              _StatusBarPill(label: _readerScaleText(book, settings)),
              const SizedBox(width: 8),
              _StatusBarPill(label: settings.readerMode.label),
              const SizedBox(width: 8),
              _StatusBarPill(label: _readerFormatLabel(book.format)),
              SizedBox(width: contextOpen ? contextWidth - 4 : 0),
            ],
          ),
        ),
      ),
    );
  }
}

String _readerLocationText({
  required Book book,
  required ReadingLocator? locator,
  required String? chapterTitle,
  required int? pageNumber,
  required int? totalPages,
}) {
  if (book.format == BookFormat.pdf) {
    final page = pageNumber ?? locator?.page;
    final total = totalPages;
    if (page != null && total != null && total > 0) {
      return '第 $page / $total 页';
    }
    if (page != null) {
      return '第 $page 页';
    }
    return 'PDF 阅读中';
  }
  final chapter = chapterTitle?.trim();
  if (chapter != null && chapter.isNotEmpty) {
    return chapter;
  }
  final index = locator?.chapterIndex;
  if (index != null) {
    return '第 ${index + 1} 章';
  }
  return 'EPUB 阅读中';
}

String _readerScaleText(Book book, ReaderSettings settings) {
  return switch (book.format) {
    BookFormat.epub => '字号 ${settings.fontSize.round()}',
    BookFormat.pdf => switch (settings.pdfZoomMode) {
      PdfZoomMode.fitWidth => '适宽',
      PdfZoomMode.fitPage => '整页',
      PdfZoomMode.actual => '100%',
      PdfZoomMode.custom => '${(settings.pdfScale * 100).round()}%',
    },
  };
}

String _readerFormatLabel(BookFormat format) {
  return switch (format) {
    BookFormat.epub => 'EPUB',
    BookFormat.pdf => 'PDF',
  };
}

final class _StatusBarPill extends StatelessWidget {
  const _StatusBarPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

final class _ReaderStatusBanner extends StatelessWidget {
  const _ReaderStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            message,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onInverseSurface,
            ),
          ),
        ),
      ),
    );
  }
}
