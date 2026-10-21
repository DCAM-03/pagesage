/// What part of the book an AI request carries as context.
///
/// Lives in its own file so the loader that supplies the text
/// (`ai_context_source.dart`) and the builder that shapes it do not import
/// each other.
///
/// A whole-book or whole-folder range is deliberately absent. Neither can be
/// answered by reading one file, both need retrieval over `SearchChunks`, and
/// a range that ships the current chapter under a label promising the book is
/// the exact failure this file exists to prevent. See
/// `docs/12-ai-retrieval-strategy.md`.
enum AiContextRange {
  selectedText('selectedText', '仅选中文本'),
  surroundingParagraphs('surroundingParagraphs', '前后段落'),
  currentChapter('currentChapter', '当前章节'),
  currentPage('currentPage', '当前页');

  const AiContextRange(this.value, this.label);

  final String value;
  final String label;

  /// Whether this range needs text loaded from the book file.
  ///
  /// The selection is already in hand at the call site; every other range has
  /// to be read from disk.
  bool get needsBookText => this != AiContextRange.selectedText;
}
