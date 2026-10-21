import '../books/reading_position.dart';

final class AiSettings {
  const AiSettings({
    this.enabled = false,
    this.provider = 'openai-compatible',
    this.baseUrl = '',
    this.model = '',
    this.temperature = 0.2,
    this.maxTokens = 1200,
    this.streaming = true,
    this.systemPrompt = '',
    this.confirmBeforeRequest = false,
    this.hasApiKey = false,
  });

  final bool enabled;
  final String provider;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool streaming;
  final String systemPrompt;

  /// Show a dialog before every request.
  ///
  /// Off by default: the rail already lists every block that will be sent,
  /// with its size and origin, and a dialog on every question turns a
  /// deliberate privacy check into a reflex the reader clicks through. The
  /// setting stays for readers who want the extra stop.
  final bool confirmBeforeRequest;
  final bool hasApiKey;

  AiSettings copyWith({
    bool? enabled,
    String? provider,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? streaming,
    String? systemPrompt,
    bool? confirmBeforeRequest,
    bool? hasApiKey,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      streaming: streaming ?? this.streaming,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      confirmBeforeRequest: confirmBeforeRequest ?? this.confirmBeforeRequest,
      hasApiKey: hasApiKey ?? this.hasApiKey,
    );
  }
}

final class AiConversation {
  const AiConversation({
    required this.id,
    required this.provider,
    required this.model,
    required this.prompt,
    required this.answer,
    required this.createdAt,
    this.bookId,
    this.locator,
    this.contextText,
    this.sourceText,
    this.noteId,
    this.threadId,
  });

  final String id;
  final String? bookId;
  final ReadingLocator? locator;
  final String provider;
  final String model;
  final String prompt;
  final String? contextText;
  final String answer;
  final String? sourceText;
  final String? noteId;

  /// Turns asked against the same context share this.
  ///
  /// Null on conversations saved before threads existed; they are single
  /// turns, and the history shows them that way.
  final String? threadId;

  final int createdAt;
}

/// One earlier exchange in the same thread.
final class AiThreadTurn {
  const AiThreadTurn({required this.prompt, required this.answer});

  final String prompt;
  final String answer;
}

final class AiRequest {
  const AiRequest({
    required this.prompt,
    required this.contextText,
    required this.settings,
    this.history = const [],
  });

  final String prompt;
  final String contextText;
  final AiSettings settings;

  /// Earlier turns of the same thread, oldest first, not counting this one.
  ///
  /// The context travels once, in the first message; repeating it per turn
  /// would multiply the most expensive part of the request.
  final List<AiThreadTurn> history;
}

final class AiChunk {
  const AiChunk(this.text);

  final String text;
}

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AiChatCancelledException extends AiChatException {
  const AiChatCancelledException([this.partialAnswer = '']) : super('请求已取消');

  final String partialAnswer;
}

final class AiCancelToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _onCancel?.call();
  }

  void bind(void Function() onCancel) {
    if (_cancelled) {
      onCancel();
      return;
    }
    _onCancel = onCancel;
  }
}

enum AiProviderStatus {
  ready('ready'),
  missingConfiguration('missingConfiguration'),
  missingApiKey('missingApiKey'),
  unavailable('unavailable');

  const AiProviderStatus(this.value);

  final String value;
}

abstract interface class AiProvider {
  Stream<AiChunk> streamChat({
    required AiRequest request,
    required String apiKey,
    AiCancelToken? cancelToken,
  });

  Future<AiProviderStatus> testConnection({
    required AiSettings settings,
    required String apiKey,
    AiCancelToken? cancelToken,
  });
}

abstract interface class AiSettingsRepository {
  Stream<AiSettings> watchSettings();

  Future<AiSettings> getSettings();

  Future<void> saveSettings(AiSettings settings, {String? apiKey});

  Future<void> clearApiKey();
}

abstract interface class AiConversationRepository {
  Stream<List<AiConversation>> watchConversations();

  Future<List<AiConversation>> getConversations();

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
  });

  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  });

  Future<void> clearAll();
}
