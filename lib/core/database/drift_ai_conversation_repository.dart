import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/ai/ai_models.dart';
import '../../domain/books/reading_position.dart';
import '../../domain/search/search_models.dart' as domain;
import '../../domain/books/locator_excerpt.dart';
import 'drift_locator_mapping.dart';
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftAiConversationRepository
    implements AiConversationRepository, DetailedAiConversationRepository {
  const DriftAiConversationRepository(this._dao, this._searchRepository);

  final db.AiConversationDao _dao;
  final domain.SearchRepository _searchRepository;

  @override
  Stream<List<AiConversation>> watchConversations() {
    return _dao.watchConversations().map(
      (rows) => rows.map(_mapConversation).toList(growable: false),
    );
  }

  @override
  Future<List<AiConversation>> getConversations() async {
    final rows = await _dao.getConversations();
    return rows.map(_mapConversation).toList(growable: false);
  }

  @override
  Future<AiConversation> saveConversation({
    String? id,
    String? bookId,
    ReadingLocator? locator,
    required String provider,
    required String model,
    required String prompt,
    String? contextText,
    required String answer,
    String? sourceText,
    String? threadId,
    AiContextSnapshot? contextSnapshot,
  }) {
    return saveConversationDetailed(
      id: id,
      bookId: bookId,
      locator: locator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      threadId: threadId,
      contextSnapshot: contextSnapshot,
    );
  }

  @override
  Future<AiConversation> saveConversationDetailed({
    String? id,
    String? bookId,
    ReadingLocator? locator,
    required String provider,
    required String model,
    required String prompt,
    String? contextText,
    required String answer,
    String? sourceText,
    String? threadId,
    AiContextSnapshot? contextSnapshot,
    AiAnswerMeta? answerMeta,
    String? profileId,
    String? profileSnapshot,
  }) async {
    final resolvedLocator = locator == null
        ? null
        : enrichLocatorForJump(
            locator,
            fallbackExcerpt: sourceText ?? contextText,
          );
    final conversation = AiConversation(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      locator: resolvedLocator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      threadId: threadId,
      contextSnapshot: contextSnapshot,
      answerMeta: answerMeta,
      profileSnapshot: profileSnapshot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.insertConversation(
      db.AiConversationsCompanion.insert(
        id: conversation.id,
        bookId: Value(conversation.bookId),
        locator: Value(conversation.locator?.toJsonText()),
        provider: conversation.provider,
        model: conversation.model,
        prompt: conversation.prompt,
        contextText: Value(conversation.contextText),
        answer: conversation.answer,
        sourceText: Value(conversation.sourceText),
        threadId: Value(conversation.threadId),
        contextSnapshot: Value(conversation.contextSnapshot?.toJsonText()),
        profileId: Value(profileId),
        profileSnapshot: Value(profileSnapshot),
        answerMeta: Value(answerMeta?.toJsonText()),
        createdAt: conversation.createdAt,
      ),
    );
    await _searchRepository.indexText(
      sourceType: 'ai',
      sourceId: conversation.id,
      bookId: conversation.bookId,
      title: conversation.prompt,
      text: [conversation.prompt, conversation.answer].join('\n'),
      locator: conversation.locator,
    );
    return conversation;
  }

  @override
  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) {
    return _dao.linkNote(conversationId: conversationId, noteId: noteId);
  }

  @override
  Future<void> clearAll() async {
    await _dao.clearAll();
    await _searchRepository.deleteBySource('ai', null);
  }

  AiConversation _mapConversation(db.AiConversationRow row) {
    return AiConversation(
      id: row.id,
      bookId: row.bookId,
      locator: row.locator == null
          ? null
          : locatorFromDatabaseText(row.locator!),
      provider: row.provider,
      model: row.model,
      prompt: row.prompt,
      contextText: row.contextText,
      answer: row.answer,
      sourceText: row.sourceText,
      noteId: row.noteId,
      threadId: row.threadId,
      contextSnapshot: row.contextSnapshot == null
          ? null
          : AiContextSnapshot.fromJsonText(row.contextSnapshot!),
      answerMeta: row.answerMeta == null
          ? null
          : AiAnswerMeta.fromJsonText(row.answerMeta!),
      profileSnapshot: row.profileSnapshot,
      createdAt: row.createdAt,
    );
  }
}
