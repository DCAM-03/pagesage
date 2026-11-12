// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../../../core/security/security_keys.dart';
import '../../../core/security/secure_store.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/books/reading_position.dart';
import 'evidence_policy.dart';
import '../data/openai_compatible_provider.dart';

final class AiChatService {
  const AiChatService({
    required AiSettingsRepository settingsRepository,
    required AiConversationRepository conversationRepository,
    required SecureStore secureStore,
    AiProvider? provider,
    Future<String?> Function(String key)? readSecret,
  }) : _settingsRepository = settingsRepository,
       _conversationRepository = conversationRepository,
       _secureStore = secureStore,
       _provider = provider ?? const OpenAiCompatibleProvider(),
       _readSecret = readSecret;

  final AiSettingsRepository _settingsRepository;
  final AiConversationRepository _conversationRepository;
  final SecureStore _secureStore;
  final AiProvider _provider;
  final Future<String?> Function(String key)? _readSecret;

  Future<AiConversation> ask({
    String? bookId,
    ReadingLocator? locator,
    required String contextText,
    required String prompt,
    String? sourceText,
    String? threadId,
    List<AiThreadTurn> history = const [],
    AiContextSnapshot? contextSnapshot,
    AnswerIntent answerIntent = AnswerIntent.explain,
    EvidenceDecision? evidenceDecision,
    void Function(String chunk)? onChunk,
    AiCancelToken? cancelToken,
    AiConversation? regenerate,
  }) async {
    if (regenerate != null &&
        (regenerate.bookId != bookId ||
            (regenerate.threadId ?? regenerate.id) != threadId)) {
      throw const AiChatException('重试目标与当前会话不一致，请重新打开历史');
    }
    final references = contextSnapshot?.references ?? const [];
    if (contextSnapshot != null) {
      String expected;
      if (contextSnapshot.version >= 2 &&
          contextSnapshot.answerIntent == AnswerIntent.sourceQuestion.name) {
        try {
          expected = AiContextSerializerV1().serialize(references);
        } on AiContextSerializationException {
          throw const AiChatException('来源快照与发送上下文不一致，请重新选择上下文');
        }
      } else {
        expected = joinContextReferences(references);
      }
      if (expected != contextText) {
        throw const AiChatException('来源快照与发送上下文不一致，请重新选择上下文');
      }
    }
    final credentials = await _readCredentials();
    if (cancelToken?.isCancelled == true) {
      throw const AiChatCancelledException('');
    }
    final buffer = StringBuffer();
    try {
      await for (final chunk in _provider.streamChat(
        request: AiRequest(
          prompt: prompt,
          contextText: contextText,
          settings: credentials.settings,
          history: history,
          answerMode: answerIntent.name,
        ),
        apiKey: credentials.apiKey,
        cancelToken: cancelToken,
      )) {
        if (cancelToken?.isCancelled == true) {
          throw AiChatCancelledException(buffer.toString());
        }
        buffer.write(chunk.text);
        onChunk?.call(chunk.text);
      }
    } on AiChatCancelledException catch (error) {
      throw AiChatCancelledException(
        error.partialAnswer.isEmpty ? buffer.toString() : error.partialAnswer,
      );
    }

    final answer = buffer.toString().trim();
    if (cancelToken?.isCancelled == true) {
      throw AiChatCancelledException(answer);
    }
    if (answer.isEmpty) {
      throw const AiChatException('AI 回答为空');
    }
    final decision =
        evidenceDecision ??
        _defaultDecision(
          question: prompt,
          intent: answerIntent,
          references: references,
          contextText: contextText,
        );
    final check = AnswerCitationVerifierV1().verify(
      answer: answer,
      references: references,
      intent: answerIntent,
    );
    final status = AnswerCitationVerifierV1().status(
      intent: answerIntent,
      evidenceState: decision.state,
      interrupted: false,
      check: check,
    );
    final meta = AiAnswerMeta(
      intent: answerIntent.name,
      evidenceState: decision.state.name,
      answerStatus: status.name,
      policyVersion: EvidencePolicyV1.version,
      reasonCodes: decision.reasonCodes,
      citations: check.citationIds.toList()..sort(),
      claimChecks: check.uncitedParagraphs,
      scopeCompleteness: decision.scopeCompleteness.name,
      truncated: contextSnapshot?.truncated ?? false,
    );
    return _conversationRepository.saveConversationDetailed(
      id: regenerate?.id,
      bookId: bookId,
      locator: locator,
      provider: credentials.settings.provider,
      model: credentials.settings.model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText ?? contextText,
      threadId: threadId,
      contextSnapshot: contextSnapshot,
      profileId: credentials.profileId,
      profileSnapshot: credentials.profileSnapshot,
      answerMeta: meta,
    );
  }

