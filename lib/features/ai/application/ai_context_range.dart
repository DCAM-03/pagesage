/// What part of the book an AI request carries as context.
///
/// Lives in its own file so the loader that supplies the text
/// (`ai_context_source.dart`) and the builder that shapes it do not import
/// each other.
///
/// The whole-book and whole-folder ranges were deliberately absent until
/// retrieval existed. Reading one page or chapter cannot answer them, and a
/// range that ships the current chapter under a label promising the book is
/// the exact failure this file exists to prevent. They are here now because
/// `ContextRetriever` picks real passages from the indexed book text, and
/// those passages appear in the reference list, so the label no longer
/// outruns what is actually sent. See `docs/12-ai-retrieval-strategy.md`.
enum AiContextRange {
  selectedText('selectedText', '仅选中文本'),
  surroundingParagraphs('surroundingParagraphs', '前后段落'),
  currentChapter('currentChapter', '当前章节'),
  currentPage('currentPage', '当前页'),
  wholeBook('wholeBook', '全书关联'),
  folder('folder', '文件夹关联');

  const AiContextRange(this.value, this.label);

  final String value;
  final String label;

  /// Whether this range needs text loaded from the book file.
  ///
  /// The selection is already in hand at the call site; every other range has
  /// to read from disk.
  bool get needsBookText => this != AiContextRange.selectedText;

  /// Whether the range picks passages by retrieval rather than reading one
  /// page or chapter.
  ///
  /// This is the line between the two families: reading returns the whole of
  /// one page or one chapter, retrieval returns the few passages of a book (or
  /// of several books) that the question is about.
  bool get usesRetrieval =>
      this == AiContextRange.wholeBook || this == AiContextRange.folder;
}
