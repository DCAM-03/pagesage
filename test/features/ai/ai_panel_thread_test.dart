import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/ai_chat_service.dart';
import 'package:pagesage/features/ai/application/ai_providers.dart';
import 'package:pagesage/features/ai/presentation/ai_panel.dart';

final class _RecordingProvider implements AiProvider {
  final requests = <AiRequest>[];

  @override
  Stream<AiChunk> streamChat({
    required AiRequest request,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async* {
    requests.add(request);
    yield AiChunk('回答${requests.length}');
  }

  @override
  Future<AiProviderStatus> testConnection({
    required AiSettings settings,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async => AiProviderStatus.ready;
}

/// Keeps what was saved; the panel reads the thread id back off the result.
final class _MemoryConversations implements AiConversationRepository {
  final saved = <AiConversation>[];

  @override
  Future<AiConversation> saveConversation({
    String? id,
    String? bookId,
    ReadingLocator? locator,
    required String provider,
    required String model,
    required String prompt,
    String? contextText,
    required String answer,
    String? sourceText,
    String? threadId,
  }) async {
    final conversation = AiConversation(
      id: id ?? 'conv-${saved.length + 1}',
      bookId: bookId,
      locator: locator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      threadId: threadId,
      createdAt: saved.length + 1,
    );
    saved.add(conversation);
    return conversation;
  }

  @override
  Future<void> clearAll() async => saved.clear();

  @override
  Future<List<AiConversation>> getConversations() async =>
      List.of(saved.reversed);

  @override
  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) async {}

  @override
  Stream<List<AiConversation>> watchConversations() =>
      Stream.value(List.of(saved.reversed));
}

const _settings = AiSettings(
  enabled: true,
  baseUrl: 'http://localhost:11434',
  model: 'test-model',
  hasApiKey: true,
);

final class _Settings implements AiSettingsRepository {
  const _Settings();

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<AiSettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Stream<AiSettings> watchSettings() => Stream.value(_settings);
}

Widget _panel({
  required _RecordingProvider provider,
  required _MemoryConversations conversations,
  String selection = '选中的句子',
}) {
  final service = AiChatService(
    settingsRepository: const _Settings(),
    conversationRepository: conversations,
    secureStore: SecureStore(),
    provider: provider,
    readSecret: (_) async => 'test-key',
  );
  return ProviderScope(
    overrides: [
      aiChatServiceProvider.overrideWithValue(service),
      aiSettingsRepositoryProvider.overrideWithValue(const _Settings()),
      aiConversationRepositoryProvider.overrideWithValue(conversations),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: AiPanel(
          bookId: 'book-1',
          bookPath: null,
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

Future<void> _ask(WidgetTester tester, String prompt) async {
  await tester.enterText(find.byType(TextField).last, prompt);
  await tester.pumpAndSettle();
  await tester.tap(find.text('发送'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text('发送')),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('a follow-up question carries the earlier turn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = _RecordingProvider();
    final conversations = _MemoryConversations();
    await tester.pumpWidget(
      _panel(provider: provider, conversations: conversations),
    );
    await tester.pumpAndSettle();

    await _ask(tester, '第一问');
    expect(provider.requests.single.history, isEmpty);

    await _ask(tester, '第二问');
    final second = provider.requests.last;
    expect(second.history, hasLength(1));
    expect(second.history.single.prompt, '第一问');
    expect(second.history.single.answer, '回答1');

    // Both turns belong to one thread, so the history view can regroup them.
    expect(conversations.saved, hasLength(2));
    expect(conversations.saved[0].threadId, isNotNull);
    expect(conversations.saved[1].threadId, conversations.saved[0].threadId);
  });

  testWidgets('a new selection starts a new thread', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = _RecordingProvider();
    final conversations = _MemoryConversations();
    await tester.pumpWidget(
      _panel(provider: provider, conversations: conversations),
    );
    await tester.pumpAndSettle();
    await _ask(tester, '第一问');

    // The reader selects different text; the old answer discussed a passage
    // the next question will not carry.
    await tester.pumpWidget(
      _panel(
        provider: provider,
        conversations: conversations,
        selection: '另一段话',
      ),
    );
    await tester.pumpAndSettle();
    await _ask(tester, '第二问');

    expect(provider.requests.last.history, isEmpty);
    expect(
      conversations.saved.last.threadId,
      isNot(conversations.saved.first.threadId),
    );
  });
}
