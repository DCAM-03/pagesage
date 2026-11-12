import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/theme_mode_button.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/platform/platform_providers.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/annotations/image_anchor.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/bookmark.dart';
import '../../../domain/books/reader_fonts.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';
import '../../../features/settings/application/settings_providers.dart';
import '../../../renderers/common/book_document_loader.dart';
import '../../../renderers/common/renderer_event.dart';
import '../../../renderers/epub/epub_document_loader.dart';
import '../../../renderers/pdf/pdf_zoom.dart';
import '../../../renderers/epub/epub_jump.dart';
import '../../../domain/books/locator_excerpt.dart';
import '../../../renderers/markdown/markdown_document_loader.dart';
import '../../../renderers/markdown/markdown_folder.dart';
import '../../../renderers/markdown/markdown_folder_snapshot.dart';
import '../../ai/presentation/ai_panel.dart';
import '../../import/application/import_intent.dart';
import '../../ocr/application/ocr_page_controller.dart';
import '../../ocr/application/ocr_job_controller.dart';
import '../../ocr/application/ocr_providers.dart';
import '../../../domain/ocr/ocr_jobs.dart';
import '../../../domain/ocr/ocr_models.dart';
import '../application/reader_providers.dart';
import '../application/reader_notebook_providers.dart';
import '../application/reader_annotation_comment_service.dart';
import '../application/reader_excerpt_note_service.dart';
import '../application/reader_image_annotation_service.dart';
import '../application/reader_ocr_coordinator.dart';
import '../application/whole_book_ocr_queue.dart';
import '../application/markdown_folder_session.dart';
import '../application/markdown_folder_refresh_coordinator.dart';
import 'floating_menu_placement.dart';
import 'reader_settings_sheet.dart';
import 'reader_desktop_toc_pane.dart';
import 'reader_epub_toc_sheet.dart';
import 'reader_pdf_toc_sheet.dart';
import 'reader_notebook.dart';
import 'reader_search_pane.dart';
import 'reader_context_pane.dart';
import 'reader_annotation_actions.dart';
import 'reader_annotation_comment_editor.dart';
import 'reader_annotation_editor.dart';
import 'reader_bookmark_actions.dart';
import 'reader_chrome.dart';
import 'reader_desktop_toolbar.dart';
import 'reader_location_text.dart';
import 'reader_mobile_chrome.dart';
import 'reader_selection_actions.dart';
import 'reader_image_actions.dart';
import 'reader_annotations_host.dart';
import 'reader_excerpt_editor.dart';
import 'reader_ocr_overlay_controller.dart';
import 'reader_ocr_result_sheet.dart';
import 'reader_pdf_toolbar.dart';
import 'reader_status_widgets.dart';

final class ReaderPage extends ConsumerWidget {
  const ReaderPage({required this.bookId, this.initialLocator, super.key});

  final String bookId;
  final ReadingLocator? initialLocator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(readerSettingsProvider).value?.themePreset;
    return Theme(
      data: preset == null
          ? Theme.of(context)
          : AppTheme.reader(
              preset,
              highContrast: MediaQuery.highContrastOf(context),
            ),
      child: _ReaderContent(bookId: bookId, initialLocator: initialLocator),
    );
  }
}

final class _ReaderContent extends ConsumerStatefulWidget {
  const _ReaderContent({required this.bookId, this.initialLocator});

  final String bookId;
  final ReadingLocator? initialLocator;

  @override
  ConsumerState<_ReaderContent> createState() => _ReaderPageState();
}

