import 'package:flutter/material.dart';

import '../../domain/books/reader_settings.dart';
import '../epub/epub_document.dart';

/// Quiet syntax colours that still meet WCAG AA on every reader theme's
/// code-panel background.
///
/// The panel is a tint of the theme foreground over its background, so the
/// palette is chosen for that composite rather than for plain white paper.
Color codeSyntaxColor(ReaderThemePreset preset, EpubCodeTokenType? type) {
  if (preset == ReaderThemePreset.contrast) {
    return switch (type) {
      EpubCodeTokenType.keyword => const Color(0xFF3B0A4A),
      EpubCodeTokenType.type => const Color(0xFF003566),
      EpubCodeTokenType.string => const Color(0xFF003D22),
      EpubCodeTokenType.number => const Color(0xFF4A2800),
      EpubCodeTokenType.comment => const Color(0xFF2E3842),
      EpubCodeTokenType.literal => const Color(0xFF511A10),
      null => preset.foreground,
    };
  }
  if (preset == ReaderThemePreset.night) {
    return switch (type) {
      EpubCodeTokenType.keyword => const Color(0xFFE6A8FF),
      EpubCodeTokenType.type => const Color(0xFF9CD2FF),
      EpubCodeTokenType.string => const Color(0xFF8CE2B3),
      EpubCodeTokenType.number => const Color(0xFFFFC48A),
      EpubCodeTokenType.comment => const Color(0xFFB7C0CC),
      EpubCodeTokenType.literal => const Color(0xFFFFAB9A),
      null => preset.foreground,
    };
  }
  return switch (type) {
    EpubCodeTokenType.keyword => const Color(0xFF5B1A6B),
    EpubCodeTokenType.type => const Color(0xFF0B4A86),
    EpubCodeTokenType.string => const Color(0xFF075A35),
    EpubCodeTokenType.number => const Color(0xFF6B3B00),
    EpubCodeTokenType.comment => const Color(0xFF44505C),
    EpubCodeTokenType.literal => const Color(0xFF7A2E20),
    null => preset.foreground,
  };
}

/// A lightweight, language-aware scanner for fenced code.
///
/// It is deliberately not a compiler parser. It recognises the things a reader
/// scans for first — comments, strings, numbers and common words — while every
/// run is expressed over the original code text. Every fence still gets
/// numbers and quoted text; a language only adds comments and word categories.
final class CodeSyntax {
  const CodeSyntax();

