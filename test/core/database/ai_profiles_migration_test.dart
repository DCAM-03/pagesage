import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_ai_profile_repository.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/core/security/security_keys.dart';
import 'package:pagesage/domain/ai/ai_models.dart';

void main() {
  late AppDatabase database;
  late SecureStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SecureStore.memory(seed: {aiApiKeyStorageKey: 'legacy-secret'});
  });

  tearDown(() => database.close());

  test('legacy single settings migrate into one verified profile', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.settingsDao.setValue(
      'ai.baseUrl',
      'https://legacy.example.test/v1',
      now,
    );
    await database.settingsDao.setValue('ai.model', 'legacy-model', now);
    await database.settingsDao.setValue('ai.temperature', '0.4', now);
    await database.settingsDao.setValue('ai.enabled', 'true', now);
    final repository = DriftAiProfileRepository(database, store);

    final profiles = await repository.listProfiles();
    final settings = await repository.getSettings();

    expect(profiles, hasLength(1));
    expect(profiles.single.name, '默认配置');
    expect(profiles.single.baseUrl, 'https://legacy.example.test/v1');
    expect(profiles.single.model, 'legacy-model');
    expect(profiles.single.hasApiKey, isTrue);
    expect(settings.activeProfileId, profiles.single.id);
    expect(
      await store.read(aiProfileApiKeyStorageKey(profiles.single.id)),
      'legacy-secret',
    );
    expect(await store.read(aiApiKeyStorageKey), isNull);
  });

  test('migration is idempotent across repository instances', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.settingsDao.setValue('ai.model', 'legacy-model', now);
    final first = DriftAiProfileRepository(database, store);
    final firstProfiles = await first.listProfiles();
    final second = DriftAiProfileRepository(database, store);
    final secondProfiles = await second.listProfiles();

    expect(
      secondProfiles.map((profile) => profile.id),
      firstProfiles.map((profile) => profile.id),
    );
    expect(
      await database.settingsDao.getValue('ai.profileMigrationState'),
      'done',
    );
  });

  test('no legacy configuration does not create a fake profile', () async {
    final emptyStore = SecureStore.memory();
    final repository = DriftAiProfileRepository(database, emptyStore);

    expect(await repository.listProfiles(), isEmpty);
    expect(
      await database.settingsDao.getValue('ai.profileMigrationState'),
      'empty',
    );
  });

  test('a secure-store read failure keeps migration pending', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.settingsDao.setValue('ai.model', 'legacy-model', now);
    final repository = DriftAiProfileRepository(
      database,
      _FailingReadSecureStore(),
    );

    expect(await repository.listProfiles(), isEmpty);
    expect(
      await database.settingsDao.getValue('ai.profileMigrationState'),
      'pending',
    );
  });

  test('copying a profile copies the secret only when requested', () async {
    final emptyStore = SecureStore.memory();
    final repository = DriftAiProfileRepository(database, emptyStore);
    final source = await repository.createProfile(name: '来源');
    final updated = await repository.updateProfile(
      source.copyWithForTest(
        baseUrl: 'https://source.example.test/v1',
        model: 'source-model',
      ),
      apiKey: 'source-secret',
      expectedRevision: source.revision,
    );

    final plain = await repository.createProfile(
      name: '复制',
      sourceProfileId: updated.id,
    );
    final withSecret = await repository.createProfile(
      name: '复制密钥',
      sourceProfileId: updated.id,
      copyCredential: true,
    );

    expect(plain.baseUrl, 'https://source.example.test/v1');
    expect(plain.model, 'source-model');
    expect(plain.hasApiKey, isFalse);
    expect(withSecret.hasApiKey, isTrue);
    expect(
      await emptyStore.read(aiProfileApiKeyStorageKey(withSecret.id)),
      'source-secret',
    );

    await repository.deleteProfile(withSecret.id);
    expect(
      await emptyStore.read(aiProfileApiKeyStorageKey(withSecret.id)),
      isNull,
    );
  });

  for (final reopen in [false, true]) {
    test('pending credential migration retries (reopen=$reopen)', () async {
      final failingStore = _RecoverableWriteSecureStore();
      await database.settingsDao.setValue('ai.model', 'legacy-model', 1);
      var repository = DriftAiProfileRepository(database, failingStore);
      final first = await repository.listProfiles();
      expect(first, hasLength(1));
      expect(first.single.hasApiKey, isFalse);
      expect(
        await database.settingsDao.getValue('ai.profileMigrationState'),
        'pending',
      );

      failingStore.failWrites = false;
      if (reopen) {
        repository = DriftAiProfileRepository(database, failingStore);
      }
      final retried = await repository.listProfiles();
      expect(retried.single.id, first.single.id);
      expect(retried.single.hasApiKey, isTrue);
      expect(
        await database.settingsDao.getValue('ai.activeProfileId'),
        first.single.id,
      );
      expect(
        await database.settingsDao.getValue('ai.profileMigrationState'),
        'done',
      );
      expect(await failingStore.read(aiApiKeyStorageKey), isNull);
    });
  }
}

final class _RecoverableWriteSecureStore extends SecureStore {
  _RecoverableWriteSecureStore()
    : super.memory(seed: {aiApiKeyStorageKey: 'legacy-secret'});

  bool failWrites = true;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw SecureStoreException.write(StateError('unavailable'));
    await super.write(key, value);
  }
}

final class _FailingReadSecureStore extends SecureStore {
  _FailingReadSecureStore() : super.memory();

  @override
  Future<String?> read(String key) async {
    throw SecureStoreException.read(StateError('unavailable'));
  }
}

extension on AiProfile {
  AiProfile copyWithForTest({required String baseUrl, required String model}) {
    return AiProfile(
      id: id,
      name: name,
      provider: provider,
      baseUrl: baseUrl,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      streaming: streaming,
      systemPrompt: systemPrompt,
      revision: revision,
      hasApiKey: hasApiKey,
      credentialState: credentialState,
    );
  }
}
