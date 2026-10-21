import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tasks/task_cancellation.dart';
import '../../../domain/books/book.dart';
import '../../../domain/ocr/ocr_models.dart';
import 'ocr_providers.dart';

enum OcrPagePhase { idle, running, success, error }

final class OcrPageUiState {
  const OcrPageUiState({
    this.phase = OcrPagePhase.idle,
    this.pageNumber,
    this.result,
    this.errorMessage,
    this.generation = 0,
  });

  final OcrPagePhase phase;
  final int? pageNumber;
  final OcrPageResult? result;
  final String? errorMessage;
  final int generation;

  bool get isRunning => phase == OcrPagePhase.running;

  OcrPageUiState copyWith({
    OcrPagePhase? phase,
    int? pageNumber,
    OcrPageResult? result,
    String? errorMessage,
    int? generation,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return OcrPageUiState(
      phase: phase ?? this.phase,
      pageNumber: pageNumber ?? this.pageNumber,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      generation: generation ?? this.generation,
    );
  }
}

/// Riverpod 3 family Notifier: constructor receives the family argument.
final ocrPageControllerProvider =
    NotifierProvider.family<OcrPageController, OcrPageUiState, String>(
      OcrPageController.new,
    );

final class OcrPageController extends Notifier<OcrPageUiState> {
  OcrPageController(this.bookId);

  final String bookId;
  TaskCancelToken? _token;
  int _generation = 0;

  @override
  OcrPageUiState build() => const OcrPageUiState();

  Future<OcrPageResult?> recognize({
    required Book book,
    required int pageNumber,
    String? languageHint,
    bool forceRefresh = false,
    Uint8List? displayImageBytes,
  }) async {
    final results = await recognizePages(
      book: book,
      pageNumbers: [pageNumber],
      languageHint: languageHint,
      forceRefresh: forceRefresh,
      exportPage: displayImageBytes == null
          ? null
          : (page) async => page == pageNumber ? displayImageBytes : null,
    );
    return results.isEmpty ? null : results.first.result;
  }

  /// Look up a stored OCR page without starting a new recognition.
  Future<OcrPageResult?> peekCached({required int pageNumber}) {
    return ref
        .read(ocrCurrentPageUseCaseProvider)
        .peekCachedPage(bookId: bookId, pageNumber: pageNumber);
  }

  /// Recognize one or more visible pages (e.g. double-page spread).
  ///
  /// Cached pages (session + disk) are reused unless [forceRefresh] is true.
  /// Display-image export is only used for pages that still need OCR.
  Future<List<({int page, OcrPageResult result})>> recognizePages({
    required Book book,
    required List<int> pageNumbers,
    String? languageHint,
    bool forceRefresh = false,
    Future<Uint8List?> Function(int pageNumber)? exportPage,
  }) async {
    if (book.id != bookId || pageNumbers.isEmpty) {
      return const [];
    }
    cancel();
    final generation = ++_generation;
    final token = TaskCancelToken();
    _token = token;
    final primaryPage = pageNumbers.first;
    state = OcrPageUiState(
      phase: OcrPagePhase.running,
      pageNumber: primaryPage,
      generation: generation,
    );

    final completed = <({int page, OcrPageResult result})>[];
    try {
      final useCase = ref.read(ocrCurrentPageUseCaseProvider);
      for (final pageNumber in pageNumbers) {
        token.throwIfCancelled();
        if (generation != _generation) {
          return const [];
        }
        state = OcrPageUiState(
          phase: OcrPagePhase.running,
          pageNumber: pageNumber,
          generation: generation,
        );
        // Prefer cache/disk first so returning to a recognized page is free.
        if (!forceRefresh) {
          final cached = await useCase.peekCachedPage(
            bookId: book.id,
            pageNumber: pageNumber,
          );
          if (cached != null) {
            if (generation != _generation) {
              return const [];
            }
            completed.add((page: pageNumber, result: cached));
            continue;
          }
        }
        final displayBytes = exportPage == null
            ? null
            : await exportPage(pageNumber);
        token.throwIfCancelled();
        final result = await useCase.recognizeCurrentPage(
          book: book,
          pageNumber: pageNumber,
          languageHint: languageHint,
          cancelToken: token,
          forceRefresh: forceRefresh,
          displayImageBytes: displayBytes,
        );
        if (generation != _generation) {
          return const [];
        }
        completed.add((page: pageNumber, result: result));
      }
      if (generation != _generation) {
        return const [];
      }
      state = OcrPageUiState(
        phase: OcrPagePhase.success,
        pageNumber: completed.last.page,
        result: completed.last.result,
        generation: generation,
      );
      return completed;
    } on TaskCancelledException {
      if (generation != _generation) {
        return const [];
      }
      state = OcrPageUiState(
        phase: OcrPagePhase.idle,
        pageNumber: primaryPage,
        generation: generation,
      );
      return const [];
    } catch (error) {
      if (generation != _generation) {
        return const [];
      }
      state = OcrPageUiState(
        phase: OcrPagePhase.error,
        pageNumber: primaryPage,
        errorMessage: _readable(error),
        generation: generation,
      );
      // Return partial successes if any page finished before the failure.
      return completed;
    } finally {
      if (identical(_token, token)) {
        _token = null;
      }
    }
  }

  void cancel() {
    _token?.cancel();
    _token = null;
    _generation += 1;
    if (state.isRunning) {
      state = state.copyWith(
        phase: OcrPagePhase.idle,
        clearError: true,
        generation: _generation,
      );
    }
  }

  void clearResult() {
    state = state.copyWith(
      phase: OcrPagePhase.idle,
      clearResult: true,
      clearError: true,
    );
  }

  String _readable(Object error) {
    if (error is OcrEmptyResultException ||
        error is OcrUnavailableException ||
        error is OcrFailedException) {
      return error.toString();
    }
    return '文本识别失败';
  }
}
