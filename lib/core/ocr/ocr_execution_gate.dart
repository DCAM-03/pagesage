import 'dart:async';

import '../tasks/task_cancellation.dart';

/// Serializes OCR work across interactive pages and durable range jobs.
final class OcrExecutionGate {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>({
    required Future<T> Function() operation,
    TaskCancelToken? cancelToken,
  }) async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    var releaseWhenPreviousCompletes = false;
    try {
      if (cancelToken == null) {
        await previous;
      } else {
        final acquired = await Future.any<bool>([
          previous.then((_) => true),
          cancelToken.whenCancelled.then((_) => false),
        ]);
        if (!acquired) {
          releaseWhenPreviousCompletes = true;
          unawaited(previous.then((_) => released.complete()));
          cancelToken.throwIfCancelled();
        }
      }
      cancelToken?.throwIfCancelled();
      return await operation();
    } finally {
      if (!releaseWhenPreviousCompletes) released.complete();
    }
  }
}
