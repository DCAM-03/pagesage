import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/database/drift_ai_profile_repository.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/core/security/security_keys.dart';
import 'package:pagesage/domain/ai/ai_models.dart';

void main() {
  late AppDatabase database;
  late SecureStore secrets;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    secrets = SecureStore.memory();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(secrets),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('both interfaces publish writes to existing subscribers', () async {
    final settings = container.read(aiSettingsRepositoryProvider);
    final profiles = container.read(aiProfileRepositoryProvider);
    final settingsEvents = <AiSettings>[];
    final profileEvents = <List<AiProfile>>[];
    final settingsSubscription = settings.watchSettings().listen(
      settingsEvents.add,
    );
    final profileSubscription = profiles.watchProfiles().listen(
      profileEvents.add,
    );
    addTearDown(settingsSubscription.cancel);
    addTearDown(profileSubscription.cancel);
    await pumpEventQueue();

    final profile = await profiles.createProfile(name: '本地模型');
    await profiles.setActiveProfile(profile.id);
    await pumpEventQueue();
    expect(settingsEvents.last.activeProfileId, profile.id);

    final current = await settings.getSettings();
    await settings.saveSettings(current.copyWith(model: 'updated-model'));
    await pumpEventQueue();
    expect(profileEvents.last.single.model, 'updated-model');
  });

  test('first save creates a profile and stores only its credential', () async {
    final repository = container.read(aiSettingsRepositoryProvider);
    final empty = await repository.getSettings();
    await repository.saveSettings(
      empty.copyWith(
        enabled: true,
        baseUrl: 'https://example.test/v1',
        model: 'first-model',
      ),
      apiKey: 'test-secret',
    );

    final saved = await repository.getSettings();
    expect(saved.activeProfileId, isNotNull);
    expect(saved.model, 'first-model');
    expect(saved.hasApiKey, isTrue);
    expect(await secrets.read(aiApiKeyStorageKey), isNull);
    expect(
      await secrets.read(aiProfileApiKeyStorageKey(saved.activeProfileId!)),
      'test-secret',
    );
  });

  test('updates during the initial read are not lost', () async {
    final gatedSecrets = _ReadGateSecureStore();
    final repository = DriftAiProfileRepository(database, gatedSecrets);
    addTearDown(repository.dispose);
    final profile = await repository.createProfile(name: 'old');
    final readGate = Completer<void>();
    gatedSecrets.nextRead = readGate;
    final events = <List<AiProfile>>[];
    final updated = Completer<void>();
    final subscription = repository.watchProfiles().listen((profiles) {
      events.add(profiles);
      if (profiles.single.name == 'new' && !updated.isCompleted) {
        updated.complete();
      }
    });
    addTearDown(subscription.cancel);
    await gatedSecrets.readStarted.future;
    await repository.updateProfile(
      AiProfile(id: profile.id, name: 'new'),
      expectedRevision: profile.revision,
    );
    readGate.complete();
    await updated.future.timeout(const Duration(seconds: 2));
    expect(events.last.single.name, 'new');
  });

  test('provider disposal closes both interface subscriptions', () async {
    final profilesClosed = Completer<void>();
    final settingsClosed = Completer<void>();
    final profiles = container.read(aiProfileRepositoryProvider);
    final settings = container.read(aiSettingsRepositoryProvider);
    final profileSubscription = profiles.watchProfiles().listen(
      (_) {},
      onDone: profilesClosed.complete,
    );
    final settingsSubscription = settings.watchSettings().listen(
      (_) {},
      onDone: settingsClosed.complete,
    );
    addTearDown(profileSubscription.cancel);
    addTearDown(settingsSubscription.cancel);
    await pumpEventQueue();
    container.dispose();
    await Future.wait([
      profilesClosed.future,
      settingsClosed.future,
    ]).timeout(const Duration(seconds: 2));
  });

  test('saving a stale settings snapshot rejects the lost update', () async {
    final profiles = container.read(aiProfileRepositoryProvider);
    final settings = container.read(aiSettingsRepositoryProvider);
    final original = await profiles.createProfile(name: 'original');
    final stale = await settings.getSettings();
    await profiles.updateProfile(
      AiProfile(id: original.id, name: 'external', model: 'external-model'),
      expectedRevision: original.revision,
    );
    await expectLater(
      settings.saveSettings(stale.copyWith(model: 'stale-model')),
      throwsA(isA<AiProfileException>()),
    );
    expect((await settings.getSettings()).model, 'external-model');
  });

  test('concurrent edits with the same revision cannot both commit', () async {
    final repository = container.read(aiProfileRepositoryProvider);
    final original = await repository.createProfile(name: '原始配置');
    final outcomes = await Future.wait(
      ['first', 'second'].map((name) async {
        try {
          return await repository.updateProfile(
            AiProfile(id: original.id, name: name),
            apiKey: '$name-secret',
            expectedRevision: original.revision,
          );
        } on AiProfileException catch (error) {
          return error;
        }
      }),
    );

    expect(outcomes.whereType<AiProfile>(), hasLength(1));
    expect(outcomes.whereType<AiProfileException>(), hasLength(1));
    final winner = outcomes.whereType<AiProfile>().single;
    expect((await repository.getProfile(original.id))?.name, winner.name);
    expect(
      await secrets.read(aiProfileApiKeyStorageKey(original.id)),
      '${winner.name}-secret',
    );
  });
}

final class _ReadGateSecureStore extends SecureStore {
  _ReadGateSecureStore() : super.memory();

  Completer<void>? nextRead;
  final readStarted = Completer<void>();

  @override
  Future<String?> read(String key) async {
    final gate = nextRead;
    if (gate != null) {
      nextRead = null;
      readStarted.complete();
      await gate.future;
    }
    return super.read(key);
  }
}
