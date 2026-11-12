import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('v5 search chunks survive the parent-context migration', () async {
    final sqlite = sqlite3.openInMemory();
    final fresh = AppDatabase.forTesting(
      NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
    );
    await fresh.searchDao.upsertChunk(
      SearchChunksCompanion.insert(
        id: 'book:legacy:0',
        bookId: const Value('legacy-book'),
        sourceType: 'book',
        sourceId: const Value('legacy-book:chapter:0'),
        title: const Value('旧索引'),
        body: '旧索引正文仍然可搜索。',
        sortOrder: const Value(7),
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await fresh.close();

    sqlite.execute('DROP INDEX IF EXISTS idx_search_chunks_parent_id');
    sqlite.execute('DROP TABLE search_parent_chunks');
    sqlite.execute('ALTER TABLE search_chunks DROP COLUMN parent_id');
    sqlite.execute('PRAGMA user_version = 5');
    sqlite.execute('ALTER TABLE ai_conversations DROP COLUMN context_snapshot');

    final database = AppDatabase.forTesting(
      NativeDatabase.opened(sqlite, closeUnderlyingOnClose: true),
    );
    addTearDown(database.close);

    final chunks = await database.searchDao.bookChunks();

    expect(chunks, hasLength(1));
    expect(chunks.single.chunk.body, contains('旧索引正文'));
    expect(chunks.single.chunk.parentId, isNull);
  });
}
