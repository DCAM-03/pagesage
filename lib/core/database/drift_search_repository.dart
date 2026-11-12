import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/books/reading_position.dart';
import '../../domain/search/search_models.dart' as domain;
import '../search/cjk_search.dart';
import '../search/search_normalizer.dart';
import 'drift_locator_mapping.dart';
import 'app_database.dart' as db;

final class DriftSearchRepository
    implements
        domain.SearchRepository,
        domain.SearchResponseRepository,
        domain.SearchGenerationRepository {
  const DriftSearchRepository(
    this._dao, [
    this._normalizer = const SearchNormalizer(),
    this._textNormalizer = const SearchTextNormalizerV1(),
    this._queryParser = const SearchQueryParserV1(),
  ]);

  final db.SearchDao _dao;
  final SearchNormalizer _normalizer;
  final SearchTextNormalizerV1 _textNormalizer;
  final SearchQueryParserV1 _queryParser;
  static const Uuid _uuid = Uuid();

  @override
  Future<List<domain.SearchResult>> search(domain.SearchQuery query) async {
    return (await _searchInternal(query)).results;
  }

  Future<({List<domain.SearchResult> results, bool truncated})> _searchInternal(
    domain.SearchQuery query,
  ) async {
    ParsedSearchQuery parsed;
    try {
      parsed = _queryParser.parse(query.query);
    } on SearchQueryException {
      return (results: const <domain.SearchResult>[], truncated: false);
    }
    if (parsed.isEmpty) {
      return (results: const <domain.SearchResult>[], truncated: false);
    }
    await _ensureTermDocuments();
    final candidateLimit = (query.limit * 10).clamp(50, 500);
    final rows = await _dao.searchCandidates(
      normalizedMatch: safeFtsMatch(parsed),
      cjkMatch: safeFtsMatch(parsed),
      sourceTypeClauses: _sourceClauses(query),
      bookId: query.bookId,
      categoryId: query.categoryId,
      tagIds: query.tagIds,
      format: query.format?.value,
      limit: candidateLimit,
    );
    final candidates = <SearchRankCandidate>[];
    for (final row in rows) {
      final chunk = row.chunk;
      final resultType = _searchResultType(chunk);
      if (query.typeFilters.isNotEmpty &&
          !query.typeFilters.contains(resultType)) {
        continue;
      }
      final normalizedTitle = row.normalizedTitle;
      final normalizedText = row.normalizedText;
      if (!matchesSearchGroups(parsed, normalizedTitle, normalizedText)) {
        continue;
      }
      var titleExact = 0;
      var textExact = 0;
      var sourceOrder = 4;
      for (final group in parsed.groups) {
        if (normalizedTitle.contains(group.text)) titleExact += 1;
        if (normalizedText.contains(group.text)) textExact += 1;
      }
      sourceOrder = switch (resultType) {
        domain.SearchResultType.book => 0,
        domain.SearchResultType.note => 1,
        domain.SearchResultType.bookmark => 2,
        domain.SearchResultType.content => 3,
        domain.SearchResultType.ai => 4,
      };
      final exact = titleExact + textExact >= parsed.groups.length;
      candidates.add(
        SearchRankCandidate(
          id: chunk.id,
          bookTitle: row.bookTitle ?? chunk.title ?? '',
          bookId: chunk.bookId,
          address: chunk.sourceId ?? chunk.id,
          startOffset: chunk.startOffset ?? 0,
          chunkId: chunk.id,
          normalizedTitle: normalizedTitle,
          normalizedText: normalizedText,
          rrf:
              1 / (60 + _rankToOrdinal(row.normalizedRank)) +
              (row.hitSources > 1
                  ? 1 / (60 + _rankToOrdinal(row.cjkRank))
                  : 0) -
              sourceOrder * 1e-9,
          exactGroups: exact ? parsed.groups.length : 0,
          titleExactGroups: titleExact,
          textExactGroups: textExact,
          related: !exact,
        ),
      );
    }
    candidates.sort(compareSearchRankCandidates);
    final selected = candidates.take(query.limit).toList(growable: false);
    final byChunk = <String, db.SearchCandidateRow>{
      for (final row in rows) row.chunk.id: row,
    };
    return (
      results: [
        for (final candidate in selected)
          _mapCandidate(byChunk[candidate.chunkId]!, candidate, parsed),
      ],
      truncated: rows.length >= candidateLimit,
    );
  }

  @override
  Future<domain.SearchResponse> searchResponse(domain.SearchQuery query) async {
    final result = await _searchInternal(query);
    return domain.SearchResponse(
      results: result.results,
      indexState: domain.SearchIndexState.ready,
      candidateTruncated: result.truncated,
      requestEpoch: query.requestEpoch,
      snapshotId: _uuid.v4(),
    );
  }

  Set<String> _sourceClauses(domain.SearchQuery query) {
    final filters = query.typeFilters;
    if (filters.isEmpty) {
      return const {
        "c.source_type = 'book'",
        "c.source_type = 'note'",
        "c.source_type = 'bookmark'",
        "c.source_type = 'ai'",
      };
    }
    return {
      if (filters.contains(domain.SearchResultType.book) ||
          filters.contains(domain.SearchResultType.content))
        "c.source_type = 'book'",
      if (filters.contains(domain.SearchResultType.note))
        "c.source_type = 'note'",
      if (filters.contains(domain.SearchResultType.bookmark))
        "c.source_type = 'bookmark'",
      if (filters.contains(domain.SearchResultType.ai)) "c.source_type = 'ai'",
    };
  }

  double _rankToOrdinal(double rank) => rank.abs().clamp(0, 10000).toDouble();

  domain.SearchResult _mapCandidate(
    db.SearchCandidateRow candidate,
    SearchRankCandidate rank,
    ParsedSearchQuery parsed,
  ) {
    final chunk = candidate.chunk;
    final normalized = _textNormalizer.normalize(chunk.body);
    final ranges = <({int start, int end})>[];
    for (final group in parsed.groups) {
      var index = normalized.text.indexOf(group.text);
      if (index < 0) continue;
      var groupMatches = 0;
      while (index >= 0 && groupMatches < 3) {
        final range = _textNormalizer.originalRange(
          normalized,
          index,
          index + group.text.length,
        );
        if (range.end > range.start) ranges.add(range);
        groupMatches += 1;
        index = normalized.text.indexOf(group.text, index + group.text.length);
      }
    }
    ranges.sort((left, right) => left.start.compareTo(right.start));
    var index = 1;
    while (index < ranges.length) {
      final before = ranges[index - 1];
      final current = ranges[index];
      if (current.start <= before.end) {
        ranges[index - 1] = (
          start: before.start,
          end: current.end > before.end ? current.end : before.end,
        );
        ranges.removeAt(index);
      } else {
        index++;
      }
    }
    final first = ranges.isEmpty ? 0 : ranges.first.start;
    final start = (first - 48).clamp(0, chunk.body.length).toInt();
    final end = (first + 132).clamp(0, chunk.body.length).toInt();
    final plain = chunk.body.substring(start, end);
    final snippet = _highlightSnippet(plain, ranges, start);
    var locator = chunk.locator == null
        ? null
        : locatorFromDatabaseText(chunk.locator!);
    if (chunk.sourceType == 'book' &&
        chunk.textOrigin != 'ocr' &&
        !rank.related &&
        ranges.isNotEmpty &&
        locator != null &&
        locator.type != ReadingLocatorType.pdf &&
        locator.chapterOffset != null) {
      final match = ranges.first;
      locator = ReadingLocator.fromJson({
        ...locator.toJson(),
        'cfi': null,
        'chapterOffset': locator.chapterOffset! + match.start,
        'chapterEndOffset': locator.chapterOffset! + match.end,
        'excerpt': chunk.body.substring(match.start, match.end),
      });
    }
    return domain.SearchResult(
      id: chunk.id,
      type: _searchResultType(chunk),
      title: chunk.title ?? '搜索结果',
      snippet: snippet.isEmpty ? chunk.body : snippet,
      bookId: chunk.bookId,
      sourceId: chunk.sourceId,
      locator: locator,
      matchKind: rank.related ? SearchMatchKind.related : SearchMatchKind.exact,
      precision: chunk.textOrigin == 'ocr'
          ? domain.SearchMatchPrecision.pageOnly
          : rank.related
          ? domain.SearchMatchPrecision.related
          : domain.SearchMatchPrecision.exact,
      matchRanges: List.unmodifiable(ranges),
      textOrigin: chunk.textOrigin,
    );
  }

  String _highlightSnippet(
    String plain,
    List<({int start, int end})> ranges,
    int offset,
  ) {
    if (ranges.isEmpty) return plain;
    final buffer = StringBuffer();
    var cursor = 0;
    for (final range in ranges) {
      final start = (range.start - offset).clamp(0, plain.length).toInt();
      final end = (range.end - offset).clamp(start, plain.length).toInt();
      if (start < cursor || end <= start) continue;
      buffer.write(plain.substring(cursor, start));
      buffer.write('<mark>');
      buffer.write(plain.substring(start, end));
      buffer.write('</mark>');
      cursor = end;
    }
    buffer.write(plain.substring(cursor));
    return buffer.toString();
  }

  Future<List<domain.SearchResult>> searchLegacy(
    domain.SearchQuery query,
  ) async {
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

  Future<void> _ensureTermDocuments() => _dao.transaction(_backfillTerms);

  Future<void> _backfillTerms() async {
    final rows = await _dao.chunksMissingTerms(
      normalizerVersion: SearchTextNormalizerV1.version,
      tokenizerVersion: SearchTextNormalizerV1.tokenizerVersion,
    );
    final terms = <db.SearchTermDocumentsCompanion>[];
    for (final chunk in rows) {
      final derived = SearchIndexTerms.fromText(
        inputKey: chunk.id,
        title: chunk.title ?? '',
        text: chunk.body,
        sourceRevision: chunk.sourceRevision ?? chunk.id,
        textRevision: chunk.textRevision ?? chunk.body,
        extractorVersion: 'legacy-index-v1',
        normalizer: _textNormalizer,
      );
      terms.add(
        db.SearchTermDocumentsCompanion.insert(
          id: _uuid.v5(Namespace.url.value, 'pagesage:search-term:${chunk.id}'),
          chunkId: chunk.id,
          generationId: Value(chunk.generationId),
          titleNormalized: derived.titleNormalized,
          textNormalized: derived.textNormalized,
          titleTerms: derived.titleTerms,
          textTerms: derived.textTerms,
          normalizerVersion: SearchTextNormalizerV1.version,
          tokenizerVersion: SearchTextNormalizerV1.tokenizerVersion,
        ),
      );
    }
    if (terms.isNotEmpty) {
      await _dao.upsertTermDocuments(terms);
    }
  }

  @override
  Future<List<domain.SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async {
    final rows = await _dao.bookChunks(
      bookIds: bookIds,
      categoryId: categoryId,
    );
    final grouped = <String, List<domain.SearchChunk>>{};
    for (final row in rows) {
      final chunk = row.chunk;
      final bookId = chunk.bookId;
      if (bookId == null) {
        continue;
      }
      (grouped[bookId] ??= <domain.SearchChunk>[]).add(
        domain.SearchChunk(
          id: chunk.id,
          bookId: bookId,
          title: chunk.title ?? '',
          text: chunk.body,
          sortOrder: chunk.sortOrder,
          locator: chunk.locator == null
              ? null
              : locatorFromDatabaseText(chunk.locator!),
          parentId: chunk.parentId,
          parentTitle: row.parentTitle,
          parentText: row.parentText,
          parentLocator: row.parentLocator == null
              ? null
              : locatorFromDatabaseText(row.parentLocator!),
          textOrigin: chunk.textOrigin,
        ),
      );
    }
    return [
      for (final entry in grouped.entries)
        domain.SearchBookChunks(bookId: entry.key, chunks: entry.value),
    ];
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
    return indexTexts([
      domain.SearchIndexEntry(
        sourceType: sourceType,
        sourceId: sourceId,
        bookId: bookId,
        title: title,
        text: text,
        locator: locator,
        sortOrder: sortOrder,
      ),
    ]);
  }

  @override
  Future<void> indexTexts(List<domain.SearchIndexEntry> entries) {
    return _writeTexts(entries);
  }

  @override
  Future<domain.SearchIndexGeneration> beginBookGeneration(
    String bookId,
  ) async {
    final unitId = _uuid.v5(
      Namespace.url.value,
      'pagesage:search-unit:$bookId',
    );
    final generationId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.upsertSearchUnit(
      db.SearchIndexUnitsCompanion.insert(
        id: unitId,
        unitKey: 'book:$bookId',
        bookId: Value(bookId),
        requestedInputRevision: generationId,
        state: const Value('building'),
        updatedAt: now,
      ),
    );
    await _dao.insertSearchGeneration(
      db.SearchIndexGenerationsCompanion(
        id: Value(generationId),
        unitId: Value(unitId),
        inputRevision: Value(generationId),
        extractorVersion: const Value('pagesage-search-v1'),
        tokenizerVersion: const Value(SearchTextNormalizerV1.tokenizerVersion),
        state: const Value('building'),
        createdAt: Value(now),
      ),
    );
    return domain.SearchIndexGeneration(
      id: generationId,
      bookId: bookId,
      unitId: unitId,
    );
  }

  @override
  Future<void> indexGenerationTexts(
    String generationId,
    List<domain.SearchIndexEntry> entries,
  ) {
    return _writeTexts(entries, generationId: generationId);
  }

  @override
  Future<void> publishBookGeneration(String generationId) {
    return _dao.publishSearchGeneration(generationId);
  }

  @override
  Future<void> discardBookGeneration(String generationId) {
    return _dao.discardSearchGeneration(generationId);
  }

  Future<void> _writeTexts(
    List<domain.SearchIndexEntry> entries, {
    String? generationId,
  }) {
    if (entries.isEmpty) {
      return Future<void>.value();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final chunks = <db.SearchChunksCompanion>[];
    final parents = <String, db.SearchParentChunksCompanion>{};
    for (final entry in entries) {
      final body = entry.text?.trim().isNotEmpty == true
          ? entry.text!
          : entry.title ?? '';
      final baseId = '${entry.sourceType}:${entry.sourceId}';
      final chunkId = generationId == null ? baseId : '$baseId#$generationId';
      final baseParentId = entry.parentId;
      final parentId = baseParentId == null
          ? null
          : generationId == null
          ? baseParentId
          : '$baseParentId#$generationId';
      chunks.add(
        db.SearchChunksCompanion.insert(
          id: chunkId,
          bookId: Value(entry.bookId),
          parentId: Value(parentId),
          sourceType: entry.sourceType,
          sourceId: Value(entry.sourceId),
          locator: Value(entry.locator?.toJsonText()),
          title: Value(entry.title),
          body: body,
          sortOrder: Value(entry.sortOrder),
          createdAt: now,
          updatedAt: now,
          generationId: Value(generationId),
          sourceRevision: Value(entry.sourceRevision),
          textRevision: Value(entry.textRevision),
          textOrigin: Value(entry.textOrigin),
        ),
      );
      final parentText = entry.parentText;
      if (parentId != null &&
          parentText != null &&
          parentText.trim().isNotEmpty) {
        parents.putIfAbsent(
          parentId,
          () => db.SearchParentChunksCompanion.insert(
            id: parentId,
            bookId: Value(entry.bookId),
            sourceType: entry.sourceType,
            sourceId: Value(parentId),
            locator: Value(entry.parentLocator?.toJsonText()),
            title: Value(entry.parentTitle),
            body: parentText,
            sortOrder: Value(entry.parentSortOrder),
            createdAt: now,
            updatedAt: now,
            generationId: Value(generationId),
            sourceRevision: Value(entry.sourceRevision),
            textRevision: Value(entry.textRevision),
            textOrigin: Value(entry.textOrigin),
          ),
        );
      }
    }
    return _dao.transaction(() async {
      await _dao.upsertParents(parents.values.toList(growable: false));
      await _dao.upsertChunks(chunks);
      await _publishTerms(chunks);
    });
  }

  Future<void> _publishTerms(List<db.SearchChunksCompanion> chunks) async {
    final terms = <db.SearchTermDocumentsCompanion>[];
    for (final chunk in chunks) {
      final id = chunk.id.value;
      final body = chunk.body.value;
      final derived = SearchIndexTerms.fromText(
        inputKey: id,
        title: chunk.title.value ?? '',
        text: body,
        sourceRevision: chunk.sourceRevision.value ?? id,
        textRevision: chunk.textRevision.value ?? body,
        extractorVersion: 'legacy-index-v1',
        normalizer: _textNormalizer,
      );
      terms.add(
        db.SearchTermDocumentsCompanion.insert(
          id: _uuid.v5(Namespace.url.value, 'pagesage:search-term:$id'),
          chunkId: id,
          generationId: Value(chunk.generationId.value),
          titleNormalized: derived.titleNormalized,
          textNormalized: derived.textNormalized,
          titleTerms: derived.titleTerms,
          textTerms: derived.textTerms,
          normalizerVersion: SearchTextNormalizerV1.version,
          tokenizerVersion: SearchTextNormalizerV1.tokenizerVersion,
        ),
      );
    }
    if (terms.isNotEmpty) {
      await _dao.upsertTermDocuments(terms);
    }
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
      locator: chunk.locator == null
          ? null
          : locatorFromDatabaseText(chunk.locator!),
      textOrigin: chunk.textOrigin,
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
