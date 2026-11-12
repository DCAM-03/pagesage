import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/database/drift_ai_conversation_repository.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:pagesage/features/ai/application/evidence_policy.dart';

void main() {
  test(
    'v6 upgrade preserves conversation and links without inventing a snapshot',
    () async {
      final sqlite = sqlite3.openInMemory();
      final fresh = AppDatabase.forTesting(
        NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
      );
      await fresh.aiConversationDao.insertConversation(
        AiConversationsCompanion.insert(
          id: 'old',
          bookId: const Value('book-a'),
          threadId: const Value('thread-a'),
          provider: 'local',
          model: 'model',
          prompt: '旧问题',
          answer: '旧回答',
          contextText: const Value('旧上下文'),
          sourceText: const Value('旧来源'),
          noteId: const Value('note-a'),
          createdAt: 7,
        ),
      );
      await fresh.close();
      sqlite.execute(
        'ALTER TABLE ai_conversations DROP COLUMN context_snapshot',
      );
      sqlite.execute('PRAGMA user_version = 6');
      final database = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
      addTearDown(database.close);
      final repository = DriftAiConversationRepository(
        database.aiConversationDao,
        DriftSearchRepository(database.searchDao),
      );
      final rows = await repository.getConversations();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.id, 'old');
      expect(row.threadId, 'thread-a');
      expect(row.noteId, 'note-a');
      expect(row.contextText, '旧上下文');
      expect(row.sourceText, '旧来源');
      expect(row.answer, '旧回答');
      expect(row.createdAt, 7);
      expect(row.contextSnapshot, isNull);
      expect(database.schemaVersion, 12);
    },
  );

  test(
    'sources and insertion order survive closing and reopening SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pagesage-ai-snapshot-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/reader.sqlite');
      final database = AppDatabase.forTesting(NativeDatabase(file));
      final repository = DriftAiConversationRepository(
        database.aiConversationDao,
        DriftSearchRepository(database.searchDao),
      );
      final snapshot = AiContextSnapshot(
        range: 'folder',
        references: [
          AiContextReference(
            id: 'ref-7',
            title: '第 42 页',
            text: '跨书原文',
            bookId: 'book-b',
            bookTitle: '乙书',
            locator: ReadingLocator.pdf(page: 42),
            sourceKey: 'book-b:42',
            startOffset: 3,
            endOffset: 7,
          ),
        ],
      );
      final saved = await repository.saveConversation(
        id: 'first',
        bookId: 'book-a',
        provider: 'local',
        model: 'm',
        prompt: '第一问',
        answer: '第一答',
        contextText: '跨书原文',
        contextSnapshot: snapshot,
        threadId: 'thread-a',
      );
      await database.aiConversationDao.insertConversation(
        AiConversationsCompanion.insert(
          id: 'second',
          bookId: const Value('book-a'),
          provider: 'local',
          model: 'm',
          prompt: '第二问',
          answer: '第二答',
          createdAt: saved.createdAt,
          threadId: const Value('thread-a'),
        ),
      );
      await database.close();
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);
      final restored = await DriftAiConversationRepository(
        reopened.aiConversationDao,
        DriftSearchRepository(reopened.searchDao),
      ).getConversations();
      expect(restored.map((turn) => turn.id), ['second', 'first']);
      expect(
        restored.last.contextSnapshot?.toJsonText(),
        snapshot.toJsonText(),
      );
      expect(
        restored.last.contextSnapshot?.references.single.locator?.page,
        42,
      );
      expect(restored.last.contextSnapshot?.references.single.bookId, 'book-b');
    },
  );

  test('v2 snapshot rejects duplicate citation ids and excess references', () {
    const duplicate = AiContextReference(
      id: 'ref-1',
      title: '甲',
      text: '原文',
      citationId: 'R1',
    );
    final duplicated = AiContextSnapshot(
      range: 'wholeBook',
      references: [
        duplicate,
        AiContextReference(
          id: 'ref-2',
          title: '乙',
          text: '另一段',
          citationId: 'R1',
        ),
      ],
      version: 2,
    );
    expect(
      () => AiContextSnapshot.fromJsonText(duplicated.toJsonText()),
      throwsFormatException,
    );

    final tooMany = AiContextSnapshot(
      range: 'wholeBook',
      references: [
        for (
          var index = 0;
          index < AiContextSerializerV1.maxReferences + 1;
          index += 1
        )
          AiContextReference(id: 'ref-$index', title: '来源', text: '原文 $index'),
      ],
      version: 2,
    );
    expect(
      () => AiContextSnapshot.fromJsonText(tooMany.toJsonText()),
      throwsFormatException,
    );
  });
}
