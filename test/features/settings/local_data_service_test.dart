import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/files/app_paths.dart';
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
}

final class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}
