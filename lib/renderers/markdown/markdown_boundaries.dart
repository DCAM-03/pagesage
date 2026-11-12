import 'dart:math';

import 'package:markdown/markdown.dart' as md;

/// Turns supported Markdown extensions into readable, non-executable text.
///
/// Display math and diagram fences keep their source. Inline math keeps its
/// expression. HTML contributes its visible words only: tags, comments,
/// processing instructions and remote source attributes never become chapter
/// text. The reader therefore stays a local text renderer, with one chapter
/// string for search, selection, progress and location.
final class MarkdownBoundary {
  const MarkdownBoundary() : type = '';

  MarkdownBoundary._(this.type);

  final String type;

  static const int maxSourceLength = 20000;

  static const String diagramBoundaryTag = 'pagesage-mermaid-source';

  static final RegExp _displayMathFence = RegExp(r'^[ \t]{0,3}(\$\$|\\\[)\s*$');

  static final RegExp _inlineMath = RegExp(
    r'(?<!\\)\\\((?:\\.|[^\\\n])+?(?<!\\)\\\)|'
    r'(?<!\\)\$\$(?!\$)(?!\s)((?:\\.|[^$\\\n])+?)(?<!\s)(?<!\\)\$\$|'
    r'(?<!\\)\$(?!\$|\s)((?:\\.|[^$\\\n])*?)(?<!\s)(?<!\\)\$(?!\d)',
  );

  static final RegExp _semanticHtml = RegExp(
    r'<\s*(b|strong|i|em|s|strike|del|u|mark|sup|sub|kbd)\b[^>]*>'
    r'(.*?)'
    r'<\s*/\s*\1\s*>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _htmlSyntax = RegExp(
    r'<\s*(?<tag>script|style|iframe|object|embed|svg|math|template|'
    r'textarea|form|button|audio|video)\b[^>]*>.*?'
    r'<\s*/\s*\k<tag>\s*>|'
    r'<!--.*?-->|<\?.*?\?>|<!\[CDATA\[.*?\]\]>|'
    r'<\s*/?\s*[a-zA-Z][a-zA-Z0-9-]*(?:\s+[^<>]*?)?\s*/?>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _dangerousTagPattern = RegExp(
    r'^</?\s*(?<tag>script|style|iframe|object|embed|link|meta|base|form|'
    r'input|textarea|button|audio|video|source|svg|math|template)\b',
    caseSensitive: false,
  );

