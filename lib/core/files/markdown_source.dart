/// A Markdown file split into what is metadata and what is the document.
///
/// Front matter is the `---` block at the very top of a file. It is metadata,
/// not prose: it should not appear in the text, should not be searchable, and
/// should not take up an offset in the reading position. Everything that
/// reads a Markdown file — the import pass that names the book and the parser
/// that lays it out — goes through here so the two cannot disagree about
/// where the document starts.
final class MarkdownSource {
  const MarkdownSource({required this.body, this.title});

  /// The document, with the front matter removed.
  final String body;

  /// The title the file declares for itself, if it declares one.
  final String? title;

  static MarkdownSource parse(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      return MarkdownSource(body: normalized);
    }

    var end = -1;
    for (var i = 1; i < lines.length; i += 1) {
      final line = lines[i].trim();
      if (line == '---' || line == '...') {
        end = i;
        break;
      }
    }
    if (end < 0) {
      // An opening fence that never closes is not front matter; it is a
      // horizontal rule at the top of the document.
      return MarkdownSource(body: normalized);
    }

    String? title;
    for (final line in lines.sublist(1, end)) {
      final match = RegExp(r'^title\s*:\s*(.*)$').firstMatch(line.trim());
      if (match != null) {
        title = _unquote(match.group(1)!.trim());
        break;
      }
    }

    final body = lines.sublist(end + 1).join('\n');
    return MarkdownSource(
      body: body.startsWith('\n') ? body.substring(1) : body,
      title: (title == null || title.isEmpty) ? null : title,
    );
  }

  static String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
