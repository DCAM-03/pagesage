import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reader_fonts.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/features/reader/presentation/reader_settings_sheet.dart';
import 'package:pagesage/features/settings/application/settings_providers.dart';
import 'package:pagesage/features/settings/presentation/reader_font_picker.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  setUpAll(() async {
    if (captureWorkbench) await loadWorkbenchCaptureFonts();
  });

  Future<GlobalKey<NavigatorState>> pumpSettings(
    WidgetTester tester,
    _SettingsRepository repository, {
    double width = 1440,
    double textScale = 1,
    bool sheet = false,
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 960);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.dispose();
    });
    final navigatorKey = GlobalKey<NavigatorState>();
    final theme = dark ? AppTheme.dark() : AppTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _AiSettingsRepository(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: captureWorkbench
              ? theme.copyWith(
                  chipTheme: theme.chipTheme.copyWith(
                    labelStyle: theme.chipTheme.labelStyle?.copyWith(
                      fontFamily: 'Segoe UI',
                    ),
                    secondaryLabelStyle: theme.chipTheme.secondaryLabelStyle
                        ?.copyWith(fontFamily: 'Segoe UI'),
                  ),
                )
              : theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: workbenchCaptureKey, child: child!),
          ),
          home: sheet
              ? Scaffold(
                  body: ReaderSettingsSheet(
                    initialSettings: repository.settings,
                  ),
                )
              : const SettingsPage(),
        ),
      ),
    );
    if (repository.initiallyLoading) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
    return navigatorKey;
  }

  Future<void> tapFont(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await showControl(tester, chip);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('failed reading save is visible and retries the retained value', (
    tester,
  ) async {
    final repository = _SettingsRepository(const ReaderSettings())
      ..failSave = true;
    await pumpSettings(tester, repository, sheet: true);
    await tapFont(tester, '霞鹜文楷');
    await tester.ensureVisible(find.text('重试保存'));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置未保存，修改已保留'), findsOneWidget);
    expect(repository.saved, isEmpty);
    await captureWorkbenchWidget(tester, 'reader-settings-save-failed');
    repository.failSave = false;
    await tester.tap(find.text('重试保存'));
    await tester.pumpAndSettle();
    expect(repository.settings.fontFamily, ReaderFonts.wenKai.id);
    expect(find.text('阅读设置已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings font choices save and update the reading summary', (
    tester,
  ) async {
    final repository = _SettingsRepository(
      const ReaderSettings(
        fontSize: 22,
        readerMode: ReaderMode.paged,
        themePreset: ReaderThemePreset.green,
        desktopContextTab: ReaderContextTab.ai,
      ),
    );
    await pumpSettings(tester, repository);
    await tapFont(tester, '霞鹜文楷');

    expect(repository.saved, hasLength(1));
    expect(repository.settings.fontFamily, ReaderFonts.wenKai.id);
    expect(repository.settings.desktopContextTab, ReaderContextTab.ai);
    expect(find.text('22 px · 分页 · 护眼\n霞鹜文楷'), findsOneWidget);
    await tapFont(tester, '霞鹜文楷');
    expect(repository.saved, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy custom fonts stay selected until explicitly applied', (
    tester,
  ) async {
    final repository = _SettingsRepository(
      const ReaderSettings(fontFamily: 'Noto Serif CJK SC'),
    );
    await pumpSettings(tester, repository, sheet: true);
    expect(find.text('与设置页共用，对当前及后续打开的书籍生效。'), findsOneWidget);
    final field = find.widgetWithText(TextField, '自定义字体名称');
    await tester.ensureVisible(field);
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Noto Serif CJK SC',
    );
    expect(repository.saved, isEmpty);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '自定义'))
          .selected,
      isTrue,
    );
    await tester.enterText(field, '  Source Han Serif SC  ');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.saved, isEmpty);
    await tester.ensureVisible(find.text('应用字体'));
    await tester.tap(find.text('应用字体'));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(1));
    expect(repository.settings.fontFamily, 'Source Han Serif SC');

    await tester.enterText(field, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(2));
    expect(repository.settings.fontFamily, isEmpty);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '系统默认'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('both entry points reopen the same saved font', (tester) async {
    final repository = _SettingsRepository(const ReaderSettings());
    final navigator = await pumpSettings(tester, repository);
    await tapFont(tester, 'Atkinson');
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, child) => Scaffold(
            body: ReaderSettingsSheet(
              initialSettings: ref.watch(readerSettingsProvider).requireValue,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Atkinson'))
          .selected,
      isTrue,
    );
    await tapFont(tester, '自定义');
    final field = find.widgetWithText(TextField, '自定义字体名称');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Noto Serif CJK SC');
    await tester.ensureVisible(find.text('应用字体'));
    await tester.tap(find.text('应用字体'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('18 px · 连续滚动 · 白昼\nNoto Serif CJK SC'), findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Noto Serif CJK SC',
    );
    expect(repository.saved, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact category summary reacts to settings updates', (
    tester,
  ) async {
    final repository = _SettingsRepository(const ReaderSettings());
    await pumpSettings(tester, repository, width: 390);
    expect(find.text('18 px · 连续滚动 · 白昼\n系统默认'), findsOneWidget);
    repository.publish(
      const ReaderSettings(
        fontFamily: 'LXGW WenKai Lite',
        fontSize: 24,
        readerMode: ReaderMode.paged,
        themePreset: ReaderThemePreset.paper,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('24 px · 分页 · 纸张\n霞鹜文楷'), findsOneWidget);
    await tester.tap(find.text('阅读'));
    await tester.pumpAndSettle();
    await tapFont(tester, '系统默认');
    await showControl(tester, find.byTooltip('返回设置'), delta: -300);
    await tester.tap(find.byTooltip('返回设置'));
    await tester.pumpAndSettle();
    expect(find.text('24 px · 分页 · 纸张\n系统默认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom draft survives changes to other reading controls', (
    tester,
  ) async {
    final repository = _SettingsRepository(const ReaderSettings());
    await pumpSettings(tester, repository);
    await tapFont(tester, '自定义');
    final field = find.widgetWithText(TextField, '自定义字体名称');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Unapplied font');
    final theme = find.widgetWithText(ChoiceChip, '纸张');
    await tester.ensureVisible(theme);
    await tester.tap(theme);
    await tester.pumpAndSettle();
    expect(repository.settings.fontFamily, isEmpty);
    await tester.ensureVisible(field);
    expect(tester.widget<TextField>(field).controller?.text, 'Unapplied font');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading summary distinguishes loading from defaults', (
    tester,
  ) async {
    final repository = _SettingsRepository(
      const ReaderSettings(),
      initiallyLoading: true,
    );
    await pumpSettings(tester, repository, width: 390);
    expect(find.text('正在读取阅读配置…'), findsOneWidget);
    expect(find.text('18 px · 连续滚动 · 白昼\n系统默认'), findsNothing);
    repository.publish(const ReaderSettings());
    await tester.pumpAndSettle();
    expect(find.text('正在读取阅读配置…'), findsNothing);
    expect(find.text('18 px · 连续滚动 · 白昼\n系统默认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading summary reports a settings read failure', (
    tester,
  ) async {
    final repository = _SettingsRepository(const ReaderSettings());
    await pumpSettings(tester, repository, width: 390);
    repository.fail();
    await tester.pumpAndSettle();
    expect(find.text('无法读取阅读配置'), findsOneWidget);
    expect(find.text('18 px · 连续滚动 · 白昼\n系统默认'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (width: 1440.0, scale: 1.0, sheet: false),
    (width: 1440.0, scale: 2.0, sheet: false),
    (width: 900.0, scale: 1.5, sheet: false),
    (width: 390.0, scale: 2.0, sheet: false),
    (width: 360.0, scale: 1.5, sheet: true),
    (width: 420.0, scale: 2.0, sheet: true),
  ]) {
    testWidgets('reading settings fit $scenario', (tester) async {
      final repository = _SettingsRepository(
        const ReaderSettings(
          fontFamily: 'Noto Serif CJK SC Extra Long Custom Family Name',
        ),
      );
      await pumpSettings(
        tester,
        repository,
        width: scenario.width,
        textScale: scenario.scale,
        sheet: scenario.sheet,
        dark: scenario.scale == 2,
      );
      await captureWorkbenchWidget(
        tester,
        'reading-settings-${scenario.width.round()}-${scenario.scale}-${scenario.sheet}',
      );
      expect(tester.takeException(), isNull);
      if (scenario.width == 390) {
        await tester.tap(find.text('阅读'));
        await tester.pumpAndSettle();
      }
      final font = find.byType(ReaderFontPicker);
      await showControl(tester, font);
      await tester.pumpAndSettle();
      await captureWorkbenchWidget(
        tester,
        'reading-settings-font-${scenario.width.round()}-${scenario.scale}',
      );
      expect(tester.takeException(), isNull);
      await showControl(
        tester,
        find.byType(SegmentedButton<ReaderMode>),
        delta: scenario.sheet ? -250 : 250,
      );
      expect(tester.takeException(), isNull);
      expect(repository.saved, isEmpty);
    });
  }
}

Future<void> showControl(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

final class _SettingsRepository implements SettingsRepository {
  _SettingsRepository(this.settings, {this.initiallyLoading = false});

  ReaderSettings settings;
  final bool initiallyLoading;
  bool failSave = false;
  final saved = <ReaderSettings>[];
  final _changes = StreamController<ReaderSettings>.broadcast();

  void publish(ReaderSettings settings) {
    this.settings = settings;
    _changes.add(settings);
  }

  void fail() {
    _changes.addError(StateError('Settings unavailable'));
  }

  @override
  Future<ReaderSettings> getReaderSettings() async => settings;

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {
    if (failSave) throw StateError('injected save failure');
    saved.add(settings);
    publish(settings);
  }

  @override
  Stream<ReaderSettings> watchReaderSettings() async* {
    if (!initiallyLoading) yield settings;
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();
}

final class _AiSettingsRepository implements AiSettingsRepository {
  const _AiSettingsRepository();

  @override
  Future<AiSettings> getSettings() async => const AiSettings();

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Future<void> clearApiKey() async {}

  @override
  Stream<AiSettings> watchSettings() => Stream.value(const AiSettings());
}
