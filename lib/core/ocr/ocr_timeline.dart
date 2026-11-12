import 'dart:developer' as developer;

/// Records OCR stages in the Dart timeline without logging book content.
///
/// Timeline events are visible in DevTools while profiling. They are cheap when
/// tracing is disabled and deliberately contain only sizes, paths and timing
/// metadata.
Future<T> traceOcrAsync<T>(
  String name,
  Future<T> Function() action, {
  Map<String, Object?>? arguments,
}) async {
  final task = developer.TimelineTask();
  task.start(name, arguments: arguments);
  try {
    return await action();
  } finally {
    task.finish();
  }
}

T traceOcrSync<T>(
  String name,
  T Function() action, {
  Map<String, Object?>? arguments,
}) {
  final task = developer.TimelineTask();
  task.start(name, arguments: arguments);
  try {
    return action();
  } finally {
    task.finish();
  }
}
