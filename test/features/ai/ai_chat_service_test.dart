import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/ai_chat_service.dart';

void main() {
  test('streams chunks and saves the completed conversation', () async {
    final conversations = _FakeAiConversationRepository();
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: conversations,
      secureStore: SecureStore(),
      provider: _FakeAiProvider(['你好', '，PageSage']),
      readSecret: (_) async => 'test-key',
    );
    final chunks = <String>[];

    final conversation = await service.ask(
      bookId: 'book-1',
      locator: ReadingLocator.epub(chapterIndex: 0),
      contextText: '上下文',
      prompt: '解释',
      onChunk: chunks.add,
    );

    expect(chunks, ['你好', '，PageSage']);
    expect(conversation.answer, '你好，PageSage');
    expect(conversations.saved.single.answer, '你好，PageSage');
    expect(conversations.saved.single.contextText, '上下文');
  });

  test('cancel keeps the generated partial answer', () async {
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: _FakeAiConversationRepository(),
      secureStore: SecureStore(),
      provider: _FakeAiProvider(['第一段', '第二段']),
      readSecret: (_) async => 'test-key',
    );
    final cancelToken = AiCancelToken();

    await expectLater(
      service.ask(
        contextText: '上下文',
        prompt: '解释',
        cancelToken: cancelToken,
        onChunk: (_) => cancelToken.cancel(),
      ),
      throwsA(
        isA<AiChatCancelledException>().having(
          (error) => error.partialAnswer,
          'partialAnswer',
          '第一段',
        ),
      ),
    );
  });

  test('disabled AI fails before provider is called', () async {
    final provider = _FakeAiProvider(['不应调用']);
    final conversations = _FakeAiConversationRepository();
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(
        settings: const AiSettings(
          enabled: false,
          baseUrl: 'https://example.test/v1',
          model: 'test-model',
        ),
      ),
      conversationRepository: conversations,
      secureStore: SecureStore(),
      provider: provider,
      readSecret: (_) async => 'test-key',
    );

    await expectLater(
      service.ask(contextText: '上下文', prompt: '解释'),
      throwsA(
        isA<AiChatException>().having(
          (error) => error.message,
          'message',
          'AI 功能未启用',
        ),
      ),
    );
    expect(provider.streamCallCount, 0);
    expect(conversations.saved, isEmpty);
  });

  test('missing provider configuration fails before reading api key', () async {
    var secretRead = false;
    final provider = _FakeAiProvider(['不应调用']);
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(
        settings: const AiSettings(enabled: true, baseUrl: '', model: ''),
      ),
      conversationRepository: _FakeAiConversationRepository(),
      secureStore: SecureStore(),
      provider: provider,
      readSecret: (_) async {
        secretRead = true;
        return 'test-key';
      },
    );

    await expectLater(
      service.ask(contextText: '上下文', prompt: '解释'),
      throwsA(
        isA<AiChatException>().having(
          (error) => error.message,
          'message',
          '请先配置 AI Provider',
        ),
      ),
    );
    expect(secretRead, isFalse);
    expect(provider.streamCallCount, 0);
  });

  test('missing api key fails before provider is called', () async {
    final provider = _FakeAiProvider(['不应调用']);
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: _FakeAiConversationRepository(),
      secureStore: SecureStore(),
      provider: provider,
      readSecret: (_) async => '',
    );

    await expectLater(
      service.ask(contextText: '上下文', prompt: '解释'),
      throwsA(
        isA<AiChatException>().having(
          (error) => error.message,
          'message',
          '请先保存 API Key',
        ),
      ),
    );
    expect(provider.streamCallCount, 0);
  });

  test('empty provider answer is not saved', () async {
    final conversations = _FakeAiConversationRepository();
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: conversations,
      secureStore: SecureStore(),
      provider: _FakeAiProvider(['  ', '\n']),
      readSecret: (_) async => 'test-key',
    );

    await expectLater(
      service.ask(contextText: '上下文', prompt: '解释'),
      throwsA(
        isA<AiChatException>().having(
          (error) => error.message,
          'message',
          'AI 回答为空',
        ),
      ),
    );
    expect(conversations.saved, isEmpty);
  });

  test('testConnection can run when AI is disabled but configured', () async {
    final provider = _FakeAiProvider(['不用于连接测试']);
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(
        settings: const AiSettings(
          enabled: false,
          baseUrl: 'https://example.test/v1',
          model: 'test-model',
        ),
      ),
      conversationRepository: _FakeAiConversationRepository(),
      secureStore: SecureStore(),
      provider: provider,
      readSecret: (_) async => 'test-key',
    );

    final status = await service.testConnection();

    expect(status, AiProviderStatus.ready);
    expect(provider.testConnectionCallCount, 1);
    expect(provider.lastTestSettings?.enabled, isFalse);
  });
}

final class _FakeAiProvider implements AiProvider {
  _FakeAiProvider(this.chunks);

  final List<String> chunks;
  int streamCallCount = 0;
  int testConnectionCallCount = 0;
  AiSettings? lastTestSettings;

  @override
  Stream<AiChunk> streamChat({
    required AiRequest request,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async* {
    streamCallCount += 1;
    for (final chunk in chunks) {
      yield AiChunk(chunk);
    }
  }

  @override
  Future<AiProviderStatus> testConnection({
    required AiSettings settings,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async {
    testConnectionCallCount += 1;
    lastTestSettings = settings;
    return AiProviderStatus.ready;
  }
}

final class _FakeAiSettingsRepository implements AiSettingsRepository {
  const _FakeAiSettingsRepository({
    this.settings = const AiSettings(
      enabled: true,
      baseUrl: 'https://example.test/v1',
      model: 'test-model',
    ),
  });

  final AiSettings settings;

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<AiSettings> getSettings() async => settings;

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Stream<AiSettings> watchSettings() => Stream.fromFuture(getSettings());
}

final class _FakeAiConversationRepository implements AiConversationRepository {
  final saved = <AiConversation>[];

  @override
  Future<void> clearAll() async {}

  @override
  Future<List<AiConversation>> getConversations() async => saved;

  @override
  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) async {}

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
      id: id ?? 'conversation-${saved.length + 1}',
      bookId: bookId,
      locator: locator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      createdAt: 1,
    );
    saved.add(conversation);
    return conversation;
  }

  @override
  Stream<List<AiConversation>> watchConversations() => Stream.value(saved);
}
