import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/files/image_cache_store.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/annotations/image_anchor.dart';
import '../../../domain/books/reading_position.dart';
import '../../../renderers/pdf/pdf_page_image_source.dart';

final readerImageAnnotationServiceProvider =
    Provider<ReaderImageAnnotationService>((ref) {
      return ReaderImageAnnotationService(
        annotationRepository: ref.watch(annotationRepositoryProvider),
        imageCacheStore: ref.watch(imageCacheStoreProvider),
      );
    });

final class ReaderImageAnnotationService {
  const ReaderImageAnnotationService({
    required this.annotationRepository,
    required this.imageCacheStore,
  });

  final AnnotationRepository annotationRepository;
  final CachedImageStore imageCacheStore;

  Future<Annotation> saveAnnotation({
    required String bookId,
    required ImageAnchor anchor,
    required String selectedText,
    required AnnotationColor color,
    required AnnotationStyle style,
    required PdfPageImageSource? imageSource,
  }) async {
    final page = anchor is PdfImageAnchor ? anchor.page : null;
    final annotation = await annotationRepository.saveAnnotation(
      bookId: bookId,
      locator: ReadingLocator.pdf(
        page: page ?? 1,
        selectionRects: [anchor.rect],
      ),
      selectedText: selectedText.trim(),
      color: color,
      style: style,
      imageAnchor: anchor,
    );
    if (imageSource != null && anchor is PdfImageAnchor) {
      unawaited(_cacheImage(bookId, anchor, imageSource));
    }
    return annotation;
  }

  Future<Uint8List?> renderRegion({
    required ImageAnchor anchor,
    required PdfPageImageSource? imageSource,
  }) async {
    if (anchor is! PdfImageAnchor || imageSource == null) {
      return null;
    }
    return imageSource.exportPageRegion(
      pageNumber: anchor.page,
      rect: anchor.rect,
    );
  }

  Future<void> _cacheImage(
    String bookId,
    PdfImageAnchor anchor,
    PdfPageImageSource imageSource,
  ) async {
    try {
      final bytes = await imageSource.exportPageRegion(
        pageNumber: anchor.page,
        rect: anchor.rect,
      );
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      await imageCacheStore.put(bookId: bookId, anchor: anchor, bytes: bytes);
    } on Object {
      // The annotation remains useful when its optional image cache fails.
    }
  }
}
