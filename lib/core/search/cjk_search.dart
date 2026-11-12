import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Versioned text normalization and CJK term generation for FTS5.
///
/// The normalizer records a UTF-16 offset back to the original text for every
/// emitted UTF-16 unit. Search uses those offsets to produce real highlight
/// ranges; it never treats a derived term or an FTS snippet as book text.
final class SearchTextNormalizerV1 {
  const SearchTextNormalizerV1();

  static const String version = 'normalizer-v2';
  static const String tokenizerVersion = 'cjk-tokenizer-v1';
  static const int maxQueryLength = 256;
  static const int maxGroups = 16;
  static const int maxTerms = 128;

  SearchNormalizedText normalize(String source) {
    final buffer = StringBuffer();
    final offsets = <int>[];
    var pendingStart = -1;
    var pendingEnd = -1;
    for (var index = 0; index < source.length; index += 1) {
      final rune = _runeAt(source, index);
      final normalized = _normalizeRune(rune.value);
      if (_isWhitespace(normalized)) {
        if (buffer.isNotEmpty) {
          if (pendingStart < 0) pendingStart = index;
          pendingEnd = index + rune.width;
        }
        index += rune.width - 1;
        continue;
      }
      if (pendingStart >= 0) {
        buffer.write(' ');
        offsets.add(
          pendingEnd - pendingStart == 1 ? pendingStart : -pendingStart,
        );
        pendingStart = -1;
        pendingEnd = -1;
      }
      buffer.writeCharCode(normalized);
      offsets.add(index);
      if (rune.width == 2) offsets.add(index + 1);
      index += rune.width - 1;
    }
    final text = buffer.toString();
    return SearchNormalizedText(text, List.unmodifiable(offsets));
  }

  ({int start, int end}) originalRange(
    SearchNormalizedText normalized,
    int start,
    int end,
  ) {
    if (normalized.offsets.isEmpty || start < 0 || end <= start) {
      return (start: 0, end: 0);
    }
    final last = end - 1 >= normalized.offsets.length
        ? normalized.offsets.length - 1
        : end - 1;
    final firstOffset = normalized.offsets[start.clamp(0, last)];
    final lastOffset = normalized.offsets[last].abs();
    final startOffset = firstOffset.abs();
    final mappedEnd = lastOffset >= startOffset ? lastOffset + 1 : startOffset;
    return (start: startOffset, end: mappedEnd);
  }

  bool isCjk(int rune) {
    return (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF);
  }

  bool isLatinWord(int rune) {
    return (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A);
  }

  bool isBoundary(int rune) {
    return _isWhitespace(rune) || (!isCjk(rune) && !isLatinWord(rune));
  }

  String cjkTerms(String normalized) {
    final output = StringBuffer();
    final runes = <int>[];
    for (final rune in normalized.runes) {
      if (isCjk(rune)) {
        runes.add(rune);
        continue;
      }
      _writeCjkRun(output, runes);
      runes.clear();
    }
    _writeCjkRun(output, runes);
    return output.toString().trim();
  }

  String normalizedTerms(String normalized) {
    final output = StringBuffer();
    final token = StringBuffer();
    for (final rune in normalized.runes) {
      if (isLatinWord(rune)) {
        token.writeCharCode(rune);
      } else {
        _writeNormalizedToken(output, token);
        token.clear();
      }
    }
    _writeNormalizedToken(output, token);
    return output.toString().trim();
  }

  void _writeCjkRun(StringBuffer output, List<int> runes) {
    if (runes.isEmpty) return;
    for (final rune in runes) {
      output.write('u${_hex(rune)} ');
    }
    for (var index = 0; index + 1 < runes.length; index += 1) {
      output.write('b${_hex(runes[index])}${_hex(runes[index + 1])} ');
    }
  }

  void _writeNormalizedToken(StringBuffer output, StringBuffer token) {
    if (token.isEmpty) return;
    output.write('${token.toString().toLowerCase()} ');
  }

  String _hex(int value) => value.toRadixString(16).padLeft(6, '0');

  int _normalizeRune(int rune) {
    if (rune == 0x3000) return 0x20;
    final folded = rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune;
    return folded >= 0x41 && folded <= 0x5A ? folded + 0x20 : folded;
  }

  bool _isWhitespace(int rune) {
    return rune == 0x20 ||
        rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D ||
        rune == 0x0C;
  }

  ({int value, int width}) _runeAt(String text, int index) {
    final codeUnit = text.codeUnitAt(index);
    if (index + 1 < text.length && codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      final next = text.codeUnitAt(index + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        return (
          value: 0x10000 + ((codeUnit - 0xD800) << 10) + (next - 0xDC00),
          width: 2,
        );
      }
    }
    return (value: codeUnit, width: 1);
  }
}

