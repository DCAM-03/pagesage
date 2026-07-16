import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef DroppedFilesHandler = FutureOr<void> Function(List<String> paths);

final class WindowDropImportService {
  WindowDropImportService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pagesage/window_drop');

  final MethodChannel _channel;
  DroppedFilesHandler? _handler;

  void start(DroppedFilesHandler handler) {
    if (!Platform.isWindows) {
      return;
    }
    _handler = handler;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  void stop() {
    if (!Platform.isWindows) {
      return;
    }
    _handler = null;
    _channel.setMethodCallHandler(null);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'filesDropped') {
      return;
    }
    final arguments = call.arguments;
    if (arguments is! List) {
      return;
    }
    final paths = arguments
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) {
      return;
    }
    await _handler?.call(paths);
  }
}
