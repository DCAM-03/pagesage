import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('upgrading from v3 adds thread_id and keeps existing rows', () async {
    final sqlite = sqlite3.openInMemory();

    // Build a current-schema file, then rewind it to the v3 shape: drop the
    // column the migration adds, put a row in, and set the old version. Doing
    // it this way keeps every other table and index the app expects, so the
    // upgrade path under test is the real one.
    final fresh = AppDatabase.forTesting(
      NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
    );
    final row = AiConversationsCompanion.insert(
      id: 'conv-old',
      bookId: const Value('book-1'),
      provider: 'openai-compatible',
      model: 'm',
      prompt: '旧问题',
      answer: '旧回答',
      createdAt: 1,
    );
    await fresh.aiConversationDao.insertConversation(row);
    await fresh.close();

    sqlite.execute('ALTER TABLE ai_conversations DROP COLUMN thread_id');
    sqlite.execute('ALTER TABLE ai_conversations DROP COLUMN context_snapshot');
    // Rewinding to v3 also has to remove what v5 adds, otherwise the upgrade
    // under test finds the columns already there.
    sqlite.execute('ALTER TABLE annotations DROP COLUMN target');
    sqlite.execute('ALTER TABLE annotations DROP COLUMN image_anchor');
    sqlite.execute('PRAGMA user_version = 3');
    expect(
      sqlite.select('SELECT COUNT(*) AS c FROM ai_conversations').first['c'],
      1,
    );

    final database = AppDatabase.forTesting(
      NativeDatabase.opened(sqlite, closeUnderlyingOnClose: true),
    );
    addTearDown(database.close);

    final rows = await database.aiConversationDao.getConversations();

    expect(rows, hasLength(1), reason: 'the migration must not clear data');
    expect(rows.single.id, 'conv-old');
    expect(rows.single.prompt, '旧问题');
    // A pre-existing conversation is a single turn; it gets no invented thread.
    expect(rows.single.threadId, isNull);
  });

  test('a conversation saved after the upgrade can carry a thread', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.aiConversationDao.insertConversation(
      AiConversationsCompanion.insert(
        id: 'conv-new',
        provider: 'openai-compatible',
        model: 'm',
        prompt: '问题',
        answer: '回答',
        threadId: const Value('thread-1'),
        createdAt: 2,
      ),
    );

    final rows = await database.aiConversationDao.getConversations();
    expect(rows.single.threadId, 'thread-1');
  });
}
