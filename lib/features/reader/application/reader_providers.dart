import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/book_repository.dart';
import '../../../domain/books/reading_position.dart';
import '../../../renderers/common/renderer_event.dart';

final readerBookProvider = FutureProvider.family<Book?, String>((ref, bookId) {
  return ref.watch(bookRepositoryProvider).getBook(bookId);
});

final readerProgressProvider =
    FutureProvider.family<ReadingProgressSnapshot?, String>((ref, bookId) {
      return ref.watch(bookRepositoryProvider).getProgress(bookId);
    });

final readerSessionControllerProvider = Provider.autoDispose
    .family<ReaderSessionController, String>((ref, bookId) {
      final controller = ReaderSessionController(
        bookId: bookId,
        repository: ref.watch(bookRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final class ReaderSessionController {
  ReaderSessionController({
    required String bookId,
    required BookRepository repository,
  }) : this._(bookId, repository);

  ReaderSessionController._(this.bookId, this._repository);

  final String bookId;
  final BookRepository _repository;
  RendererLocationChanged? _pendingLocation;
  Future<void>? _pendingSave;
  bool _disposed = false;

  Future<void> markOpened() {
    if (_disposed) {
      return Future<void>.value();
    }
    return _repository.markOpened(bookId);
  }

  void handleEvent(RendererEvent event) {
    if (_disposed) {
      return;
    }
    switch (event) {
      case RendererReady():
      case RendererTextSelected():
      case RendererSearchResults():
      case RendererOutlineChanged():
      case RendererBookmarkRequested():
      case RendererCapabilityChanged():
      case RendererNotice():
      case RendererAnnotationSelected():
      case RendererFailed():
        return;
      case RendererLocationChanged():
        final previous = _pendingLocation;
        // Skip no-op updates that only jitter fractional progress on the same page.
        if (previous != null &&
            previous.pageNumber == event.pageNumber &&
            previous.locator.href == event.locator.href &&
            previous.locator.chapterIndex == event.locator.chapterIndex &&
            (previous.progress - event.progress).abs() < 0.0015) {
          return;
        }
        _pendingLocation = event;
        _pendingSave ??= Future<void>.delayed(
          const Duration(milliseconds: 700),
          _flushPending,
        );
    }
  }

  Future<void> flush() async {
    await _pendingSave;
    await _flushPending();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final pending = _pendingLocation;
    _pendingLocation = null;
    _pendingSave = null;
    if (pending != null) {
      // Best-effort final save; page already called flush when possible.
      unawaited(_save(pending));
    }
  }

  Future<void> _flushPending() async {
    if (_disposed) {
      return;
    }
    final location = _pendingLocation;
    _pendingLocation = null;
    _pendingSave = null;
    if (location != null) {
      await _save(location);
    }
  }

  Future<void> _save(RendererLocationChanged event) async {
    await _repository.saveProgress(
      bookId: bookId,
      locator: event.locator,
      progress: event.progress,
      chapterTitle: event.chapterTitle,
      pageNumber: event.pageNumber,
    );
    if (event.progress >= 1) {
      await _repository.updateReadStatus(bookId, ReadStatus.finished);
    }
  }
}
