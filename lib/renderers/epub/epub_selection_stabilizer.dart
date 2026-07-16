import 'dart:async';

import 'package:flutter/foundation.dart';

final class EpubSelectionStabilizer<T> {
  EpubSelectionStabilizer({
    required this.onSettled,
    this.delay = const Duration(milliseconds: 260),
  });

  final Duration delay;
  final ValueChanged<T> onSettled;

  Timer? _timer;
  T? _latest;

  void schedule(T selection) {
    _latest = selection;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final latest = _latest;
      if (latest == null) {
        return;
      }
      onSettled(latest);
    });
  }

  void cancel() {
    _latest = null;
    _timer?.cancel();
    _timer = null;
  }
}
