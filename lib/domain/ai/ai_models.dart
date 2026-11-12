import '../books/reading_position.dart';
import 'ai_context_reference.dart';

export 'ai_context_reference.dart';

final class AiSettings {
  const AiSettings({
    this.enabled = false,
    this.activeProfileId,
    this.profileName = '默认配置',
    this.profileRevision = 1,
    this.profileIds = const [],
    this.profileNames = const {},
    this.provider = 'openai-compatible',
    this.baseUrl = '',
    this.model = '',
    this.temperature = 0.2,
    this.maxTokens = 1200,
    this.streaming = true,
    this.systemPrompt = '',
    this.confirmBeforeRequest = false,
    this.hasApiKey = false,
    this.credentialState = 'missing',
  });

  final bool enabled;
  final String? activeProfileId;
  final String profileName;
  final int profileRevision;
  final List<String> profileIds;
  final Map<String, String> profileNames;
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
  final String credentialState;

  AiSettings copyWith({
    bool? enabled,
    Object? activeProfileId = _sentinel,
    String? profileName,
    int? profileRevision,
    List<String>? profileIds,
    Map<String, String>? profileNames,
    String? provider,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? streaming,
    String? systemPrompt,
    bool? confirmBeforeRequest,
    bool? hasApiKey,
    String? credentialState,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      activeProfileId: identical(activeProfileId, _sentinel)
          ? this.activeProfileId
          : activeProfileId as String?,
      profileName: profileName ?? this.profileName,
      profileRevision: profileRevision ?? this.profileRevision,
      profileIds: profileIds ?? this.profileIds,
      profileNames: profileNames ?? this.profileNames,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      streaming: streaming ?? this.streaming,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      confirmBeforeRequest: confirmBeforeRequest ?? this.confirmBeforeRequest,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      credentialState: credentialState ?? this.credentialState,
    );
  }
}

const Object _sentinel = Object();

final class AiProfileException implements Exception {
  const AiProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AiProfile {
  const AiProfile({
    required this.id,
    required this.name,
    this.provider = 'openai-compatible',
    this.baseUrl = '',
    this.model = '',
    this.temperature = 0.2,
    this.maxTokens = 1200,
    this.streaming = true,
    this.systemPrompt = '',
    this.revision = 1,
    this.hasApiKey = false,
    this.credentialState = 'missing',
  });

  final String id;
  final String name;
  final String provider;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool streaming;
  final String systemPrompt;
  final int revision;
  final bool hasApiKey;
  final String credentialState;
}

abstract interface class AiProfileRepository {
  Stream<List<AiProfile>> watchProfiles();

  Future<List<AiProfile>> listProfiles();

  Future<AiProfile?> getProfile(String id);

  Future<AiProfile> createProfile({
    required String name,
    String? sourceProfileId,
    bool copyCredential = false,
  });

  Future<AiProfile> updateProfile(
    AiProfile profile, {
    String? apiKey,
    required int expectedRevision,
  });

  Future<void> deleteProfile(String id, {String? replacementProfileId});

  Future<void> setActiveProfile(String? id);
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
    this.contextSnapshot,
    this.answerMeta,
    this.profileSnapshot,
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
  final AiContextSnapshot? contextSnapshot;
  final AiAnswerMeta? answerMeta;
  final String? profileSnapshot;

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
    this.answerMode,
  });

  final String prompt;
  final String contextText;
  final AiSettings settings;

  /// Earlier turns of the same thread, oldest first, not counting this one.
  ///
  /// The context travels once, in the first message; repeating it per turn
  /// would multiply the most expensive part of the request.
  final List<AiThreadTurn> history;

  /// The reader-selected answer mode, carried to the provider so it can give
  /// source questions a citation protocol without changing explanation,
  /// translation or rewrite requests. A string keeps the domain model free of
  /// an application-layer policy enum.
  final String? answerMode;
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
    AiContextSnapshot? contextSnapshot,
  });

  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  });

  Future<void> clearAll();
}

abstract interface class DetailedAiConversationRepository {
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
  });
}

extension AiConversationRepositoryDetailed on AiConversationRepository {
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
  }) {
    if (this is DetailedAiConversationRepository) {
      return (this as DetailedAiConversationRepository)
          .saveConversationDetailed(
            id: id,
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
            profileId: profileId,
            profileSnapshot: profileSnapshot,
          );
    }
    return saveConversation(
      id: id,
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
    );
  }
}
