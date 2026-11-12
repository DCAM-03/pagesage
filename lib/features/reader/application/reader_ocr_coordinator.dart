import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ocr/ocr_timeline.dart';
import '../../../domain/books/book.dart';
import '../../../domain/ocr/ocr_models.dart';
import '../../../renderers/pdf/pdf_page_image_source.dart';
import '../../ocr/application/ocr_page_controller.dart';

typedef ReaderOcrPageResult = ({int page, OcrPageResult result});
typedef ReaderOcrCachedOverlay = ({int page, List<OcrTextBlock> blocks});

typedef ReaderOcrRecognizePages =
    Future<List<ReaderOcrPageResult>> Function({
      required Book book,
      required List<int> pageNumbers,
      String? languageHint,
      bool forceRefresh,
      Future<Uint8List?> Function(int pageNumber)? exportPage,
    });

typedef ReaderOcrPeekPage =
    Future<OcrPageResult?> Function({required int pageNumber});

final readerOcrCoordinatorProvider = Provider.autoDispose
    .family<ReaderOcrCoordinator, String>((ref, bookId) {
      final controller = ref.watch(ocrPageControllerProvider(bookId).notifier);
      return ReaderOcrCoordinator(
        recognizePageBatch: controller.recognizePages,
        peekPage: controller.peekCached,
      );
    });

/// Coordinates the reader-side OCR flow without owning reader UI.
///
/// Page discovery, display-space export, the one retry for a page that was
/// still rasterising, and cached-overlay lookup all belong together. The
/// reader keeps the status text, result sheet and AI hand-off.
final class ReaderOcrCoordinator {
  const ReaderOcrCoordinator({
    required this.recognizePageBatch,
    required this.peekPage,
  });

  final ReaderOcrRecognizePages recognizePageBatch;
  final ReaderOcrPeekPage peekPage;

  /// Visible pages in reading order, falling back to [fallbackPage].
  Future<List<int>> visiblePages({
    required int fallbackPage,
    PdfPageImageSource? pageSource,
  }) async {
    if (pageSource == null) {
      return [fallbackPage];
    }
    try {
      final pages = await pageSource.getVisiblePages(
        fallbackPage: fallbackPage,
      );
      final seen = <int>{};
      final valid = [
        for (final page in pages)
          if (page > 0 && seen.add(page)) page,
      ];
      return valid.isEmpty ? [fallbackPage] : valid;
    } on Object {
      return [fallbackPage];
    }
  }

  /// Recognizes [pageNumbers], preferring the pixels currently on screen.
  ///
  /// A null/empty export is retried once after the page has had time to
  /// settle; if it still fails, the OCR use case falls back to native PDF
  /// rendering.
  Future<List<ReaderOcrPageResult>> recognizePages({
    required Book book,
    required List<int> pageNumbers,
    PdfPageImageSource? pageSource,
    String? languageHint,
  }) {
    return recognizePageBatch(
      book: book,
      pageNumbers: pageNumbers,
      languageHint: languageHint,
      forceRefresh: false,
      exportPage: pageSource == null
          ? null
          : (pageNumber) => _exportPage(pageSource, pageNumber),
    );
  }

  /// Restores cached OCR geometry for visible pages that are not painted yet.
  ///
  /// [isCurrent] lets the reader invalidate a slow disk lookup after a page
  /// turn; returning false stops the lookup instead of painting stale blocks.
  Future<List<ReaderOcrCachedOverlay>> restoreOverlays({
    required int fallbackPage,
    PdfPageImageSource? pageSource,
    required bool Function(int pageNumber) isRestored,
    bool Function()? isCurrent,
  }) async {
    bool current() => isCurrent?.call() ?? true;

    if (!current()) return const [];
    final pages = await visiblePages(
      fallbackPage: fallbackPage,
      pageSource: pageSource,
    );
    if (!current()) return const [];

    final overlays = <ReaderOcrCachedOverlay>[];
    for (final page in pages) {
      if (!current()) return const [];
      if (isRestored(page)) continue;
      final cached = await peekPage(pageNumber: page);
      if (!current()) return const [];
      if (cached == null || !cached.hasGeometry) continue;
      final blocks = cached.blocks
          .where((block) => block.hasGeometry)
          .toList(growable: false);
      if (blocks.isEmpty) continue;
      overlays.add((page: page, blocks: blocks));
    }
    return overlays;
  }

  Future<Uint8List?> _exportPage(
    PdfPageImageSource pageSource,
    int pageNumber,
  ) async {
    try {
      var exported = await traceOcrAsync(
        'ocr.export.renderer',
        () => pageSource.exportPageImage(pageNumber: pageNumber),
        arguments: {'page': pageNumber},
      );
      if (exported == null || exported.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        exported = await traceOcrAsync(
          'ocr.export.renderer.retry',
          () => pageSource.exportPageImage(pageNumber: pageNumber),
          arguments: {'page': pageNumber},
        );
      }
      return exported;
    } on Object {
      return null;
    }
  }
}
