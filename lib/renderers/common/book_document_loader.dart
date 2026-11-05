import '../epub/epub_document.dart';

/// Opens a book file into the document the reader renders.
///
/// The renderer works on chapters, blocks and character offsets — the shape a
/// reflowable book has, whatever produced it. Each format knows how to get
/// there; the renderer does not need to.
abstract interface class BookDocumentLoader {
  Future<EpubDocument> load(String filePath);
}

/// A book that could not be opened, with a reason a reader can act on.
///
/// The renderer shows [message] as-is, so it has to say what went wrong in
/// the reader's language rather than the parser's.
abstract interface class BookLoadException implements Exception {
  String get message;
}