final class SearchNormalizedText {
  const SearchNormalizedText(this.text, this.offsets);

  final String text;
  final List<int> offsets;
}

enum SearchGroupKind { latin, cjk, mixed }

final class SearchGroup {
  const SearchGroup({
    required this.text,
    required this.kind,
    required this.terms,
  });

  final String text;
  final SearchGroupKind kind;
  final List<String> terms;
}

final class ParsedSearchQuery {
  const ParsedSearchQuery({
    required this.groups,
    required this.normalized,
    required this.terms,
  });

  final List<SearchGroup> groups;
  final String normalized;
  final List<String> terms;

  bool get isEmpty => groups.isEmpty;
}

final class SearchQueryParserV1 {
  const SearchQueryParserV1([this.normalizer = const SearchTextNormalizerV1()]);

  final SearchTextNormalizerV1 normalizer;

  ParsedSearchQuery parse(String raw) {
    if (raw.length > SearchTextNormalizerV1.maxQueryLength) {
      throw const SearchQueryException('搜索内容过长');
    }
    final normalized = normalizer.normalize(raw).text;
    if (normalized.isEmpty) {
      return const ParsedSearchQuery(groups: [], normalized: '', terms: []);
    }
    final groups = <SearchGroup>[];
    final runes = normalized.runes.toList(growable: false);
    var start = 0;
    while (start <= runes.length) {
      while (start < runes.length && _boundary(runes[start])) {
        start += 1;
      }
      if (start >= runes.length) break;
      var end = start;
      var currentKind = _kind(runes[start]);
      while (end < runes.length && !_boundary(runes[end])) {
        final kind = _kind(runes[end]);
        if (currentKind == SearchGroupKind.mixed || kind != currentKind) {
          currentKind = SearchGroupKind.mixed;
        }
        end += 1;
      }
      final text = String.fromCharCodes(runes.sublist(start, end));
      final terms = <String>[
        ..._splitTokens(normalizer.cjkTerms(text)),
        ..._splitTokens(normalizer.normalizedTerms(text)),
      ];
      if (terms.isNotEmpty) {
        groups.add(SearchGroup(text: text, kind: currentKind, terms: terms));
      }
      if (groups.length > SearchTextNormalizerV1.maxGroups) {
        throw const SearchQueryException('搜索分组过多');
      }
      start = end;
    }
    final terms = <String>{for (final group in groups) ...group.terms}.toList()
      ..sort();
    if (terms.length > SearchTextNormalizerV1.maxTerms) {
      throw const SearchQueryException('搜索词过多');
    }
    return ParsedSearchQuery(
      groups: List.unmodifiable(groups),
      normalized: normalized,
      terms: List.unmodifiable(terms),
    );
  }

  List<String> _splitTokens(String value) => value
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  bool _boundary(int rune) => normalizer.isBoundary(rune);

  SearchGroupKind _kind(int rune) =>
      normalizer.isCjk(rune) ? SearchGroupKind.cjk : SearchGroupKind.latin;
}

final class SearchQueryException implements Exception {
  const SearchQueryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SearchIndexTerms {
  const SearchIndexTerms({
    required this.titleNormalized,
    required this.textNormalized,
    required this.titleTerms,
    required this.textTerms,
    required this.inputRevision,
  });

  factory SearchIndexTerms.fromText({
    required String inputKey,
    required String title,
    required String text,
    required String sourceRevision,
    required String textRevision,
    required String extractorVersion,
    SearchTextNormalizerV1 normalizer = const SearchTextNormalizerV1(),
  }) {
    final normalizedTitle = normalizer.normalize(title).text;
    final normalizedText = normalizer.normalize(text).text;
    final revision = sha256
        .convert(
          utf8.encode(
            [
              inputKey,
              sourceRevision,
              textRevision,
              extractorVersion,
              SearchTextNormalizerV1.version,
              SearchTextNormalizerV1.tokenizerVersion,
              normalizedTitle,
              normalizedText,
            ].map((value) => '${value.length}:$value').join('|'),
          ),
        )
        .toString();
    return SearchIndexTerms(
      titleNormalized: normalizedTitle,
      textNormalized: normalizedText,
      titleTerms: normalizer.cjkTerms(normalizedTitle),
      textTerms: normalizer.cjkTerms(normalizedText),
      inputRevision: revision,
    );
  }

  final String titleNormalized;
  final String textNormalized;
  final String titleTerms;
  final String textTerms;
  final String inputRevision;
}

final class SearchMatchKind {
  static const String exact = 'exact';
  static const String related = 'related';
}

final class SearchRankCandidate {
  const SearchRankCandidate({
    required this.id,
    required this.bookTitle,
    required this.bookId,
    required this.address,
    required this.startOffset,
    required this.chunkId,
    required this.normalizedTitle,
    required this.normalizedText,
    required this.rrf,
    required this.exactGroups,
    required this.titleExactGroups,
    required this.textExactGroups,
    required this.related,
  });

