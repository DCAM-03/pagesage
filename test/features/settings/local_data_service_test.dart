import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/core/security/security_keys.dart';
import 'package:pagesage/features/settings/application/local_data_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pagesage_local_data_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('deletes database file library cache and clears secrets', () async {
    var secretsCleared = false;
    final appPaths = AppPaths();
    final databaseFile = await appPaths.databaseFile();
    await databaseFile.parent.create(recursive: true);
    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await database.customSelect('SELECT 1').get();
    final library = await appPaths.libraryDirectory();
    await library.create(recursive: true);
    await File(p.join(library.path, 'book.epub')).writeAsString('book');
    final cache = await appPaths.cacheDirectory();
    await cache.create(recursive: true);
    await File(p.join(cache.path, 'cache.tmp')).writeAsString('cache');

    await LocalDataService(
      database: database,
      appPaths: appPaths,
      clearSecrets: () async => secretsCleared = true,
    ).deleteAllLocalData();

    expect(secretsCleared, isTrue);
    expect(await databaseFile.exists(), isFalse);
    expect(await library.exists(), isFalse);
    expect(await cache.exists(), isFalse);
  });

  test('clears credentials for active and deleted profiles', () async {
    final file = await AppPaths().databaseFile();
    final database = AppDatabase.forTesting(NativeDatabase(file));
    final store = SecureStore.memory(
      seed: {
        aiApiKeyStorageKey: 'legacy',
        aiProfileApiKeyStorageKey('active'): 'active-secret',
        aiProfileApiKeyStorageKey('deleted'): 'deleted-secret',
        'unrelated': 'retained',
      },
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    for (final id in ['active', 'deleted']) {
      await database.aiProfileDao.insertProfile(
        AiProfilesCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
          deletedAt: Value(id == 'deleted' ? 2 : null),
        ),
      );
    }
    await container.read(localDataServiceProvider).deleteAllLocalData();
    expect(await store.read(aiApiKeyStorageKey), isNull);
    expect(await store.read(aiProfileApiKeyStorageKey('active')), isNull);
    expect(await store.read(aiProfileApiKeyStorageKey('deleted')), isNull);
    expect(await store.read('unrelated'), 'retained');
    expect(await file.exists(), isFalse);
  });

  test('credential failure preserves database for retry', () async {
    final paths = AppPaths();
    final file = await paths.databaseFile();
    final database = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(database.close);
    await database.settingsDao.setValue('test.preserved', 'original', 1);
    await expectLater(
      LocalDataService(
        database: database,
        appPaths: paths,
        clearSecrets: () async => throw StateError('credential store locked'),
      ).deleteAllLocalData(),
      throwsStateError,
    );
    expect(await file.exists(), isTrue);
    expect(await database.settingsDao.getValue('test.preserved'), 'original');
  });
}

final class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}
