import 'dart:async';
import 'dart:collection';

final class TaskQueue {
  TaskQueue({this.maxConcurrent = 1}) {
    if (maxConcurrent < 1) {
      throw ArgumentError.value(maxConcurrent, 'maxConcurrent', 'must be >= 1');
    }
  }

  final int maxConcurrent;
  final Queue<_QueuedTask<Object?>> _queue = Queue<_QueuedTask<Object?>>();
  int _running = 0;

  int get pendingCount => _queue.length;

  int get runningCount => _running;

  bool get isIdle => _running == 0 && _queue.isEmpty;

  Future<T> enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue.add(
      _QueuedTask<T>(action: action, completer: completer)
          as _QueuedTask<Object?>,
    );
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      _running += 1;
      Future<void>(() async {
        try {
          final result = await task.action();
          task.completer.complete(result);
        } on Object catch (error, stackTrace) {
          task.completer.completeError(error, stackTrace);
        } finally {
          _running -= 1;
          _drain();
        }
      });
    }
  }
}

final class _QueuedTask<T> {
  const _QueuedTask({required this.action, required this.completer});

  final Future<T> Function() action;
  final Completer<T> completer;
}
