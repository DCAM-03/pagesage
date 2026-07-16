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

final class ReaderSettingsController {
  ReaderSettingsController(this._repository);

  final SettingsRepository _repository;
  Timer? _debounceTimer;
  ReaderSettings? _pendingSettings;

  Future<void> save(ReaderSettings settings) {
    _debounceTimer?.cancel();
    _pendingSettings = settings;
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      final pending = _pendingSettings;
      _pendingSettings = null;
      if (pending != null) {
        unawaited(_repository.saveReaderSettings(pending));
      }
    });
    return Future.value();
  }

  Future<void> saveNow(ReaderSettings settings) {
    _debounceTimer?.cancel();
    _pendingSettings = null;
    return _repository.saveReaderSettings(settings);
  }

  void dispose() {
    _debounceTimer?.cancel();
    final pending = _pendingSettings;
    _pendingSettings = null;
    if (pending != null) {
      unawaited(_repository.saveReaderSettings(pending));
    }
  }
}