  EvidenceDecision _defaultDecision({
    required String question,
    required AnswerIntent intent,
    required List<AiContextReference> references,
    required String contextText,
  }) {
    return EvidencePolicyV1().decide(
      question: question,
      intent: intent,
      references: references.isEmpty
          ? [
              AiContextReference(
                id: 'legacy-payload',
                title: '旧版上下文',
                text: contextText,
              ),
            ]
          : references,
      scopeCompleteness: ScopeCompleteness.ready,
      explicitSelection: true,
      truncated: false,
    );
  }

  Future<List<AiConversation>> restoreThread(AiConversation selected) async {
    final conversations = await _conversationRepository.getConversations();
    if (!conversations.any(
      (conversation) =>
          conversation.id == selected.id &&
          conversation.bookId == selected.bookId,
    )) {
      throw const AiChatException('这条历史记录已删除，请刷新历史列表');
    }
    return conversations.reversed
        .where((conversation) {
          if (conversation.bookId != selected.bookId) return false;
          final threadId = selected.threadId ?? selected.id;
          return conversation.threadId == threadId ||
              conversation.id == threadId;
        })
        .toList(growable: false);
  }

  Future<AiProviderStatus> testConnection() async {
    final credentials = await _readCredentials(requireEnabled: false);
    return _provider.testConnection(
      settings: credentials.settings,
      apiKey: credentials.apiKey,
    );
  }

  Future<_AiCredentials> _readCredentials({bool requireEnabled = true}) async {
    final settings = await _settingsRepository.getSettings();
    if (requireEnabled && !settings.enabled) {
      throw const AiChatException('AI 功能未启用');
    }
    if (settings.baseUrl.trim().isEmpty || settings.model.trim().isEmpty) {
      throw const AiChatException('请先配置 AI Provider');
    }
    final profileId = settings.activeProfileId;
    final key = profileId == null
        ? aiApiKeyStorageKey
        : aiProfileApiKeyStorageKey(profileId);
    final apiKey = await (_readSecret ?? _secureStore.read)(key);
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiChatException('请先保存 API Key');
    }
    final latest = await _settingsRepository.getSettings();
    if (latest.activeProfileId != profileId ||
        latest.profileRevision != settings.profileRevision ||
        latest.baseUrl != settings.baseUrl ||
        (profileId != null && !latest.hasApiKey) ||
        (requireEnabled && !latest.enabled)) {
      throw const AiChatException('AI 配置已变化，请重新发送');
    }
    final snapshot = profileId == null
        ? null
        : jsonEncode({
            'version': 1,
            'profileId': profileId,
            'profileName': settings.profileName,
            'profileRevision': settings.profileRevision,
            'provider': settings.provider,
            'model': settings.model,
            'endpointOrigin': Uri.tryParse(settings.baseUrl)?.origin ?? '',
            'parameters': {
              'temperature': settings.temperature,
              'maxTokens': settings.maxTokens,
              'streaming': settings.streaming,
            },
          });
    return _AiCredentials(
      settings: settings,
      apiKey: apiKey,
      profileId: profileId,
      profileSnapshot: snapshot,
    );
  }
}

final class _AiCredentials {
  const _AiCredentials({
    required this.settings,
    required this.apiKey,
    this.profileId,
    this.profileSnapshot,
  });

  final AiSettings settings;
  final String apiKey;
  final String? profileId;
  final String? profileSnapshot;
}