  static final RegExp _remoteSource = RegExp(
    r'''\b(?:src|href|srcset|poster)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false,
  );

  static final RegExp _htmlEntity = RegExp(
    r'&(?:([a-zA-Z][a-zA-Z0-9]*)|#([0-9]{1,7})|#[xX]([0-9a-fA-F]{1,6}));',
  );

  static final RegExp _lineBreakTag = RegExp(
    r'<\s*br\s*/?\s*>',
    caseSensitive: false,
  );

  static const String _lineBreakSentinel = '\uE000';

  static final RegExp _htmlBlockStart = RegExp(
    r'''^[ \t]{0,3}<(/?)(script|style|pre|textarea|div|section|article|'''
    r'''aside|header|footer|nav|main|table|ul|ol|figure|details|'''
    r'''iframe|object|embed|form|svg|math|template|p|span|b|i|strong|em|'''
    r'''a|blockquote|code|area|base|br|col|embed|hr|img|input|link|meta|'''
    r'''param|source|track|wbr|h[1-6])\b''',
    caseSensitive: false,
  );

  static final RegExp _htmlCommentStart = RegExp(r'^[ \t]{0,3}<!--');

  static final RegExp _dangerousBlock = RegExp(
    r'''^[ \t]{0,3}<(script|style|iframe|object|embed|svg|math|template|'''
    r'''textarea|form|button|audio|video)\b''',
    caseSensitive: false,
  );

  static String _boundaryToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static final RegExp _boundaryPattern = RegExp(
    r'^<pagesage-safe-boundary data-pagesage-kind="(math|diagram|html|mermaid)" '
    r'data-token="([0-9a-f]{32})">\s*$',
  );

  /// Wraps closed display math, supported diagram fences and HTML blocks
  /// before [md.Document] parses them.
  ///
  /// An unclosed fence or HTML block keeps its original lines. Markdown
  /// inside a code fence is never rewritten.
  String prepare(String source) {
    final token = _boundaryToken();
    final lines = source.split('\n');
    final prepared = <String>[];
    var fence = '';
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final fenceMarker = _fenceMarker(line);
      if (fence.isNotEmpty) {
        final closing = line.trim();
        if (closing.length >= fence.length &&
            closing.codeUnits.every((unit) => unit == fence.codeUnitAt(0))) {
          fence = '';
        }
        prepared.add(line);
        continue;
      }
      final diagramLanguage = _diagramLanguage(line);
      if (diagramLanguage != null) {
        if (fenceMarker != null) {
          final end = _findClosingFence(lines, index + 1, fenceMarker);
          if (end != null) {
            prepared.add(_openBoundary('mermaid', token));
            prepared.add('<$diagramBoundaryTag>');
            prepared.addAll(lines.sublist(index + 1, end));
            prepared.add('</$diagramBoundaryTag>');
            prepared.add(_closeBoundary(token));
            index = end;
            continue;
          }
        }
      }
      if (fenceMarker != null) {
        fence = fenceMarker;
        prepared.add(line);
        continue;
      }
      final mathMatch = _displayMathFence.firstMatch(line);
      if (mathMatch != null) {
        final closing = _matchingMathFence(mathMatch.group(1)!);
        final end = _findClosingLine(lines, index + 1, closing);
        if (end != null) {
          prepared.add(_openBoundary('math', token));
          prepared.addAll(lines.sublist(index + 1, end));
          prepared.add(_closeBoundary(token));
          index = end;
          continue;
        }
      }
      final htmlMatch = _htmlBlockStart.firstMatch(line);
      final dangerousMatch = _dangerousBlock.firstMatch(line);
      final commentStart = _htmlCommentStart.hasMatch(line);
      if (htmlMatch != null || dangerousMatch != null || commentStart) {
        final end = switch (dangerousMatch) {
          null when commentStart => _findHtmlCommentEnd(lines, index),
          null => _findHtmlBlockEnd(lines, index, htmlMatch!.group(2)!),
          _ => _findDangerousBlockEnd(lines, index, dangerousMatch.group(1)!),
        };
        prepared.add(_openBoundary('html', token));
        prepared.addAll(lines.sublist(index, end + 1));
        prepared.add(_closeBoundary(token));
        index = end;
        continue;
      }
      prepared.add(line);
    }
    return prepared.join('\n');
  }

  /// The custom inline syntaxes that expose math and raw HTML to the walker.
  List<md.InlineSyntax> get inlineSyntaxes => <md.InlineSyntax>[
    _BoundaryInlineSyntax(_inlineMath.pattern, 'math'),
    _InlineHtmlSyntax(_semanticHtml.pattern),
    _BoundaryInlineSyntax(_htmlSyntax.pattern, 'html', caseSensitive: false),
  ];

  /// The custom block syntax that turns a prepared boundary into one node.
  md.BlockSyntax get blockSyntax => const _BoundaryBlockSyntax();

  /// Reads a boundary element as a source block.
  MarkdownBoundary? read(md.Element element) {
    final type = element.attributes['data-pagesage-kind'];
    if (type == null || type.isEmpty) {
      return null;
    }
    return MarkdownBoundary._(type);
  }

  /// Reads a boundary element as readable, non-executable chapter text.
  String sourceText(md.Element element, {required String label}) {
    final raw = element.textContent;
    if (element.attributes['data-pagesage-kind'] == 'mermaid') {
      final body = raw
          .replaceAll('<$diagramBoundaryTag>', '')
          .replaceAll('</$diagramBoundaryTag>', '')
          .trim();
      return _clamp(body.isEmpty ? label : body);
    }
    final body = element.attributes['data-pagesage-kind'] == 'html'
        ? _safeVisibleText(raw)
        : _stripDisplayDelimiters(raw);
    final cleaned = _clamp(body.replaceAll('\r\n', '\n').trim());
    if (cleaned.isNotEmpty ||
        element.attributes['data-pagesage-kind'] == 'html') {
      return cleaned;
    }
    return label;
  }

  /// Converts inline math into readable source and raw HTML into safe text.
  String inlineText(md.Element element) {
    return switch (element.tag) {
      'pagesage-math' => _stripDisplayDelimiters(element.textContent),
      'pagesage-html' || 'pagesage-html-inline' => _safeVisibleText(
        element.textContent,
        preserveLineBreaks: true,
      ),
      _ => element.textContent,
    };
  }

  /// The safe inline HTML tag this node represents, if any.
  String? inlineHtmlTag(md.Element element) {
    return element.attributes['data-pagesage-html-tag']?.toLowerCase();
  }

  /// The unmodified source carried by a prepared boundary.
  String rawText(md.Element element) => element.textContent;

  String diagramSource(md.Element element) {
    return element.textContent
        .replaceAll('<$diagramBoundaryTag>', '')
        .replaceAll('</$diagramBoundaryTag>', '')
        .replaceAll('\r\n', '\n')
        .trim();
  }

  String _stripDisplayDelimiters(String raw) {
    var text = raw.trim();
    for (final delimiter in const <String>[
      r'$$',
      r'\[',
      r'\]',
      r'\(',
      r'\)',
      r'$',
    ]) {
      if (text.startsWith(delimiter)) {
        text = text.substring(delimiter.length);
      }
      if (text.endsWith(delimiter)) {
        text = text.substring(0, text.length - delimiter.length);
      }
    }
    return _clamp(text.trim());
  }

  String _safeVisibleText(String raw, {bool preserveLineBreaks = false}) {
    final dangerous = <String>{};
    final matched = _htmlSyntax.allMatches(raw).toList();
    var text = raw;
    for (final match in matched.reversed) {
      final syntax = match.group(0)!;
      final dangerousTag = _dangerousTagPattern.firstMatch(syntax);
      if (dangerousTag != null) {
        dangerous.add(dangerousTag.group(1)!.toLowerCase());
      }
      final replacement = preserveLineBreaks && _lineBreakTag.hasMatch(syntax)
          ? _lineBreakSentinel
          : '';
      text = text.replaceRange(match.start, match.end, replacement);
    }
    text = text
        .replaceAll(_remoteSource, '')
        .replaceAllMapped(_htmlEntity, (match) {
          final entity = match.group(1)?.toLowerCase();
          if (entity != null) {
            return switch (entity) {
              'amp' => '&',
              'lt' => '<',
              'gt' => '>',
              'quot' => '"',
              'apos' || 'nbsp' => ' ',
              _ => match.group(0)!,
            };
          }
          final decimal = match.group(2);
          if (decimal != null) {
            return _codePoint(int.tryParse(decimal));
          }
          final hexadecimal = match.group(3);
          if (hexadecimal != null) {
            return _codePoint(int.tryParse(hexadecimal, radix: 16));
          }
          return match.group(0)!;
        })
        .replaceAll(RegExp(r'[\t\f\r]+'), ' ')
        .replaceAll(RegExp(r'[ ]{2,}'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), ' ')
        .trim();
    if (preserveLineBreaks) {
      text = text.replaceAll(_lineBreakSentinel, '\n');
    }
    if (dangerous.isNotEmpty) {
      final names = dangerous.toList()..sort();
      final note = '已忽略 ${names.join('、')} 标签';
      return text.isEmpty ? note : '$text  $note';
    }
    return text;
  }

  String _codePoint(int? value) {
    if (value == null || value <= 0 || value > 0x10FFFF) {
      return '';
    }
    return value <= 0xFFFF
        ? String.fromCharCode(value)
        : String.fromCharCodes(<int>[
            0xD800 + ((value - 0x10000) >> 10),
            0xDC00 + ((value - 0x10000) & 0x3FF),
          ]);
  }

  String _clamp(String value) {
    return value.length <= maxSourceLength
        ? value
        : '${value.substring(0, maxSourceLength)}…';
  }

  String _openBoundary(String type, String token) =>
      '<pagesage-safe-boundary data-pagesage-kind="$type" '
      'data-token="$token">';

  String _closeBoundary(String token) =>
      '</pagesage-safe-boundary data-token="$token">';

  String _matchingMathFence(String opening) => opening == r'\[' ? r'\]' : r'$$';

  String? _fenceMarker(String line) {
    return RegExp(r'^[ \t]{0,3}(`{3,}|~{3,})').firstMatch(line)?.group(1);
  }

  int? _findClosingLine(List<String> lines, int start, String closing) {
    for (var index = start; index < lines.length; index += 1) {
      if (_fenceMarker(lines[index]) != null) {
        return null;
      }
      if (_lineIs(lines[index], closing)) {
        return index;
      }
    }
    return null;
  }

  bool _lineIs(String line, String expected) {
    return expected == r'$$' ? line.trim() == r'$$' : line.trim() == r'\]';
  }

  String? _diagramLanguage(String line) {
    final match = RegExp(
      r'^[ \t]{0,3}(?:`{3,}|~{3,})\s*([A-Za-z0-9_+-]+)',
    ).firstMatch(line);
    final language = match?.group(1)?.toLowerCase();
    return const <String>{
          'mermaid',
          'plantuml',
          'graphviz',
          'dot',
        }.contains(language)
        ? language
        : null;
  }

  int? _findClosingFence(List<String> lines, int start, String marker) {
    for (var index = start; index < lines.length; index += 1) {
      final trimmed = lines[index].trim();
      if (trimmed.length >= marker.length &&
          trimmed.codeUnits.every((unit) => unit == marker.codeUnitAt(0))) {
        return index;
      }
    }
    return null;
  }

  int _findDangerousBlockEnd(List<String> lines, int start, String tag) {
    final closing = RegExp(
      r'</\s*' + RegExp.escape(tag) + r'\s*>',
      caseSensitive: false,
    );
    for (var index = start; index < lines.length; index += 1) {
      if (closing.hasMatch(lines[index])) {
        return index;
      }
      if (index > start && lines[index].trim().isEmpty) {
        return index - 1;
      }
    }
    return lines.length - 1;
  }

  int _findHtmlCommentEnd(List<String> lines, int start) {
    for (var index = start; index < lines.length; index += 1) {
      if (lines[index].contains('-->')) {
        return index;
      }
    }
    return lines.length - 1;
  }

  int _findHtmlBlockEnd(List<String> lines, int start, String tag) {
    if (const <String>{
      'area',
      'base',
      'br',
      'col',
      'embed',
      'hr',
      'img',
      'input',
      'link',
      'meta',
      'param',
      'source',
      'track',
      'wbr',
    }.contains(tag.toLowerCase())) {
      return start;
    }
    final closing = RegExp(
      r'</\s*' + RegExp.escape(tag) + r'\s*>',
      caseSensitive: false,
    );
    for (var index = start; index < lines.length; index += 1) {
      if (closing.hasMatch(lines[index])) {
        return index;
      }
      if (index > start && lines[index].trim().isEmpty) {
        return index - 1;
      }
    }
    return lines.length - 1;
  }
}

final class _BoundaryInlineSyntax extends md.InlineSyntax {
  _BoundaryInlineSyntax(super.pattern, this.tag, {super.caseSensitive});

  final String tag;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('pagesage-$tag', match.group(0)!));
    return true;
  }
}

final class _InlineHtmlSyntax extends md.InlineSyntax {
  _InlineHtmlSyntax(super.pattern) : super(caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('pagesage-html-inline', match.group(2)!);
    element.attributes['data-pagesage-html-tag'] = match
        .group(1)!
        .toLowerCase();
    parser.addNode(element);
    return true;
  }
}

final class _BoundaryBlockSyntax extends md.BlockSyntax {
  const _BoundaryBlockSyntax();

  @override
  RegExp get pattern => MarkdownBoundary._boundaryPattern;

  @override
  bool canEndBlock(md.BlockParser parser) => true;

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) {
      return null;
    }
    final kind = match.group(1)!;
    final token = match.group(2)!;
    final closing = '</pagesage-safe-boundary data-token="$token">';
    final lines = <String>[];
    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim() == closing) {
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }
    final element = md.Element.text('pagesage-safe-boundary', lines.join('\n'));
    element.attributes['data-pagesage-kind'] = kind;
    return element;
  }
}
