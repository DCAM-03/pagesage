import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../renderers/markdown/markdown_folder_diff.dart';
import '../../../renderers/markdown/markdown_folder.dart';
import '../../../renderers/markdown/markdown_folder_snapshot.dart';

enum MarkdownFolderRefreshState { idle, scanning, ready, degraded, error }

final class MarkdownFolderRefreshEvent {
  const MarkdownFolderRefreshEvent({
    required this.state,
    required this.snapshot,
    required this.diff,
    required this.epoch,
    this.message,
  });

  final MarkdownFolderRefreshState state;
  final MarkdownFolderSnapshot snapshot;
  final MarkdownFolderDiff diff;
  final int epoch;
  final String? message;
}

final class MarkdownFolderRefreshCoordinator {
  MarkdownFolderRefreshCoordinator({
    required String rootPath,
    MarkdownFolderSnapshotLoader? loader,
    Duration debounce = const Duration(milliseconds: 400),
    Duration pollInterval = const Duration(seconds: 30),
    int maxWatchers = 256,
  }) : this._(
         rootPath,
         loader ?? MarkdownFolderSnapshotLoader(const MarkdownFolderLoader()),
         debounce,
         pollInterval,
         maxWatchers,
       );

  MarkdownFolderRefreshCoordinator._(
    this._rootPath,
    this._loader,
    this._debounce,
    this._pollInterval,
    this._maxWatchers,
  );

  final String _rootPath;
  final MarkdownFolderSnapshotLoader _loader;
  final Duration _debounce;
  final Duration _pollInterval;
  final int _maxWatchers;
  final StreamController<MarkdownFolderRefreshEvent> _events =
      StreamController<MarkdownFolderRefreshEvent>.broadcast();
  final List<StreamSubscription<FileSystemEvent>> _subscriptions = [];

  Timer? _debounceTimer;
  Timer? _pollTimer;
  MarkdownFolderSnapshot? _current;
  Future<void>? _reconcile;
  bool _dirty = false;
  bool _disposed = false;
  int _epoch = 0;

  Stream<MarkdownFolderRefreshEvent> get events => _events.stream;
  MarkdownFolderSnapshot? get current => _current;
  int get epoch => _epoch;

  Future<MarkdownFolderRefreshEvent> start() async {
    _registerWatchers();
    final event = await refresh(full: true);
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
    return event;
  }

  Future<MarkdownFolderRefreshEvent> refresh({bool full = false}) async {
    if (_disposed) {
      throw StateError('MarkdownFolderRefreshCoordinator is disposed');
    }
    final pending = _reconcile;
    if (pending != null) {
      _dirty = true;
      await pending;
      final last = _lastEvent;
      if (last != null) return last;
    }
    _epoch += 1;
    final requestedEpoch = _epoch;
    final future = _reconcileNow(full: full, previous: _current);
    _reconcile = future;
    try {
      await future;
      if (_dirty && requestedEpoch == _epoch) {
        _dirty = false;
        return refresh(full: full);
      }
      return _lastEvent!;
    } finally {
      if (identical(_reconcile, future)) _reconcile = null;
    }
  }

  Future<MarkdownFolderRefreshEvent> _reconcileNow({
    required bool full,
    required MarkdownFolderSnapshot? previous,
  }) async {
    final epoch = _epoch;
    _dirty = false;
    MarkdownFolderSnapshot next;
    MarkdownFolderRefreshState state = MarkdownFolderRefreshState.ready;
    String? message;
    try {
      next = await _loader.load(
        _rootPath,
        verification: full
            ? MarkdownFolderVerification.full
            : MarkdownFolderVerification.metadata,
        contentPaths: {
          if (!full)
            for (final change in _lastEvent?.diff.changes ?? const [])
              change.path,
        },
        previous: previous,
      );
    } on Object {
      state = MarkdownFolderRefreshState.error;
      message = '文件夹暂时不可读，已保留当前正文';
      next = _current ?? _emptySnapshot();
    }
    final diff = previous == null
        ? const MarkdownFolderDiff(changes: [], renameHints: {})
        : MarkdownFolderDiff.compute(
            previous,
            next,
          ).withMetadataOnlyChanges(previous, next);
    if (state == MarkdownFolderRefreshState.ready &&
        _subscriptions.length < _watchedDirectoryCount()) {
      state = MarkdownFolderRefreshState.degraded;
      message = '自动检测受限，定期检查中';
    }
    if (state == MarkdownFolderRefreshState.ready && !_registerWatchers()) {
      state = MarkdownFolderRefreshState.degraded;
      message = '自动检测受限，定期检查中';
    }
    _current = next;
    final event = MarkdownFolderRefreshEvent(
      state: state,
      snapshot: next,
      diff: diff,
      epoch: epoch,
      message: message,
    );
    _lastEvent = event;
    if (!_disposed && !_events.isClosed) _events.add(event);
    return event;
  }

  void _onWatchEvent(FileSystemEvent event) {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (_disposed) return;
      if (_reconcile != null) {
        _dirty = true;
        return;
      }
      unawaited(refresh());
    });
  }

  bool _registerWatchers() {
    var complete = true;
    final root = Directory(_rootPath);
    if (!root.existsSync()) return false;
    final directories = <Directory>[root];
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is Directory &&
            !p.basename(entity.path).startsWith('.') &&
            !p.split(entity.path).contains('node_modules')) {
          directories.add(entity);
        }
      }
    } on Object {
      complete = false;
    }
    if (directories.length > _maxWatchers) {
      directories.removeRange(_maxWatchers, directories.length);
      complete = false;
    }
    final known = _subscriptions.length;
    for (var index = known; index < directories.length; index += 1) {
      try {
        final stream = directories[index].watch();
        _subscriptions.add(
          stream.listen(
            _onWatchEvent,
            onError: (_) => _degrade(),
            onDone: _degrade,
          ),
        );
      } on Object {
        complete = false;
      }
    }
    return complete;
  }

  void _degrade() {
    if (_disposed) return;
    unawaited(refresh());
  }

  int _watchedDirectoryCount() {
    final root = Directory(_rootPath);
    if (!root.existsSync()) return 0;
    var count = 1;
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is Directory &&
            !p.basename(entity.path).startsWith('.') &&
            !p.split(entity.path).contains('node_modules')) {
          count += 1;
        }
      }
    } on Object {
      return count + 1;
    }
    return count;
  }

  MarkdownFolderSnapshot _emptySnapshot() {
    return MarkdownFolderSnapshot(
      manifest: MarkdownFolderManifest(
        rootPath: _rootPath,
        files: const [],
        roots: const [],
        totalBytes: 0,
      ),
      contentHashes: const {},
      observedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    final pending = _reconcile;
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // Reconciliation errors are reported as events, not thrown at disposal.
      }
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _events.close();
  }

  MarkdownFolderRefreshEvent? _lastEvent;
}