  static const Map<String, _CodeDialect> _dialects = {
    'bash': _CodeDialect(
      lineComment: '#',
      keywords: {
        'case',
        'do',
        'done',
        'elif',
        'else',
        'esac',
        'fi',
        'for',
        'function',
        'if',
        'in',
        'local',
        'return',
        'then',
        'until',
        'while',
      },
      literals: {'false', 'null', 'true'},
    ),
    'c': _cLike,
    'cpp': _cLike,
    'csharp': _cLike,
    'css': _CodeDialect(
      blockComment: _cBlockComment,
      keywords: {'@import', '@media', 'important'},
    ),
    'dart': _CodeDialect(
      lineComment: '//',
      blockComment: _cBlockComment,
      keywords: {
        'as',
        'async',
        'await',
        'break',
        'case',
        'catch',
        'class',
        'const',
        'continue',
        'default',
        'do',
        'else',
        'enum',
        'extends',
        'final',
        'finally',
        'for',
        'if',
        'implements',
        'import',
        'in',
        'is',
        'new',
        'return',
        'switch',
        'throw',
        'try',
        'var',
        'while',
        'with',
        'yield',
      },
      types: {
        'bool',
        'double',
        'dynamic',
        'int',
        'List',
        'Map',
        'num',
        'Object',
        'Set',
        'String',
        'void',
      },
      literals: {'false', 'null', 'true'},
    ),
    'go': _CodeDialect(
      lineComment: '//',
      blockComment: _cBlockComment,
      keywords: {
        'break',
        'case',
        'chan',
        'const',
        'continue',
        'default',
        'defer',
        'else',
        'fallthrough',
        'for',
        'func',
        'go',
        'goto',
        'if',
        'import',
        'interface',
        'map',
        'package',
        'range',
        'return',
        'select',
        'struct',
        'switch',
        'type',
        'var',
      },
      types: {'bool', 'byte', 'error', 'float32', 'float64', 'int', 'string'},
      literals: {'false', 'iota', 'nil', 'true'},
    ),
    'html': _markupDialect,
    'java': _cLike,
    'javascript': _scriptDialect,
    'json': _CodeDialect(literals: {'false', 'null', 'true'}),
    'jsx': _scriptDialect,
    'kotlin': _CodeDialect(
      lineComment: '//',
      blockComment: _cBlockComment,
      keywords: {
        'as',
        'break',
        'class',
        'continue',
        'do',
        'else',
        'for',
        'fun',
        'if',
        'in',
        'interface',
        'is',
        'object',
        'override',
        'package',
        'return',
        'suspend',
        'throw',
        'try',
        'val',
        'var',
        'when',
        'while',
      },
      types: {'Boolean', 'Byte', 'Double', 'Float', 'Int', 'Long', 'String'},
      literals: {'false', 'null', 'true'},
    ),
    'lua': _CodeDialect(
      lineComment: '--',
      blockComment: (open: '--[[', close: ']]'),
      keywords: {
        'and',
        'break',
        'do',
        'else',
        'elseif',
        'end',
        'for',
        'function',
        'if',
        'in',
        'local',
        'not',
        'or',
        'repeat',
        'return',
        'then',
        'until',
        'while',
      },
      literals: {'false', 'nil', 'true'},
    ),
    'markdown': _CodeDialect(
      keywords: {'#', '##', '###', '####', '#####', '######', '>'},
    ),
    'objectivec': _cLike,
    'php': _CodeDialect(
      lineComment: '//',
      blockComment: _cBlockComment,
      keywords: {
        'abstract',
        'break',
        'case',
        'catch',
        'class',
        'const',
        'continue',
        'default',
        'do',
        'echo',
        'else',
        'elseif',
        'extends',
        'final',
        'finally',
        'foreach',
        'function',
        'if',
        'implements',
        'interface',
        'namespace',
        'new',
        'private',
        'protected',
        'public',
        'return',
        'static',
        'switch',
        'throw',
        'try',
        'use',
        'var',
        'while',
      },
      literals: {'false', 'null', 'true'},
    ),
    'python': _CodeDialect(
      lineComment: '#',
      keywords: {
        'and',
        'as',
        'assert',
        'async',
        'await',
        'break',
        'class',
        'continue',
        'def',
        'del',
        'elif',
        'else',
        'except',
        'finally',
        'for',
        'from',
        'global',
        'if',
        'import',
        'in',
        'is',
        'lambda',
        'nonlocal',
        'not',
        'or',
        'pass',
        'raise',
        'return',
        'try',
        'while',
        'with',
        'yield',
      },
      types: {
        'bool',
        'bytes',
        'dict',
        'float',
        'int',
        'list',
        'object',
        'set',
        'str',
        'tuple',
      },
      literals: {'False', 'None', 'True'},
    ),
    'ruby': _CodeDialect(
      lineComment: '#',
      keywords: {
        'begin',
        'break',
        'case',
        'class',
        'def',
        'do',
        'else',
        'elsif',
        'end',
        'ensure',
        'for',
        'if',
        'in',
        'module',
        'next',
        'rescue',
        'return',
        'then',
        'unless',
        'until',
        'when',
        'while',
        'yield',
      },
      literals: {'false', 'nil', 'true'},
    ),
    'rust': _CodeDialect(
      lineComment: '//',
      blockComment: _cBlockComment,
      keywords: {
        'as',
        'async',
        'await',
        'break',
        'const',
        'continue',
        'crate',
        'dyn',
        'else',
        'enum',
        'extern',
        'fn',
        'for',
        'if',
        'impl',
        'in',
        'let',
        'loop',
        'match',
        'mod',
        'move',
        'mut',
        'pub',
        'ref',
        'return',
        'self',
        'static',
        'struct',
        'super',
        'trait',
        'type',
        'unsafe',
        'use',
        'where',
        'while',
      },
      types: {
        'bool',
        'char',
        'f32',
        'f64',
        'i8',
        'i16',
        'i32',
        'i64',
        'isize',
        'str',
        'u8',
        'u16',
        'u32',
        'u64',
        'usize',
        'String',
        'Vec',
      },
      literals: {'false', 'None', 'Some', 'true'},
    ),
    'scala': _cLike,
    'shell': _CodeDialect(
      lineComment: '#',
      keywords: {
        'case',
        'do',
        'done',
        'elif',
        'else',
        'esac',
        'fi',
        'for',
        'function',
        'if',
        'in',
        'local',
        'return',
        'then',
        'until',
        'while',
      },
      literals: {'false', 'null', 'true'},
    ),
    'sql': _CodeDialect(
      lineComment: '--',
      blockComment: _cBlockComment,
      keywords: {
        'ALTER',
        'AND',
        'AS',
        'BY',
        'CREATE',
        'DELETE',
        'DROP',
        'FROM',
        'GROUP',
        'HAVING',
        'INSERT',
        'INTO',
        'JOIN',
        'LIMIT',
        'NOT',
        'ON',
        'OR',
        'ORDER',
        'SELECT',
        'SET',
        'TABLE',
        'UPDATE',
        'VALUES',
        'WHERE',
      },
      literals: {'FALSE', 'NULL', 'TRUE'},
      caseInsensitive: true,
    ),
    'swift': _CodeDialect(
      lineComment: '//',
      blockComment: _cBlockComment,
      keywords: {
        'async',
        'await',
        'break',
        'case',
        'catch',
        'class',
        'continue',
        'default',
        'defer',
        'do',
        'else',
        'enum',
        'extension',
        'fallthrough',
        'for',
        'func',
        'guard',
        'if',
        'import',
        'in',
        'init',
        'let',
        'protocol',
        'repeat',
        'return',
        'struct',
        'switch',
        'throw',
        'try',
        'var',
        'where',
        'while',
      },
      types: {'Bool', 'Double', 'Float', 'Int', 'String', 'UInt', 'Void'},
      literals: {'false', 'nil', 'true'},
    ),
    'toml': _CodeDialect(lineComment: '#', literals: {'false', 'true'}),
    'ts': _scriptDialect,
    'typescript': _scriptDialect,
    'xml': _markupDialect,
    'yaml': _CodeDialect(lineComment: '#', literals: {'false', 'null', 'true'}),
  };

