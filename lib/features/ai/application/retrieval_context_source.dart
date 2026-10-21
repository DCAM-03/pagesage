import '../../../domain/books/book.dart';
import '../../../domain/books/book_repository.dart';
import '../../../domain/search/search_models.dart';
import 'ai_context_range.dart';
import 'ai_context_reference.dart';
import 'context_retriever.dart';

/// What retrieval found, and what to tell the reader when it found nothing.
final class RetrievalOutcome {
  const RetrievalOutcome({
    required this.references,
    required this.booksSearched,
    required this.selection,
  });

  /// The passages to offer, in reading order. Empty when nothing matched.
  final List<AiContextReference> references;

  /// How many books were actually searched, for the "已检索 N 本书" line.
  final int booksSearched;

  /// The query that produced these passages.
  final String selection;

  bool get isEmpty => references.isEmpty;
}

/// Picks the passages a whole-book or whole-folder question is about.
///
/// Sits between the panel and the two data sources it needs: the indexed
/// chunk store (for the text) and the book repository (for titles and for
/// which books a folder holds). Neither the panel nor the retriever knows
/// about the other's concern — the retriever scores text, this decides whose
/// text.
final class RetrievalContextSource {
  const RetrievalContextSource({
    required SearchRepository searchRepository,
    required BookRepository bookRepository,
    ContextRetriever retriever = const ContextRetriever(),
  }) : this._(searchRepository, bookRepository, retriever);

  const RetrievalContextSource._(
    this._searchRepository,
    this._bookRepository,
    this._retriever,
  );

  final SearchRepository _searchRepository;
  final BookRepository _bookRepository;
  final ContextRetriever _retriever;

  /// Runs retrieval for [range]. Only the two retrieval ranges are accepted.
  ///
  /// [bookId] is the book the panel is open in; the folder comes from that
  /// book's own category, so the panel does not have to know about folders.
  ///
  /// Returns nothing when the book has no folder. Widening to the whole
  /// library instead would send text from books the reader never named —
  /// "the folder" means a specific folder, and there is not one here.
  Future<RetrievalOutcome> load({
    required AiContextRange range,
    required String bookId,
    required String query,
  }) async {
    if (!range.usesRetrieval) {
      throw ArgumentError.value(range, 'range', 'not a retrieval range');
    }
    final terms = ContextRetriever.searchTerms(query);
    if (terms.isEmpty) {
      return RetrievalOutcome(
        references: const [],
        booksSearched: 0,
        selection: query,
      );
    }

    final current = await _bookRepository.getBook(bookId);
    if (current == null) {
      return RetrievalOutcome(
        references: const [],
        booksSearched: 0,
        selection: query,
      );
    }

    final List<Book> books;
    if (range == AiContextRange.wholeBook) {
      books = [current];
    } else {
      final categoryId = current.categoryId;
      if (categoryId == null) {
        return RetrievalOutcome(
          references: const [],
          booksSearched: 0,
          selection: query,
        );
      }
      final library = await _bookRepository.getLibrary();
      books = [
        for (final entry in library)
          if (entry.book.categoryId == categoryId) entry.book,
      ];
    }

    // A book that was never indexed (a scan, an import still running) has no
    // chunks and cannot contribute; counting it would make "已检索 N 本书"
    // overstate what happened.
    final chunksByBook = <String, List<SearchChunk>>{};
    final titles = <String, String>{};
    for (final book in books) {
      if (book.indexingStatus != 'done') continue;
      final loaded = await _searchRepository.bookChunks(bookIds: [book.id]);
      final chunks = loaded.isEmpty
          ? const <SearchChunk>[]
          : loaded.first.chunks;
      if (chunks.isEmpty) continue;
      chunksByBook[book.id] = chunks;
      titles[book.id] = book.title;
    }

    final references = _retriever.retrieve(
      books: [
        for (final entry in chunksByBook.entries)
          SearchBookChunks(bookId: entry.key, chunks: entry.value),
      ],
      query: query,
      // The panel is open inside the current book; labelling its own passages
      // with its title would repeat it on every row. Cross-book passages need
      // the title to be tellable apart.
      bookTitles: {if (range == AiContextRange.folder) ...titles},
    );

    return RetrievalOutcome(
      references: references,
      booksSearched: chunksByBook.length,
      selection: query,
    );
  }
}
