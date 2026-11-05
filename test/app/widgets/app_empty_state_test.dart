import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/widgets/app_chrome.dart';

void main() {
  testWidgets('AppEmptyState exposes a useful semantic summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.local_library_outlined,
            title: '还没有书籍',
            message: '导入 EPUB 或 PDF 后开始阅读。',
            action: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload_file),
              label: const Text('导入 EPUB/PDF/Markdown'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '空状态：还没有书籍。导入 EPUB 或 PDF 后开始阅读。',
      ),
      findsOneWidget,
    );
    expect(find.text('导入 EPUB/PDF/Markdown'), findsOneWidget);
  });

  testWidgets('AppEmptyState supports informational states without actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.task_alt_outlined,
            title: '没有后台任务',
            message: '导入、索引、导出和备份会在这里显示。',
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '空状态：没有后台任务。导入、索引、导出和备份会在这里显示。',
      ),
      findsOneWidget,
    );
  });
}
