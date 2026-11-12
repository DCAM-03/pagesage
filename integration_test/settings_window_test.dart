import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/domain/books/reader_fonts.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';

import 'support/reader_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'settings groups save reader choices without using real secrets',
    (tester) async {
      final harness = await ReaderHarness.create(books: []);
      final captureKey = GlobalKey();
      addTearDown(harness.dispose);
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(harness.database),
            secureStoreProvider.overrideWithValue(SecureStore.memory()),
          ],
          child: RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsPage(),
            ),
          ),
        ),
      );
      await harness.settle(tester, rounds: 12);
      final font = find.widgetWithText(ChoiceChip, '霞鹜文楷');
      await tester.ensureVisible(font);
      await tester.tap(font);
      await harness.settle(tester, rounds: 10);
      final persisted = await harness.database.settingsDao.getValue(
        'reader.settings',
      );
      expect(
        ReaderSettings.fromJsonText(persisted!).fontFamily,
        ReaderFonts.wenKai.id,
      );
      await harness.capture('settings-01-reader', boundaryKey: captureKey);
      for (final label in ['AI', '分类与标签', '隐私与数据', '关于', '阅读']) {
        await tester.tap(find.text(label).hitTestable().first);
        await harness.settle(tester, rounds: 6);
        expect(tester.takeException(), isNull);
        final contentScroll = Scrollable.of(
          tester.element(find.text(label).last),
        ).position;
        expect(contentScroll.pixels, 0, reason: '切换设置分组应从标题开始显示');
        if (label == 'AI') {
          await harness.capture('settings-02-ai', boundaryKey: captureKey);
        }
      }
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '霞鹜文楷'));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '霞鹜文楷'))
            .selected,
        isTrue,
      );
      await harness.closeReader(tester);
    },
  );
}
