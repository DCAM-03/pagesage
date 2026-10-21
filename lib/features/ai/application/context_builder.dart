import '../../../domain/books/reading_position.dart';
import 'ai_context_range.dart';

final class AiContext {
  const AiContext({
    required this.text,
    required this.range,
    required this.description,
  });

  final String text;
  final AiContextRange range;
  final String description;
}

final class ContextBuilder {
  const ContextBuilder();

  AiContext build({
    required String selectedText,
    required AiContextRange range,
    ReadingLocator? locator,
    String? availableText,
  }) {
    final selected = selectedText.trim();
    final source = availableText?.trim();
    final text = switch (range) {
      AiContextRange.selectedText => selected,
      // Bounded too: a chapter with no blank lines is a single paragraph, and
      // returning it whole would leave `_ask` rejecting the request with an
      // error the reader has no way to act on.
      AiContextRange.surroundingParagraphs => _boundedChapter(
        selected: selected,
        source: _surroundingParagraphs(selected: selected, source: source),
      ),
      AiContextRange.currentChapter ||
      AiContextRange.currentPage ||
      // Retrieval returns several passages, each already sized by the
      // retriever; they reach the request as separate references, so there is
      // no single body of text to cut here.
      AiContextRange.wholeBook ||
      AiContextRange.folder => _boundedChapter(
        selected: selected,
        source: source,
      ),
    };
    return AiContext(
      text: text,
      range: range,
      description: _describe(range: range, text: text),
    );
  }

  /// Public form of [_boundedChapter], for callers that carry their own
  /// reference list rather than one blob of context.
  ///
  /// The panel bounds each reference separately so that one long chapter
  /// cannot consume the whole budget and silently drop the others.
  String boundText({required String text, String selected = ''}) {
    return _boundedChapter(selected: selected.trim(), source: text.trim());
  }

  /// Whether [text] has to be cut before a request can carry it.
  static bool exceedsBudget(String text) => text.trim().length > maxSourceChars;

  /// A whole page or chapter, trimmed to fit a request rather than rejected.
  ///
  /// A long chapter runs past any sane request size, and the panel used to
  /// answer that with an error that left the reader to shorten a text they did
  /// not choose. Cutting here keeps the action available: `ContextBuilder`
  /// already cuts paragraphs around the selection, and this is the same
  /// courtesy one level up. The cut window is centred on the selection when
  /// one can be found, so the passage under discussion is never what gets
  /// dropped.
  String _boundedChapter({required String selected, required String? source}) {
    if (source == null || source.isEmpty) return selected;
    if (source.length <= maxSourceChars) return source;
    final anchor = selected.isEmpty ? -1 : source.indexOf(selected);
    final centre = anchor < 0 ? 0 : anchor + selected.length ~/ 2;
    var start = (centre - maxSourceChars ~/ 2).clamp(
      0,
      source.length - maxSourceChars,
    );
    // Prefer a paragraph edge over a cut mid-sentence in the head of the
    // window; the tail keeps whatever the budget allows.
    final edge = source.lastIndexOf(RegExp(r'\n\s*\n'), start);
    if (start > 0 && edge != -1 && edge > start - 400) start = edge;
    final end = (start + maxSourceChars).clamp(0, source.length);
    return source.substring(start, end).trim();
  }

  /// Ceiling on the book text a single request carries.
  ///
  /// The panel enforces the same number as a hard limit before sending; this
  /// is the unit both use, so the two cannot drift apart.
  static const maxSourceChars = 12000;

  String _surroundingParagraphs({
    required String selected,
    required String? source,
  }) {
    if (source == null || source.isEmpty || selected.isEmpty) {
      return selected;
    }
    final paragraphs = source
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    final index = paragraphs.indexWhere((paragraph) {
      return paragraph.contains(selected) || selected.contains(paragraph);
    });
    if (index < 0) {
      return selected;
    }
    final start = index == 0 ? 0 : index - 1;
    final end = index + 2 > paragraphs.length ? paragraphs.length : index + 2;
    return paragraphs.sublist(start, end).join('\n\n');
  }

  String _describe({required AiContextRange range, required String text}) {
    // UI metadata only — location is shown separately, never mixed into payload.
    return '${range.label} · 约 ${text.length} 字 · 仅发送下方文本';
  }

  /// Human-readable reading location for UI chips (not mixed into payload copy).
  String? locationLabel(ReadingLocator? locator) {
    return switch (locator?.type) {
      ReadingLocatorType.epub => locator?.displayLabel,
      ReadingLocatorType.pdf =>
        locator?.page == null ? null : '第 ${locator!.page} 页',
      null => null,
    };
  }
}
