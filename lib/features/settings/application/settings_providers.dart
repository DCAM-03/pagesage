import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/settings_repository.dart';

final readerSettingsProvider = StreamProvider<ReaderSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchReaderSettings();
});

final readerSettingsControllerProvider = Provider<ReaderSettingsController>((
  ref,
) {
  final controller = ReaderSettingsController(
    ref.watch(settingsRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

enum ReaderSettingsSavePhase { idle, waiting, saving, saved, failed }

final readerSettingsSavePhaseProvider = StreamProvider<ReaderSettingsSavePhase>(
  (ref) => ref.watch(readerSettingsControllerProvider).watchSavePhase(),
);

final class ReaderSettingsController {
  ReaderSettingsController(this._repository);

  final SettingsRepository _repository;
  final _changes = StreamController<ReaderSettingsSavePhase>.broadcast();
  final List<Completer<void>> _waiting = [];
  Timer? _debounceTimer;
  ReaderSettings? _pendingSettings;
  ReaderSettings? _failedSettings;
  ReaderSettings? _savingSettings;
  Future<void>? _writing;
  bool _disposed = false;
  ReaderSettingsSavePhase _phase = ReaderSettingsSavePhase.idle;

  ReaderSettingsSavePhase get phase => _phase;
  ReaderSettings? get unsavedSettings =>
      _pendingSettings ?? _failedSettings ?? _savingSettings;

  Stream<ReaderSettingsSavePhase> watchSavePhase() =>
      Stream<ReaderSettingsSavePhase>.multi((controller) {
        final subscription = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
        controller.add(_phase);
      });

  Future<void> save(ReaderSettings settings) {
    if (_disposed) {
      return Future.error(StateError('Settings controller closed'));
    }
    _debounceTimer?.cancel();
    _pendingSettings = settings;
    _failedSettings = null;
    final completion = Completer<void>();
    _waiting.add(completion);
    _setPhase(ReaderSettingsSavePhase.waiting);
    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(flush()),
    );
    return completion.future;
  }

  Future<void> saveNow(ReaderSettings settings) {
    final completion = save(settings);
    unawaited(flush());
    return completion;
  }

  Future<void> retry() {
    final settings = _failedSettings;
    return settings == null ? Future.value() : saveNow(settings);
  }

  Future<void> flush() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final writing = _writing;
    if (writing != null) {
      return writing.then((_) {
        if (_pendingSettings != null) return flush();
      });
    }
    return _writing ??= _drain().whenComplete(() => _writing = null);
  }

  Future<void> _drain() async {
    while (_pendingSettings != null && _debounceTimer == null) {
      final settings = _pendingSettings!;
      final completions = List<Completer<void>>.of(_waiting);
      _waiting.clear();
      _pendingSettings = null;
      _savingSettings = settings;
      _setPhase(ReaderSettingsSavePhase.saving);
      try {
        await _repository.saveReaderSettings(settings);
        if (_pendingSettings == null) {
          _failedSettings = null;
          _setPhase(ReaderSettingsSavePhase.saved);
        }
      } catch (_) {
        if (_pendingSettings == null) {
          _failedSettings = settings;
          _setPhase(ReaderSettingsSavePhase.failed);
        }
      } finally {
        _savingSettings = null;
        for (final completion in completions) {
          completion.complete();
        }
      }
    }
  }

  void _setPhase(ReaderSettingsSavePhase phase) {
    _phase = phase;
    if (!_changes.isClosed) _changes.add(phase);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(flush().whenComplete(_changes.close));
  }
}
