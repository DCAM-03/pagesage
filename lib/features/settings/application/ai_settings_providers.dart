import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';

final aiProfilesProvider = StreamProvider<List<AiProfile>>((ref) {
  return ref.watch(aiProfileRepositoryProvider).watchProfiles();
});

final aiSettingsProvider = StreamProvider<AiSettings>((ref) {
  return ref.watch(aiSettingsRepositoryProvider).watchSettings();
});

final aiSettingsControllerProvider = Provider<AiSettingsController>((ref) {
  return AiSettingsController(
    ref.watch(aiSettingsRepositoryProvider),
    ref.watch(aiProfileRepositoryProvider),
  );
});

final class AiSettingsController {
  const AiSettingsController(this._repository, [this._profiles]);

  final AiSettingsRepository _repository;
  final AiProfileRepository? _profiles;

  Future<void> save(AiSettings settings, {String? apiKey}) {
    return _repository.saveSettings(settings, apiKey: apiKey);
  }

  Future<void> setEnabled(bool enabled) async {
    final settings = await _repository.getSettings();
    await _repository.saveSettings(settings.copyWith(enabled: enabled));
  }

  Future<void> clearApiKey() {
    return _repository.clearApiKey();
  }

  Future<void> selectProfile(String? id) {
    final profiles = _profiles;
    return profiles == null
        ? Future<void>.value()
        : profiles.setActiveProfile(id);
  }

  Future<AiProfile?> createProfile({
    required String name,
    String? sourceProfileId,
    bool copyCredential = false,
  }) {
    final profiles = _profiles;
    if (profiles == null) return Future<AiProfile?>.value();
    return profiles.createProfile(
      name: name,
      sourceProfileId: sourceProfileId,
      copyCredential: copyCredential,
    );
  }

  Future<void> renameActiveProfile(String name) async {
    final settings = await _repository.getSettings();
    final id = settings.activeProfileId;
    final profiles = _profiles;
    if (id == null || profiles == null) return;
    final profile = await profiles.getProfile(id);
    if (profile == null) return;
    await profiles.updateProfile(
      AiProfile(
        id: profile.id,
        name: name,
        provider: profile.provider,
        baseUrl: profile.baseUrl,
        model: profile.model,
        temperature: profile.temperature,
        maxTokens: profile.maxTokens,
        streaming: profile.streaming,
        systemPrompt: profile.systemPrompt,
        revision: profile.revision,
        hasApiKey: profile.hasApiKey,
        credentialState: profile.credentialState,
      ),
      expectedRevision: profile.revision,
    );
  }

  Future<void> deleteActiveProfile() async {
    final settings = await _repository.getSettings();
    final id = settings.activeProfileId;
    final repository = _profiles;
    if (id == null || repository == null) return;
    final profiles = await repository.listProfiles();
    final replacement = profiles
        .where((profile) => profile.id != id)
        .firstOrNull
        ?.id;
    await repository.deleteProfile(id, replacementProfileId: replacement);
  }
}
