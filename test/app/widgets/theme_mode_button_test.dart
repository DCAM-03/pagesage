import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/app/widgets/app_chrome.dart';
import 'package:pagesage/app/widgets/theme_mode_button.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/settings_repository.dart';

void main() {
  testWidgets('the header icon cycles through all three modes', (tester) async {
    final settings = _RecordingSettingsRepository(const ReaderSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings,
        const MediaQuery(
          // Narrow enough that the sidebar is absent, which is exactly the
          // case the header copy exists for.
          data: MediaQueryData(size: Size(400, 720)),
          child: Scaffold(
            body: AppPageHeader(
              title: '书库',
              subtitle: '本地 EPUB/PDF 阅读库',
              showThemeMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The tooltip names the current mode, so the state is readable before any
    // click — and the icon changes with it.
    expect(find.byTooltip('外观：跟随系统'), findsOneWidget);
    expect(find.byIcon(Icons.contrast), findsOneWidget);

    await tester.tap(find.byTooltip('外观：跟随系统'));
    await tester.pumpAndSettle();
    expect(settings.saved.last.appThemeMode, ThemeMode.light);
    expect(find.byTooltip('外观：亮色'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('外观：亮色'));
    await tester.pumpAndSettle();
    expect(settings.saved.last.appThemeMode, ThemeMode.dark);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    // Back to the start: the cycle has no dead end.
    await tester.tap(find.byTooltip('外观：暗色'));
    await tester.pumpAndSettle();
    expect(settings.saved.last.appThemeMode, ThemeMode.system);
    expect(find.byTooltip('外观：跟随系统'), findsOneWidget);
  });

  testWidgets('the switch is absent where the command bar has it', (
    tester,
  ) async {
    final settings = _RecordingSettingsRepository(const ReaderSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings,
        const MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: Scaffold(
            body: AppPageHeader(title: '书库', showThemeMode: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('外观：跟随系统'), findsNothing);
  });

  testWidgets('the command bar keeps the switch in its tool group', (
    tester,
  ) async {
    final settings = _RecordingSettingsRepository(const ReaderSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings,
        Scaffold(
          body: AppCommandBar(onSearch: () {}, onImport: () {}, onTasks: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('外观：跟随系统'), findsOneWidget);
    // Beside 搜索 and 导入 rather than pushed to the far edge.
    final switchX = tester.getCenter(find.byTooltip('外观：跟随系统')).dx;
    final searchX = tester.getCenter(find.text('搜索')).dx;
    final importX = tester.getCenter(find.text('导入')).dx;
    expect(switchX, lessThan(searchX));
    expect(searchX, lessThan(importX));
  });

  testWidgets('the command bar can omit the import action', (tester) async {
    final settings = _RecordingSettingsRepository(const ReaderSettings());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings,
        Scaffold(
          body: AppCommandBar(
            onSearch: () {},
            onImport: () {},
            onTasks: () {},
            showImport: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('导入'), findsNothing);
    expect(find.byTooltip('导入 EPUB/PDF/Markdown'), findsNothing);
  });

  testWidgets('a header without the switch stays free of the settings store', (
    tester,
  ) async {
    // Detail pages pass `showThemeMode: false`; this asserts the default does
    // not pull the provider, which is what keeps those headers cheap and
    // pumpable without a repository.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AppPageHeader(title: '书')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ThemeModeMenuButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness(SettingsRepository settings, Widget home) {
  return ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    child: MaterialApp(theme: AppTheme.light(), home: home),
  );
}

final class _RecordingSettingsRepository implements SettingsRepository {
  _RecordingSettingsRepository(this._settings);

  ReaderSettings _settings;
  final saved = <ReaderSettings>[];
  final _controller = StreamController<ReaderSettings>.broadcast();

  @override
  Future<ReaderSettings> getReaderSettings() async => _settings;

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {
    _settings = settings;
    saved.add(settings);
    _controller.add(settings);
  }

  @override
  Stream<ReaderSettings> watchReaderSettings() async* {
    yield _settings;
    yield* _controller.stream;
  }

  void dispose() => _controller.close();
}
