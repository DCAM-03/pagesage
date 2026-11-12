import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/features/settings/application/ai_settings_providers.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  setUpAll(() async {
    if (captureWorkbench) await loadWorkbenchCaptureFonts();
  });

  Future<void> pumpAiSettings(
    WidgetTester tester,
    _RecordingAiSettingsRepository repository, {
    double width = 1280,
    double height = 900,
    double textScale = 1,
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith(
            (ref) => throw StateError('AI form tests must not open a database'),
          ),
          settingsRepositoryProvider.overrideWithValue(
            const _FakeSettingsRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(repository),
          aiProfilesProvider.overrideWith((ref) => Stream.value(const [])),
          aiSettingsControllerProvider.overrideWith(
            (ref) => AiSettingsController(repository),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: workbenchCaptureKey, child: child!),
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
  }

  testWidgets('disabling AI persists immediately', (tester) async {
    final repository = _RecordingAiSettingsRepository(
      const AiSettings(
        enabled: true,
        baseUrl: 'https://api.example.com/v1',
        model: 'test-model',
        hasApiKey: true,
      ),
    );
    await pumpAiSettings(tester, repository);

    final enabledTile = find.widgetWithText(SwitchListTile, '启用联网 AI');
    await tester.tap(enabledTile);
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.enabled, isFalse);
    expect(repository.saved.single.streaming, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending save blocks repeated submissions', (tester) async {
    final gate = Completer<void>();
    final repository = _RecordingAiSettingsRepository(
      const AiSettings(
        enabled: true,
        baseUrl: 'https://api.example.com/v1',
        model: 'test-model',
        hasApiKey: true,
      ),
    )..saveGate = gate;
    await pumpAiSettings(tester, repository);
    final model = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'test-model',
    );
    await tester.ensureVisible(model);
    await tester.enterText(model, 'updated-model');
    await tester.ensureVisible(find.text('保存 AI 设置'));
    await tester.pump();
    final save = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '保存 AI 设置'))
        .onPressed;
    expect(save, isNotNull);
    save!();
    save();
    await tester.pump();
    final submissions = repository.saved.length;
    gate.complete();
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(tester.takeException(), isNull);
  });

  test('setEnabled preserves persisted values from unsaved controls', () async {
    final repository = _RecordingAiSettingsRepository(
      const AiSettings(
        enabled: true,
        baseUrl: 'https://api.example.com/v1',
        model: 'test-model',
        streaming: true,
        hasApiKey: true,
      ),
    );
    final controller = AiSettingsController(repository);

    await controller.setEnabled(false);

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.enabled, isFalse);
    expect(repository.saved.single.streaming, isTrue);
  });

  testWidgets('invalid generation parameters block saving', (tester) async {
    final repository = _RecordingAiSettingsRepository(
      const AiSettings(
        enabled: true,
        baseUrl: 'https://api.example.com/v1',
        model: 'test-model',
        hasApiKey: true,
      ),
    );
    await pumpAiSettings(tester, repository);
    final advanced = find.text('高级设置');
    await tester.scrollUntilVisible(
      advanced,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();

    final temperatureField = find.byKey(const ValueKey('ai-temperature'));
    expect(tester.widget<TextField>(temperatureField).controller?.text, '0.2');

    await tester.ensureVisible(temperatureField);
    await tester.enterText(temperatureField, 'abc');
    await tester.pump();
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(temperatureField, findsNothing);
    await tester.ensureVisible(find.text('保存 AI 设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存 AI 设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(temperatureField);
    await tester.pumpAndSettle();

    expect(find.text('请输入 0 到 2 之间的数字'), findsOneWidget);
    expect(repository.saved, isEmpty);

    await tester.enterText(temperatureField, '3');
    await tester.pump();
    await tester.ensureVisible(find.text('保存 AI 设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存 AI 设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(temperatureField);
    await tester.pumpAndSettle();

    expect(find.text('范围应为 0 到 2'), findsOneWidget);
    expect(repository.saved, isEmpty);

    await tester.enterText(temperatureField, '0.5');
    await tester.pump();
    await tester.ensureVisible(find.text('保存 AI 设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存 AI 设置'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.temperature, 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching categories retains the unsaved model and replacement key',
    (tester) async {
      final repository = _RecordingAiSettingsRepository(_configured);
      await pumpAiSettings(tester, repository);
      final model = find.byKey(const ValueKey('ai-model'));
      final keyField = find.byKey(const ValueKey('ai-api-key'));
      await tester.ensureVisible(model);
      await tester.enterText(model, 'draft-model');
      await tester.ensureVisible(keyField);
      await tester.enterText(keyField, 'test-unsaved-key');
      await tester.tap(find.text('阅读').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI').first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(model).controller?.text, 'draft-model');
      expect(
        tester.widget<TextField>(keyField).controller?.text,
        'test-unsaved-key',
      );
      expect(tester.widget<TextField>(keyField).obscureText, isTrue);
      expect(find.text('有未保存的更改'), findsOneWidget);
      expect(repository.saved, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving survives a category switch and keeps the form disabled', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _RecordingAiSettingsRepository(_configured)
      ..saveGate = gate;
    await pumpAiSettings(tester, repository);
    final model = find.byKey(const ValueKey('ai-model'));
    await tester.ensureVisible(model);
    await tester.enterText(model, 'updated-model');
    final button = find.widgetWithText(FilledButton, '保存 AI 设置');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(repository.saved, hasLength(1));
    await tester.tap(find.text('阅读').first);
    await tester.pump();
    await tester.tap(find.text('AI').first);
    await tester.pump();
    expect(tester.widget<TextField>(model).enabled, isFalse);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('AI 设置已保存'), findsOneWidget);
    expect(tester.widget<TextField>(model).controller?.text, 'updated-model');
    expect(tester.takeException(), isNull);
  });

  testWidgets('save failures are inline, preserve input and support retry', (
    tester,
  ) async {
    final repository = _RecordingAiSettingsRepository(_configured)
      ..failSave = true;
    await pumpAiSettings(tester, repository);
    final model = find.byKey(const ValueKey('ai-model'));
    await tester.ensureVisible(model);
    await tester.enterText(model, 'draft-model');
    final save = find.widgetWithText(FilledButton, '保存 AI 设置');
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('AI 设置保存失败，输入已保留，请重试'), findsOneWidget);
    expect(tester.widget<TextField>(model).controller?.text, 'draft-model');
    repository.failSave = false;
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('AI 设置已保存'), findsOneWidget);
    expect(repository.saved.last.model, 'draft-model');
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (width: 1440.0, height: 960.0, scale: 1.0),
    (width: 900.0, height: 800.0, scale: 1.5),
    (width: 390.0, height: 780.0, scale: 1.5),
    (width: 390.0, height: 640.0, scale: 2.0),
  ]) {
    testWidgets('AI settings layout fits $scenario', (tester) async {
      final repository = _RecordingAiSettingsRepository(_configured);
      await pumpAiSettings(
        tester,
        repository,
        width: scenario.width,
        height: scenario.height,
        textScale: scenario.scale,
        dark: scenario.scale > 1,
      );
      await captureWorkbenchWidget(
        tester,
        'ai-settings-${scenario.width.round()}-${scenario.scale}',
      );
      final save = find.widgetWithText(FilledButton, '保存 AI 设置');
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await captureWorkbenchWidget(
        tester,
        'ai-settings-actions-${scenario.width.round()}-${scenario.scale}',
      );
      final advanced = find.text('高级设置');
      await tester.ensureVisible(advanced);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      final temperature = find.byKey(const ValueKey('ai-temperature'));
      await tester.ensureVisible(temperature);
      await tester.pumpAndSettle();
      await captureWorkbenchWidget(
        tester,
        'ai-settings-advanced-${scenario.width.round()}-${scenario.scale}',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact settings retain drafts when returning to the list', (
    tester,
  ) async {
    final repository = _RecordingAiSettingsRepository(_configured);
    await pumpAiSettings(tester, repository, width: 390, height: 780);
    final model = find.byKey(const ValueKey('ai-model'));
    await tester.ensureVisible(model);
    await tester.enterText(model, 'compact-draft');
    final back = find.byTooltip('返回设置');
    await tester.scrollUntilVisible(
      back,
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(model).controller?.text, 'compact-draft');
    expect(repository.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI settings show unconfigured, busy and failed states', (
    tester,
  ) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final repository = _RecordingAiSettingsRepository(
      const AiSettings(enabled: true),
    )..saveGate = gate;
    await pumpAiSettings(tester, repository);
    await captureWorkbenchWidget(tester, 'ai-settings-unconfigured');
    final baseUrl = find.byKey(const ValueKey('ai-base-url'));
    await tester.ensureVisible(baseUrl);
    await tester.enterText(baseUrl, 'https://api.example.com/v1');
    final model = find.byKey(const ValueKey('ai-model'));
    await tester.ensureVisible(model);
    await tester.enterText(model, 'draft-model');
    final save = find.widgetWithText(FilledButton, '保存 AI 设置');
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(find.text('有未保存的更改'), findsOneWidget);
    await captureWorkbenchWidget(tester, 'ai-settings-unsaved');
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<TextField>(model).enabled, isFalse);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await captureWorkbenchWidget(tester, 'ai-settings-saving');
    repository.failSave = true;
    gate.complete();
    await tester.pumpAndSettle();
    final failure = find.text('AI 设置保存失败，输入已保留，请重试');
    await tester.ensureVisible(failure);
    await tester.pumpAndSettle();
    expect(failure, findsOneWidget);
    await captureWorkbenchWidget(tester, 'ai-settings-failed');
    await tester.ensureVisible(find.text('启用联网 AI'));
    await tester.pumpAndSettle();
    repository.failSave = false;
    await tester.tap(find.widgetWithText(SwitchListTile, '启用联网 AI'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(model).enabled, isTrue);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '保存并测试'))
          .onPressed,
      isNull,
    );
    await captureWorkbenchWidget(tester, 'ai-settings-disabled');
    expect(tester.takeException(), isNull);
  });
}

const _configured = AiSettings(
  enabled: true,
  baseUrl: 'https://api.example.com/v1',
  model: 'test-model',
  hasApiKey: true,
);

final class _FakeSettingsRepository implements SettingsRepository {
  const _FakeSettingsRepository();

  @override
  Future<ReaderSettings> getReaderSettings() async => const ReaderSettings();

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {}

  @override
  Stream<ReaderSettings> watchReaderSettings() {
    return Stream.value(const ReaderSettings());
  }
}

final class _RecordingAiSettingsRepository implements AiSettingsRepository {
  _RecordingAiSettingsRepository(this._settings);

  AiSettings _settings;
  final List<AiSettings> saved = [];
  Completer<void>? saveGate;
  bool failSave = false;

  @override
  Future<void> clearApiKey() async {
    _settings = _settings.copyWith(hasApiKey: false);
  }

  @override
  Future<AiSettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {
    saved.add(settings);
    await saveGate?.future;
    if (failSave) throw StateError('test save failure');
    _settings = settings.copyWith(
      hasApiKey: _settings.hasApiKey || (apiKey?.isNotEmpty ?? false),
    );
  }

  @override
  Stream<AiSettings> watchSettings() => Stream.value(_settings);
}