  final String id;
  final String bookTitle;
  final String? bookId;
  final String address;
  final int startOffset;
  final String chunkId;
  final String normalizedTitle;
  final String normalizedText;
  final double rrf;
  final int exactGroups;
  final int titleExactGroups;
  final int textExactGroups;
  final bool related;
}

int compareSearchRankCandidates(
  SearchRankCandidate left,
  SearchRankCandidate right,
) {
  final exact = right.exactGroups.compareTo(left.exactGroups);
  if (exact != 0) return exact;
  final title = right.titleExactGroups.compareTo(left.titleExactGroups);
  if (title != 0) return title;
  final text = right.textExactGroups.compareTo(left.textExactGroups);
  if (text != 0) return text;
  final score = right.rrf.compareTo(left.rrf);
  if (score != 0) return score;
  final book = left.bookTitle.compareTo(right.bookTitle);
  if (book != 0) return book;
  final bookId = (left.bookId ?? '').compareTo(right.bookId ?? '');
  if (bookId != 0) return bookId;
  final address = left.address.compareTo(right.address);
  if (address != 0) return address;
  final offset = left.startOffset.compareTo(right.startOffset);
  if (offset != 0) return offset;
  return left.chunkId.compareTo(right.chunkId);
}

bool matchesSearchGroups(
  ParsedSearchQuery query,
  String normalizedTitle,
  String normalizedText, {
  bool requireAll = true,
}) {
  if (query.isEmpty) return false;
  var matched = 0;
  for (final group in query.groups) {
    final ok = _groupMatches(group, normalizedTitle, normalizedText);
    if (!ok && requireAll) return false;
    if (ok) matched += 1;
  }
  return matched > 0;
}

bool _groupMatches(SearchGroup group, String title, String text) {
  final haystacks = [title, text];
  if (haystacks.any((value) => value.contains(group.text))) {
    return true;
  }
  if (group.kind == SearchGroupKind.latin) {
    final tokens = group.terms
        .where((term) => !term.startsWith('u') && !term.startsWith('b'))
        .toList(growable: false);
    return tokens.isNotEmpty &&
        tokens.every(
          (token) => haystacks.any((value) => value.contains(token)),
        );
  }
  return _runsMatch(group.text, haystacks);
}

bool _runsMatch(String text, List<String> haystacks) {
  final runes = text.runes.toList(growable: false);
  var index = 0;
  var sawRun = false;
  while (index < runes.length) {
    final cjk = _isCjkRune(runes[index]);
    final start = index;
    while (index < runes.length && _isCjkRune(runes[index]) == cjk) {
      index += 1;
    }
    final run = runes.sublist(start, index);
    if (_isBoundaryRune(run.first)) continue;
    sawRun = true;
    final ok = cjk
        ? _cjkRunMatches(run, haystacks)
        : _latinRunMatches(run, haystacks);
    if (!ok) return false;
  }
  return sawRun;
}

bool _cjkRunMatches(List<int> runes, List<String> haystacks) {
  final chars = [for (final rune in runes) String.fromCharCode(rune)];
  if (chars.length == 1) {
    return haystacks.any((value) => value.contains(chars.single));
  }
  final bigrams = <String>[
    for (var index = 0; index + 1 < chars.length; index += 1)
      '${chars[index]}${chars[index + 1]}',
  ];
  final hits = [
    for (final bigram in bigrams)
      haystacks.any((value) => value.contains(bigram)),
  ];
  final hitCount = hits.where((hit) => hit).length;
  final required = bigrams.length < 3
      ? bigrams.length
      : (bigrams.length * 2 / 3).ceil();
  if (hitCount < required) return false;
  if (bigrams.length >= 3) {
    var chain = false;
    for (var index = 0; index + 1 < hits.length; index += 1) {
      if (hits[index] && hits[index + 1]) {
        chain = true;
        break;
      }
    }
    if (!chain) return false;
  }
  return true;
}

bool _latinRunMatches(List<int> runes, List<String> haystacks) {
  final token = String.fromCharCodes(runes).toLowerCase();
  return token.isNotEmpty && haystacks.any((value) => value.contains(token));
}

bool _isCjkRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
}

bool _isBoundaryRune(int rune) {
  return rune == 0x20 ||
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0D ||
      rune == 0x0C;
}

String safeFtsMatch(ParsedSearchQuery query) {
  return query.terms
      .map((term) => '"${term.replaceAll('"', '""')}"')
      .join(' OR ');
}
