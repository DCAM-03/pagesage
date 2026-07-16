import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/app/widgets/app_chrome.dart';

void main() {
  testWidgets('AppPageHeader stacks actions on narrow large-text screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: AppPageHeader(
              title: '这是一个非常长的页面标题用于验证窄屏不会横向溢出',
              subtitle: '很长的副标题也应该最多两行并正常省略',
              actions: [
                IconButton(
                  tooltip: '搜索',
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: '导入',
                  onPressed: () {},
                  icon: const Icon(Icons.upload_file),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
  });
}
