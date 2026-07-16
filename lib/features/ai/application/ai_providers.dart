import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import 'ai_chat_service.dart';

final aiChatServiceProvider = Provider<AiChatService>((ref) {
  return AiChatService(
    settingsRepository: ref.watch(aiSettingsRepositoryProvider),
    conversationRepository: ref.watch(aiConversationRepositoryProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});
