import 'dart:math' as math;

import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/domain/ai/ai_context_reference.dart';

/// Frozen copy of the retriever that shipped before parent/child chunking.
///
/// The comparison must not silently follow future changes in the production
/// retriever. Only the class name and imports differ from the code at the
/// start of this evaluation.
final class LegacyContextRetriever {
  const LegacyContextRetriever();

  static const defaultLimit = 5;
  static const maxBlockChars = 1600;

  List<AiContextReference> retrieve({
    required List<SearchBookChunks> books,
    required String query,
    Map<String, String> bookTitles = const {},
    int limit = defaultLimit,
  }) {
    final terms = searchTerms(query);
    if (terms.isEmpty) {
      return const [];
    }
    if (books.every((book) => book.chunks.isEmpty)) {
      return const [];
    }

    final documentFrequency = <String, int>{};
    for (final book in books) {
      for (final chunk in book.chunks) {
        final lower = chunk.text.toLowerCase();
        for (final term in terms) {
          if (lower.contains(term)) {
            documentFrequency[term] = (documentFrequency[term] ?? 0) + 1;
          }
        }
      }
    }
    final totalChunks = books.fold<int>(0, (sum, b) => sum + b.chunks.length);
    final averageLength = totalChunks == 0
        ? 1.0
        : books.fold<int>(
                0,
                (sum, b) =>
                    sum + b.chunks.fold<int>(0, (s, c) => s + c.text.length),
              ) /
              totalChunks;

    final hits = <_Candidate>[];
    final allById = <String, _Candidate>{};
    for (final book in books) {
      final title = bookTitles[book.bookId];
      for (var index = 0; index < book.chunks.length; index += 1) {
        final chunk = book.chunks[index];
        final candidate = _Candidate(
          bookId: book.bookId,
          bookTitle: title,
          chunk: chunk,
          position: index,
          score: _score(
            chunk.text,
            terms,
            documentFrequency: documentFrequency,
            totalChunks: totalChunks,
            averageLength: averageLength,
          ),
        );
        allById[chunk.id] = candidate;
        if (candidate.score > 0) {
          hits.add(candidate);
        }
      }
    }
    if (hits.isEmpty) {
      return const [];
    }

    final selected = _select(hits, allById: allById, limit: limit);
    return [
      for (final chunk in selected)
        AiContextReference(
          id: 'retrieved-${chunk.chunk.id}',
          title: _titleFor(chunk.chunk),
          text: _excerpt(chunk.chunk.text, terms),
          locator: chunk.chunk.locator,
          bookTitle: chunk.bookTitle,
          bookId: chunk.bookTitle == null ? null : chunk.bookId,
        ),
    ];
  }

