import 'dart:io';

import '../../../core/database/app_database.dart';
import '../../../core/files/app_paths.dart';

final class LocalDataService {
  const LocalDataService({
    required AppDatabase database,
    required AppPaths appPaths,
    Future<void> Function()? clearSecrets,
  }) : this._(database, appPaths, clearSecrets);

  const LocalDataService._(this._database, this._appPaths, this._clearSecrets);

  final AppDatabase _database;
  final AppPaths _appPaths;
  final Future<void> Function()? _clearSecrets;

  Future<void> deleteAllLocalData() async {
    final databaseFile = await _appPaths.databaseFile();
    await _database.transaction(() async {
      await _database.customStatement('DELETE FROM search_chunks');
      await _database.customStatement('DELETE FROM ai_conversations');
      await _database.customStatement('DELETE FROM note_tags');
      await _database.customStatement('DELETE FROM notes');
      await _database.customStatement('DELETE FROM annotations');
      await _database.customStatement('DELETE FROM bookmarks');
      await _database.customStatement('DELETE FROM reading_progress');
      await _database.customStatement('DELETE FROM book_tags');
      await _database.customStatement('DELETE FROM tags');
      await _database.customStatement('DELETE FROM categories');
      await _database.customStatement('DELETE FROM import_tasks');
      await _database.customStatement('DELETE FROM books');
      await _database.customStatement('DELETE FROM app_settings');
    });
    await _clearSecrets?.call();
    await _database.close();
    await _deleteFile(databaseFile);
    await _deleteFile(File('${databaseFile.path}-wal'));
    await _deleteFile(File('${databaseFile.path}-shm'));
    await _deleteDirectory(await _appPaths.libraryDirectory());
    await _deleteDirectory(await _appPaths.cacheDirectory());
  }

  Future<void> _deleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
