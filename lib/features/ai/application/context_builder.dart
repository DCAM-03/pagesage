import '../../../domain/books/reading_position.dart';

enum AiContextRange {
  selectedText('selectedText', '仅选中文本'),
  surroundingParagraphs('surroundingParagraphs', '前后段落'),
  currentChapter('currentChapter', '当前章节'),
  currentPage('currentPage', '当前页');

  const AiContextRange(this.value, this.label);

  final String value;
  final String label;
}

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
      AiContextRange.surroundingParagraphs => _surroundingParagraphs(
        selected: selected,
        source: source,
      ),
      AiContextRange.currentChapter || AiContextRange.currentPage =>
        source?.isNotEmpty == true ? source! : selected,
    };
    return AiContext(
      text: text,
      range: range,
      description: _describe(range: range, text: text),
    );
  }

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
