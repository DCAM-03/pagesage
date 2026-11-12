import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_settings_repository.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/features/settings/application/settings_providers.dart';

void main() {
  test('pending settings survive a file database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pagesage-settings-',
    );
    final file = File('${directory.path}/settings.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(file));
    final controller = ReaderSettingsController(
      DriftSettingsRepository(database.settingsDao),
    );
    final saved = controller.save(const ReaderSettings(fontSize: 28));
    controller.dispose();
    await saved;
    await controller.flush();
    await database.close();
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    try {
      expect(
        (await DriftSettingsRepository(
          reopened.settingsDao,
        ).getReaderSettings()).fontSize,
        28,
      );
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'an immediate save after an empty flush cannot lose its wakeup',
    () async {
      final repository = _Repository();
      final controller = ReaderSettingsController(repository);
      addTearDown(controller.dispose);
      final empty = controller.flush();
      final saving = controller.saveNow(const ReaderSettings(fontSize: 29));
      await Future.wait([empty, saving]).timeout(const Duration(seconds: 2));
      expect(repository.saved.single.fontSize, 29);
    },
  );

  test('debounce completes after the latest value is persisted', () async {
    final repository = _Repository();
    final controller = ReaderSettingsController(repository);
    addTearDown(controller.dispose);
    var completed = false;
    final first = controller.save(const ReaderSettings(fontSize: 18))
      ..then((_) => completed = true);
    final second = controller.save(const ReaderSettings(fontSize: 24));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    await controller.flush();
    await Future.wait([first, second]);
    expect(repository.saved.map((value) => value.fontSize), [24]);
    expect(controller.phase, ReaderSettingsSavePhase.saved);
  });

  test('immediate writes cannot overtake an earlier slow save', () async {
    final repository = _Repository()..gate = Completer<void>();
    final controller = ReaderSettingsController(repository);
    addTearDown(controller.dispose);
    final first = controller.saveNow(const ReaderSettings(fontSize: 18));
    final second = controller.saveNow(const ReaderSettings(fontSize: 26));
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 1);
    repository.gate!.complete();
    await Future.wait([first, second]);
    expect(repository.saved.map((value) => value.fontSize), [18, 26]);
  });

  test('write failure is observable and retry preserves the value', () async {
    final repository = _Repository()..fail = true;
    final controller = ReaderSettingsController(repository);
    addTearDown(controller.dispose);
    final phases = <ReaderSettingsSavePhase>[];
    final subscription = controller.watchSavePhase().listen(phases.add);
    addTearDown(subscription.cancel);
    await controller.saveNow(const ReaderSettings(fontSize: 25));
    await Future<void>.delayed(Duration.zero);
    expect(phases, contains(ReaderSettingsSavePhase.failed));
    repository.fail = false;
    await controller.retry();
    expect(repository.saved.single.fontSize, 25);
    expect(controller.phase, ReaderSettingsSavePhase.saved);
  });

  test('dispose flushes a queued value even with a write in flight', () async {
    final repository = _Repository()..gate = Completer<void>();
    final controller = ReaderSettingsController(repository);
    final first = controller.saveNow(const ReaderSettings(fontSize: 18));
    final last = controller.save(const ReaderSettings(fontSize: 27));
    controller.dispose();
    repository.gate!.complete();
    await Future.wait([first, last]);
    expect(repository.saved.last.fontSize, 27);
  });
}

class _Repository implements SettingsRepository {
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  final saved = <ReaderSettings>[];

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('test failure');
    saved.add(settings);
  }

  @override
  Future<ReaderSettings> getReaderSettings() async =>
      saved.lastOrNull ?? const ReaderSettings();

  @override
  Stream<ReaderSettings> watchReaderSettings() =>
      Stream.fromFuture(getReaderSettings());
}
