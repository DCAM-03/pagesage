import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/ai_context_range.dart';
import 'package:pagesage/features/ai/application/ai_context_source.dart';
import 'package:pagesage/features/ai/application/ai_providers.dart';
import 'package:pagesage/features/ai/presentation/ai_panel.dart';

/// Stands in for the disk reader, which cannot complete under the fake clock.
/// Holds `load` open until the test releases it.
final class _SlowSource extends AiContextSource {
  final _gate = Completer<ContextSource?>();
  final requested = <AiContextRange>[];

  @override
  Future<ContextSource?> load({
    required AiContextRange range,
    required String bookPath,
    required ReadingLocator? locator,
    required bool isEpub,
  }) {
    requested.add(range);
    return _gate.future;
  }
}

final class _StubSource extends AiContextSource {
  _StubSource({this.text, this.unreadable = false});

  final String? text;

  /// Simulates a book that is missing or corrupt, as opposed to an empty page.
  final bool unreadable;

  /// Ranges the panel asked for, in order.
  final requested = <AiContextRange>[];

  @override
  Future<ContextSource?> load({
    required AiContextRange range,
    required String bookPath,
    required ReadingLocator? locator,
    required bool isEpub,
  }) async {
    requested.add(range);
    if (unreadable) throw const BookUnreadableException();
    if (text == null) return null;
    return ContextSource(title: '第一章', text: text!);
  }
}

/// Configured AI, so `_ask` gets as far as the confirmation dialog.
final class _ConfiguredAiSettings implements AiSettingsRepository {
  const _ConfiguredAiSettings();

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<AiSettings> getSettings() async => const AiSettings(
    enabled: true,
    baseUrl: 'http://localhost:11434',
    model: 'test-model',
    hasApiKey: true,
  );

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Stream<AiSettings> watchSettings() =>
      Stream.value(const AiSettings(enabled: true, hasApiKey: true));
}

Widget _panel(
  String? bookPath,
  AiContextSource source, {
  String selection = '选中的句子',
  bool aiConfigured = false,
}) {
  return ProviderScope(
    overrides: [
      aiContextSourceProvider.overrideWithValue(source),
      if (aiConfigured)
        aiSettingsRepositoryProvider.overrideWithValue(
          const _ConfiguredAiSettings(),
        ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: AiPanel(
          bookId: 'book-1',
          bookPath: bookPath,
          isEpub: true,
          locator: ReadingLocator.epub(
            href: 'OEBPS/chapter1.xhtml',
            chapterIndex: 0,
            chapterOffset: 0,
            progress: 0,
          ),
          initialContext: selection,
        ),
      ),
    ),
  );
}

