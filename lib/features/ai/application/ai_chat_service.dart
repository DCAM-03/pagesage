// ignore_for_file: prefer_initializing_formals

import '../../../core/security/secure_store.dart';
import '../../../core/security/security_keys.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/books/reading_position.dart';
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
    void Function(String chunk)? onChunk,
    AiCancelToken? cancelToken,
  }) async {
    final credentials = await _readCredentials();
    final buffer = StringBuffer();
    try {
      await for (final chunk in _provider.streamChat(
        request: AiRequest(
          prompt: prompt,
          contextText: contextText,
          settings: credentials.settings,
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
    if (answer.isEmpty) {
      throw const AiChatException('AI 回答为空');
    }
    return _conversationRepository.saveConversation(
      bookId: bookId,
      locator: locator,
      provider: credentials.settings.provider,
      model: credentials.settings.model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText ?? contextText,
    );
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
    final apiKey = await (_readSecret ?? _secureStore.read)(aiApiKeyStorageKey);
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiChatException('请先保存 API Key');
    }
    return _AiCredentials(settings: settings, apiKey: apiKey);
  }
}

final class _AiCredentials {
  const _AiCredentials({required this.settings, required this.apiKey});

  final AiSettings settings;
  final String apiKey;
}
