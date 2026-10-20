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

final class SearchQuery {
  const SearchQuery({
    required this.query,
    this.typeFilters = const {},
    this.bookId,
    this.categoryId,
    this.tagIds = const {},
    this.format,
    this.limit = 50,
  });

  final String query;
  final Set<SearchResultType> typeFilters;
  final String? bookId;
  final String? categoryId;
  final Set<String> tagIds;
  final BookFormat? format;
  final int limit;
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
  });

  final String id;
  final SearchResultType type;
  final String title;
  final String snippet;
  final String? bookId;
  final String? sourceId;
  final ReadingLocator? locator;
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
  });

  final String sourceType;
  final String sourceId;
  final String? bookId;
  final String? title;
  final String? text;
  final ReadingLocator? locator;
  final int sortOrder;
}

abstract interface class SearchRepository {
  Future<List<SearchResult>> search(SearchQuery query);

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
