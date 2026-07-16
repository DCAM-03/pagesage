import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../domain/annotations/annotation.dart';
import '../../domain/books/book.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import '../common/renderer_command.dart';
import '../common/renderer_event.dart';
import '../common/web_renderer_helpers.dart';
import 'pdf_renderer_controller.dart';
import 'pdf_renderer_server.dart';

final class PdfRendererView extends StatefulWidget {
  const PdfRendererView({
    required this.book,
    required this.settings,
    required this.initialProgress,
    required this.annotations,
    required this.onEvent,
    this.searchQuery,
    this.focusLocator,
    this.clearSearchHighlightsVersion = 0,
    this.jumpToken = 0,
    super.key,
  });

  final Book book;
  final ReaderSettings settings;
  final ReadingProgressSnapshot? initialProgress;
  final List<Annotation> annotations;
  final ValueChanged<RendererEvent> onEvent;
  final String? searchQuery;
  final ReadingLocator? focusLocator;
  final int clearSearchHighlightsVersion;
  /// Soft jump token from the host (TOC / search) without remounting WebView.
  final int jumpToken;

  @override
  State<PdfRendererView> createState() => _PdfRendererViewState();
}

final class _PdfRendererViewState extends State<PdfRendererView> {
  PdfRendererController? _rendererController;
  late Future<PdfRendererServer> _serverFuture;
  PdfRendererServer? _server;
  final GlobalKey _webViewKey = GlobalKey();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _serverFuture = PdfRendererServer.start(
      bookPath: widget.book.libraryFilePath,
    );
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfRendererView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _rendererController?.dispatch(RendererApplyThemeCommand(widget.settings));
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _applySearchQuery();
    }
    if (oldWidget.clearSearchHighlightsVersion !=
        widget.clearSearchHighlightsVersion) {
      _rendererController?.dispatch(
        const RendererClearSearchHighlightsCommand(),
      );
    }
    if (oldWidget.annotations != widget.annotations) {
      _applyAnnotations();
    }
    if (oldWidget.jumpToken != widget.jumpToken) {
      final locator = widget.initialProgress?.locator;
      if (locator != null && _loaded) {
        unawaited(
          _rendererController?.dispatch(RendererGoToCommand(locator)) ??
              Future<void>.value(),
        );
      }
    }
    if (oldWidget.focusLocator != widget.focusLocator &&
        widget.focusLocator == null &&
        _loaded) {
      // Focus flash ended; clear temporary marks unless a real search is active.
      final activeSearch = widget.searchQuery?.trim() ?? '';
      if (activeSearch.isEmpty) {
        unawaited(
          _rendererController?.dispatch(
                const RendererClearSearchHighlightsCommand(),
              ) ??
              Future<void>.value(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfRendererServer>(
      future: _serverFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PdfRendererMessage(message: '无法启动 PDF 阅读服务');
        }

        final server = snapshot.data;
        if (server == null) {
          return const Center(child: CircularProgressIndicator());
        }
        _server = server;

        return KeyedSubtree(
          key: _webViewKey,
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(server.viewerUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: false,
              supportZoom: true,
            ),
            onWebViewCreated: (controller) {
              _rendererController = PdfRendererController(controller);
              controller.addJavaScriptHandler(
                handlerName: 'PageSageBridge',
                callback: (arguments) {
                  final event = parseRendererEvent(
                    arguments.isEmpty ? null : arguments.first,
                  );
                  widget.onEvent(_mapEventToFlutterCoords(event));
                  return null;
                },
              );
            },
            onLoadStop: (controller, url) async {
              if (url?.toString() != server.viewerUrl) {
                return;
              }
              if (_loaded) {
                return;
              }
              _loaded = true;
              try {
                await _waitForRendererBridge(controller);
                await controller.evaluateJavascript(
                  source: rendererOpenUrlScript(
                    fileUrl: server.bookUrl,
                    settings: widget.settings,
                    locator: widget.initialProgress?.locator,
                  ),
                );
                await _applySearchQuery();
                await _applyAnnotations();
              } on Object catch (error) {
                widget.onEvent(RendererFailed(error.toString()));
              }
            },
            onConsoleMessage: (controller, consoleMessage) {
              // PDF.js frequently logs non-fatal "error" noise (fonts, optional
              // content). Never treat console text as a hard render failure —
              // bridge `failed` / onReceivedError remain the real signals.
              final message = consoleMessage.message;
              final level = consoleMessage.messageLevel;
              if (level == ConsoleMessageLevel.ERROR &&
                  (message.contains('PageSage') ||
                      message.contains('failed to open') ||
                      message.contains('无法'))) {
                widget.onEvent(RendererFailed(message));
              }
            },
            onReceivedError: (controller, request, error) {
              widget.onEvent(RendererFailed(error.description));
            },
          ),
        );
      },
    );
  }

  /// WebView reports client coordinates relative to the page viewport; convert
  /// them into Flutter global coordinates so selection/annotation menus land
  /// on the actual text instead of the window origin.
  RendererEvent _mapEventToFlutterCoords(RendererEvent event) {
    final box = _webViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return event;
    }
    final origin = box.localToGlobal(Offset.zero);
    return switch (event) {
      RendererTextSelected(
        :final text,
        :final locator,
        :final sourceRect,
        :final selectionRects,
      ) =>
        RendererTextSelected(
          text: text,
          locator: locator,
          sourceRect: _offsetRect(sourceRect, origin),
          selectionRects: selectionRects,
        ),
      RendererAnnotationSelected(:final annotationId, :final sourceRect) =>
        RendererAnnotationSelected(
          annotationId,
          sourceRect: _offsetRect(sourceRect, origin),
        ),
      _ => event,
    };
  }

  ReaderRect? _offsetRect(ReaderRect? rect, Offset origin) {
    if (rect == null) {
      return null;
    }
    return ReaderRect(
      page: rect.page,
      x: rect.x + origin.dx,
      y: rect.y + origin.dy,
      width: rect.width,
      height: rect.height,
    );
  }

  Future<void> _applySearchQuery() async {
    final query = widget.searchQuery?.trim();
    if (query == null || query.isEmpty) {
      await _rendererController?.dispatch(
        const RendererClearSearchHighlightsCommand(),
      );
      return;
    }
    await _rendererController?.dispatch(RendererSearchCommand(query));
  }

  Future<void> _applyAnnotations() async {
    if (!_loaded) {
      return;
    }
    await _rendererController?.dispatch(
      RendererApplyAnnotationsCommand(widget.annotations),
    );
  }

  Future<void> _waitForRendererBridge(InAppWebViewController controller) async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      final ready = await controller.evaluateJavascript(
        source:
            'Boolean(window.PageSageRenderer && '
            'typeof window.PageSageRenderer.open === "function" && '
            'typeof window.PageSageRenderer.applyAnnotations === "function")',
      );
      if (ready == true || ready == 1 || ready == 'true') {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('PDF renderer bridge is not ready');
  }
}

final class _PdfRendererMessage extends StatelessWidget {
  const _PdfRendererMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
