import '../books/reading_position.dart';
import '../books/book.dart';

enum SearchResultType {
  book('book'),
  content('content'),
  note('note'),
  bookmark('bookmark'),
  ai('ai');

  const SearchResultType(this.value);

  final String value;

  static SearchResultType fromValue(String value) {
    return values.firstWhere(
      (type) => type.value == value,
      orElse: () => SearchResultType.content,
    );
  }
}

enum SearchIndexState { ready, building, stale, failed, truncated }

enum SearchMatchPrecision { exact, related, pageOnly }

final class SearchQuery {
  const SearchQuery({
    required this.query,
    this.typeFilters = const {},
    this.bookId,
    this.categoryId,
    this.tagIds = const {},
    this.format,
    this.limit = 50,
    this.requestEpoch = 0,
  });

  final String query;
  final Set<SearchResultType> typeFilters;
  final String? bookId;
  final String? categoryId;
  final Set<String> tagIds;
  final BookFormat? format;
  final int limit;
  final int requestEpoch;
}

final class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.snippet,
    this.bookId,
    this.sourceId,
    this.locator,
    this.matchKind,
    this.precision,
    this.matchRanges = const [],
    this.textOrigin = 'native',
  });

  final String id;
  final SearchResultType type;
  final String title;
  final String snippet;
  final String? bookId;
  final String? sourceId;
  final ReadingLocator? locator;
  final String? matchKind;
  final SearchMatchPrecision? precision;
  final List<({int start, int end})> matchRanges;
  final String textOrigin;

  bool get isOcrText => textOrigin == 'ocr';
}

final class SearchResponse {
  const SearchResponse({
    required this.results,
    required this.indexState,
    required this.candidateTruncated,
    required this.requestEpoch,
    required this.snapshotId,
  });

  final List<SearchResult> results;
  final SearchIndexState indexState;
  final bool candidateTruncated;
  final int requestEpoch;
  final String snapshotId;

  SearchResponse copyWith({String? snapshotId}) => SearchResponse(
    results: results,
    indexState: indexState,
    candidateTruncated: candidateTruncated,
    requestEpoch: requestEpoch,
    snapshotId: snapshotId ?? this.snapshotId,
  );
}

/// One chunk of content prepared for FTS indexing.
final class SearchIndexEntry {
  const SearchIndexEntry({
    required this.sourceType,
    required this.sourceId,
    this.bookId,
    this.title,
    this.text,
    this.locator,
    this.sortOrder = 0,
    this.parentId,
    this.parentTitle,
    this.parentText,
    this.parentLocator,
    this.parentSortOrder = 0,
    this.textOrigin = 'native',
    this.sourceRevision,
    this.textRevision,
  });

  final String sourceType;
  final String sourceId;
  final String? bookId;
  final String? title;
  final String? text;
  final ReadingLocator? locator;
  final int sortOrder;
  final String? parentId;
  final String? parentTitle;
  final String? parentText;
  final ReadingLocator? parentLocator;
  final int parentSortOrder;
  final String textOrigin;
  final String? sourceRevision;
  final String? textRevision;
}

/// A chunk of book body text, as stored for search.
///
/// Distinct from [SearchResult]: that carries a snippet cut around the match,
/// which is what a results list shows. Retrieval for an AI answer needs the
/// chunk whole, because the passage is going to be read by a model rather
/// than glanced at by a person.
final class SearchChunk {
  const SearchChunk({
    required this.id,
    required this.title,
    required this.text,
    required this.sortOrder,
    this.bookId,
    this.locator,
    this.parentId,
    this.parentTitle,
    this.parentText,
    this.parentLocator,
    this.textOrigin = 'native',
  });

  final String id;
  final String? bookId;
  final String title;
  final String text;
  final ReadingLocator? locator;
  final String? parentId;
  final String? parentTitle;
  final String? parentText;
  final ReadingLocator? parentLocator;
  final String textOrigin;

  bool get isOcrText => textOrigin == 'ocr';

  /// Position within the book, ascending. Used for neighbourhood expansion.
  final int sortOrder;
}

/// One book's body chunks, in reading order.
final class SearchBookChunks {
  const SearchBookChunks({required this.bookId, required this.chunks});

  final String bookId;
  final List<SearchChunk> chunks;
}

abstract interface class SearchRepository {
  Future<List<SearchResult>> search(SearchQuery query);

  /// Book body chunks for retrieval, in reading order.
  ///
  /// [bookIds] selects whole books; [categoryId] selects a folder when no
  /// book is named. Metadata rows and notes are excluded: the whole-book and
  /// whole-folder ranges are about a book's content, and indexing the title as
  /// a chunk would let a book match a question purely on its name.
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  });

  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  });

  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  });

  /// Batch-index many chunks in one repository call (preferred for books).
  Future<void> indexTexts(List<SearchIndexEntry> entries);

  Future<void> deleteBySource(String sourceType, String? sourceId);

  Future<void> deleteByBook(String bookId);
}

abstract interface class SearchResponseRepository {
  Future<SearchResponse> searchResponse(SearchQuery query);
}

/// A book index build that only becomes visible after [publish].
///
/// Reindexing must not delete the current index first: readers keep searching
/// the old generation while the replacement is written, and a cancel or crash
/// leaves that old generation intact.
abstract interface class SearchGenerationRepository {
  Future<SearchIndexGeneration> beginBookGeneration(String bookId);

  Future<void> indexGenerationTexts(
    String generationId,
    List<SearchIndexEntry> entries,
  );

  Future<void> publishBookGeneration(String generationId);

  Future<void> discardBookGeneration(String generationId);
}

final class SearchIndexGeneration {
  const SearchIndexGeneration({
    required this.id,
    required this.bookId,
    required this.unitId,
  });

  final String id;
  final String bookId;
  final String unitId;
}

extension SearchRepositoryResponse on SearchRepository {
  Future<SearchResponse> searchResponse(SearchQuery query) async {
    if (this is SearchResponseRepository) {
      return (this as SearchResponseRepository).searchResponse(query);
    }
    return SearchResponse(
      results: await search(query),
      indexState: SearchIndexState.ready,
      candidateTruncated: false,
      requestEpoch: query.requestEpoch,
      snapshotId: '',
    );
  }
}