  static List<String> searchTerms(String query) {
    final normalized = query
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), ' ')
        .trim();
    if (normalized.isEmpty) {
      return const [];
    }
    final seen = <String>{};
    final terms = <String>[];
    void add(String term) {
      if (term.isEmpty || _questionWords.contains(term)) return;
      if (seen.add(term)) terms.add(term);
    }

    for (final run in normalized.split(' ')) {
      if (run.isEmpty) continue;
      if (!_isCjk(run)) {
        if (!_englishStopWords.contains(run)) add(run);
        continue;
      }
      final chars = run.runes.map(String.fromCharCode).toList(growable: false);
      if (chars.length == 1) {
        add(chars.first);
        continue;
      }
      for (var i = 0; i + 1 < chars.length; i += 1) {
        if (_functionChars.contains(chars[i]) ||
            _functionChars.contains(chars[i + 1])) {
          continue;
        }
        add('${chars[i]}${chars[i + 1]}');
      }
      if (chars.length > 2) {
        add(run);
      }
    }
    return terms;
  }

  double _score(
    String text,
    List<String> terms, {
    required Map<String, int> documentFrequency,
    required int totalChunks,
    required double averageLength,
  }) {
    final lower = text.toLowerCase();
    final length = text.length;
    final lengthNorm = averageLength <= 0
        ? 1.0
        : 1 - _bm25B + _bm25B * (length / averageLength);
    var score = 0.0;
    var matched = 0;
    for (final term in terms) {
      final count = _count(lower, term);
      if (count == 0) {
        continue;
      }
      matched += 1;
      final df = documentFrequency[term] ?? 1;
      final idf = math.max(
        0.0,
        math.log(1 + (totalChunks - df + 0.5) / (df + 0.5)),
      );
      final tf = count > 20 ? 20 : count;
      score += idf * (tf * (_bm25K1 + 1)) / (tf + _bm25K1 * lengthNorm);
    }
    if (matched == 0) {
      return 0;
    }
    return score * (1 + (matched - 1) * _coverageWeight);
  }

  static const _bm25K1 = 1.2;
  static const _bm25B = 0.75;
  static const _coverageWeight = 0.8;

  int _count(String haystack, String needle) {
    var count = 0;
    var index = haystack.indexOf(needle);
    while (index >= 0) {
      count += 1;
      index = haystack.indexOf(needle, index + needle.length);
    }
    return count;
  }

  List<_Candidate> _select(
    List<_Candidate> hits, {
    required Map<String, _Candidate> allById,
    required int limit,
  }) {
    final ranked = [...hits]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byBook = a.bookId.compareTo(b.bookId);
        if (byBook != 0) return byBook;
        return a.chunk.sortOrder.compareTo(b.chunk.sortOrder);
      });

    final chosen = <_Candidate>[];
    final perBook = <String, int>{};

    void add(_Candidate candidate) {
      chosen.add(candidate);
      perBook[candidate.bookId] = (perBook[candidate.bookId] ?? 0) + 1;
    }

    final navigable = ranked.where(
      (hit) => !_looksLikeContents(hit.chunk.text),
    );
    final pool = navigable.length >= 2 ? navigable : ranked;

    for (final hit in pool) {
      if (chosen.length >= limit) break;
      if ((perBook[hit.bookId] ?? 0) >= 2) continue;
      if (chosen.any((picked) => picked.chunk.id == hit.chunk.id)) {
        continue;
      }
      if (chosen.any(
        (picked) =>
            picked.bookId == hit.bookId &&
            (picked.position - hit.position).abs() <= 1,
      )) {
        continue;
      }

      add(hit);
      if (chosen.length >= limit) break;
      final next = allById[_neighbourId(hit.chunk.id)];
      if (next != null &&
          next.bookId == hit.bookId &&
          next.score == 0 &&
          !chosen.any((picked) => picked.chunk.id == next.chunk.id)) {
        add(
          _Candidate(
            bookId: next.bookId,
            bookTitle: next.bookTitle,
            chunk: next.chunk,
            position: next.position,
            score: 0,
          ),
        );
      }
    }

    chosen.sort((a, b) {
      final byBook = a.bookId.compareTo(b.bookId);
      if (byBook != 0) return byBook;
      return a.chunk.sortOrder.compareTo(b.chunk.sortOrder);
    });
    return chosen;
  }

  bool _looksLikeContents(String text) {
    if (text.length < 200) return false;
    var dots = 0;
    var digits = 0;
    for (final rune in text.runes) {
      if (rune == 0x2E || rune == 0x2026) {
        dots += 1;
      } else if (rune >= 0x30 && rune <= 0x39) {
        digits += 1;
      }
    }
    return dots / text.length > 0.15 && digits / text.length > 0.03;
  }

  String _neighbourId(String id) {
    final parts = id.split(':');
    if (parts.length < 2) return id;
    final last = int.tryParse(parts.last);
    if (last == null) return id;
    parts[parts.length - 1] = '${last + 1}';
    return parts.join(':');
  }

  String _titleFor(SearchChunk chunk) {
    final title = chunk.title.trim();
    if (title.isNotEmpty) return title;
    final page = chunk.locator?.page;
    return page == null ? '书中段落' : '第 $page 页';
  }

  String _excerpt(String text, List<String> terms) {
    final trimmed = text.trim();
    if (trimmed.length <= _excerptLead + 200) return trimmed;
    final lower = trimmed.toLowerCase();
    var first = -1;
    for (final term in terms) {
      final index = lower.indexOf(term);
      if (index >= 0 && (first < 0 || index < first)) {
        first = index;
      }
    }
    if (first <= _excerptLead) {
      return trimmed.length <= maxBlockChars
          ? trimmed
          : trimmed.substring(0, maxBlockChars).trim();
    }
    final start = first - _excerptLead;
    final end = (start + maxBlockChars).clamp(0, trimmed.length);
    return trimmed.substring(start, end).trim();
  }

  static const _excerptLead = 180;

  static const _questionWords = {
    '什么',
    '为什',
    '怎么',
    '如何',
    '哪些',
    '哪个',
    '这个',
    '那个',
    '这些',
    '那些',
    '请问',
    '解释',
    '说明',
    '一下',
    '是否',
    '可以',
  };

  static const _functionChars = {
    '的',
    '了',
    '和',
    '与',
    '或',
    '是',
    '在',
    '有',
    '不',
    '也',
    '就',
    '都',
    '而',
    '及',
    '等',
    '这',
    '那',
    '把',
    '被',
    '对',
    '从',
    '到',
    '为',
    '会',
    '能',
    '要',
    '着',
    '过',
    '吗',
    '呢',
    '吧',
  };

  static const _englishStopWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'of',
    'to',
    'in',
    'is',
    'are',
    'it',
    'be',
    'for',
    'on',
    'with',
    'what',
    'why',
    'how',
    'does',
    'do',
    'this',
    'that',
  };

  static bool _isCjk(String value) {
    return value.runes.any(
      (rune) =>
          (rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0xF900 && rune <= 0xFAFF) ||
          (rune >= 0x3040 && rune <= 0x30FF) ||
          (rune >= 0xAC00 && rune <= 0xD7AF),
    );
  }
}

final class _Candidate {
  const _Candidate({
    required this.bookId,
    required this.bookTitle,
    required this.chunk,
    required this.position,
    required this.score,
  });

  final String bookId;
  final String? bookTitle;
  final SearchChunk chunk;
  final int position;
  final double score;
}