  static const _CodeDialect _cLike = _CodeDialect(
    lineComment: '//',
    blockComment: _cBlockComment,
    keywords: {
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'delete',
      'do',
      'else',
      'enum',
      'extends',
      'final',
      'finally',
      'for',
      'goto',
      'if',
      'implements',
      'import',
      'instanceof',
      'interface',
      'new',
      'override',
      'package',
      'private',
      'protected',
      'public',
      'return',
      'static',
      'struct',
      'switch',
      'throw',
      'try',
      'using',
      'virtual',
      'while',
    },
    types: {
      'bool',
      'boolean',
      'byte',
      'char',
      'double',
      'float',
      'int',
      'long',
      'object',
      'short',
      'string',
      'void',
    },
    literals: {'false', 'null', 'true'},
  );

  static const _CodeDialect _scriptDialect = _CodeDialect(
    lineComment: '//',
    blockComment: _cBlockComment,
    keywords: {
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'delete',
      'do',
      'else',
      'export',
      'extends',
      'finally',
      'for',
      'from',
      'function',
      'if',
      'import',
      'in',
      'instanceof',
      'interface',
      'let',
      'new',
      'of',
      'return',
      'static',
      'super',
      'switch',
      'this',
      'throw',
      'try',
      'typeof',
      'var',
      'void',
      'while',
      'yield',
    },
    types: {
      'Array',
      'boolean',
      'Map',
      'number',
      'Object',
      'Promise',
      'Set',
      'string',
      'Symbol',
      'unknown',
    },
    literals: {'false', 'NaN', 'null', 'true', 'undefined'},
  );

  static const _CodeDialect _markupDialect = _CodeDialect(
    blockComment: (open: '<!--', close: '-->'),
    keywords: {'!DOCTYPE'},
  );

  static const ({String open, String close}) _cBlockComment = (
    open: '/*',
    close: '*/',
  );

  static const Map<String, String> _aliases = {
    'c++': 'cpp',
    'cs': 'csharp',
    'golang': 'go',
    'htm': 'html',
    'js': 'javascript',
    'jsonc': 'json',
    'kt': 'kotlin',
    'md': 'markdown',
    'objc': 'objectivec',
    'py': 'python',
    'rb': 'ruby',
    'rs': 'rust',
    'sh': 'shell',
    'tsx': 'typescript',
    'yml': 'yaml',
    'zsh': 'shell',
  };

