import '../../../domain/books/book.dart';

sealed class ImportBookResult {
  const ImportBookResult();
}

final class ImportBookCancelled extends ImportBookResult {
  const ImportBookCancelled();
}

final class ImportBookSuccess extends ImportBookResult {
  const ImportBookSuccess(this.book);

  final Book book;
}

final class ImportBookDuplicate extends ImportBookResult {
  const ImportBookDuplicate({
    required this.existingBook,
    required this.sourcePath,
  });

  final Book existingBook;
  final String sourcePath;
}

final class ImportBookFailure extends ImportBookResult {
  const ImportBookFailure(this.message, {this.details});

  final String message;
  final Object? details;
}

final class ImportBooksResult {
  const ImportBooksResult({
    required this.successes,
    required this.duplicates,
    required this.failures,
    required this.cancelled,
  });

  final List<Book> successes;
  final List<ImportBookDuplicate> duplicates;
  final List<ImportBookFailure> failures;
  final bool cancelled;

  int get total => successes.length + duplicates.length + failures.length;
}
