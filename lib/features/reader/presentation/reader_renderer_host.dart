import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/annotations/annotation.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';
import '../../../renderers/common/renderer_event.dart';
import '../../../renderers/epub/epub_renderer_view.dart';
import '../../../renderers/markdown/markdown_document_loader.dart';
import '../../../renderers/pdf/pdf_canvas_view.dart';

final readerRendererHostProvider =
    Provider<Widget Function(ReaderRendererHostConfig)>((ref) {
      return (config) => _DefaultRendererHost(config: config);
    });

final class ReaderRendererHostConfig {
  const ReaderRendererHostConfig({
    required this.book,
    required this.progress,
    this.documentPath,
    this.folderRelativePath,
    required this.settings,
    required this.annotations,
    required this.version,
    required this.jumpToken,
    required this.searchQuery,
    required this.focusLocator,
    required this.clearSearchHighlightsVersion,
    this.clearSelectionVersion = 0,
    required this.onEvent,
    this.ocrOverlayToken = 0,
    this.ocrOverlayPage,
    this.ocrOverlayBlocks = const [],
    this.onZoomChanged,
    this.imageDragMode = false,
    this.onImageAreaSelected,
  });

  final Book book;
  final ReadingProgressSnapshot? progress;
  final String? documentPath;
  final String? folderRelativePath;
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

  /// Bumped when the selection should be dismissed; the renderer clears its
  /// highlight and handles when this changes.
  final int clearSelectionVersion;
  final ValueChanged<RendererEvent> onEvent;

  /// Bumped when a new OCR overlay should be painted onto the PDF page.
  final int ocrOverlayToken;
  final int? ocrOverlayPage;
  final List<Map<String, Object?>> ocrOverlayBlocks;

  /// Zoom performed inside the renderer (pinch, Ctrl+wheel, double-click).
  final PdfZoomChanged? onZoomChanged;

  /// While true a drag draws a box around a picture instead of selecting text.
  ///
  /// Only the canvas PDF renderer supports it; other renderers ignore it.
  final bool imageDragMode;

  /// Called when the reader finishes drawing an image box.
  final ValueChanged<RendererImageAreaSelected>? onImageAreaSelected;
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
      BookFormat.markdown => EpubRendererView(
        key: ValueKey('md-${config.book.id}-${config.version}'),
        book: config.book,
        documentPath: config.documentPath,
        settings: config.settings,
        initialProgress: config.progress,
        annotations: config.annotations,
        searchQuery: config.searchQuery,
        focusLocator: config.focusLocator,
        jumpToken: config.jumpToken,
        documentLoader: config.folderRelativePath == null
            ? const MarkdownDocumentLoader()
            : MarkdownFileDocumentLoader(
                relativePath: config.folderRelativePath!,
              ),
        onEvent: config.onEvent,
      ),
      BookFormat.pdf => PdfCanvasView(
        key: ValueKey('pdf-canvas-${config.book.id}-${config.version}'),
        book: config.book,
        settings: config.settings,
        initialProgress: config.progress,
        annotations: config.annotations,
        ocrOverlayPage: config.ocrOverlayPage,
        ocrOverlayBlocks: config.ocrOverlayBlocks,
        ocrOverlayToken: config.ocrOverlayToken,
        searchQuery: config.searchQuery,
        focusLocator: config.focusLocator,
        jumpToken: config.jumpToken,
        clearSearchHighlightsVersion: config.clearSearchHighlightsVersion,
        clearSelectionVersion: config.clearSelectionVersion,
        onZoomChanged: config.onZoomChanged,
        imageDragMode: config.imageDragMode,
        onImageAreaSelected: config.onImageAreaSelected,
        onEvent: config.onEvent,
      ),
    };
  }
}
