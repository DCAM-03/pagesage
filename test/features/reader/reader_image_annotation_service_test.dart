import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/image_cache_store.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/annotations/image_anchor.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/reader/application/reader_image_annotation_service.dart';
import 'package:pagesage/renderers/pdf/pdf_page_image_source.dart';

void main() {
  test('saves the annotation before caching the rendered image', () async {
    final events = <String>[];
    final repository = _RecordingAnnotationRepository(events);
    final cache = _RecordingImageCacheStore(events);
    final source = _RecordingPdfImageSource(events);
    final service = ReaderImageAnnotationService(
      annotationRepository: repository,
      imageCacheStore: cache,
    );
    const anchor = PdfImageAnchor(
      page: 7,
      ordinal: 2,
      rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
    );

    final annotation = await service.saveAnnotation(
      bookId: 'book-1',
      anchor: anchor,
      selectedText: ' 图注 ',
      color: AnnotationColor.blue,
      style: AnnotationStyle.highlight,
      imageSource: source,
    );

    expect(annotation.imageAnchor, anchor);
    expect(annotation.selectedText, '图注');
    expect(annotation.locator.page, 7);
    expect(events, ['save', 'render:7']);

    await cache.writeCompleted.future;

    expect(events, ['save', 'render:7', 'cache']);
    expect(cache.cachedBookId, 'book-1');
    expect(cache.cachedAnchor, anchor);
    expect(cache.cachedBytes, [1, 2, 3]);
  });

  test('image extraction failure does not undo the annotation', () async {
    final events = <String>[];
    final repository = _RecordingAnnotationRepository(events);
    final cache = _RecordingImageCacheStore(events);
    final source = _RecordingPdfImageSource(
      events,
      failure: StateError('render failed'),
    );
    final service = ReaderImageAnnotationService(
      annotationRepository: repository,
      imageCacheStore: cache,
    );
    const anchor = PdfImageAnchor(
      page: 3,
      ordinal: 0,
      rect: ReaderRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5),
    );

    final annotation = await service.saveAnnotation(
      bookId: 'book-2',
      anchor: anchor,
      selectedText: '',
      color: AnnotationColor.blue,
      style: AnnotationStyle.highlight,
      imageSource: source,
    );

    await source.renderCompleted.future;

    expect(annotation.imageAnchor, anchor);
    expect(events, ['save', 'render:3']);
    expect(cache.writeCompleted.isCompleted, isFalse);
  });

  test('renderRegion returns null without a PDF source', () async {
    final service = ReaderImageAnnotationService(
      annotationRepository: _RecordingAnnotationRepository([]),
      imageCacheStore: _RecordingImageCacheStore([]),
    );

    expect(
      await service.renderRegion(
        anchor: const PdfImageAnchor(
          page: 1,
          ordinal: 0,
          rect: ReaderRect(x: 0, y: 0, width: 1, height: 1),
        ),
        imageSource: null,
      ),
      isNull,
    );
  });
}

final class _RecordingAnnotationRepository implements AnnotationRepository {
  _RecordingAnnotationRepository(this.events);

  final List<String> events;

  @override
  Future<Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    AnnotationColor color = AnnotationColor.yellow,
    AnnotationStyle style = AnnotationStyle.highlight,
    ImageAnchor? imageAnchor,
  }) async {
    events.add('save');
    return Annotation(
      id: id ?? 'annotation-1',
      bookId: bookId,
      locator: locator,
      selectedText: selectedText,
      color: color,
      style: style,
      createdAt: 1,
      updatedAt: 1,
      target: AnnotationTarget.image,
      imageAnchor: imageAnchor,
    );
  }

  @override
  Future<List<Annotation>> getAll() async => const [];

  @override
  Future<List<Annotation>> getByBook(String bookId) async => const [];

  @override
  Stream<List<Annotation>> watchByBook(String bookId) => const Stream.empty();

  @override
  Future<void> deleteAnnotation(String id) async {}

  @override
  Future<void> linkNote({
    required String annotationId,
    required String noteId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> unlinkNote({required String annotationId}) {
    throw UnimplementedError();
  }
}

final class _RecordingImageCacheStore extends CachedImageStore {
  _RecordingImageCacheStore(this.events)
    : super(appPaths: AppPaths(overrideRoot: Directory('unused')));

  final List<String> events;
  final Completer<void> writeCompleted = Completer<void>();
  String? cachedBookId;
  ImageAnchor? cachedAnchor;
  Uint8List? cachedBytes;

  @override
  Future<File> put({
    required String bookId,
    required ImageAnchor anchor,
    required Uint8List bytes,
  }) async {
    events.add('cache');
    cachedBookId = bookId;
    cachedAnchor = anchor;
    cachedBytes = bytes;
    writeCompleted.complete();
    return File('cached-image.png');
  }
}

final class _RecordingPdfImageSource implements PdfPageImageSource {
  _RecordingPdfImageSource(this.events, {this.failure});

  final List<String> events;
  final Object? failure;
  final Completer<void> renderCompleted = Completer<void>();

  @override
  Future<Uint8List?> exportPageRegion({
    required int pageNumber,
    required ReaderRect rect,
  }) async {
    events.add('render:$pageNumber');
    renderCompleted.complete();
    if (failure case final error?) {
      throw error;
    }
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Uint8List?> exportPageImage({
    required int pageNumber,
    double quality = 0.92,
  }) async => null;

  @override
  Future<List<int>> getVisiblePages({int? fallbackPage}) async =>
      fallbackPage == null ? const [] : [fallbackPage];
}
