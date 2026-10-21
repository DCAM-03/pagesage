import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ai/application/ai_context_range.dart';
import 'package:pagesage/features/ai/application/retrieval_context_source.dart';

Book _book({
  required String id,
  required String title,
  String? categoryId,
  String indexingStatus = 'done',
}) {
  return Book(
    id: id,
    title: title,
    format: BookFormat.pdf,
    libraryFilePath: '/tmp/$id.pdf',
    fileHash: 'hash-$id',
    fileSize: 100,
    categoryId: categoryId,
    indexingStatus: indexingStatus,
    createdAt: 1,
    updatedAt: 1,
  );
}

final class _Books implements BookRepository {
  _Books(this.books, {this.current});

  final List<Book> books;
  final Book? current;

  @override
  Future<Book?> getBook(String id) async {
    if (current?.id == id) return current;
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<List<LibraryBook>> getLibrary() async => [
    for (final book in books) LibraryBook(book: book),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Chunks implements SearchRepository {
  _Chunks(this.byBook);

  final Map<String, List<SearchChunk>> byBook;

  @override
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async {
    final ids = bookIds.isEmpty ? byBook.keys : bookIds;
    return [
      for (final id in ids)
        if (byBook[id] case final chunks?)
          SearchBookChunks(bookId: id, chunks: chunks),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SearchChunk _chunk(String id, String text, {int sortOrder = 0}) {
  return SearchChunk(
    id: id,
    bookId: id.split(':').first,
    title: '第 $sortOrder 块',
    text: text,
    sortOrder: sortOrder,
  );
}

void main() {
  final current = _book(id: 'book-a', title: '甲书', categoryId: 'folder-1');

  RetrievalContextSource source({
    required _Books books,
    required _Chunks chunks,
  }) {
    return RetrievalContextSource(
      searchRepository: chunks,
      bookRepository: books,
    );
  }

  test('the whole-book range searches only the book the panel is in', () async {
    final chunks = _Chunks({
      'book-a': [_chunk('book-a:pdf:1:0', '虚拟内存与分页')],
      'book-b': [_chunk('book-b:pdf:1:0', '虚拟内存与分页')],
    });
    final outcome = await source(
      books: _Books([current], current: current),
      chunks: chunks,
    ).load(range: AiContextRange.wholeBook, bookId: 'book-a', query: '虚拟内存');

    expect(outcome.booksSearched, 1);
    expect(
      outcome.references.map((reference) => reference.locator ?? reference.id),
      hasLength(1),
    );
    // The panel is inside this book; repeating its title on every row adds
    // nothing.
    expect(outcome.references.single.bookTitle, isNull);
  });

  test('the folder range searches siblings and labels their books', () async {
    final sibling = _book(id: 'book-b', title: '乙书', categoryId: 'folder-1');
    final chunks = _Chunks({
      'book-a': [_chunk('book-a:pdf:1:0', '虚拟内存与分页')],
      'book-b': [_chunk('book-b:pdf:1:0', '虚拟内存与分段')],
      'book-c': [_chunk('book-c:pdf:1:0', '虚拟内存与分段')],
    });

    final outcome = await source(
      books: _Books([current, sibling], current: current),
      chunks: chunks,
    ).load(range: AiContextRange.folder, bookId: 'book-a', query: '虚拟内存');

    // book-c is in the library map but not in this folder: it must not be
    // searched, or text from books the reader never named would be sent.
    expect(outcome.booksSearched, 2);
    expect(outcome.references.map((reference) => reference.bookTitle).toSet(), {
      '甲书',
      '乙书',
    });
  });

  test(
    'a book with no folder searches nothing rather than everything',
    () async {
      final loose = _book(id: 'book-a', title: '甲书');
      final outcome = await source(
        books: _Books([loose], current: loose),
        chunks: _Chunks({
          'book-a': [_chunk('book-a:pdf:1:0', '虚拟内存')],
          'book-b': [_chunk('book-b:pdf:1:0', '虚拟内存')],
        }),
      ).load(range: AiContextRange.folder, bookId: 'book-a', query: '虚拟内存');

      expect(outcome.isEmpty, isTrue);
      expect(outcome.booksSearched, 0);
    },
  );

  test('a book that was never indexed does not count as searched', () async {
    final scanned = _book(
      id: 'book-b',
      title: '扫描件',
      categoryId: 'folder-1',
      indexingStatus: 'no_text',
    );
    final outcome = await source(
      books: _Books([current, scanned], current: current),
      chunks: _Chunks({
        'book-a': [_chunk('book-a:pdf:1:0', '虚拟内存')],
      }),
    ).load(range: AiContextRange.folder, bookId: 'book-a', query: '虚拟内存');

    // Claiming to have searched a scan would overstate what happened.
    expect(outcome.booksSearched, 1);
  });

  test('a query of nothing but stop words matches nothing', () async {
    final outcome = await source(
      books: _Books([current], current: current),
      chunks: _Chunks({
        'book-a': [_chunk('book-a:pdf:1:0', '虚拟内存')],
      }),
    ).load(range: AiContextRange.wholeBook, bookId: 'book-a', query: '什么 是 的');

    expect(outcome.isEmpty, isTrue);
  });

  test('asking for a non-retrieval range is a programming error', () async {
    expect(
      () =>
          source(
            books: _Books([current], current: current),
            chunks: _Chunks(const {}),
          ).load(
            range: AiContextRange.currentPage,
            bookId: 'book-a',
            query: '虚拟内存',
          ),
      throwsArgumentError,
    );
  });
}
