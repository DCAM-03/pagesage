import 'package:path/path.dart' as p;

enum BookFormat {
  epub('epub'),
  pdf('pdf'),
  markdown('md');

  const BookFormat(this.value);

  final String value;

  /// Whether this format is read as reflowable text: chapters, paragraphs,
  /// and character offsets rather than fixed pages.
  bool get isReflowable => this != BookFormat.pdf;

  static BookFormat? fromValue(String value) {
    for (final format in values) {
      if (format.value == value.toLowerCase()) {
        return format;
      }
    }
    return null;
  }
}

enum ReadStatus {
  unread('unread'),
  reading('reading'),
  finished('finished');

  const ReadStatus(this.value);

  final String value;

  static ReadStatus fromValue(String value) {
    return values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReadStatus.unread,
    );
  }
}

final class Book {
  const Book({
    required this.id,
    required this.title,
    required this.format,
    required this.libraryFilePath,
    required this.fileHash,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
    this.originalTitle,
    this.author,
    this.originalFormat,
    this.originalFilePath,
    this.coverPath,
    this.language,
    this.description,
    this.categoryId,
    this.isFavorite = false,
    this.readStatus = ReadStatus.unread,
    this.indexingStatus = 'pending',
    this.lastOpenedAt,
  });

  final String id;
  final String title;
  final String? originalTitle;
  final String? author;
  final BookFormat format;
  final String? originalFormat;
  final String? originalFilePath;
  final String libraryFilePath;
  final String? coverPath;
  final String fileHash;
  final int fileSize;
  final String? language;
  final String? description;
  final String? categoryId;
  final bool isFavorite;
  final ReadStatus readStatus;
  final String indexingStatus;
  final int createdAt;
  final int updatedAt;
  final int? lastOpenedAt;

  /// Whether this book is a whole folder of Markdown read as one book.
  ///
  /// A folder book is read where the writer keeps it rather than copied into
  /// the library, so its library path is a directory. A Markdown file always
  /// ends in `.md` or `.markdown`, so the path answers the question without a
  /// schema change — which matters because every existing query that returns
  /// a book would otherwise have to stat the disk.
  bool get isFolderBook {
    if (format != BookFormat.markdown) {
      return false;
    }
    final extension = p.extension(libraryFilePath).toLowerCase();
    return extension != '.md' && extension != '.markdown';
  }
}

final class NewBookDraft {
  const NewBookDraft({
    required this.id,
    required this.title,
    required this.format,
    required this.originalFilePath,
    required this.libraryFilePath,
    required this.fileHash,
    required this.fileSize,
    required this.createdAt,
    this.originalTitle,
    this.author,
    this.language,
    this.description,
    this.coverPath,
  });

  final String id;
  final String title;
  final String? originalTitle;
  final String? author;
  final String? language;
  final String? description;
  final String? coverPath;
  final BookFormat format;
  final String originalFilePath;
  final String libraryFilePath;
  final String fileHash;
  final int fileSize;
  final int createdAt;
}
