import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/drift_ai_profile_repository.dart';
import '../../../core/database/drift_ocr_job_repository.dart';
import '../../../core/security/secure_store.dart';

Future<void> prepareRestoredDatabase(AppDatabase database) async {
  final profiles = DriftAiProfileRepository(database, SecureStore.memory());
  try {
    await profiles.listProfiles();
  } finally {
    profiles.dispose();
  }
  final activeId = await database.settingsDao.getValue('ai.activeProfileId');
  final rows = await database.select(database.aiProfiles).get();
  final now = DateTime.now().millisecondsSinceEpoch;
  await database.transaction(() async {
    for (final row in rows) {
      final newId = const Uuid().v4();
      await database.customStatement(
        'UPDATE ai_profiles SET id = ? WHERE id = ?',
        [newId, row.id],
      );
      await database.customStatement(
        'UPDATE ai_conversations SET profile_id = ? WHERE profile_id = ?',
        [newId, row.id],
      );
      if (row.id == activeId) {
        await database.settingsDao.setValue('ai.activeProfileId', newId, now);
      }
    }
    await database.delete(database.aiCredentialOperations).go();
    await database.settingsDao.setValue(
      'ai.profileMigrationState',
      'done',
      now,
    );
    await database.customStatement(
      "UPDATE import_tasks SET status = CASE WHEN type = 'ocrPages' "
      "THEN 'paused' ELSE 'failed' END, message = '备份已恢复，请手动继续', "
      "updated_at = ? WHERE status IN ('queued', 'running', 'indexing')",
      [now],
    );
    await DriftOcrJobRepository(database).recoverInterrupted(liveTaskIds: {});
  });
}