final class _ReaderPageState extends ConsumerState<_ReaderContent>
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

  /// Bumped when the selection menu closes so the renderer drops its
  /// highlight and handles. The renderer cannot know when the host is done
  /// with a selection; without this the paint would outlive the menu.
  int _clearSelectionVersion = 0;

  /// Identifies the current selection menu, so a replaced menu's `finally`
  /// does not clear the paint of the one that replaced it.
  int _selectionMenuEpoch = 0;
  List<RendererOutlineItem> _pdfOutline = const [];
  bool _markedOpened = false;
  final ReaderOcrOverlayController _ocrOverlays = ReaderOcrOverlayController();
  int _ocrRequestEpoch = 0;
  final _wholeBookOcrQueue = WholeBookOcrQueue();
  Timer? _ocrIndexTimer;
  RendererLocationChanged? _currentLocation;
  final ValueNotifier<RendererLocationChanged?> _locationNotifier =
      ValueNotifier<RendererLocationChanged?>(null);
  RendererTextSelected? _selectedText;
  final ValueNotifier<RendererTextSelected?> _mobileSelectionNotifier =
      ValueNotifier<RendererTextSelected?>(null);
  bool _mobileSelectionSheetOpen = false;

  /// Whether a drag on a PDF page draws an image box instead of selecting
  /// text. Off by default, because the same gesture already means "select".
  bool _imageDragMode = false;
  ReadingProgressSnapshot? _jumpProgress;
  int _rendererVersion = 0;
  int _jumpToken = 0;
  ReadingLocator? _focusLocator;
  Timer? _focusClearTimer;
  bool _selectionActionsOpen = false;
  Object? _lastSelectionActionKey;
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
  String? _lastFolderText;
  String? _lastFolderTextPath;
  bool _mobileChromeVisible = true;
  Timer? _mobileChromeTimer;
  bool _pdfQuickToolbarVisible = true;
  bool _pdfQuickToolbarHovered = false;
  bool _pdfQuickToolbarMenuOpen = false;
  bool _pdfQuickToolbarFocused = false;
  bool _pdfQuickToolbarKeyboardInput = false;
  bool _pdfQuickToolbarUserCollapsed = false;
  Timer? _pdfQuickToolbarTimer;
  Timer? _statusClearTimer;
  Timer? _locationChromeTimer;
  ReaderContextTab _desktopContextTab = ReaderContextTab.search;
  ReaderSessionController? _sessionController;

  /// Folder books keep a manifest and one active file in a dedicated
  /// controller; the renderer never receives the whole folder as a document.
  final MarkdownFolderSessionController _folderSession =
      MarkdownFolderSessionController();
  MarkdownFolderRefreshCoordinator? _folderRefresh;
  StreamSubscription<MarkdownFolderRefreshEvent>? _folderRefreshSubscription;
  String? _folderRefreshState;
  Timer? _folderRefreshStatusTimer;
  ({Book book, MarkdownFolderRefreshEvent event})? _pendingFolderRefresh;
  int _lastAppliedFolderRefreshEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ocrOverlays.addListener(_onOcrOverlaysChanged);
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
        _schedulePdfQuickToolbarAutoHide(const Duration(seconds: 4));
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
  void didUpdateWidget(covariant _ReaderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _ocrRequestEpoch += 1;
      _stopFolderRefresh();
    }
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
    _folderRefreshStatusTimer?.cancel();
    unawaited(_folderRefreshSubscription?.cancel());
    unawaited(_folderRefresh?.dispose());
    _ocrOverlays.removeListener(_onOcrOverlaysChanged);
    _ocrOverlays.dispose();
    _mobileChromeTimer?.cancel();
    _pdfQuickToolbarTimer?.cancel();
    _statusClearTimer?.cancel();
    _ocrIndexTimer?.cancel();
    _locationChromeTimer?.cancel();
    _focusClearTimer?.cancel();
    _locationNotifier.dispose();
    _statusNotifier.dispose();
    _mobileSelectionNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sessionController?.flush());
    super.dispose();
  }

  void _stopFolderRefresh() {
    _folderRefreshStatusTimer?.cancel();
    unawaited(_folderRefreshSubscription?.cancel());
    unawaited(_folderRefresh?.dispose());
    _folderRefreshSubscription = null;
    _folderRefresh = null;
    _folderRefreshState = null;
    _pendingFolderRefresh = null;
    _lastAppliedFolderRefreshEpoch = 0;
  }

  void _onOcrOverlaysChanged() {
    if (mounted) {
      setState(() {});
    }
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

  /// Turns the drag-box image annotator on or off.
  ///
  /// It is a mode rather than a modifier because the same drag already means
  /// "select text"; the reader has to know which one they asked for. Turning
  /// it on says so in the status line, and Escape or a saved box turns it off
  /// again, so the mode cannot be left on unnoticed and silently break
  /// text selection.
  void _toggleImageDragMode() {
    setState(() => _imageDragMode = !_imageDragMode);
    if (_imageDragMode) {
      // Entering needs no toast: the banner is right there and says the same
      // thing for as long as the mode lasts. Two messages stacked on each
      // other made the reader read the same sentence twice.
      _setTransientStatus(null);
      return;
    }
    _setTransientStatus('已退出框选图片', clearAfter: const Duration(seconds: 2));
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

  void _showPdfQuickToolbar({bool force = false, bool autoHide = true}) {
    if (_pdfQuickToolbarUserCollapsed && !force) {
      return;
    }
    if (force) {
      _pdfQuickToolbarUserCollapsed = false;
    }
    _pdfQuickToolbarTimer?.cancel();
    if (!_pdfQuickToolbarVisible) {
      setState(() => _pdfQuickToolbarVisible = true);
    }
    if (autoHide) {
      _schedulePdfQuickToolbarAutoHide();
    }
  }

  void _hidePdfQuickToolbar({bool userInitiated = false}) {
    _pdfQuickToolbarTimer?.cancel();
    _pdfQuickToolbarHovered = false;
    if (userInitiated) {
      _pdfQuickToolbarUserCollapsed = true;
    }
    if (_pdfQuickToolbarVisible) {
      setState(() => _pdfQuickToolbarVisible = false);
    }
  }

  void _schedulePdfQuickToolbarAutoHide([
    Duration delay = const Duration(seconds: 3),
  ]) {
    _pdfQuickToolbarTimer?.cancel();
    _pdfQuickToolbarTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      if (_pdfQuickToolbarMenuOpen ||
          _pdfQuickToolbarHovered ||
          (_pdfQuickToolbarFocused && _pdfQuickToolbarKeyboardInput)) {
        _schedulePdfQuickToolbarAutoHide();
        return;
      }
      if (_pdfQuickToolbarVisible) {
        setState(() => _pdfQuickToolbarVisible = false);
      }
    });
  }

  void _setPdfQuickToolbarHovered(bool hovered) {
    _pdfQuickToolbarKeyboardInput = false;
    _pdfQuickToolbarHovered = hovered;
    if (hovered) {
      _showPdfQuickToolbar(autoHide: false);
    } else {
      _schedulePdfQuickToolbarAutoHide();
    }
  }

  void _setPdfQuickToolbarMenuOpen(bool open) {
    _pdfQuickToolbarMenuOpen = open;
    if (open) {
      _pdfQuickToolbarTimer?.cancel();
    } else if (mounted) {
      _schedulePdfQuickToolbarAutoHide();
    }
  }

  void _handleReaderHover(PointerHoverEvent event, Book book) {
    if (book.format != BookFormat.pdf || context.appBreakpoint.isCompact) {
      return;
    }
    _pdfQuickToolbarKeyboardInput = false;
    if (event.localPosition.dy <= 72) {
      _showPdfQuickToolbar();
    } else if (_pdfQuickToolbarVisible && !_pdfQuickToolbarHovered) {
      _schedulePdfQuickToolbarAutoHide();
    }
  }

  void _setPdfQuickToolbarFocused(bool focused) {
    _pdfQuickToolbarFocused = focused;
    if (focused && _pdfQuickToolbarKeyboardInput) {
      _pdfQuickToolbarTimer?.cancel();
    } else if (_pdfQuickToolbarVisible) {
      _schedulePdfQuickToolbarAutoHide();
    }
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
            child: MobileReaderMoreSheet(
              book: book,
              settings: settings,
              bookmarked: currentBookmark != null,
              searchAvailable: true,
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
              onOcrPage: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_runOcrCurrentPage(context, book));
                    }
                  : null,
              onOcrRange: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_showOcrRangeDialog(context, book));
                    }
                  : null,
              onOcrBook: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_startOcrWholeBook(context, book));
                    }
                  : null,
              onImageBox: isPdf
                  ? () {
                      Navigator.of(sheetContext).pop();
                      _toggleImageDragMode();
                    }
                  : null,
              imageBoxMode: _imageDragMode,
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
    ref.watch(readerOcrCoordinatorProvider(widget.bookId));
    final progress = ref.watch(readerProgressProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider);
    ref.listen(readerSettingsSavePhaseProvider, (previous, next) {
      if (next.asData?.value != ReaderSettingsSavePhase.failed ||
          previous?.asData?.value == ReaderSettingsSavePhase.failed) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('阅读设置未保存，修改已保留'),
          action: SnackBarAction(
            label: '重试',
            onPressed: ref.read(readerSettingsControllerProvider).retry,
          ),
        ),
      );
    });
    if (settings.value != null) {
      _syncDesktopChromePrefs(settings.value!);
    }
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
          if (event is KeyDownEvent) {
            _pdfQuickToolbarKeyboardInput = true;
            if (_pdfQuickToolbarFocused) {
              _pdfQuickToolbarTimer?.cancel();
            }
          }
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
              : ReaderDesktopToolbar(
                  title: book.value?.title ?? '阅读器',
                  tocOpen: context.supportsSidePanel && _desktopTocOpen,
                  activeContextTab:
                      context.supportsSidePanel && _desktopContextOpen
                      ? _desktopContextTab
                      : null,
                  bookmarked: currentBookmark != null,
                  onBack: () async {
                    await ref
                        .read(readerSessionControllerProvider(widget.bookId))
                        .flush();
                    if (context.mounted) {
                      context.go('/library');
                    }
                  },
                  onToc: book.value == null
                      ? null
                      : () {
                          if (context.supportsSidePanel) {
                            _setDesktopTocOpen(!_desktopTocOpen);
                            return;
                          }
                          unawaited(_showTableOfContents(context, book.value!));
                        },
                  onSearch: () => _showInBookSearch(context),
                  onBookmark: () => _toggleBookmark(context, currentBookmark),
                  onNotebook: () => _showContextOrSheet(
                    context,
                    ReaderContextTab.notebook,
                    () => _showNotebook(context),
                  ),
                  onAi: () => unawaited(_showAiPanel(context)),
                  onSettings: settings.value == null
                      ? null
                      : () => _showReaderSettings(context, settings.value!),
                  onMore: (action) => _handleReaderMoreAction(
                    context,
                    action,
                    book.value,
                    settings.value,
                  ),
                  moreItems: (context) =>
                      _readerMoreMenuItems(book.value, settings.value),
                ),
          body: book.when(
            data: (book) {
              if (book == null) {
                return const ReaderMessage(message: '找不到这本书');
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
                  return _withFolderSession(book, snapshot, () {
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
                        return Listener(
                          onPointerDown: (_) {
                            if (book.format == BookFormat.pdf &&
                                !context.appBreakpoint.isCompact) {
                              _pdfQuickToolbarKeyboardInput = false;
                              if (_pdfQuickToolbarVisible) {
                                _schedulePdfQuickToolbarAutoHide();
                              }
                            }
                          },
                          onPointerHover: (event) =>
                              _handleReaderHover(event, book),
                          child: Stack(
                            children: [
                              if (showDesktopToc)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  bottom: showDesktopChrome
                                      ? desktopStatusBarHeight
                                      : 0,
                                  width: tocWidth,
                                  child: DesktopTocPane(
                                    book: book,
                                    documentLoader: _documentLoaderFor(book),
                                    folderManifest: _folderSession.manifest,
                                    activeFolderFile:
                                        _folderSession.activeFile?.relativePath,
                                    onFolderFileSelected: _openFolderFile,
                                    onRefresh: _refreshFolderBook,
                                    refreshState: _folderRefreshState,
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
                                  child: PanelResizeHandle(
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
                                    color:
                                        readerSettings.themePreset.background,
                                  ),
                                  // Annotations are watched in a leaf widget so
                                  // highlight updates do not rebuild the whole reader chrome.
                                  child: ReaderAnnotationsHost(
                                    bookId: widget.bookId,
                                    book: book,
                                    progress: _rendererProgressFor(snapshot),
                                    documentPath:
                                        _folderSession.activeFile?.absolutePath,
                                    folderRelativePath:
                                        _folderSession.activeFile?.relativePath,
                                    settings: readerSettings,
                                    version: _rendererVersion,
                                    jumpToken: _jumpToken,
                                    searchQuery: _rendererSearchQuery,
                                    focusLocator: _focusLocator,
                                    clearSearchHighlightsVersion:
                                        _clearSearchHighlightsVersion,
                                    clearSelectionVersion:
                                        _clearSelectionVersion,
                                    onEvent: _handleRendererEvent,
                                    ocrOverlayToken: _ocrOverlays.state.token,
                                    ocrOverlayPage: _ocrOverlays.state.page,
                                    ocrOverlayBlocks: _ocrOverlays.state.blocks,
                                    onZoomChanged: _handlePdfZoomChanged,
                                    imageDragMode: _imageDragMode,
                                    onImageAreaSelected:
                                        _showImageAnnotationActions,
                                  ),
                                ),
                              ),
                              if (book.format == BookFormat.pdf &&
                                  !context.appBreakpoint.isCompact) ...[
                                Positioned(
                                  top: 12,
                                  left: showDesktopToc ? tocWidth + 16 : 16,
                                  right: showDesktopContext
                                      ? contextWidth + 16
                                      : 16,
                                  child: IgnorePointer(
                                    ignoring: !_pdfQuickToolbarVisible,
                                    child: ExcludeSemantics(
                                      excluding: !_pdfQuickToolbarVisible,
                                      child: ExcludeFocus(
                                        excluding: !_pdfQuickToolbarVisible,
                                        child: MouseRegion(
                                          onEnter: (_) =>
                                              _setPdfQuickToolbarHovered(true),
                                          onExit: (_) =>
                                              _setPdfQuickToolbarHovered(false),
                                          child: Focus(
                                            onFocusChange:
                                                _setPdfQuickToolbarFocused,
                                            child: AnimatedSlide(
                                              duration: const Duration(
                                                milliseconds: 160,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              offset: _pdfQuickToolbarVisible
                                                  ? Offset.zero
                                                  : const Offset(0, -0.12),
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 140,
                                                ),
                                                opacity: _pdfQuickToolbarVisible
                                                    ? 1
                                                    : 0,
                                                child: Center(
                                                  child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxWidth: 760,
                                                        ),
                                                    child: ValueListenableBuilder<RendererLocationChanged?>(
                                                      valueListenable:
                                                          _locationNotifier,
                                                      builder: (context, location, _) {
                                                        return PdfQuickToolbar(
                                                          pageNumber: location
                                                              ?.pageNumber,
                                                          totalPages: location
                                                              ?.totalPages,
                                                          settings:
                                                              readerSettings,
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
                                                              unawaited(
                                                                _showPageJump(
                                                                  context,
                                                                ),
                                                              ),
                                                          onZoomOut: () =>
                                                              unawaited(
                                                                _adjustReaderScale(
                                                                  -1,
                                                                ),
                                                              ),
                                                          onZoomIn: () =>
                                                              unawaited(
                                                                _adjustReaderScale(
                                                                  1,
                                                                ),
                                                              ),
                                                          onFitWidth: () =>
                                                              unawaited(
                                                                _setPdfZoomMode(
                                                                  PdfZoomMode
                                                                      .fitWidth,
                                                                ),
                                                              ),
                                                          onFitPage: () =>
                                                              unawaited(
                                                                _setPdfZoomMode(
                                                                  PdfZoomMode
                                                                      .fitPage,
                                                                ),
                                                              ),
                                                          onOcrPage: () =>
                                                              unawaited(
                                                                _runOcrCurrentPage(
                                                                  context,
                                                                  book,
                                                                ),
                                                              ),
                                                          onOcrRange: () =>
                                                              unawaited(
                                                                _showOcrRangeDialog(
                                                                  context,
                                                                  book,
                                                                ),
                                                              ),
                                                          onOcrBook: () =>
                                                              unawaited(
                                                                _startOcrWholeBook(
                                                                  context,
                                                                  book,
                                                                ),
                                                              ),
                                                          onOcrMenuChanged:
                                                              _setPdfQuickToolbarMenuOpen,
                                                          onCollapse: () =>
                                                              _hidePdfQuickToolbar(
                                                                userInitiated:
                                                                    true,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!_pdfQuickToolbarVisible)
                                  Positioned(
                                    top: 10,
                                    left: showDesktopToc ? tocWidth + 16 : 16,
                                    right: showDesktopContext
                                        ? contextWidth + 16
                                        : 16,
                                    child: Center(
                                      child: MouseRegion(
                                        onEnter: (_) => _showPdfQuickToolbar(),
                                        child: PdfQuickToolbarReveal(
                                          pageNumber:
                                              _currentLocation?.pageNumber,
                                          totalPages:
                                              _currentLocation?.totalPages,
                                          onReveal: () =>
                                              _showPdfQuickToolbar(force: true),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                              if (showDesktopContext)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  bottom: showDesktopChrome
                                      ? desktopStatusBarHeight
                                      : 0,
                                  width: contextWidth,
                                  child: ReaderContextPane(
                                    bookId: widget.bookId,
                                    bookPath: book.libraryFilePath,
                                    format: book.format,
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
                                  child: PanelResizeHandle(
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
                                right: showDesktopContext
                                    ? contextWidth + 16
                                    : 16,
                                bottom: showDesktopChrome
                                    ? desktopStatusBarHeight + 10
                                    : 16,
                                // One column, so a persistent mode banner and a
                                // transient status cannot land on top of each other.
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_imageDragMode) ...[
                                      ImageBoxModeBanner(
                                        onExit: _toggleImageDragMode,
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    ValueListenableBuilder<String?>(
                                      valueListenable: _statusNotifier,
                                      builder: (context, status, _) {
                                        if (status == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return ReaderStatusBanner(
                                          message: status,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (_renderError != null)
                                Positioned.fill(
                                  left: showDesktopToc ? tocWidth : 0,
                                  right: showDesktopContext ? contextWidth : 0,
                                  child: ReaderErrorPanel(
                                    message: _renderError!,
                                    onRetry: _retryRenderer,
                                    onShowDetails: () =>
                                        _showRenderErrorDetails(
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
                                          return ReaderStatusBar(
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
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      offset: _mobileChromeVisible
                                          ? Offset.zero
                                          : const Offset(0, -0.35),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        opacity: _mobileChromeVisible ? 1 : 0,
                                        child: SafeArea(
                                          bottom: false,
                                          child: MobileReaderTopBar(
                                            title: book.title,
                                            progress:
                                                _currentLocation?.progress ??
                                                snapshot?.progress,
                                            locationLabel: readerLocationText(
                                              book: book,
                                              locator:
                                                  _currentLocation?.locator ??
                                                  snapshot?.locator,
                                              chapterTitle:
                                                  _currentLocation
                                                      ?.chapterTitle ??
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
                                              _showTableOfContents(
                                                context,
                                                book,
                                              ),
                                            ),
                                            onMore: () => unawaited(
                                              _showMobileMoreSheet(
                                                context: context,
                                                book: book,
                                                settings: readerSettings,
                                                currentBookmark:
                                                    currentBookmark,
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
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      offset: _mobileChromeVisible
                                          ? Offset.zero
                                          : const Offset(0, 0.35),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        opacity: _mobileChromeVisible ? 1 : 0,
                                        child: SafeArea(
                                          top: false,
                                          child:
                                              ValueListenableBuilder<
                                                RendererLocationChanged?
                                              >(
                                                valueListenable:
                                                    _locationNotifier,
                                                builder: (context, location, _) {
                                                  return MobileReaderBottomBar(
                                                    book: book,
                                                    locator:
                                                        location?.locator ??
                                                        snapshot?.locator,
                                                    progress:
                                                        location?.progress ??
                                                        snapshot?.progress,
                                                    chapterTitle:
                                                        location
                                                            ?.chapterTitle ??
                                                        snapshot?.chapterTitle,
                                                    pageNumber:
                                                        location?.pageNumber,
                                                    totalPages:
                                                        location?.totalPages,
                                                    bookmarked:
                                                        currentBookmark != null,
                                                    onToc: () => unawaited(
                                                      _showTableOfContents(
                                                        context,
                                                        book,
                                                      ),
                                                    ),
                                                    onSearch: () => unawaited(
                                                      _showInBookSearch(
                                                        context,
                                                      ),
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
                                                            _showPageJump(
                                                              context,
                                                            ),
                                                          )
                                                        : null,
                                                    onMore: () => unawaited(
                                                      _showMobileMoreSheet(
                                                        context: context,
                                                        book: book,
                                                        settings:
                                                            readerSettings,
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
                                      child: ReaderChromeRevealButton(
                                        onPressed: () =>
                                            _showMobileChrome(autoHide: true),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  });
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const ReaderMessage(message: '无法读取阅读进度'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const ReaderMessage(message: '无法打开书籍'),
          ),
        ),
      ),
    );
  }

  void _handleRendererEvent(RendererEvent rawEvent) {
    if (!mounted) {
      return;
    }
    final event = _folderSession.normalizeEvent(rawEvent);
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
      case RendererImageAreaSelected():
        _showImageAnnotationActions(event);
      case RendererTextSelected():
        final previousText = _selectedText?.text;
        _selectedText = event;
        if (_desktopContextOpen) {
          final needAiTab = _desktopContextTab != ReaderContextTab.ai;
          final textChanged = previousText != event.text;
          if (needAiTab || textChanged) {
            setState(() {
              _desktopContextTab = ReaderContextTab.ai;
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
      case RendererExternalLinkRequested(:final uri):
        unawaited(_confirmOpenExternalLink(uri));
      case RendererInternalLinkRequested(:final locator):
        _jumpTo(locator);
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

  /// Asks before leaving PageSage for the user's browser.
  ///
  /// The link comes from the document, not from the user, so the address is
  /// shown in full and nothing opens until it is confirmed. `externalApplication`
  /// keeps the launch out of any in-app web surface, which also means the page
  /// cannot see the reader.
  Future<void> _confirmOpenExternalLink(String uri) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开外部链接'),
        content: SelectableText(
          uri,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final launched = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接，请检查系统浏览器设置')));
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

  List<PopupMenuEntry<ReaderMoreAction>> _readerMoreMenuItems(
    Book? book,
    ReaderSettings? settings,
  ) {
    // Flat items only. Nested ListTiles inside PopupMenuItem look broken.
    // Notebook/AI already have toolbar buttons, so keep this menu focused.
    final isPdf = book?.format == BookFormat.pdf;
    final isFolderBook = book?.isFolderBook ?? false;
    return [
      if (isFolderBook)
        const PopupMenuItem(
          value: ReaderMoreAction.refreshFolder,
          child: Text('刷新文件夹并重建索引'),
        ),
      PopupMenuItem(
        value: ReaderMoreAction.quickTheme,
        enabled: settings != null,
        child: const Text('阅读主题与界面颜色'),
      ),
      PopupMenuItem(
        value: ReaderMoreAction.readerMode,
        enabled: settings != null,
        child: Text(
          settings?.readerMode == ReaderMode.paged ? '切换为连续滚动' : '切换为分页阅读',
        ),
      ),
      const PopupMenuDivider(),
      if (isPdf) ...[
        const PopupMenuItem(
          value: ReaderMoreAction.pageJump,
          child: Text('跳转页码'),
        ),
        CheckedPopupMenuItem(
          value: ReaderMoreAction.pdfFitWidth,
          checked: settings?.pdfZoomMode == PdfZoomMode.fitWidth,
          child: const Text('适合宽度'),
        ),
        CheckedPopupMenuItem(
          value: ReaderMoreAction.pdfFitPage,
          checked: settings?.pdfZoomMode == PdfZoomMode.fitPage,
          child: const Text('适合页面'),
        ),
        const PopupMenuItem(
          value: ReaderMoreAction.pdfZoomOut,
          child: Text('缩小'),
        ),
        const PopupMenuItem(
          value: ReaderMoreAction.pdfZoomIn,
          child: Text('放大'),
        ),
        CheckedPopupMenuItem(
          value: ReaderMoreAction.pdfImageBox,
          checked: _imageDragMode,
          child: const Text('框选图片'),
        ),
        const PopupMenuItem(
          value: ReaderMoreAction.ocrRange,
          child: Text('识别页面范围…'),
        ),
        const PopupMenuDivider(),
      ],
      const PopupMenuItem(
        value: ReaderMoreAction.addAnnotation,
        child: Text('给选中文本添加标注'),
      ),
      const PopupMenuItem(
        value: ReaderMoreAction.createNote,
        child: Text('保存摘录笔记'),
      ),
    ];
  }

  Future<void> _handleReaderMoreAction(
    BuildContext context,
    ReaderMoreAction action,
    Book? book,
    ReaderSettings? settings,
  ) async {
    switch (action) {
      case ReaderMoreAction.refreshFolder:
        await _refreshFolderBook();
      case ReaderMoreAction.pageJump:
        await _showPageJump(context);
      case ReaderMoreAction.pdfFitWidth:
        await _setPdfZoomMode(PdfZoomMode.fitWidth);
      case ReaderMoreAction.pdfFitPage:
        await _setPdfZoomMode(PdfZoomMode.fitPage);
      case ReaderMoreAction.pdfZoomOut:
        await _adjustReaderScale(-1);
      case ReaderMoreAction.pdfZoomIn:
        await _adjustReaderScale(1);
      case ReaderMoreAction.pdfImageBox:
        _toggleImageDragMode();
      case ReaderMoreAction.ocrRange:
        if (book != null) {
          await _showOcrRangeDialog(context, book);
        }
      case ReaderMoreAction.readerMode:
        if (settings != null) {
          await _toggleReaderMode(settings);
        }
      case ReaderMoreAction.quickTheme:
        if (settings != null) {
          await _showQuickThemeSheet(context, settings);
        }
      case ReaderMoreAction.notebook:
        _showContextOrSheet(
          context,
          ReaderContextTab.notebook,
          () => _showNotebook(context),
        );
      case ReaderMoreAction.ai:
        _showContextOrSheet(
          context,
          ReaderContextTab.ai,
          () => _showAiPanel(context),
        );
      case ReaderMoreAction.addAnnotation:
        await _addAnnotation(context);
      case ReaderMoreAction.createNote:
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
      await showReaderAnnotationActions(context, ref, annotation);
    } finally {
      _annotationActionsOpen = false;
      _flushPendingFolderRefresh();
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
    const estimatedHeight = 230.0;
    final placement = placeFloatingMenu(
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
    final linkedNote = await ref
        .read(readerAnnotationCommentServiceProvider)
        .commentFor(annotation);
    if (!mounted) {
      return;
    }
    final hasNote = linkedNote != null;
    _selectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) => InheritedTheme.captureAll(
        context,
        Stack(
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
                                    color: readerAnnotationColor(
                                      annotation.color,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasNote ? '标注 · 批注' : '标注',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除标注',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    dismiss();
                                    unawaited(
                                      deleteReaderAnnotation(
                                        context,
                                        ref,
                                        annotation,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
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
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colorScheme.onSurface),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Text(
                                '点击下方「添加批注」写下你的理解。',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    dismiss();
                                    unawaited(
                                      editReaderAnnotation(
                                        context,
                                        ref,
                                        annotation,
                                      ),
                                    );
                                  },
                                  child: const Text('样式'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    dismiss();
                                    unawaited(
                                      editReaderAnnotationComment(
                                        context,
                                        ref,
                                        annotation,
                                      ),
                                    );
                                  },
                                  child: Text(hasNote ? '编辑批注' : '添加批注'),
                                ),
                                if (hasNote) ...[
                                  OutlinedButton(
                                    onPressed: () {
                                      dismiss();
                                      unawaited(
                                        deleteReaderAnnotationComment(
                                          context,
                                          ref,
                                          annotation,
                                        ),
                                      );
                                    },
                                    child: const Text('删除批注'),
                                  ),
                                ],
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
      ),
    );

    overlayState.insert(_selectionOverlayEntry!);
    await completer.future;
  }

  /// The reader drew a box over a picture: offer the image-specific actions.
  ///
  /// The menu is the same surface and placement as the text selection menu —
  /// the reader just performed the same kind of gesture and should not have to
  /// learn a second one.
  Future<void> _showImageAnnotationActions(
    RendererImageAreaSelected event,
  ) async {
    if (!mounted) return;
    final caption = _captionForAnchor(event.anchor);
    _showMobileChrome(autoHide: false);
    ReaderImageAction? action;
    try {
      if (context.supportsSidePanel) {
        action = await _showDesktopImageMenu(context, event);
      } else {
        action = await showReaderImageActionSheet(context, caption: caption);
      }
    } finally {
      _scheduleMobileChromeAutoHide();
    }
    if (!mounted || action == null) {
      // Dismissed without choosing: stay in the mode, so a badly drawn box
      // can simply be drawn again. Only an action ends it.
      return;
    }
    switch (action) {
      case ReaderImageAction.annotate:
        await _annotateImage(event);
      case ReaderImageAction.save:
        await _saveImageToFile(event);
      case ReaderImageAction.copyCaption:
        await Clipboard.setData(ClipboardData(text: caption));
        if (mounted) {
          _setTransientStatus('已复制图注', clearAfter: const Duration(seconds: 2));
        }
    }
    if (mounted && _imageDragMode) {
      setState(() => _imageDragMode = false);
    }
  }

  /// Floating bar next to the box the reader just drew, like the text one.
  Future<ReaderImageAction?> _showDesktopImageMenu(
    BuildContext context,
    RendererImageAreaSelected event,
  ) async {
    _closeSelectionOverlay();
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    const estimatedWidth = 300.0;
    const estimatedHeight = 48.0;
    final placement = placeFloatingMenu(
      overlaySize: overlaySize,
      target: _toOverlayLocalRect(event.sourceRect, overlayBox),
      menuWidth: estimatedWidth,
      menuHeight: estimatedHeight,
      gap: 10,
    );
    final completer = Completer<void>();
    _selectionOverlayCompleter = completer;
    ReaderImageAction? picked;
    void dismiss([ReaderImageAction? action]) {
      picked = action;
      _closeSelectionOverlay();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    _selectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) => InheritedTheme.captureAll(
        context,
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: dismiss,
                child: const IgnorePointer(
                  child: ColoredBox(color: Color(0x00000000)),
                ),
              ),
            ),
            Positioned(
              left: placement.left,
              top: placement.top,
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
                    child: ReaderImageActionOverlay(
                      hasCaption: _captionForAnchor(event.anchor).isNotEmpty,
                      onAction: (picked) => dismiss(picked),
                      onDismiss: dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    overlayState.insert(_selectionOverlayEntry!);
    await completer.future;
    return picked;
  }

  /// The page's caption for an annotated image.
  ///
  /// Empty for PDFs: an image XObject carries no alt text, and nothing in the
  /// document says which words are its caption. EPUB has `alt`/`figcaption`
  /// and will fill this in when its images land. Returning '' is the honest
  /// answer, and the menu says so instead of offering an empty copy.
  String _captionForAnchor(ImageAnchor anchor) => '';

  Future<void> _annotateImage(RendererImageAreaSelected event) async {
    final anchor = event.anchor;
    final result = await showReaderAnnotationEditor(
      context,
      initialText: '',
      initialColor: AnnotationColor.blue,
      initialStyle: AnnotationStyle.highlight,
    );
    if (result == null) return;
    if (!mounted) return;
    await ref
        .read(readerImageAnnotationServiceProvider)
        .saveAnnotation(
          bookId: widget.bookId,
          anchor: anchor,
          selectedText: result.selectedText,
          color: result.color,
          style: result.style,
          imageSource: ref.read(activePdfRendererControllerProvider),
        );
    if (!mounted) return;
    _setTransientStatus('已标注图片', clearAfter: const Duration(seconds: 2));
  }

  Future<void> _saveImageToFile(RendererImageAreaSelected event) async {
    final anchor = event.anchor;
    if (anchor is! PdfImageAnchor) return;
    final source = ref.read(activePdfRendererControllerProvider);
    if (source == null) {
      _setTransientStatus(
        '找不到页面渲染器，无法保存图片',
        clearAfter: const Duration(seconds: 3),
      );
      return;
    }
    _setTransientStatus('正在生成图片…', clearAfter: const Duration(seconds: 8));
    final bytes = await ref
        .read(readerImageAnnotationServiceProvider)
        .renderRegion(anchor: anchor, imageSource: source);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _setTransientStatus('这一页无法生成图片', clearAfter: const Duration(seconds: 3));
      return;
    }
    // The page may still have been rasterising when the reader left the view;
    // the dialog below has no context to attach to after that.
    if (!mounted) return;
    final book = ref.read(readerBookProvider(widget.bookId)).value;
    final stem = book == null
        ? '第 ${anchor.page} 页'
        : '${book.title} 第 ${anchor.page} 页';
    final path = await ref
        .read(filePickerServiceProvider)
        .pickImageSavePath(baseName: stem, bytes: bytes);
    if (!mounted) return;
    if (path == null) {
      // Cancelled: no file was written, and saying "saved" would be a lie.
      _setTransientStatus(null);
      return;
    }
    _setTransientStatus('已保存图片', clearAfter: const Duration(seconds: 3));
  }

  void _showSelectionActionsOnce(RendererTextSelected event) {
    final locator = event.locator;
    final key = (
      event.text.trim(),
      locator.type,
      locator.cfi,
      locator.href,
      locator.page,
      locator.chapterIndex,
      locator.chapterOffset,
      locator.chapterEndOffset,
    );
    // Ignore duplicate events while the same selection menu is open.
    if (_selectionActionsOpen && _lastSelectionActionKey == key) {
      return;
    }
    if (_mobileSelectionSheetOpen) {
      _lastSelectionActionKey = key;
      _mobileSelectionNotifier.value = event;
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
      builder: (context) => ReaderBottomSheetFrame(
        child: ReaderSettingsSheet(initialSettings: currentSettings),
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
                  '阅读主题',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
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
                      QuickThemeChip(
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
                  '书库与设置页颜色',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.x1),
                const AppThemeHint(),
                const SizedBox(height: AppSpacing.x2),
                const AppThemeModeSelector(),
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
    // A mode that changes what dragging means must answer Escape first, or
    // the reader has no obvious way out of it.
    if (_imageDragMode) {
      _toggleImageDragMode();
      return;
    }
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
    // In custom mode the saved scale is what the page is drawn at, and every
    // renderer zoom writes it back. In the fit modes it is not: a fit-width
    // page is rarely at 100%, so stepping it blindly would jump. There the
    // reported layout scale is the honest base.
    final base = book?.format == BookFormat.pdf
        ? settings.pdfZoomMode == PdfZoomMode.custom
              ? settings.pdfScale
              : (_currentLocation?.locator.zoom ?? settings.pdfScale)
        : settings.pdfScale;
    final next = book?.format == BookFormat.pdf
        ? settings.copyWith(
            pdfScale: (base + direction * pdfZoomStep)
                .clamp(ReaderSettings.pdfScaleMin, ReaderSettings.pdfScaleMax)
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

  /// Persists a zoom performed inside the canvas renderer.
  ///
  /// Pinches and wheel notches arrive in bursts, so this plans the write
  /// instead of forcing one per notch; the renderer keeps painting the
  /// transient scale until the saved value round-trips.
  void _handlePdfZoomChanged(double scale, PdfZoomMode mode) {
    final settings = ref.read(readerSettingsProvider).value;
    if (settings == null) {
      return;
    }
    final next = settings.copyWith(
      pdfScale: scale
          .clamp(ReaderSettings.pdfScaleMin, ReaderSettings.pdfScaleMax)
          .toDouble(),
      pdfZoomMode: mode,
    );
    unawaited(ref.read(readerSettingsControllerProvider).save(next));
    _setTransientStatus(
      mode == PdfZoomMode.fitWidth
          ? '适合宽度'
          : '缩放 ${(next.pdfScale * 100).round()}%',
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
      final folderManifest = book.isFolderBook
          ? _folderSession.manifest ??
                (await _folderSession.load(
                  book: book,
                  initialLocator: widget.initialLocator,
                )).manifest
          : null;
      final document = book.isFolderBook
          ? null
          : await _documentLoaderFor(book).load(book.libraryFilePath);
      if (!context.mounted) {
        return;
      }
      final currentLocator = _currentLocation?.locator;
      final currentChapter = folderManifest == null
          ? currentLocator?.chapterIndex
          : normalizeFolderHref(currentLocator?.href ?? '') ==
                normalizeFolderHref(
                  _folderSession.activeFile?.relativePath ?? '',
                )
          ? currentLocator?.chapterIndex
          : null;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => ReaderBottomSheetFrame(
          child: EpubTocSheet(
            document: document,
            folderManifest: folderManifest,
            activeFolderFile: _folderSession.activeFile?.relativePath,
            onFolderFileSelected: _openFolderFile,
            currentChapterIndex: currentChapter,
            onFolderLocatorSelected: (locator) {
              _jumpTo(locator);
              Navigator.of(sheetContext).pop();
            },
            onSelected: document == null
                ? null
                : (item) {
                    final chapterIndex = (item.chapterIndex ?? 0)
                        .clamp(0, document.chapters.length - 1)
                        .toInt();
                    final chapter = document.chapters[chapterIndex];
                    final progress = document.progressForChapter(
                      chapterIndex: chapter.index,
                      chapterOffset: item.chapterOffset ?? 0,
                    );
                    final locator = book.format == BookFormat.markdown
                        ? ReadingLocator.markdown(
                            href: item.href,
                            chapterIndex: chapter.index,
                            chapterOffset: item.chapterOffset,
                            progress: progress,
                          )
                        : ReadingLocator.epub(
                            href: item.href,
                            chapterIndex: chapter.index,
                            chapterOffset: item.chapterOffset,
                            progress: progress,
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
                    Navigator.of(sheetContext).pop();
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
      builder: (context) => ReaderBottomSheetFrame(
        child: PdfTocSheet(
          outline: _pdfOutline,
          totalPages: totalPages ?? 0,
          currentPage: _currentLocation?.pageNumber,
          currentPageOffsetFraction:
              _currentLocation?.locator.pageOffsetFraction,
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
      await deleteReaderBookmarkWithUndo(context, ref, currentBookmark);
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
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        readerActionSnackBar(
          message: '已添加书签',
          actionLabel: '添加备注',
          compact: context.appBreakpoint.isCompact,
          onAction: () =>
              unawaited(editReaderBookmarkNote(context, ref, bookmark)),
        ),
      );
  }

  Future<void> _showNotebook(BuildContext context) async {
    final locator = await showModalBottomSheet<ReadingLocator>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ReaderBottomSheetFrame(
        child: ReaderNotebookSheet(bookId: widget.bookId),
      ),
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
    _desktopContextTab = settings.desktopContextTab;
  }

  void _showContextOrSheet(
    BuildContext context,
    ReaderContextTab tab,
    Future<void> Function() fallback,
  ) {
    if (context.supportsSidePanel) {
      _openDesktopContext(tab);
      return;
    }
    unawaited(fallback());
  }

  void _openDesktopContext(ReaderContextTab tab) {
    setState(() {
      _desktopContextOpen = true;
      _desktopContextTab = tab;
    });
    _saveDesktopChromePrefs();
  }

  void _setDesktopContextTab(ReaderContextTab tab) {
    setState(() => _desktopContextTab = tab);
    _saveDesktopChromePrefs();
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
      desktopContextTab: _desktopContextTab,
    );
    if (debounced) {
      unawaited(ref.read(readerSettingsControllerProvider).save(next));
      return;
    }
    unawaited(ref.read(readerSettingsControllerProvider).saveNow(next));
  }

  Future<void> _showInBookSearch(BuildContext context) async {
    if (context.supportsSidePanel) {
      _openDesktopContext(ReaderContextTab.search);
      return;
    }
    final action = await showModalBottomSheet<InBookSearchAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ReaderSearchPane(
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

  Future<void> _handleInBookSearchAction(InBookSearchAction action) async {
    _jumpTo(action.locator);
    if (!mounted) {
      return;
    }
    if (action.intent == InBookSearchIntent.askAi) {
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
    final value = await showDialog<String>(
      context: context,
      builder: (context) =>
          PageJumpDialog(initialPage: currentLocator?.page ?? 1),
    );
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
    final result = await showReaderAnnotationEditor(
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
    // A menu can be replaced by one for a newer selection before its future
    // resumes; only the latest menu is allowed to clear the renderer's paint.
    final epoch = ++_selectionMenuEpoch;
    _selectionActionsOpen = true;
    // Whether the reader picked an action or merely walked away from the menu.
    //
    // Acting on a selection is not the same as being done with it: after
    // asking AI about a passage, the reader still needs to see which passage
    // that was. The paint therefore stays up once an action ran, and only a
    // dismissal clears it. The renderer still drops it on the next tap
    // elsewhere, which is the reader's other way of saying "finished".
    var acted = false;
    void runAction(
      ReaderSelectionAction action, [
      RendererTextSelected? activeSelection,
    ]) {
      acted = true;
      unawaited(
        _handleSelectionAction(context, activeSelection ?? selection, action),
      );
    }

    _showMobileChrome(autoHide: false);
    try {
      if (context.supportsSidePanel) {
        await _showDesktopSelectionMenu(
          context,
          selection,
          onAction: runAction,
        );
        return;
      }
      _mobileSelectionSheetOpen = true;
      _mobileSelectionNotifier.value = selection;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ValueListenableBuilder<RendererTextSelected?>(
            valueListenable: _mobileSelectionNotifier,
            builder: (context, latest, child) => ReaderSelectionActionSurface(
              selection: latest ?? selection,
              compact: true,
              onAction: (action) {
                Navigator.of(sheetContext).pop();
                runAction(action, latest ?? selection);
              },
              onDismiss: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ),
      );
    } finally {
      if (epoch == _selectionMenuEpoch) {
        _mobileSelectionSheetOpen = false;
        _selectionActionsOpen = false;
        _lastSelectionActionKey = null;
        _flushPendingFolderRefresh();
        if (mounted && !acted) {
          setState(() => _clearSelectionVersion += 1);
        }
        _scheduleMobileChromeAutoHide();
      }
    }
  }

  Future<void> _showDesktopSelectionMenu(
    BuildContext context,
    RendererTextSelected selection, {
    required ValueChanged<ReaderSelectionAction> onAction,
  }) async {
    _closeSelectionOverlay();
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    // Toolbar is icon-only; keep intrinsic width and avoid fixed-width overflow.
    const estimatedWidth = 520.0;
    const estimatedHeight = 104.0;
    final localTarget = _toOverlayLocalRect(selection.sourceRect, overlayBox);
    final placement = placeFloatingMenu(
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
      builder: (overlayContext) => InheritedTheme.captureAll(
        context,
        Stack(
          children: [
            // Tap-outside-to-dismiss, but pointer-transparent underneath: the
            // selection handles sit outside the menu and must stay draggable
            // while it is open. `ColoredBox` is hit-test opaque, so a fully
            // transparent colour would still swallow every drag; `IgnorePointer`
            // on the colour fill keeps only the tap recognizer live.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: dismiss,
                child: const IgnorePointer(
                  child: ColoredBox(color: Color(0x00000000)),
                ),
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
                    child: DesktopReaderSelectionOverlay(
                      selection: selection,
                      onAction: (action) {
                        dismiss();
                        onAction(action);
                      },
                      onDismiss: dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  void _closeSelectionOverlay() {
    final entry = _selectionOverlayEntry;
    entry?.remove();
    entry?.dispose();
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
    ReaderSelectionAction action,
  ) async {
    switch (action) {
      case ReaderSelectionAction.highlight:
        await _saveQuickAnnotation(
          context,
          selection,
          color: AnnotationColor.yellow,
          style: AnnotationStyle.highlight,
        );
      case ReaderSelectionAction.underline:
        await _saveQuickAnnotation(
          context,
          selection,
          color: AnnotationColor.blue,
          style: AnnotationStyle.underline,
        );
      case ReaderSelectionAction.comment:
        await _createAnnotationComment(context, selection);
      case ReaderSelectionAction.note:
        await _createExcerptNote(context, selection: selection);
      case ReaderSelectionAction.search:
        _applyRendererSearchQuery(selection.text);
        if (context.supportsSidePanel) {
          _openDesktopContext(ReaderContextTab.search);
        } else {
          unawaited(_showInBookSearch(context));
        }
      case ReaderSelectionAction.copy:
        await Clipboard.setData(ClipboardData(text: selection.text));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已复制选中文本')));
        }
      case ReaderSelectionAction.ai:
        await _showAiPanel(context);
    }
  }

  Future<void> _createAnnotationComment(
    BuildContext context,
    RendererTextSelected selection,
  ) async {
    final comment = await showReaderAnnotationCommentEditor(
      context,
      selectedText: selection.text,
    );
    if (comment == null || !context.mounted) {
      return;
    }
    final bookId = widget.bookId;
    try {
      await ref
          .read(readerAnnotationCommentServiceProvider)
          .createWithComment(
            bookId: bookId,
            locator: selection.locator,
            selectedText: selection.text,
            comment: comment,
          );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存批注失败')));
      }
      return;
    }
    if (!context.mounted || widget.bookId != bookId) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已添加批注'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createExcerptNote(
    BuildContext context, {
    RendererTextSelected? selection,
  }) async {
    final selectedText = selection ?? _selectedText;
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
    final bookId = widget.bookId;
    final service = ref.read(readerExcerptNoteServiceProvider);
    final draft = await showReaderExcerptEditor(
      context,
      initialTitle:
          location?.chapterTitle ??
          progress?.chapterTitle ??
          locator.displayLabel,
      sourceText: sourceText,
    );
    if (draft == null || draft.content.isEmpty) {
      return;
    }
    final note = await service.saveExcerpt(
      bookId: bookId,
      title: draft.title.isEmpty ? null : draft.title,
      content: draft.content,
      sourceText: sourceText,
      locator: locator,
    );
    if (note == null || !context.mounted || widget.bookId != bookId) {
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
    if (_folderSession.manifest != null &&
        enriched.type == ReadingLocatorType.markdown) {
      if (_folderSession.needsLegacyJump(enriched)) {
        unawaited(_jumpToLegacyFolder(enriched));
        return;
      }
      final file = _folderSession.fileForJump(enriched);
      if (file != null) {
        final switchingFile = _folderSession.switchesFile(enriched);
        final folderLocator = switchingFile
            ? _folderSession.selectFile(file, locator: enriched)
            : _folderSession.locatorForActiveFile(enriched);
        setState(() {
          if (switchingFile) {
            _currentLocation = null;
            _locationNotifier.value = null;
            _rendererVersion += 1;
          }
          _jumpProgress = ReadingProgressSnapshot(
            bookId: widget.bookId,
            locator: folderLocator,
            progress: folderLocator.progress,
            pageNumber: folderLocator.page,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          _jumpToken += 1;
          _focusLocator = null;
        });
        _setTransientStatus(
          jumpStatusLabelFor(folderLocator, pdfTextLayerAvailable: true),
          clearAfter: const Duration(milliseconds: 2800),
        );
        return;
      }
    }
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

  Widget _withFolderSession(
    Book book,
    ReadingProgressSnapshot? snapshot,
    Widget Function() build,
  ) {
    if (!book.isFolderBook) {
      return build();
    }
    final future = _folderSession.load(
      book: book,
      initialLocator: widget.initialLocator ?? snapshot?.locator,
    );
    return FutureBuilder<MarkdownFolderSession>(
      future: future,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.hasError) {
          return const ReaderMessage(message: '无法读取文件夹');
        }
        final session = sessionSnapshot.data;
        if (session == null) {
          return const Center(child: CircularProgressIndicator());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_primeFolderTextCache());
          _startFolderRefresh(book);
        });
        return build();
      },
    );
  }

  Future<void> _primeFolderTextCache() async {
    final file = _folderSession.activeFile;
    if (file == null || _lastFolderTextPath == file.relativePath) {
      return;
    }
    try {
      final text = await File(file.absolutePath).readAsString();
      if (!mounted) return;
      _lastFolderText = text;
      _lastFolderTextPath = file.relativePath;
    } on Object {
      // The refresh coordinator reports unreadable files separately.
    }
  }

  void _startFolderRefresh(Book book) {
    if (_folderRefresh != null ||
        !book.isFolderBook ||
        _folderSession.manifest == null) {
      return;
    }
    final coordinator = MarkdownFolderRefreshCoordinator(
      rootPath: book.libraryFilePath,
      loader: MarkdownFolderSnapshotLoader(_folderSession.source),
    );
    _folderRefresh = coordinator;
    _folderRefreshSubscription = coordinator.events.listen(
      (event) => _onFolderRefresh(book, event),
    );
    unawaited(coordinator.start());
  }

  void _onFolderRefresh(Book book, MarkdownFolderRefreshEvent event) {
    if (!mounted) return;
    final activePath = _folderSession.activeFile?.relativePath;
    final currentChanged =
        activePath != null && event.diff.involves(activePath);
    final nextActiveFile = event.snapshot.manifest.fileForHref(activePath);
    final selectionFrozen = _selectionActionsOpen || _annotationActionsOpen;
    if (selectionFrozen) {
      _pendingFolderRefresh = (book: book, event: event);
      if (currentChanged) {
        setState(() => _folderRefreshState = '来源已更新，选区结束后刷新正文');
      }
      return;
    }
    if (event.epoch < _lastAppliedFolderRefreshEpoch) return;
    _lastAppliedFolderRefreshEpoch = event.epoch;
    _folderSession.replaceManifest(event.snapshot.manifest);
    if (currentChanged && nextActiveFile != null) {
      MarkdownDocumentLoader.clearCache();
      final locator =
          _currentLocation?.locator ??
          _jumpProgress?.locator ??
          _folderSession.initialLocator;
      final oldText = _lastFolderTextPath == activePath
          ? _lastFolderText ?? ''
          : locator?.excerpt ?? '';
      final newText = _readFolderFileText(nextActiveFile);
      if (locator != null && newText != null) {
        final result = _folderSession.reanchor(
          locator,
          oldText: oldText,
          newText: newText,
        );
        _jumpProgress = ReadingProgressSnapshot(
          bookId: widget.bookId,
          locator: result.locator,
          progress: result.locator.progress,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
      _lastFolderText = newText;
      _lastFolderTextPath = nextActiveFile.relativePath;
      _rendererVersion += 1;
      _jumpToken += 1;
      _setTransientStatus('文件已更新', clearAfter: const Duration(seconds: 3));
    } else if (currentChanged) {
      _setTransientStatus(
        '当前文件已移除，保留上次内容',
        clearAfter: const Duration(seconds: 4),
      );
    }
    if (!event.diff.isEmpty) {
      unawaited(_reindexFolderBook(book));
    }
    final stateText = switch (event.state) {
      MarkdownFolderRefreshState.ready => event.diff.isEmpty ? null : '文件夹已同步',
      MarkdownFolderRefreshState.degraded => event.message,
      MarkdownFolderRefreshState.error => event.message,
      _ => null,
    };
    _folderRefreshState = _folderSession.folderNotice ?? stateText;
    _folderRefreshStatusTimer?.cancel();
    if (stateText != null) {
      _folderRefreshStatusTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _folderRefreshState = _folderSession.folderNotice);
      });
    }
    if (mounted) setState(() {});
  }

  void _flushPendingFolderRefresh() {
    final pending = _pendingFolderRefresh;
    if (pending == null ||
        !mounted ||
        _selectionActionsOpen ||
        _annotationActionsOpen) {
      return;
    }
    _pendingFolderRefresh = null;
    _onFolderRefresh(pending.book, pending.event);
  }

  String? _readFolderFileText(MarkdownFolderFile? file) {
    if (file == null) return null;
    try {
      return File(file.absolutePath).readAsStringSync();
    } on Object {
      return null;
    }
  }

  Future<void> _reindexFolderBook(Book book) async {
    try {
      await ref.read(searchIndexerProvider).indexBook(book);
    } on Object {
      if (mounted) {
        _setTransientStatus(
          '文件已更新，但搜索索引待重建',
          clearAfter: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _refreshFolderBook() async {
    await _folderRefresh?.refresh(full: true);
  }

  ReadingProgressSnapshot? _rendererProgressFor(
    ReadingProgressSnapshot? snapshot,
  ) {
    if (_folderSession.manifest == null) {
      return _jumpProgress ?? snapshot;
    }
    return _folderSession.rendererProgress(
      bookId: widget.bookId,
      snapshot: snapshot,
      jumpProgress: _jumpProgress,
    );
  }

  void _openFolderFile(MarkdownFolderFile file) {
    if (_folderSession.manifest == null ||
        _folderSession.activeFile?.relativePath == file.relativePath) {
      return;
    }
    final locator = _folderSession.openFile(file);
    setState(() {
      _currentLocation = null;
      _locationNotifier.value = null;
      _jumpProgress = ReadingProgressSnapshot(
        bookId: widget.bookId,
        locator: locator,
        progress: locator.progress,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _rendererVersion += 1;
      _jumpToken += 1;
      _focusLocator = null;
    });
    unawaited(_primeFolderTextCache());
    _setTransientStatus(
      '已打开 ${file.title}',
      clearAfter: const Duration(milliseconds: 1600),
    );
  }

  Future<void> _jumpToLegacyFolder(ReadingLocator locator) async {
    try {
      final resolved = await _folderSession.resolveLegacyJump(locator);
      if (!mounted) {
        return;
      }
      if (resolved == null) {
        _setTransientStatus(
          '旧版文件夹位置已失效，请重新选择目录',
          clearAfter: const Duration(seconds: 4),
        );
        return;
      }
      _jumpTo(resolved);
    } on Object {
      if (mounted) {
        _setTransientStatus('无法定位旧版文件夹位置');
      }
    }
  }

  Future<void> _runOcrCurrentPage(BuildContext context, Book book) async {
    if (book.format != BookFormat.pdf || book.id != widget.bookId) {
      return;
    }
    final requestEpoch = ++_ocrRequestEpoch;
    bool isCurrent() =>
        mounted && widget.bookId == book.id && requestEpoch == _ocrRequestEpoch;
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
    final coordinator = ref.read(readerOcrCoordinatorProvider(book.id));
    final pages = await coordinator.visiblePages(
      fallbackPage: fallbackPage,
      pageSource: pdfController,
    );
    if (!mounted || !isCurrent()) {
      return;
    }

    final statusLabel = pages.length > 1
        ? '正在识别第 ${pages.first}–${pages.last} 页…'
        : '正在识别第 ${pages.first} 页…';
    _setTransientStatus(statusLabel, clearAfter: const Duration(seconds: 12));

    final completed = await coordinator.recognizePages(
      book: book,
      pageNumbers: pages,
      pageSource: pdfController,
    );
    if (!mounted || !isCurrent()) {
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
      _ocrOverlays.show(overlays);

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
      _scheduleOcrReindex(book);
      return;
    }

    final first = completed.first;
    _setTransientStatus(
      '第 ${first.page} 页识别完成',
      clearAfter: const Duration(seconds: 2),
    );
    final result = OcrPageResult(
      text: combinedText.isEmpty ? first.result.text : combinedText,
      language: first.result.language,
      engine: first.result.engine,
      confidence: first.result.confidence,
      blocks: first.result.blocks,
    );
    final locator = ReadingLocator.pdf(
      page: first.page,
      progress: _currentLocation?.progress ?? 0,
      excerpt: result.text.length > 120
          ? '${result.text.substring(0, 120)}…'
          : result.text,
    );
    await showReaderOcrResultSheet(
      this.context,
      pageNumber: first.page,
      result: result,
      onAskAi: () => unawaited(
        _showAiPanel(
          this.context,
          locatorOverride: locator,
          initialContextOverride: result.text,
        ),
      ),
    );
    _scheduleOcrReindex(book);
  }

  void _scheduleOcrReindex(Book book) {
    _ocrIndexTimer?.cancel();
    _ocrIndexTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_reindexAfterOcr(book));
    });
  }

  Future<void> _reindexAfterOcr(Book book) async {
    try {
      await ref.read(searchIndexerProvider).indexBook(book);
      if (mounted && widget.bookId == book.id) {
        _setTransientStatus(
          '识别文本已加入搜索',
          clearAfter: const Duration(milliseconds: 1800),
        );
      }
    } on Object {
      if (mounted && widget.bookId == book.id) {
        _setTransientStatus(
          '识别完成，搜索索引待重建',
          clearAfter: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _showOcrRangeDialog(BuildContext context, Book book) async {
    if (book.format != BookFormat.pdf) return;
    final totalPages = _currentLocation?.totalPages;
    if (totalPages == null || totalPages < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF 页码尚未准备好')));
      return;
    }
    final currentPage = (_currentLocation?.pageNumber ?? 1).clamp(
      1,
      totalPages,
    );
    final controller = TextEditingController(text: '$currentPage');
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('识别页面范围'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('支持单页、连续页码和多段范围，例如 1-3, 8, 10-12。'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: '页码范围',
                  helperText: '全书共 $totalPages 页，单次最多 2000 页',
                ),
                onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
              ),
              const SizedBox(height: 8),
              Text(
                '已有原生文字的页面会自动跳过；识别文本会加入书内和全局搜索。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('开始识别'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || !context.mounted) return;
    late final List<int> pages;
    try {
      pages = OcrPageRange.parse(input, pageCount: totalPages);
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    try {
      await ref
          .read(ocrJobControllerProvider)
          .start(book: book, pageNumbers: pages, languageHint: book.language);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已加入识别队列 · ${pages.length} 页'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _startOcrWholeBook(BuildContext context, Book book) async {
    final totalPages = _currentLocation?.totalPages;
    if (book.format != BookFormat.pdf || totalPages == null || totalPages < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF 页码尚未准备好')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('识别整本'),
        content: Text('共 $totalPages 页，已有原生文字的页面会自动跳过。识别可能需要较长时间，可在任务中心管理。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('开始识别'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.bookId != book.id) return;
    try {
      final controller = ref.read(ocrJobControllerProvider);
      final queued = await _wholeBookOcrQueue.enqueue(
        totalPages: totalPages,
        startBatch: (pages) async {
          await controller.start(
            book: book,
            pageNumbers: pages,
            languageHint: book.language,
          );
        },
      );
      if (queued == null) return;
      if (!mounted || widget.bookId != book.id) return;
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(SnackBar(content: Text('已加入识别队列 · $queued 页')));
    } on WholeBookOcrQueueException catch (error) {
      if (!mounted || widget.bookId != book.id) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('加入队列失败，已加入 ${error.queuedPages} / $totalPages 页'),
        ),
      );
    }
  }

  /// Re-apply OCR overlays from session/disk cache when the user returns
  /// to a previously recognized page — no re-OCR, no toast.
  Future<void> _restoreOcrOverlaysForVisiblePages() async {
    final bookAsync = ref.read(readerBookProvider(widget.bookId));
    final book = bookAsync.asData?.value;
    if (book == null || book.format != BookFormat.pdf) {
      return;
    }
    final fallbackPage = _currentLocation?.pageNumber;
    if (fallbackPage == null || fallbackPage < 1) {
      return;
    }
    final generation = _ocrOverlays.beginRestore();
    final coordinator = ref.read(readerOcrCoordinatorProvider(book.id));
    final restored = await coordinator.restoreOverlays(
      fallbackPage: fallbackPage,
      pageSource: ref.read(activePdfRendererControllerProvider),
      isRestored: _ocrOverlays.isRestored,
      isCurrent: () => mounted && _ocrOverlays.isRestoreCurrent(generation),
    );
    if (!mounted ||
        !_ocrOverlays.isRestoreCurrent(generation) ||
        restored.isEmpty) {
      return;
    }
    _ocrOverlays.show([
      for (final overlay in restored)
        (
          page: overlay.page,
          blocks: [for (final block in overlay.blocks) block.toJson()],
        ),
    ]);
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
      _openDesktopContext(ReaderContextTab.ai);
      return;
    }

    final location = _currentLocation;
    final progress = ref.read(readerProgressProvider(widget.bookId)).value;
    final selectedText = _selectedText;
    final book = ref.read(readerBookProvider(widget.bookId)).value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ReaderBottomSheetFrame(
        child: AiPanel(
          bookId: widget.bookId,
          bookPath: book?.libraryFilePath,
          format: book!.format,
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

/// The loader that opens this book's file.
BookDocumentLoader _documentLoaderFor(Book book) {
  return book.format == BookFormat.markdown
      ? const MarkdownDocumentLoader()
      : const EpubDocumentLoader();
}
