import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef DroppedFilesHandler = FutureOr<void> Function(List<String> paths);

final class WindowDropImportService {
  WindowDropImportService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pagesage/window_drop');

  final MethodChannel _channel;
  DroppedFilesHandler? _handler;
  final _dragging = ValueNotifier(false);

  bool get isSupported => Platform.isLinux || Platform.isWindows;

  ValueListenable<bool> get dragging => _dragging;

  void start(DroppedFilesHandler handler) {
    if (!isSupported) {
      return;
    }
    _handler = handler;
    _channel.setMethodCallHandler(_handleMethodCall);
    unawaited(_setEnabled(true));
  }

  void stop() {
    if (!isSupported) {
      return;
    }
    _handler = null;
    _dragging.value = false;
    _channel.setMethodCallHandler(null);
    unawaited(_setEnabled(false));
  }

  void dispose() {
    stop();
    _dragging.dispose();
  }

  Future<void> _setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (_handler == null) {
      return;
    }
    if (call.method == 'dragEntered') {
      _dragging.value = true;
      return;
    }
    if (call.method == 'dragExited') {
      _dragging.value = false;
      return;
    }
    if (call.method != 'filesDropped') {
      return;
    }
    _dragging.value = false;
    final arguments = call.arguments;
    if (arguments is! List) {
      return;
    }
    final paths = arguments
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (paths.isEmpty) {
      return;
    }
    await _handler?.call(paths);
  }
}
