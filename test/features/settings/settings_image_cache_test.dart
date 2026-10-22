import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/file_providers.dart';
import 'package:pagesage/core/files/image_cache_store.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pagesage-settings-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Pumps the settings page at a width that shows the side-panel layout.
  ///
  /// The width is forced through [MediaQuery] rather than
  /// `setSurfaceSize`: the test binding reports a fixed logical size that
  /// ignores the surface override, and the breakpoint reads MediaQuery.
  Future<void> pumpSettings(WidgetTester tester, CachedImageStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths(overrideRoot: tempDir)),
          imageCacheStoreProvider.overrideWithValue(store),
          settingsRepositoryProvider.overrideWithValue(
            const _FakeSettingsRepository(),
          ),
          aiSettingsRepositoryProvider.overrideWithValue(
            const _FakeAiSettingsRepository(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(size: Size(1280, 900)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the data section offers the image export and the cache clear', (
    tester,
  ) async {
    final store = CachedImageStore(appPaths: AppPaths(overrideRoot: tempDir));
    await pumpSettings(tester, store);

    await tester.tap(find.text('隐私与数据').last);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('导出图片批注'), findsOneWidget);
    expect(find.text('清理图片缓存'), findsOneWidget);
  });

  testWidgets('clearing the cache asks first', (tester) async {
    final store = CachedImageStore(appPaths: AppPaths(overrideRoot: tempDir));
    await pumpSettings(tester, store);
    await tester.tap(find.text('隐私与数据').last);
    await tester.pump(const Duration(milliseconds: 400));

    // The tile sits below the fold of the settings panel; scroll it into
    // view before tapping, or the tap lands on nothing.
    await tester.scrollUntilVisible(
      find.text('清理图片缓存'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('清理图片缓存'));
    await tester.pump(const Duration(milliseconds: 400));

    // Deleting files asks first. What the delete itself does is covered by
    // `image_cache_store_test.dart`: a widget test runs in a fake-async zone
    // where the real file I/O never settles.
    expect(find.text('清理图片缓存？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}

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

final class _FakeAiSettingsRepository implements AiSettingsRepository {
  const _FakeAiSettingsRepository();

  @override
  Future<AiSettings> getSettings() async => const AiSettings();

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Future<void> clearApiKey() async {}

  @override
  Stream<AiSettings> watchSettings() => Stream.value(const AiSettings());
}
