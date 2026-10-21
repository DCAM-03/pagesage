import '../../../domain/books/reading_position.dart';

/// One piece of book text an AI request will carry.
///
/// The panel shows these as a list the reader can inspect, open, and drop —
/// `AGENTS.md` requires the AI context range to be explicit, and a list is the
/// only form of that which still holds once retrieval starts choosing the
/// text instead of the reader. Whole-book and whole-folder search (later
/// steps) will put several of these on screen, possibly from different books;
/// today a range produces one, plus the selection when it is not already part
/// of that one.
final class AiContextReference {
  const AiContextReference({
    required this.id,
    required this.title,
    required this.text,
    this.locator,
    this.bookTitle,
    this.bookId,
    this.isSelection = false,
  });

  /// Stable within one panel session, so removal cannot hit the wrong entry.
  final String id;

  /// Human-readable origin, e.g. `第 3 章 · 用 Rust 写猜数字游戏`.
  final String title;

  final String text;

  /// Where to jump back to, when the block can be located.
  final ReadingLocator? locator;

  /// Null for the book the panel is open in.
  final String? bookTitle;

  /// Which book to open when the reference is from another one.
  ///
  /// Null for the current book: the panel is already inside it, and jumping
  /// there is a scroll rather than a navigation. Set for retrieved passages
  /// from a sibling book, which need a different reader.
  final String? bookId;

  /// True for the reader's own selection, false for text read from the book.
  final bool isSelection;

  /// What the reader sees on the row.
  String get label => bookTitle == null ? title : '$bookTitle · $title';

  int get charCount => text.trim().length;

  AiContextReference copyWith({String? text}) {
    return AiContextReference(
      id: id,
      title: title,
      text: text ?? this.text,
      locator: locator,
      bookTitle: bookTitle,
      bookId: bookId,
      isSelection: isSelection,
    );
  }
}

/// Joins references into the text one request carries.
///
/// With more than one block each gets a heading naming where it came from —
/// otherwise the model cannot tell which passage is which, or cite it. A
/// single block is sent bare: headings would cost tokens on every ordinary
/// question and say nothing the prompt does not already imply.
String joinContextReferences(List<AiContextReference> references) {
  final visible = references
      .where((reference) => reference.text.trim().isNotEmpty)
      .toList(growable: false);
  if (visible.isEmpty) return '';
  if (visible.length == 1) return visible.first.text.trim();
  return visible
      .map((reference) => '【${reference.label}】\n${reference.text.trim()}')
      .join('\n\n');
}
