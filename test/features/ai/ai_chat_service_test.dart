import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/ai_chat_service.dart';
import 'package:pagesage/features/ai/application/evidence_policy.dart';

void main() {
  test(
    'configuration changes during credential loading prevent a mixed request',
    () async {
      final settings = _ChangingSettings();
      final provider = _FakeAiProvider(['must not send']);
      final service = AiChatService(
        settingsRepository: settings,
        conversationRepository: _FakeAiConversationRepository(),
        secureStore: SecureStore.memory(),
        provider: provider,
        readSecret: (_) async {
          settings.current = settings.current.copyWith(profileRevision: 2);
          return 'test-key';
        },
      );
      await expectLater(
        service.ask(contextText: 'context', prompt: 'question'),
        throwsA(isA<AiChatException>()),
      );
      expect(provider.streamCallCount, 0);
    },
  );

  test(
    'cancelling while credentials load never opens a provider request',
    () async {
      final token = AiCancelToken();
      final provider = _FakeAiProvider(['must not send']);
      final service = AiChatService(
        settingsRepository: _FakeAiSettingsRepository(),
        conversationRepository: _FakeAiConversationRepository(),
        secureStore: SecureStore.memory(),
        provider: provider,
        readSecret: (_) async {
          token.cancel();
          return 'test-key';
        },
      );
      await expectLater(
        service.ask(
          contextText: 'context',
          prompt: 'question',
          cancelToken: token,
        ),
        throwsA(isA<AiChatCancelledException>()),
      );
      expect(provider.streamCallCount, 0);
    },
  );

  test(
    'source snapshot is saved only when it matches the sent payload',
    () async {
      final provider = _FakeAiProvider(['回答']);
      final conversations = _FakeAiConversationRepository();
      final service = AiChatService(
        settingsRepository: _FakeAiSettingsRepository(),
        conversationRepository: conversations,
        secureStore: SecureStore(),
        provider: provider,
        readSecret: (_) async => 'test-key',
      );
      final snapshot = AiContextSnapshot(
        range: 'selectedText',
        references: [
          const AiContextReference(id: 'ref-1', title: '选区', text: '实际发送的原文'),
        ],
      );
      await expectLater(
        service.ask(
          contextText: '其他文本',
          prompt: '问题',
          contextSnapshot: snapshot,
        ),
        throwsA(
          isA<AiChatException>().having(
            (error) => error.message,
            'message',
            contains('不一致'),
          ),
        ),
      );
      expect(provider.streamCallCount, 0);
      expect(conversations.saved, isEmpty);
      await service.ask(
        contextText: '实际发送的原文',
        prompt: '问题',
        contextSnapshot: snapshot,
      );
      expect(
        conversations.saved.single.contextSnapshot?.toJsonText(),
        snapshot.toJsonText(),
      );
    },
  );

  test(
    'restoring deleted history fails without calling the provider',
    () async {
      final provider = _FakeAiProvider(['不应调用']);
      final service = AiChatService(
        settingsRepository: _FakeAiSettingsRepository(),
        conversationRepository: _FakeAiConversationRepository(),
        secureStore: SecureStore(),
        provider: provider,
      );
      await expectLater(
        service.restoreThread(
          const AiConversation(
            id: 'gone',
            provider: 'local',
            model: 'm',
            prompt: '问题',
            answer: '回答',
            createdAt: 1,
          ),
        ),
        throwsA(
          isA<AiChatException>().having(
            (error) => error.message,
            'message',
            contains('已删除'),
          ),
        ),
      );
      expect(provider.streamCallCount, 0);
    },
  );

  test('source-question snapshot validates the serialized payload', () async {
    final provider = _FakeAiProvider(['书中有依据。[R1]']);
    final conversations = _FakeAiConversationRepository();
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: conversations,
      secureStore: SecureStore(),
      provider: provider,
      readSecret: (_) async => 'test-key',
    );
    const references = [
      AiContextReference(id: 'ref-1', title: '甲', text: '第一段'),
      AiContextReference(id: 'ref-2', title: '乙', text: '第二段'),
    ];
    final cited = AiContextSerializerV1().withCitationIds(references);
    final snapshot = AiContextSnapshot(
      range: 'wholeBook',
      references: cited,
      version: 2,
      answerIntent: 'sourceQuestion',
      evidenceState: 'eligible',
    );
    final payload = AiContextSerializerV1().serialize(cited);

    await expectLater(
      service.ask(
        contextText: joinContextReferences(cited),
        prompt: '书中说了什么',
        contextSnapshot: snapshot,
        answerIntent: AnswerIntent.sourceQuestion,
      ),
      throwsA(
        isA<AiChatException>().having(
          (error) => error.message,
          'message',
          contains('不一致'),
        ),
      ),
    );
    expect(provider.streamCallCount, 0);

    final conversation = await service.ask(
      contextText: payload,
      prompt: '书中说了什么',
      contextSnapshot: snapshot,
      answerIntent: AnswerIntent.sourceQuestion,
      evidenceDecision: const EvidenceDecision(
        state: EvidenceState.eligible,
        reasonCodes: ['test'],
        scopeCompleteness: ScopeCompleteness.ready,
      ),
    );
    expect(conversation.answerMeta?.answerStatus, 'sourceLinked');
    expect(conversation.answerMeta?.citations, ['R1']);
    expect(conversation.profileSnapshot, isNull);
  });

  test('explanation snapshot keeps the joined payload contract', () async {
    final provider = _FakeAiProvider(['解释']);
    final conversations = _FakeAiConversationRepository();
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: conversations,
      secureStore: SecureStore(),
      provider: provider,
      readSecret: (_) async => 'test-key',
    );
    final snapshot = AiContextSnapshot(
      range: 'wholeBook',
      references: const [
        AiContextReference(id: 'ref-1', title: '甲', text: '第一段'),
        AiContextReference(id: 'ref-2', title: '乙', text: '第二段'),
      ],
      version: 2,
      answerIntent: 'explain',
      evidenceState: 'eligible',
    );
    final conversation = await service.ask(
      contextText: joinContextReferences(snapshot.references),
      prompt: '解释这段',
      contextSnapshot: snapshot,
    );
    expect(conversation.answerMeta?.answerStatus, 'unverified');
    expect(conversation.answerMeta?.intent, 'explain');
  });
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
    final conversations = _FakeAiConversationRepository();
    final service = AiChatService(
      settingsRepository: _FakeAiSettingsRepository(),
      conversationRepository: conversations,
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
    expect(conversations.saved, isEmpty);
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

final class _ChangingSettings implements AiSettingsRepository {
  AiSettings current = const AiSettings(
    enabled: true,
    activeProfileId: 'profile',
    hasApiKey: true,
    baseUrl: 'https://example.test/v1',
    model: 'test-model',
  );

  @override
  Future<AiSettings> getSettings() async => current;

  @override
  Stream<AiSettings> watchSettings() => Stream.value(current);

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Future<void> clearApiKey() async {}
}

final class _FakeAiConversationRepository
    implements AiConversationRepository, DetailedAiConversationRepository {
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
    AiContextSnapshot? contextSnapshot,
  }) async {
    return saveConversationDetailed(
      id: id ?? 'conversation-${saved.length + 1}',
      provider: provider,
      model: model,
      prompt: prompt,
      answer: answer,
      contextText: contextText,
      sourceText: sourceText,
      threadId: threadId,
      contextSnapshot: contextSnapshot,
    );
  }

  @override
  Future<AiConversation> saveConversationDetailed({
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
    AiContextSnapshot? contextSnapshot,
    AiAnswerMeta? answerMeta,
    String? profileId,
    String? profileSnapshot,
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
      threadId: threadId,
      contextSnapshot: contextSnapshot,
      answerMeta: answerMeta,
      profileSnapshot: profileSnapshot,
      createdAt: 1,
    );
    saved.add(conversation);
    return conversation;
  }

  @override
  Stream<List<AiConversation>> watchConversations() => Stream.value(saved);
}