Future<void> _pickChapter(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<AiContextRange>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('当前章节').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('the panel starts on the selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_panel('book.epub', _StubSource()));
    await tester.pumpAndSettle();

    expect(find.text('选中的句子'), findsOneWidget);
    expect(find.text('仅选中文本'), findsWidgets);
  });

  testWidgets('picking a chapter sends the chapter, not the selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final source = _StubSource(text: '段落甲。\n\n段落乙。');
    await tester.pumpWidget(_panel('book.epub', source));
    await tester.pumpAndSettle();

    await _pickChapter(tester);

    expect(source.requested, contains(AiContextRange.currentChapter));
    expect(find.textContaining('段落乙'), findsOneWidget);
    // The loaded block is a row naming where it came from, and the selection
    // stays as its own row: that is the question's subject.
    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('选中文本'), findsOneWidget);
    expect(find.text('选中的句子'), findsOneWidget);
    expect(find.textContaining('2 段引用'), findsOneWidget);
  });

  testWidgets('going back to the selection restores it, not the chapter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _panel('book.epub', _StubSource(text: '段落甲。\n\n段落乙。')),
    );
    await tester.pumpAndSettle();
    await _pickChapter(tester);
    expect(find.textContaining('段落乙'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<AiContextRange>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅选中文本').last);
    await tester.pumpAndSettle();

    expect(find.text('选中的句子'), findsOneWidget);
    expect(find.textContaining('段落乙'), findsNothing);
    expect(find.text('选中文本'), findsOneWidget);
  });

  testWidgets('without a book file the ranges that need one are disabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final source = _StubSource(text: '段落乙。');
    await tester.pumpWidget(_panel(null, source));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AiContextRange>));
    await tester.pumpAndSettle();

    final items = tester
        .widgetList<DropdownMenuItem<AiContextRange>>(
          find.byType(DropdownMenuItem<AiContextRange>),
        )
        .toList(growable: false);
    for (final item in items) {
      expect(
        item.enabled,
        item.value == AiContextRange.selectedText,
        reason: '${item.value} should only be selectable without a file',
      );
    }

    await tester.tap(find.text('当前章节').last);
    await tester.pumpAndSettle();

    // Nothing was read, and the panel still sends exactly the selection.
    expect(source.requested, isEmpty);
    expect(find.text('选中的句子'), findsOneWidget);
  });

  testWidgets('a page with no text says so instead of sending the selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_panel('book.epub', _StubSource()));
    await tester.pumpAndSettle();

    await _pickChapter(tester);

    expect(find.textContaining('没有可读文字'), findsOneWidget);
    expect(find.text('选中的句子'), findsOneWidget);
    // The fallback must show in the selector too, or it claims to be sending
    // the chapter it just failed to read.
    expect(find.text('当前章节'), findsNothing);
  });

  testWidgets('a selection arriving mid-read wins over the stale chapter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final source = _SlowSource();
    await tester.pumpWidget(_panel('book.epub', source));
    await tester.pumpAndSettle();

    await _pickChapter(tester);
    expect(find.text('正在读取…'), findsOneWidget);

    // The reader turns the page while the chapter is still loading.
    await tester.pumpWidget(_panel('book.epub', source, selection: '下一页的句子'));
    await tester.pumpAndSettle();

    // The old read finishes; it must not repaint the new selection.
    source._gate.complete(const ContextSource(title: '旧的一章', text: '旧章节正文'));
    await tester.pumpAndSettle();

    expect(find.text('下一页的句子'), findsOneWidget);
    expect(find.textContaining('旧章节正文'), findsNothing);
    expect(find.text('旧的一章'), findsNothing);
    expect(find.text('正在读取…'), findsNothing);
  });

  testWidgets('dropping a reference takes it out of what will be sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_panel('book.epub', _StubSource(text: '章节正文内容')));
    await tester.pumpAndSettle();
    await _pickChapter(tester);
    expect(find.textContaining('章节正文内容'), findsOneWidget);

    // Drop the chapter; the selection stays and the range stops claiming it.
    await tester.tap(find.byTooltip('移除这段引用').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('章节正文内容'), findsNothing);
    expect(find.text('选中的句子'), findsOneWidget);
    expect(find.textContaining('1 段引用'), findsNothing);
    expect(find.textContaining('约 5 字'), findsOneWidget);
  });

  testWidgets('editing a reference changes the text that is sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_panel('book.epub', _StubSource(text: '章节正文内容')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑文本'));
    await tester.pumpAndSettle();

    final editor = find.byType(TextField).first;
    await tester.enterText(editor, '改写后的选中文本');
    await tester.pumpAndSettle();

    expect(find.textContaining('改写后的选中文本'), findsWidgets);
    // Only the selection is in the list here; the total follows the edit.
    expect(find.textContaining('约 8 字'), findsOneWidget);
    expect(find.text('8 字'), findsOneWidget);
  });

  testWidgets('the last reference cannot be dropped to nothing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_panel('book.epub', _StubSource()));
    await tester.pumpAndSettle();

    // With only the selection left there is nothing to remove it to.
    expect(find.byTooltip('移除这段引用'), findsNothing);
  });

  testWidgets('the privacy prompt names every block being sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _panel('book.epub', _StubSource(text: '章节正文内容'), aiConfigured: true),
    );
    await tester.pumpAndSettle();
    await _pickChapter(tester);

    await tester.enterText(find.byType(TextField).last, '解释这段');
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    // A bare range name would not tell the reader that two separate blocks,
    // one of them a whole chapter, are about to leave the device.
    expect(find.text('发送 AI 请求？'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final body = tester.widget<Text>(
      find.descendant(of: dialog, matching: find.byType(Text)).at(1),
    );
    expect(body.data, contains('2 段引用'));
    expect(body.data, contains('选中文本'));
    expect(body.data, contains('第一章'));
  });

  testWidgets('an unreadable book says so and leaves no spinner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_panel('book.epub', _StubSource(unreadable: true)));
    await tester.pumpAndSettle();

    await _pickChapter(tester);

    // Blaming the page for a corrupt file would send the reader looking in
    // the wrong place.
    expect(find.textContaining('无法读取书籍文件'), findsOneWidget);
    expect(find.textContaining('没有可读文字'), findsNothing);
    expect(find.text('读取中'), findsNothing);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('选中的句子'), findsOneWidget);
  });
}
