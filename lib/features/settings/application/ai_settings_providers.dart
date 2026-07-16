import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';

final aiSettingsProvider = StreamProvider<AiSettings>((ref) {
  return ref.watch(aiSettingsRepositoryProvider).watchSettings();
});

final aiSettingsControllerProvider = Provider<AiSettingsController>((ref) {
  return AiSettingsController(ref.watch(aiSettingsRepositoryProvider));
});

final class AiSettingsController {
  const AiSettingsController(this._repository);

  final AiSettingsRepository _repository;

  Future<void> save(AiSettings settings, {String? apiKey}) {
    return _repository.saveSettings(settings, apiKey: apiKey);
  }

  Future<void> clearApiKey() {
    return _repository.clearApiKey();
  }
}
