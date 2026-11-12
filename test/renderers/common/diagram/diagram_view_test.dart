import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/common/diagram/diagram_view.dart';

void main() {
  Future<void> pumpView(WidgetTester tester, String source) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MermaidDiagramView(
            source: source,
            settings: const ReaderSettings(fontSize: 18),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a supported diagram opens as a drawing by default', (
    tester,
  ) async {
    const source = 'flowchart LR\nA["读取"] --> B{"完成？"}';
    await pumpView(tester, source);

    expect(find.text('Mermaid 图形'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byTooltip('查看源码'), findsOneWidget);
    expect(find.byTooltip('展开查看'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the source toggle keeps the complete original text', (
    tester,
  ) async {
    const source = 'flowchart TD\nA --> B\nB --> C';
    await pumpView(tester, source);

    await tester.tap(find.byIcon(Icons.code));
    await tester.pumpAndSettle();

    expect(find.text('Mermaid 源码'), findsOneWidget);
    expect(find.text(source), findsOneWidget);
    expect(find.byTooltip('查看图形'), findsOneWidget);
  });

  testWidgets('an unsupported diagram falls back to readable source', (
    tester,
  ) async {
    const source = 'flowchart TD\nsubgraph one\nA --> B\nend';
    await pumpView(tester, source);

    expect(find.text('Mermaid 源码'), findsOneWidget);
    expect(find.text(source), findsOneWidget);
    expect(find.textContaining('当前版本不支持'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded view can reset zoom and close', (tester) async {
    await pumpView(tester, 'flowchart LR\nA --> B');

    await tester.tap(find.byTooltip('展开查看'));
    await tester.pumpAndSettle();

    expect(find.text('展开查看 Mermaid 图形'), findsOneWidget);
    expect(find.byTooltip('复位缩放'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('展开查看 Mermaid 图形'), findsNothing);
  });
}