  /// Returns non-overlapping visual runs in ascending order.
  ///
  /// [chapterOffset] is where [code] starts in its chapter; the returned runs
  /// use that same coordinate system, exactly like emphasis and links.
  List<EpubCodeRun> tokenize(
    String code, {
    String? language,
    required int chapterOffset,
  }) {
    final dialect = _dialects[_normalizeLanguage(language)];
    final runs = <EpubCodeRun>[];
    var cursor = 0;
    while (cursor < code.length) {
      final start = cursor;
      final character = code[cursor];
      if (_isWhitespace(character)) {
        cursor += 1;
        continue;
      }

      final blockComment = dialect?.blockComment;
      if (dialect?.lineComment != null &&
          code.startsWith(dialect!.lineComment!, cursor)) {
        cursor = _endOfLine(code, cursor);
        _add(runs, start, cursor, EpubCodeTokenType.comment, chapterOffset);
        continue;
      }
      if (blockComment != null && code.startsWith(blockComment.open, cursor)) {
        final close = code.indexOf(
          blockComment.close,
          cursor + blockComment.open.length,
        );
        cursor = close < 0 ? code.length : close + blockComment.close.length;
        _add(runs, start, cursor, EpubCodeTokenType.comment, chapterOffset);
        continue;
      }
      if (_isQuote(character)) {
        cursor = _endOfQuoted(code, cursor, character);
        _add(runs, start, cursor, EpubCodeTokenType.string, chapterOffset);
        continue;
      }
      if (_isDigit(character) ||
          (character == '.' &&
              cursor + 1 < code.length &&
              _isDigit(code[cursor + 1]))) {
        cursor = _endOfNumber(code, cursor);
        _add(runs, start, cursor, EpubCodeTokenType.number, chapterOffset);
        continue;
      }
      if (_isWordStart(character)) {
        cursor = _endOfWord(code, cursor);
        final word = code.substring(start, cursor);
        final lookup = dialect?.caseInsensitive == true
            ? word.toUpperCase()
            : word;
        final type = dialect == null
            ? null
            : dialect.literals.contains(lookup)
            ? EpubCodeTokenType.literal
            : dialect.keywords.contains(lookup)
            ? EpubCodeTokenType.keyword
            : dialect.types.contains(lookup)
            ? EpubCodeTokenType.type
            : null;
        if (type != null) {
          _add(runs, start, cursor, type, chapterOffset);
        }
        continue;
      }
      cursor += 1;
    }
    return runs;
  }

  void _add(
    List<EpubCodeRun> runs,
    int start,
    int end,
    EpubCodeTokenType type,
    int chapterOffset,
  ) {
    if (start >= end) {
      return;
    }
    runs.add(
      EpubCodeRun(
        start: chapterOffset + start,
        end: chapterOffset + end,
        type: type,
      ),
    );
  }

  String _normalizeLanguage(String? language) {
    final raw = language?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final first = raw.split(RegExp(r'[\s+,;:{]')).first;
    final normalized = _aliases[first] ?? first;
    return _dialects.containsKey(normalized) ? normalized : '';
  }

  int _endOfLine(String code, int start) {
    final newline = code.indexOf('\n', start);
    return newline < 0 ? code.length : newline;
  }

  int _endOfQuoted(String code, int start, String quote) {
    var cursor = start + 1;
    while (cursor < code.length) {
      final character = code[cursor];
      if (character == '\\' && cursor + 1 < code.length) {
        cursor += 2;
        continue;
      }
      if (character == quote) {
        return cursor + 1;
      }
      if (character == '\n' && quote != '`') {
        return cursor;
      }
      cursor += 1;
    }
    return code.length;
  }

  int _endOfNumber(String code, int start) {
    var cursor = start + 1;
    while (cursor < code.length) {
      final character = code[cursor];
      if (_isDigit(character) ||
          character == '.' ||
          character == '_' ||
          character == 'x' ||
          character == 'X' ||
          character == 'o' ||
          character == 'O' ||
          character == 'b' ||
          character == 'B' ||
          character == 'e' ||
          character == 'E' ||
          (character == '+' || character == '-') &&
              cursor > start &&
              (code[cursor - 1] == 'e' || code[cursor - 1] == 'E') ||
          _isHexDigit(character)) {
        cursor += 1;
        continue;
      }
      break;
    }
    return cursor;
  }

  int _endOfWord(String code, int start) {
    var cursor = start + 1;
    while (cursor < code.length && _isWordPart(code[cursor])) {
      cursor += 1;
    }
    return cursor;
  }

  bool _isWhitespace(String character) =>
      character == ' ' ||
      character == '\t' ||
      character == '\n' ||
      character == '\r' ||
      character == '\f';

  bool _isQuote(String character) =>
      character == '"' || character == "'" || character == '`';

  bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39;

  bool _isHexDigit(String character) {
    final lower = character.toLowerCase().codeUnitAt(0);
    return lower >= 0x61 && lower <= 0x66;
  }

  bool _isWordStart(String character) =>
      character == '_' ||
      character == '@' ||
      character == '#' ||
      character == '!' ||
      character == '>' ||
      (character.codeUnitAt(0) >= 0x41 && character.codeUnitAt(0) <= 0x5A) ||
      (character.codeUnitAt(0) >= 0x61 && character.codeUnitAt(0) <= 0x7A) ||
      character.codeUnitAt(0) > 0x7F;

  bool _isWordPart(String character) =>
      _isWordStart(character) || _isDigit(character) || character == '-';
}

final class _CodeDialect {
  const _CodeDialect({
    this.lineComment,
    this.blockComment,
    this.keywords = const <String>{},
    this.types = const <String>{},
    this.literals = const <String>{},
    this.caseInsensitive = false,
  });

  final String? lineComment;
  final ({String open, String close})? blockComment;
  final Set<String> keywords;
  final Set<String> types;
  final Set<String> literals;
  final bool caseInsensitive;
}
