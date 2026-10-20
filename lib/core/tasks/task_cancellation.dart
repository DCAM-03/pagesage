final class TaskCancelledException implements Exception {
  const TaskCancelledException([this.message = '任务已取消']);

  final String message;

  @override
  String toString() => message;
}

final class TaskCancelToken {
  bool _cancelled = false;
  final List<void Function()> _callbacks = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    final callbacks = List<void Function()>.of(_callbacks);
    _callbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void bind(void Function() callback) {
    if (_cancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw const TaskCancelledException();
    }
  }
}

final class TaskCancellationRegistry {
  final Map<String, TaskCancelToken> _tokens = {};
  final Set<String> _cancelledIds = {};

  TaskCancelToken register(String taskId) {
    final token = TaskCancelToken();
    if (_cancelledIds.remove(taskId)) {
      token.cancel();
    }
    _tokens[taskId] = token;
    return token;
  }

  bool cancel(String taskId) {
    final token = _tokens[taskId];
    _cancelledIds.add(taskId);
    token?.cancel();
    return token != null;
  }

  void complete(String taskId) {
    _tokens.remove(taskId);
    _cancelledIds.remove(taskId);
  }

  bool isCancelled(String taskId) {
    return _cancelledIds.contains(taskId) ||
        (_tokens[taskId]?.isCancelled ?? false);
  }

  /// Whether [taskId]'s work is running in this process right now.
  ///
  /// Startup recovery uses this to tell a task left over from a previous run
  /// (no token at all) from one this session is still executing. A task whose
  /// token was registered but then cancelled is not live either.
  bool isLive(String taskId) {
    final token = _tokens[taskId];
    return token != null && !token.isCancelled;
  }
}
