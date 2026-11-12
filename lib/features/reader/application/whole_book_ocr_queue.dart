import '../../../domain/ocr/ocr_jobs.dart';

final class WholeBookOcrQueue {
  bool _running = false;

  Future<int?> enqueue({
    required int totalPages,
    required Future<void> Function(List<int> pages) startBatch,
  }) async {
    if (_running) return null;
    if (totalPages < 1) throw ArgumentError.value(totalPages, 'totalPages');
    _running = true;
    var queued = 0;
    try {
      while (queued < totalPages) {
        final count = (totalPages - queued).clamp(
          0,
          OcrPageRange.maxPagesPerJob,
        );
        try {
          await startBatch(List.generate(count, (index) => queued + index + 1));
        } on Object catch (error, stackTrace) {
          Error.throwWithStackTrace(
            WholeBookOcrQueueException(queuedPages: queued, cause: error),
            stackTrace,
          );
        }
        queued += count;
      }
      return queued;
    } finally {
      _running = false;
    }
  }
}

final class WholeBookOcrQueueException implements Exception {
  const WholeBookOcrQueueException({
    required this.queuedPages,
    required this.cause,
  });

  final int queuedPages;
  final Object cause;
}
