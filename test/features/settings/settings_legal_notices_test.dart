import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/file_providers.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('about dialogs show current project and third-party terms', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('pagesage-legal-'),
    ))!;
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPathsProvider.overrideWithValue(AppPaths(overrideRoot: root)),
        secureStoreProvider.overrideWithValue(SecureStore.memory()),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('关于').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('开源许可说明'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('自有代码与文档采用 Apache License 2.0'),
        findsOneWidget,
      );
      expect(
        find.textContaining('archive 与 sqlite3 Dart 包使用 MIT'),
        findsOneWidget,
      );
      expect(find.textContaining('SIL Open Font License 1.1'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('隐私说明'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Markdown 文件夹按原路径只读访问'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(database.close);
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });
}
