import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_ai_profile_repository.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/core/security/security_keys.dart';
import 'package:pagesage/domain/ai/ai_models.dart';

void main() {
  late Directory directory;
  late File file;
  late AppDatabase database;
  late _Secrets secrets;
  late DriftAiProfileRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pagesage-recovery-');
    file = File('${directory.path}/test.sqlite');
    database = AppDatabase.forTesting(NativeDatabase(file));
    secrets = _Secrets();
    repository = DriftAiProfileRepository(database, secrets);
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<AiProfile> seeded() async {
    final profile = await repository.createProfile(name: '配置');
    return repository.updateProfile(
      profile,
      apiKey: 'old-test-secret',
      expectedRevision: profile.revision,
    );
  }

  Future<void> interrupt(AiProfile profile, String operation) async {
    await database.aiProfileDao.openOperation(
      AiCredentialOperationsCompanion.insert(
        id: 'interrupted-operation',
        profileId: profile.id,
        operation: operation,
        phase: 'pending',
        expectedRevision: profile.revision + 1,
        ownerSessionId: 'dead-process',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    repository.dispose();
    await database.close();
    database = AppDatabase.forTesting(NativeDatabase(file));
    repository = DriftAiProfileRepository(database, secrets);
  }

  test(
    'file reopen removes uncertain credentials and permits a new save',
    () async {
      final profile = await seeded();
      await secrets.write(
        aiProfileApiKeyStorageKey(profile.id),
        'uncertain-secret',
      );
      await interrupt(profile, 'writeSecret');
      final recovered = (await repository.listProfiles()).single;
      expect(recovered.hasApiKey, isFalse);
      expect(recovered.credentialState, 'interrupted');
      expect(await secrets.read(aiProfileApiKeyStorageKey(profile.id)), isNull);
      expect(
        await database.aiProfileDao.hasPendingOperation(profile.id),
        isFalse,
      );
      final saved = await repository.updateProfile(
        recovered,
        apiKey: 'verified-new-secret',
        expectedRevision: recovered.revision,
      );
      expect(saved.hasApiKey, isTrue);
    },
  );

  test(
    'failed key write keeps configuration revision and allows retry',
    () async {
      final profile = await seeded();
      secrets.failWrite = true;
      await expectLater(
        repository.updateProfile(
          AiProfile(id: profile.id, name: '新名称'),
          apiKey: 'new-test-secret',
          expectedRevision: profile.revision,
        ),
        throwsStateError,
      );
      secrets.failWrite = false;
      final recovered = (await repository.getProfile(profile.id))!;
      expect(recovered.name, '配置');
      expect(recovered.revision, profile.revision);
      expect(recovered.hasApiKey, isFalse);
      await repository.updateProfile(
        recovered,
        apiKey: 'retry-secret',
        expectedRevision: recovered.revision,
      );
      expect(
        await secrets.read(aiProfileApiKeyStorageKey(profile.id)),
        'retry-secret',
      );
    },
  );

  test('failed delete stays journaled and recovers after reopen', () async {
    final profile = await seeded();
    secrets.failDelete = true;
    await expectLater(repository.deleteProfile(profile.id), throwsStateError);
    expect(await database.aiProfileDao.hasPendingOperation(profile.id), isTrue);
    repository.dispose();
    await database.close();
    database = AppDatabase.forTesting(NativeDatabase(file));
    repository = DriftAiProfileRepository(database, secrets);
    await expectLater(
      repository.listProfiles(),
      throwsA(isA<AiProfileException>()),
    );
    secrets.failDelete = false;
    expect(await repository.listProfiles(), isEmpty);
    expect(await secrets.read(aiProfileApiKeyStorageKey(profile.id)), isNull);
    expect(
      await database.aiProfileDao.hasPendingOperation(profile.id),
      isFalse,
    );
  });

  test('a failed credential copy leaves no phantom active profile', () async {
    final profile = await seeded();
    secrets.failWrite = true;
    await expectLater(
      repository.createProfile(
        name: '副本',
        sourceProfileId: profile.id,
        copyCredential: true,
      ),
      throwsStateError,
    );
    secrets.failWrite = false;
    final profiles = await repository.listProfiles();
    expect(profiles.map((row) => row.id), [profile.id]);
    expect(
      await secrets.read(aiProfileApiKeyStorageKey(profile.id)),
      'old-test-secret',
    );
    final copy = await repository.createProfile(
      name: '副本',
      sourceProfileId: profile.id,
      copyCredential: true,
    );
    expect(copy.hasApiKey, isTrue);
    expect(await repository.listProfiles(), hasLength(2));
  });

  test(
    'interrupted clear retries cleanup instead of marking a key usable',
    () async {
      final profile = await seeded();
      await repository.setActiveProfile(profile.id);
      secrets.failDelete = true;
      await expectLater(repository.clearApiKey(), throwsStateError);
      secrets.failDelete = false;
      final settings = await repository.getSettings();
      expect(settings.hasApiKey, isFalse);
      expect(settings.profileRevision, profile.revision + 1);
    },
  );

  test('a second connection cannot recover a live secret write', () async {
    final profile = await seeded();
    final otherDatabase = AppDatabase.forTesting(NativeDatabase(file));
    final other = DriftAiProfileRepository(otherDatabase, secrets);
    addTearDown(() async {
      other.dispose();
      await otherDatabase.close();
    });
    secrets.gate = Completer<void>();
    final updating = repository.updateProfile(
      profile,
      apiKey: 'live-secret',
      expectedRevision: profile.revision,
    );
    await secrets.started.future;
    var readFinished = false;
    final reading = other.listProfiles()..then((_) => readFinished = true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(readFinished, isFalse);
    secrets.gate!.complete();
    await updating;
    expect((await reading).single.hasApiKey, isTrue);
    expect(
      await secrets.read(aiProfileApiKeyStorageKey(profile.id)),
      'live-secret',
    );
  });

  test(
    'recovery waits for an external process lock and resumes after exit',
    () async {
      final profile = await seeded();
      await interrupt(profile, 'writeSecret');
      final lockPath = '${await file.resolveSymbolicLinks()}.credentials.lock';
      final dart = File.fromUri(
        File(Platform.resolvedExecutable).parent.uri.resolve(
          '../../../dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
        ),
      );
      final process = await Process.start(dart.path, [
        'test/support/hold_credential_lock.dart',
        lockPath,
      ]);
      addTearDown(() {
        process.kill();
      });
      final diagnostics = process.stderr.transform(utf8.decoder).join();
      expect(
        await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 10)),
        'locked',
      );
      var finished = false;
      final recovering = repository.listProfiles()
        ..then((_) => finished = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(finished, isFalse);
      expect(
        await secrets.read(aiProfileApiKeyStorageKey(profile.id)),
        'old-test-secret',
      );
      process.kill();
      await process.exitCode;
      await diagnostics;
      final recovered = await recovering;
      expect(recovered.single.hasApiKey, isFalse);
    },
  );
}

final class _Secrets extends SecureStore {
  _Secrets() : super.memory();

  bool failWrite = false;
  bool failDelete = false;
  Completer<void>? gate;
  final started = Completer<void>();

  @override
  Future<void> write(String key, String value) async {
    if (gate != null) {
      if (!started.isCompleted) started.complete();
      await gate!.future;
    }
    await super.write(key, value);
    if (failWrite) throw StateError('injected failure after write');
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('injected delete failure');
    await super.delete(key);
  }
}
