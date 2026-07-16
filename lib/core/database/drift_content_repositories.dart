import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/ai/ai_models.dart';
import '../../domain/annotations/annotation.dart' as domain;
import '../../domain/books/bookmark.dart' as domain;
import '../../domain/books/category.dart' as domain;
import '../../domain/books/reading_position.dart';
import '../../domain/books/tag.dart' as domain;
import '../../domain/notes/note.dart' as domain;
import '../../domain/search/search_models.dart' as domain;
import '../security/security_keys.dart';
import '../security/secure_store.dart';
import '../search/search_normalizer.dart';
import '../../renderers/epub/epub_jump.dart';
import '../tasks/task_models.dart' as domain;
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftCategoryRepository implements domain.CategoryRepository {
  const DriftCategoryRepository(this._dao);

  final db.CategoryDao _dao;

  @override
  Stream<List<domain.BookCategory>> watchCategories() {
    return _dao.watchCategories().map(
      (rows) => rows.map(_mapCategory).toList(growable: false),
    );
  }

  @override
  Future<List<domain.BookCategory>> getCategories() async {
    final rows = await _dao.getCategories();
    return rows.map(_mapCategory).toList(growable: false);
  }

  @override
  Future<domain.BookCategory> saveCategory({
    String? id,
    String? parentId,
    required String name,
    int sortOrder = 0,
    String? icon,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('分类名称不能为空');
    }
    final existing = await getCategories();
    if (existing.any(
      (category) => category.id != id && category.name == trimmedName,
    )) {
      throw const FormatException('分类名称已存在');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    domain.BookCategory? previous;
    for (final category in existing) {
      if (category.id == id) {
        previous = category;
        break;
      }
    }
    var resolvedSortOrder = sortOrder;
    if (previous == null && sortOrder == 0 && existing.isNotEmpty) {
      resolvedSortOrder =
          existing
              .map((category) => category.sortOrder)
              .reduce((value, element) => value > element ? value : element) +
          1024;
    }
    final category = domain.BookCategory(
      id: id ?? _uuid.v4(),
      parentId: parentId,
      name: trimmedName,
      sortOrder: resolvedSortOrder,
      icon: icon,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertCategory(
      db.CategoriesCompanion.insert(
        id: category.id,
        parentId: Value(category.parentId),
        name: category.name,
        sortOrder: Value(category.sortOrder),
        icon: Value(category.icon),
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
      ),
    );
    return category;
  }

  @override
  Future<void> deleteCategory(String id, {String? moveBooksToCategoryId}) {
    return _dao.deleteCategory(
      id,
      moveBooksToCategoryId: moveBooksToCategoryId,
    );
  }

  domain.BookCategory _mapCategory(db.CategoryRow row) {
    return domain.BookCategory(
      id: row.id,
      parentId: row.parentId,
      name: row.name,
      sortOrder: row.sortOrder,
      icon: row.icon,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final class DriftTagRepository implements domain.TagRepository {
  const DriftTagRepository(this._dao);

  final db.TagDao _dao;

  @override
  Stream<List<domain.BookTag>> watchTags() {
    return _dao.watchTags().map(
      (rows) => rows.map(_mapTag).toList(growable: false),
    );
  }

  @override
  Future<List<domain.BookTag>> getTags() async {
    final rows = await _dao.getTags();
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Future<List<domain.BookTag>> getTagsForBook(String bookId) async {
    final rows = await _dao.getTagsForBook(bookId);
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Stream<Map<String, List<domain.BookTag>>> watchTagsByBookId() {
    return _dao.watchTagsByBookId().map((raw) {
      return {
        for (final entry in raw.entries)
          entry.key: entry.value.map(_mapTag).toList(growable: false),
      };
    });
  }

  @override
  Future<Set<String>> getBookIdsWithTag(String tagId) {
    return _dao.getBookIdsWithTag(tagId);
  }

  @override
  Future<List<domain.BookTag>> getTagsForNote(String noteId) async {
    final rows = await _dao.getTagsForNote(noteId);
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Future<domain.BookTag> saveTag({
    String? id,
    required String name,
    String? color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('标签名称不能为空');
    }
    final existing = await getTags();
    if (existing.any((tag) => tag.id != id && tag.name == trimmedName)) {
      throw const FormatException('标签名称已存在');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    domain.BookTag? previous;
    for (final tag in existing) {
      if (tag.id == id) {
        previous = tag;
        break;
      }
    }
    final tag = domain.BookTag(
      id: id ?? _uuid.v4(),
      name: trimmedName,
      color: color,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertTag(
      db.TagsCompanion.insert(
        id: tag.id,
        name: tag.name,
        color: Value(tag.color),
        createdAt: tag.createdAt,
        updatedAt: tag.updatedAt,
      ),
    );
    return tag;
  }

  @override
  Future<void> setBookTags(String bookId, Iterable<String> tagIds) {
    return _dao.setBookTags(bookId, tagIds);
  }

  @override
  Future<void> setNoteTags(String noteId, Iterable<String> tagIds) {
    return _dao.setNoteTags(noteId, tagIds);
  }

  @override
  Future<void> deleteTag(String id) {
    return _dao.deleteTag(id);
  }

  domain.BookTag _mapTag(db.TagRow row) {
    return domain.BookTag(
      id: row.id,
      name: row.name,
      color: row.color,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final class DriftBookmarkRepository implements domain.BookmarkRepository {
  const DriftBookmarkRepository(this._dao, this._searchRepository);

  final db.BookmarkDao _dao;
  final domain.SearchRepository _searchRepository;

  @override
  Stream<List<domain.Bookmark>> watchByBook(String bookId) {
    return _dao
        .watchByBook(bookId)
        .map((rows) => rows.map(_mapBookmark).toList(growable: false));
  }

  @override
  Future<List<domain.Bookmark>> getByBook(String bookId) async {
    final rows = await _dao.getByBook(bookId);
    return rows.map(_mapBookmark).toList(growable: false);
  }

  @override
  Future<List<domain.Bookmark>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_mapBookmark).toList(growable: false);
  }

  @override
  Future<Set<String>> getBookIdsWithBookmarks() {
    return _dao.getBookIdsWithBookmarks();
  }

  @override
  Future<domain.Bookmark?> findAtLocator(
    String bookId,
    ReadingLocator locator,
  ) async {
    final bookmarks = await getByBook(bookId);
    for (final bookmark in bookmarks) {
      if (bookmark.locator.matches(locator)) {
        return bookmark;
      }
    }
    return null;
  }

  @override
  Future<domain.Bookmark> saveBookmark({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    String? title,
    String? note,
    String? excerpt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = id == null ? null : await _dao.getBookmark(id);
    final resolvedExcerpt = compactLocatorExcerpt(
      excerpt ?? locator.excerpt ?? note,
    );
    final resolvedLocator = enrichLocatorForJump(
      locator,
      fallbackExcerpt: resolvedExcerpt,
    );
    final bookmark = domain.Bookmark(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      locator: resolvedLocator,
      title: title,
      note: note,
      excerpt: resolvedExcerpt,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertBookmark(
      db.BookmarksCompanion.insert(
        id: bookmark.id,
        bookId: bookmark.bookId,
        locator: bookmark.locator.toJsonText(),
        title: Value(bookmark.title),
        note: Value(bookmark.note),
        excerpt: Value(bookmark.excerpt),
        createdAt: bookmark.createdAt,
        updatedAt: bookmark.updatedAt,
      ),
    );
    await _searchRepository.indexText(
      sourceType: 'bookmark',
      sourceId: bookmark.id,
      bookId: bookId,
      title: title ?? resolvedLocator.displayLabel,
      text: [note, resolvedExcerpt].whereType<String>().join('\n'),
      locator: resolvedLocator,
    );
    return bookmark;
  }

  @override
  Future<void> deleteBookmark(String id) async {
    await _dao.deleteBookmark(id);
    await _searchRepository.deleteBySource('bookmark', id);
  }

  domain.Bookmark _mapBookmark(db.BookmarkRow row) {
    return domain.Bookmark(
      id: row.id,
      bookId: row.bookId,
      locator: _locatorFromText(row.locator),
      title: row.title,
      note: row.note,
      excerpt: row.excerpt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final class DriftAnnotationRepository implements domain.AnnotationRepository {
  const DriftAnnotationRepository(this._dao);

  final db.AnnotationDao _dao;

  @override
  Stream<List<domain.Annotation>> watchByBook(String bookId) {
    return _dao
        .watchByBook(bookId)
        .map((rows) => rows.map(_mapAnnotation).toList(growable: false));
  }

  @override
  Future<List<domain.Annotation>> getByBook(String bookId) async {
    final rows = await _dao.getByBook(bookId);
    return rows.map(_mapAnnotation).toList(growable: false);
  }

  @override
  Future<List<domain.Annotation>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_mapAnnotation).toList(growable: false);
  }

  @override
  Future<domain.Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    domain.AnnotationColor color = domain.AnnotationColor.yellow,
    domain.AnnotationStyle style = domain.AnnotationStyle.highlight,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = id == null ? null : await _dao.getAnnotation(id);
    final resolvedLocator = enrichLocatorForJump(
      locator,
      fallbackExcerpt: selectedText,
    );
    final annotation = domain.Annotation(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      locator: resolvedLocator,
      selectedText: selectedText,
      color: color,
      style: style,
      noteId: previous?.noteId,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertAnnotation(
      db.AnnotationsCompanion.insert(
        id: annotation.id,
        bookId: annotation.bookId,
        locator: annotation.locator.toJsonText(),
        selectedText: annotation.selectedText,
        color: annotation.color.value,
        style: annotation.style.value,
        noteId: Value(annotation.noteId),
        createdAt: annotation.createdAt,
        updatedAt: annotation.updatedAt,
      ),
    );
    return annotation;
  }

  @override
  Future<void> linkNote({
    required String annotationId,
    required String noteId,
  }) {
    return _dao.linkNote(annotationId: annotationId, noteId: noteId);
  }

  @override
  Future<void> deleteAnnotation(String id) {
    return _dao.deleteAnnotation(id);
  }

  domain.Annotation _mapAnnotation(db.AnnotationRow row) {
    return domain.Annotation(
      id: row.id,
      bookId: row.bookId,
      locator: _locatorFromText(row.locator),
      selectedText: row.selectedText,
      color: domain.AnnotationColor.fromValue(row.color),
      style: domain.AnnotationStyle.fromValue(row.style),
      noteId: row.noteId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final class DriftNoteRepository implements domain.NoteRepository {
  const DriftNoteRepository(this._dao, this._searchRepository);

  final db.NoteDao _dao;
  final domain.SearchRepository _searchRepository;

  @override
  Stream<List<domain.Note>> watchNotes() {
    return _dao.watchNotes().map(
      (rows) => rows.map(_mapNote).toList(growable: false),
    );
  }

  @override
  Future<List<domain.Note>> getNotes() async {
    final rows = await _dao.getNotes();
    return rows.map(_mapNote).toList(growable: false);
  }

  @override
  Future<List<domain.Note>> getByBook(String bookId) async {
    final rows = await _dao.getByBook(bookId);
    return rows.map(_mapNote).toList(growable: false);
  }

  @override
  Future<Set<String>> getBookIdsWithNotes() {
    return _dao.getBookIdsWithNotes();
  }

  @override
  Future<domain.Note?> getNote(String id) async {
    final row = await _dao.getNote(id);
    return row == null ? null : _mapNote(row);
  }

  @override
  Future<domain.Note> saveNote({
    String? id,
    String? bookId,
    String? annotationId,
    String? title,
    required String content,
    String? sourceText,
    ReadingLocator? locator,
    domain.NoteType noteType = domain.NoteType.text,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = id == null ? null : await _dao.getNote(id);
    final resolvedLocator = locator == null
        ? null
        : enrichLocatorForJump(locator, fallbackExcerpt: sourceText);
    final note = domain.Note(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      annotationId: annotationId,
      title: title,
      content: content,
      sourceText: sourceText,
      locator: resolvedLocator,
      noteType: noteType,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertNote(
      db.NotesCompanion.insert(
        id: note.id,
        bookId: Value(note.bookId),
        annotationId: Value(note.annotationId),
        title: Value(note.title),
        content: note.content,
        sourceText: Value(note.sourceText),
        locator: Value(note.locator?.toJsonText()),
        noteType: note.noteType.value,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
    );
    await _searchRepository.indexText(
      sourceType: 'note',
      sourceId: note.id,
      bookId: note.bookId,
      title: note.title ?? '笔记',
      text: [note.sourceText, note.content].whereType<String>().join('\n'),
      locator: note.locator,
    );
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    await _dao.deleteNote(id);
    await _searchRepository.deleteBySource('note', id);
  }

  domain.Note _mapNote(db.NoteRow row) {
    return domain.Note(
      id: row.id,
      bookId: row.bookId,
      annotationId: row.annotationId,
      title: row.title,
      content: row.content,
      sourceText: row.sourceText,
      locator: row.locator == null ? null : _locatorFromText(row.locator!),
      noteType: domain.NoteType.fromValue(row.noteType),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final class DriftSearchRepository implements domain.SearchRepository {
  const DriftSearchRepository(
    this._dao, [
    this._normalizer = const SearchNormalizer(),
  ]);

  final db.SearchDao _dao;
  final SearchNormalizer _normalizer;

  @override
  Future<List<domain.SearchResult>> search(domain.SearchQuery query) async {
    final normalizedQuery = _normalizer.normalize(query.query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final typeFilters = query.typeFilters;
    final includeAllTypes = typeFilters.isEmpty;
    final rows = await _dao.search(
      _ftsQuery(normalizedQuery),
      rawQuery: normalizedQuery,
      includeBookResults:
          includeAllTypes || typeFilters.contains(domain.SearchResultType.book),
      includeContentResults:
          includeAllTypes ||
          typeFilters.contains(domain.SearchResultType.content),
      includeNoteResults:
          includeAllTypes || typeFilters.contains(domain.SearchResultType.note),
      includeBookmarkResults:
          includeAllTypes ||
          typeFilters.contains(domain.SearchResultType.bookmark),
      includeAiResults:
          includeAllTypes || typeFilters.contains(domain.SearchResultType.ai),
      bookId: query.bookId,
      categoryId: query.categoryId,
      tagIds: query.tagIds,
      format: query.format?.value,
      limit: query.limit,
    );
    if (!_normalizer.containsCjk(normalizedQuery) ||
        rows.length >= query.limit) {
      return rows.map(_mapSearchResult).toList(growable: false);
    }

    final fallbackRows = await _dao.searchLikeFallback(
      rawQuery: normalizedQuery,
      includeBookResults:
          includeAllTypes || typeFilters.contains(domain.SearchResultType.book),
      includeContentResults:
          includeAllTypes ||
          typeFilters.contains(domain.SearchResultType.content),
      includeNoteResults:
          includeAllTypes || typeFilters.contains(domain.SearchResultType.note),
      includeBookmarkResults:
          includeAllTypes ||
          typeFilters.contains(domain.SearchResultType.bookmark),
      includeAiResults:
          includeAllTypes || typeFilters.contains(domain.SearchResultType.ai),
      bookId: query.bookId,
      categoryId: query.categoryId,
      tagIds: query.tagIds,
      format: query.format?.value,
      limit: query.limit,
    );
    final merged = <String, db.SearchMatchRow>{};
    for (final row in rows.followedBy(fallbackRows)) {
      merged.putIfAbsent(row.chunk.id, () => row);
      if (merged.length >= query.limit) {
        break;
      }
    }
    return merged.values.map(_mapSearchResult).toList(growable: false);
  }

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) {
    return indexText(
      sourceType: 'book',
      sourceId: bookId,
      bookId: bookId,
      title: title,
      text: [title, author, description].whereType<String>().join('\n'),
    );
  }

  @override
  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _dao.upsertChunk(
      db.SearchChunksCompanion.insert(
        id: '$sourceType:$sourceId',
        bookId: Value(bookId),
        sourceType: sourceType,
        sourceId: Value(sourceId),
        locator: Value(locator?.toJsonText()),
        title: Value(title),
        body: text?.trim().isNotEmpty == true ? text!.trim() : title ?? '',
        sortOrder: Value(sortOrder),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) {
    return _dao.deleteBySource(sourceType, sourceId);
  }

  @override
  Future<void> deleteByBook(String bookId) {
    return _dao.deleteByBook(bookId);
  }

  domain.SearchResult _mapSearchResult(db.SearchMatchRow row) {
    final chunk = row.chunk;
    return domain.SearchResult(
      id: chunk.id,
      type: _searchResultType(chunk),
      title: chunk.title ?? '搜索结果',
      snippet: row.snippet.isEmpty ? chunk.body : row.snippet,
      bookId: chunk.bookId,
      sourceId: chunk.sourceId,
      locator: chunk.locator == null ? null : _locatorFromText(chunk.locator!),
    );
  }

  domain.SearchResultType _searchResultType(db.SearchChunkRow chunk) {
    if (chunk.sourceType == 'book') {
      return chunk.sourceId == chunk.bookId
          ? domain.SearchResultType.book
          : domain.SearchResultType.content;
    }
    return domain.SearchResultType.fromValue(chunk.sourceType);
  }

  String _ftsQuery(String query) {
    return query
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '"${part.replaceAll('"', '""')}"')
        .join(' OR ');
  }
}

final class DriftAiSettingsRepository implements AiSettingsRepository {
  const DriftAiSettingsRepository(this._settingsDao, this._secureStore);

  final db.SettingsDao _settingsDao;
  final SecureStore _secureStore;

  @override
  Stream<AiSettings> watchSettings() {
    return _settingsDao.watchSettings().asyncMap((_) => getSettings());
  }

  @override
  Future<AiSettings> getSettings() async {
    final values = <String, String?>{};
    for (final key in [
      'ai.enabled',
      'ai.provider',
      'ai.baseUrl',
      'ai.model',
      'ai.temperature',
      'ai.maxTokens',
      'ai.streaming',
      'ai.systemPrompt',
      'privacy.confirmBeforeAiRequest',
    ]) {
      values[key] = await _settingsDao.getValue(key);
    }
    return AiSettings(
      enabled: values['ai.enabled'] == 'true',
      provider: values['ai.provider'] ?? 'openai-compatible',
      baseUrl: values['ai.baseUrl'] ?? '',
      model: values['ai.model'] ?? '',
      temperature: double.tryParse(values['ai.temperature'] ?? '') ?? 0.2,
      maxTokens: int.tryParse(values['ai.maxTokens'] ?? '') ?? 1200,
      streaming: values['ai.streaming'] != 'false',
      systemPrompt: values['ai.systemPrompt'] ?? '',
      confirmBeforeRequest: values['privacy.confirmBeforeAiRequest'] != 'false',
      hasApiKey: await _secureStore.hasValue(aiApiKeyStorageKey),
    );
  }

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _settingsDao.setValue('ai.enabled', '${settings.enabled}', now);
    await _settingsDao.setValue('ai.provider', settings.provider, now);
    await _settingsDao.setValue('ai.baseUrl', settings.baseUrl, now);
    await _settingsDao.setValue('ai.model', settings.model, now);
    await _settingsDao.setValue(
      'ai.temperature',
      '${settings.temperature}',
      now,
    );
    await _settingsDao.setValue('ai.maxTokens', '${settings.maxTokens}', now);
    await _settingsDao.setValue('ai.streaming', '${settings.streaming}', now);
    await _settingsDao.setValue('ai.systemPrompt', settings.systemPrompt, now);
    await _settingsDao.setValue(
      'privacy.confirmBeforeAiRequest',
      '${settings.confirmBeforeRequest}',
      now,
    );
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStore.write(aiApiKeyStorageKey, apiKey);
    }
  }

  @override
  Future<void> clearApiKey() {
    return _secureStore.delete(aiApiKeyStorageKey);
  }
}

final class DriftAiConversationRepository implements AiConversationRepository {
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
      locator: row.locator == null ? null : _locatorFromText(row.locator!),
      provider: row.provider,
      model: row.model,
      prompt: row.prompt,
      contextText: row.contextText,
      answer: row.answer,
      sourceText: row.sourceText,
      noteId: row.noteId,
      createdAt: row.createdAt,
    );
  }
}

final class DriftTaskRepository implements domain.TaskRepository {
  const DriftTaskRepository(this._dao);

  final db.TaskDao _dao;

  @override
  Stream<List<domain.PageSageTask>> watchTasks() {
    return _dao.watchTasks().map(
      (rows) => rows.map(_mapTask).toList(growable: false),
    );
  }

  @override
  Future<List<domain.PageSageTask>> getTasks() async {
    final rows = await _dao.getTasks();
    return rows.map(_mapTask).toList(growable: false);
  }

  @override
  Future<domain.PageSageTask> saveTask({
    String? id,
    required domain.PageSageTaskType type,
    required domain.PageSageTaskStatus status,
    String? sourcePath,
    String? targetPath,
    String? bookId,
    double progress = 0,
    String? message,
    String? error,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = domain.PageSageTask(
      id: id ?? _uuid.v4(),
      type: type,
      status: status,
      sourcePath: sourcePath,
      targetPath: targetPath,
      bookId: bookId,
      progress: progress,
      message: message,
      error: error,
      createdAt: now,
      updatedAt: now,
    );
    await _dao.upsertTask(
      db.ImportTasksCompanion.insert(
        id: task.id,
        type: task.type.value,
        status: task.status.value,
        sourcePath: Value(task.sourcePath),
        targetPath: Value(task.targetPath),
        bookId: Value(task.bookId),
        progress: Value(task.progress),
        message: Value(task.message),
        error: Value(task.error),
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
      ),
    );
    return task;
  }

  @override
  Future<void> updateStatus({
    required String id,
    required domain.PageSageTaskStatus status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
  }) {
    return _dao.updateStatus(
      id: id,
      status: status.value,
      progress: progress,
      targetPath: targetPath,
      bookId: bookId,
      message: message,
      error: error,
    );
  }

  @override
  Future<void> clearCompleted() {
    return _dao.clearCompleted();
  }

  domain.PageSageTask _mapTask(db.ImportTaskRow row) {
    return domain.PageSageTask(
      id: row.id,
      type: domain.PageSageTaskType.fromValue(row.type),
      status: domain.PageSageTaskStatus.fromValue(row.status),
      sourcePath: row.sourcePath,
      targetPath: row.targetPath,
      bookId: row.bookId,
      progress: row.progress,
      message: row.message,
      error: row.error,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

ReadingLocator _locatorFromText(String text) {
  try {
    return ReadingLocator.fromJsonText(text);
  } on Object {
    final json = jsonDecode(text);
    if (json is Map<String, Object?>) {
      return ReadingLocator.fromJson(json);
    }
    return ReadingLocator.epub();
  }
}
