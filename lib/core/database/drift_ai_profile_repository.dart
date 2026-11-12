import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/ai/ai_models.dart';
import '../security/secure_store.dart';
import '../security/security_keys.dart';
import 'app_database.dart' as db;
import 'ai_credential_guard.dart';

final class DriftAiProfileRepository
    implements AiProfileRepository, AiSettingsRepository {
  DriftAiProfileRepository(this._db, this._secureStore);

  final db.AppDatabase _db;
  final SecureStore _secureStore;
  final Uuid _uuid = const Uuid();
  final String _ownerSessionId = const Uuid().v4();
  late final db.AiProfileDao _profileDao = _db.aiProfileDao;
  late final db.SettingsDao _settingsDao = _db.settingsDao;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void>? _migration;
  bool _migrationDone = false;
  late final AiCredentialGuard _guard = AiCredentialGuard(_db);

  Future<T> _run<T>(Future<T> Function() action) {
    if (Zone.current[this] == true) return action();
    return _guard.run(
      () => runZoned(() async {
        await _recoverOperations();
        await _ensureLegacyMigration();
        return action();
      }, zoneValues: {this: true}),
    );
  }

  Future<void> _prepare() => _run(() async {});

  Future<void> _recoverOperations() async {
    final operations = await (_db.select(
      _db.aiCredentialOperations,
    )..where((row) => row.phase.equals('pending'))).get();
    for (final operation in operations) {
      if (!const {
        'update',
        'writeSecret',
        'clearSecret',
        'deleteSecret',
      }.contains(operation.operation)) {
        throw const AiProfileException('无法恢复未知的凭证操作，请保留数据并检查应用版本');
      }
      if (operation.operation != 'update') {
        try {
          await _deleteSecret(operation.profileId);
        } on Object {
          throw const AiProfileException('密钥清理未完成，请检查系统安全存储后重试');
        }
      }
      await _profileDao.finishOperation(
        operation.id,
        DateTime.now().millisecondsSinceEpoch,
        phase: operation.operation == 'writeSecret' ? 'interrupted' : 'done',
      );
    }
  }

  Future<void> _deleteSecret(String profileId) async {
    final key = aiProfileApiKeyStorageKey(profileId);
    await _secureStore.delete(key);
    if (await _secureStore.hasValue(key)) {
      throw const AiProfileException('密钥清理未完成，请重试');
    }
  }

  @override
  Stream<List<AiProfile>> watchProfiles() => _watch(listProfiles);

  Stream<T> _watch<T>(Future<T> Function() read) {
    return Stream<void>.multi((controller) {
      final subscription = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
      controller.add(null);
    }).asyncMap((_) => read());
  }

  void dispose() {
    unawaited(_changes.close());
  }

  @override
  Future<List<AiProfile>> listProfiles() async {
    await _prepare();
    final rows = await _profileDao.activeProfiles();
    return Future.wait(rows.map(_fromRow));
  }

  @override
  Future<AiProfile?> getProfile(String id) async {
    await _prepare();
    final row = await _profileDao.profileById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<AiProfile> createProfile({
    required String name,
    String? sourceProfileId,
    bool copyCredential = false,
  }) => _run(() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final source = sourceProfileId == null
        ? null
        : await _profileDao.profileById(sourceProfileId);
    if (sourceProfileId != null &&
        (source == null || source.deletedAt != null)) {
      throw const AiProfileException('要复制的配置已不存在，请刷新后重试');
    }
    final sourceKey = copyCredential && sourceProfileId != null
        ? await _secureStore.read(aiProfileApiKeyStorageKey(sourceProfileId))
        : null;
    final id = _uuid.v4();
    await _profileDao.insertProfile(
      db.AiProfilesCompanion.insert(
        id: id,
        name: name.trim().isEmpty ? '新配置' : name.trim(),
        provider: Value(source?.provider ?? 'openai-compatible'),
        baseUrl: Value(source?.baseUrl ?? ''),
        model: Value(source?.model ?? ''),
        temperature: Value(source?.temperature ?? 0.2),
        maxTokens: Value(source?.maxTokens ?? 1200),
        streaming: Value(source?.streaming ?? true),
        systemPrompt: Value(source?.systemPrompt ?? ''),
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (sourceKey != null && sourceKey.isNotEmpty) {
      try {
        final created = await getProfile(id);
        if (created != null) {
          await updateProfile(
            created,
            apiKey: sourceKey,
            expectedRevision: created.revision,
          );
        }
      } catch (_) {
        await _profileDao.markDeleted(id, now);
        await _notify();
        rethrow;
      }
    }
    await _notify();
    return (await getProfile(id))!;
  });

  @override
  Future<AiProfile> updateProfile(
    AiProfile profile, {
    String? apiKey,
    required int expectedRevision,
  }) => _run(() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextRevision = expectedRevision + 1;
    final operationId = _uuid.v4();
    final changes = db.AiProfilesCompanion(
      id: Value(profile.id),
      name: Value(profile.name.trim()),
      provider: Value(profile.provider),
      baseUrl: Value(profile.baseUrl.trim()),
      model: Value(profile.model.trim()),
      temperature: Value(profile.temperature),
      maxTokens: Value(profile.maxTokens),
      streaming: Value(profile.streaming),
      systemPrompt: Value(profile.systemPrompt),
      revision: Value(nextRevision),
      updatedAt: Value(now),
    );
    final writesSecret = apiKey != null && apiKey.isNotEmpty;
    await _db.transaction(() async {
      final current = await _profileDao.profileById(profile.id);
      if (current == null || current.deletedAt != null) {
        throw const AiProfileException('配置不存在');
      }
      if (current.revision != expectedRevision) {
        throw const AiProfileException('配置已被其他操作更新，请刷新后重试');
      }
      if (await _profileDao.hasPendingOperation(profile.id)) {
        throw const AiProfileException('配置正在更新，请稍后重试');
      }
      await _profileDao.openOperation(
        db.AiCredentialOperationsCompanion.insert(
          id: operationId,
          profileId: profile.id,
          operation: writesSecret ? 'writeSecret' : 'update',
          phase: 'pending',
          expectedRevision: nextRevision,
          ownerSessionId: _ownerSessionId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    try {
      if (writesSecret) {
        await _secureStore.write(aiProfileApiKeyStorageKey(profile.id), apiKey);
        if (await _secureStore.read(aiProfileApiKeyStorageKey(profile.id)) !=
            apiKey) {
          throw const AiProfileException('密钥写入未完成，请重试');
        }
      }
      await _db.transaction(() async {
        await _profileDao.updateProfile(changes);
        await _profileDao.finishOperation(operationId, now);
      });
    } on Object {
      if (!writesSecret) {
        await _profileDao.finishOperation(operationId, now, phase: 'failed');
      }
      await _notify();
      rethrow;
    }
    await _notify();
    return (await getProfile(profile.id))!;
  });

  @override
  Future<void> deleteProfile(String id, {String? replacementProfileId}) => _run(
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final active = await _settingsDao.getValue('ai.activeProfileId');
      final current = await _profileDao.profileById(id);
      if (current == null) throw const AiProfileException('配置不存在');
      if (replacementProfileId != null) {
        final replacement = await _profileDao.profileById(replacementProfileId);
        if (replacement == null ||
            replacement.deletedAt != null ||
            replacement.id == id) {
          throw const AiProfileException('请选择有效的替代配置');
        }
      }
      final operationId = _uuid.v4();
      await _db.transaction(() async {
        await _profileDao.openOperation(
          db.AiCredentialOperationsCompanion.insert(
            id: operationId,
            profileId: id,
            operation: 'deleteSecret',
            phase: 'pending',
            expectedRevision: current.revision,
            ownerSessionId: _ownerSessionId,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _profileDao.markDeleted(id, now);
        if (active == id) {
          await _settingsDao.setValue(
            'ai.activeProfileId',
            replacementProfileId ?? '',
            now,
          );
          if (replacementProfileId == null) {
            await _settingsDao.setValue('ai.enabled', 'false', now);
          }
        }
      });
      try {
        await _deleteSecret(id);
        await _profileDao.finishOperation(operationId, now);
      } finally {
        await _notify();
      }
    },
  );

  @override
  Future<void> setActiveProfile(String? id) => _run(() async {
    if (id != null) {
      final row = await _profileDao.profileById(id);
      if (row == null || row.deletedAt != null) {
        throw const AiProfileException('配置不存在');
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _settingsDao.setValue('ai.activeProfileId', id ?? '', now);
    await _notify();
  });

  @override
  Stream<AiSettings> watchSettings() => _watch(getSettings);

  @override
  Future<AiSettings> getSettings() async {
    final profiles = await listProfiles();
    final activeId = await _settingsDao.getValue('ai.activeProfileId');
    final enabled = await _settingsDao.getValue('ai.enabled') == 'true';
    final confirm =
        await _settingsDao.getValue('privacy.confirmBeforeAiRequest') == 'true';
    final legacy = await _readLegacySettings();
    final active = profiles
        .where((profile) => profile.id == activeId)
        .firstOrNull;
    final selected = active ?? profiles.firstOrNull;
    return AiSettings(
      enabled: enabled,
      activeProfileId: selected?.id,
      profileName: selected?.name ?? '默认配置',
      profileRevision: selected?.revision ?? 1,
      profileIds: profiles.map((profile) => profile.id).toList(),
      profileNames: {for (final profile in profiles) profile.id: profile.name},
      provider: selected?.provider ?? legacy.provider,
      baseUrl: selected?.baseUrl ?? legacy.baseUrl,
      model: selected?.model ?? legacy.model,
      temperature: selected?.temperature ?? legacy.temperature,
      maxTokens: selected?.maxTokens ?? legacy.maxTokens,
      streaming: selected?.streaming ?? legacy.streaming,
      systemPrompt: selected?.systemPrompt ?? legacy.systemPrompt,
      confirmBeforeRequest: confirm,
      hasApiKey: selected?.hasApiKey ?? legacy.hasApiKey,
      credentialState: selected?.credentialState ?? 'missing',
    );
  }

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) =>
      _run(() async {
        final profileId = settings.activeProfileId;
        var profile = profileId == null ? null : await getProfile(profileId);
        if (profileId != null && profile == null) {
          throw const AiProfileException('配置不存在');
        }
        if (profile == null &&
            (settings.baseUrl.isNotEmpty ||
                settings.model.isNotEmpty ||
                settings.systemPrompt.isNotEmpty ||
                (apiKey?.isNotEmpty ?? false))) {
          profile = await createProfile(name: settings.profileName);
          await setActiveProfile(profile.id);
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        if (profile != null) {
          await updateProfile(
            AiProfile(
              id: profile.id,
              name: profile.name,
              provider: settings.provider,
              baseUrl: settings.baseUrl,
              model: settings.model,
              temperature: settings.temperature,
              maxTokens: settings.maxTokens,
              streaming: settings.streaming,
              systemPrompt: settings.systemPrompt,
              revision: profile.revision,
              hasApiKey: profile.hasApiKey,
              credentialState: profile.credentialState,
            ),
            apiKey: apiKey,
            expectedRevision: profileId == null
                ? profile.revision
                : settings.profileRevision,
          );
        }
        await _db.transaction(() async {
          await _settingsDao.setValue('ai.enabled', '${settings.enabled}', now);
          await _settingsDao.setValue(
            'privacy.confirmBeforeAiRequest',
            '${settings.confirmBeforeRequest}',
            now,
          );
        });
        await _notify();
      });

  @override
  Future<void> clearApiKey() => _run(() async {
    final settings = await getSettings();
    final id = settings.activeProfileId;
    if (id == null) {
      await _secureStore.delete(aiApiKeyStorageKey);
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      final operationId = _uuid.v4();
      await _db.transaction(() async {
        await _profileDao.openOperation(
          db.AiCredentialOperationsCompanion.insert(
            id: operationId,
            profileId: id,
            operation: 'clearSecret',
            phase: 'pending',
            expectedRevision: settings.profileRevision + 1,
            ownerSessionId: _ownerSessionId,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _profileDao.updateProfile(
          db.AiProfilesCompanion(
            id: Value(id),
            revision: Value(settings.profileRevision + 1),
            updatedAt: Value(now),
          ),
        );
      });
      await _deleteSecret(id);
      await _profileDao.finishOperation(operationId, now);
    }
    await _notify();
  });

  Future<AiProfile> _fromRow(db.AiProfileRow row) async {
    final key = aiProfileApiKeyStorageKey(row.id);
    String state = 'missing';
    var hasApiKey = false;
    try {
      hasApiKey = await _secureStore.hasValue(key);
      if (hasApiKey) state = 'configured';
    } on Object {
      state = 'unavailable';
    }
    final pending = await _profileDao.hasPendingOperation(row.id);
    if (pending) {
      state = 'pendingCleanup';
      hasApiKey = false;
    } else if (!hasApiKey && state != 'unavailable') {
      final interrupted =
          await (_db.select(_db.aiCredentialOperations)
                ..where(
                  (operation) =>
                      operation.profileId.equals(row.id) &
                      operation.phase.equals('interrupted'),
                )
                ..limit(1))
              .get();
      if (interrupted.isNotEmpty) state = 'interrupted';
    }
    return AiProfile(
      id: row.id,
      name: row.name,
      provider: row.provider,
      baseUrl: row.baseUrl,
      model: row.model,
      temperature: row.temperature,
      maxTokens: row.maxTokens,
      streaming: row.streaming,
      systemPrompt: row.systemPrompt,
      revision: row.revision,
      hasApiKey: hasApiKey,
      credentialState: state,
    );
  }

  Future<_LegacyAiSettings> _readLegacySettings() async {
    Future<String?> value(String key) => _settingsDao.getValue(key);
    var hasApiKey = false;
    final migrationState = await value('ai.profileMigrationState');
    if (migrationState != 'done' && migrationState != 'empty') {
      try {
        hasApiKey = await _secureStore.hasValue(aiApiKeyStorageKey);
      } on Object {
        hasApiKey = false;
      }
    }
    return _readLegacySettingsWithoutSecret(hasApiKey: hasApiKey);
  }

  Future<void> _notify() async {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> _ensureLegacyMigration() async {
    if (_migrationDone) return;
    final pending = _migration;
    if (pending != null) return pending;
    final future = _runLegacyMigration();
    _migration = future;
    try {
      await future;
      final state = await _settingsDao.getValue('ai.profileMigrationState');
      _migrationDone = state == 'done' || state == 'empty';
    } finally {
      if (identical(_migration, future)) _migration = null;
    }
  }

  Future<void> _runLegacyMigration() async {
    final state = await _settingsDao.getValue('ai.profileMigrationState');
    if (state == 'done' || state == 'empty') return;
    final existing = await _profileDao.activeProfiles();
    if (existing.isNotEmpty) {
      final legacyId = _uuid.v5(
        Namespace.url.value,
        'pagesage:legacy-ai-profile',
      );
      final legacy = existing
          .where((profile) => profile.id == legacyId)
          .firstOrNull;
      if (legacy == null || (state != 'migrating' && state != 'pending')) {
        await _settingsDao.setValue(
          'ai.profileMigrationState',
          'done',
          DateTime.now().millisecondsSinceEpoch,
        );
        return;
      }
      await _completeLegacyCredentialMigration(legacy.id);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final legacy = await _readLegacySettingsWithoutSecret();
    bool oldKeyExists;
    try {
      oldKeyExists = await _secureStore.hasValue(aiApiKeyStorageKey);
    } on Object {
      await _settingsDao.setValue('ai.profileMigrationState', 'pending', now);
      return;
    }
    if (legacy.baseUrl.isEmpty &&
        legacy.model.isEmpty &&
        legacy.systemPrompt.isEmpty &&
        !oldKeyExists) {
      await _settingsDao.setValue('ai.profileMigrationState', 'empty', now);
      return;
    }
    final id = _uuid.v5(Namespace.url.value, 'pagesage:legacy-ai-profile');
    await _settingsDao.setValue('ai.profileMigrationState', 'migrating', now);
    await _profileDao.insertProfile(
      db.AiProfilesCompanion.insert(
        id: id,
        name: '默认配置',
        provider: Value(legacy.provider),
        baseUrl: Value(legacy.baseUrl),
        model: Value(legacy.model),
        temperature: Value(legacy.temperature),
        maxTokens: Value(legacy.maxTokens),
        streaming: Value(legacy.streaming),
        systemPrompt: Value(legacy.systemPrompt),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _completeLegacyCredentialMigration(id);
  }

  Future<void> _completeLegacyCredentialMigration(String profileId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool oldKeyExists;
    try {
      oldKeyExists = await _secureStore.hasValue(aiApiKeyStorageKey);
    } on Object {
      await _settingsDao.setValue('ai.profileMigrationState', 'pending', now);
      return;
    }
    if (oldKeyExists) {
      try {
        final key = await _secureStore.read(aiApiKeyStorageKey);
        if (key != null && key.isNotEmpty) {
          final targetKey = aiProfileApiKeyStorageKey(profileId);
          await _secureStore.write(targetKey, key);
          final verify = await _secureStore.read(targetKey);
          if (verify != key) {
            throw StateError('credential verification failed');
          }
        }
      } on Object {
        await _settingsDao.setValue('ai.profileMigrationState', 'pending', now);
        return;
      }
    }
    await _settingsDao.setValue('ai.activeProfileId', profileId, now);
    await _settingsDao.setValue('ai.profileMigrationState', 'done', now);
    if (oldKeyExists) {
      try {
        await _secureStore.delete(aiApiKeyStorageKey);
      } on Object {
        // The new profile is verified; cleanup can be retried separately.
      }
    }
    // Keep the legacy non-sensitive values as a read-only fallback. The
    // migrated profile is now the single active credential path.
  }

  Future<_LegacyAiSettings> _readLegacySettingsWithoutSecret({
    bool hasApiKey = false,
  }) async {
    Future<String?> value(String key) => _settingsDao.getValue(key);
    return _LegacyAiSettings(
      provider: await value('ai.provider') ?? 'openai-compatible',
      baseUrl: await value('ai.baseUrl') ?? '',
      model: await value('ai.model') ?? '',
      temperature: double.tryParse(await value('ai.temperature') ?? '') ?? 0.2,
      maxTokens: int.tryParse(await value('ai.maxTokens') ?? '') ?? 1200,
      streaming: await value('ai.streaming') != 'false',
      systemPrompt: await value('ai.systemPrompt') ?? '',
      hasApiKey: hasApiKey,
    );
  }
}

final class _LegacyAiSettings {
  const _LegacyAiSettings({
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.temperature,
    required this.maxTokens,
    required this.streaming,
    required this.systemPrompt,
    required this.hasApiKey,
  });

  final String provider;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final bool streaming;
  final String systemPrompt;
  final bool hasApiKey;
}
