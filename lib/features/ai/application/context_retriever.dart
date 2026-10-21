import 'dart:math' as math;

import '../../../domain/search/search_models.dart';
import 'ai_context_reference.dart';

/// Picks the passages of a book that a question is about.
///
/// Used by the whole-book and whole-folder ranges. Those cannot read one page
/// or one chapter, and sending the book itself is both a privacy violation and
/// far past any request size, so the panel asks this which few passages to
/// offer as references.
///
/// **Lexical, not vector.** Measured on the real library (3,499 chunks, 1.0M
/// characters in the largest book), scoring every chunk of a book takes about
/// 7 ms — fast enough to run on every question without an index build, and it
/// costs no model download. The reasoning and the rejected alternatives are in
/// `docs/12-ai-retrieval-strategy.md` §4–§6.
///
/// **Chinese is the default case, and FTS5 cannot do it.** `unicode61` treats
/// a run of CJK as one token, so the stored index holds entire sentences and
/// queries like 「数据」 match almost nothing (measured: 21 hits against 489
/// chunks that actually contain it). This scores the chunk text directly
/// instead of going through the index; the like-for-like recall is the point.
final class ContextRetriever {
  const ContextRetriever();

  /// How many passages one question may offer.
  ///
  /// Enough to cover a concept split across sections, few enough that the
  /// reader can still read the list and see what is leaving the device.
  static const defaultLimit = 5;

  /// Characters per passage before it is cut around the match.
  ///
  /// A 1,200-character chunk is fine to send whole; this only matters when the
  /// chunks are larger, and keeps five references from swallowing the request
  /// budget that the surrounding ranges share.
  static const maxBlockChars = 1600;

  /// Scores every chunk and returns the best [limit], most relevant first.
  ///
  /// Returns an empty list when no chunk matches anything: an answer built
  /// from unrelated passages reads as though the book discussed the question,
  /// which is worse than telling the reader nothing matched.
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

    // How many chunks each term appears in. Bigrams of everyday Chinese
    // (「什么」「这个」) occur almost everywhere and would otherwise score
    // a chunk about nothing as highly as one about the question.
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
      // Chunks arrive in reading order; the position in that list is the
      // chunk's place in the book, which is what neighbourhood re-ranking
      // compares against.
      for (var index = 0; index < book.chunks.length; index++) {
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
      for (final hit in selected)
        AiContextReference(
          id: 'retrieved-${hit.chunk.id}',
          title: _titleFor(hit.chunk),
          text: _excerpt(hit.chunk.text, terms),
          locator: hit.chunk.locator,
          bookTitle: hit.bookTitle,
          // Set only when the passage came from another book: reaching the
          // current book's passages is a scroll, not a navigation.
          bookId: hit.bookTitle == null ? null : hit.bookId,
        ),
    ];
  }

  /// The words a query is searched with.
  ///
  /// No second model call: `docs/12-ai-retrieval-strategy.md` §6.2 allows one
  /// for query expansion, but a question that needs the model to understand it
  /// before it can look anything up would make every question two round trips
  /// and two chances to fail.
  ///
  /// **Chinese needs bigrams, not words.** Nothing here segments Chinese, and
  /// punctuation usually separates clauses rather than words, so 「什么是抽象
  /// 数据类型」 would be one term that appears nowhere in the book. Every
  /// adjacent pair of CJK characters is used instead: 「抽象数据类型」 becomes
  /// 抽象/象数/数据/据类/类型, of which the pairs that straddle a word boundary
  /// simply match less often. That is the standard no-dictionary approach, and
  /// it needs no package and no per-book setup.
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
        // English keeps "gc" and drops "the": length is not the signal, a
        // stop list is.
        if (!_englishStopWords.contains(run)) add(run);
        continue;
      }
      final chars = run.runes.map(String.fromCharCode).toList(growable: false);
      // A one-character run is a query in its own right ("内存" is two, but a
      // reader can type 「书」); it is its own term.
      if (chars.length == 1) {
        add(chars.first);
        continue;
      }
      for (var i = 0; i + 1 < chars.length; i++) {
        // A pair containing a function character is that character plus a
        // neighbour: 「表和」「组有」 are noise, and they are common enough to
        // drag unrelated chunks up the ranking. Skipping them keeps the pairs
        // that are plausibly words.
        if (_functionChars.contains(chars[i]) ||
            _functionChars.contains(chars[i + 1])) {
          continue;
        }
        add('${chars[i]}${chars[i + 1]}');
      }
      // A two-character run is exactly one bigram; a longer run also gets its
      // leading and trailing characters dropped, because the pairs that
      // straddle a clause boundary with the neighbouring text are noise. The
      // run as a whole is also kept, so an exact phrase still wins.
      if (chars.length > 2) {
        add(run);
      }
    }
    return terms;
  }

  /// Scores one chunk with BM25. Higher is better; 0 means no match at all.
  ///
  /// BM25 rather than a hand-rolled sum, because the hand-rolled version had
  /// two failures that only showed on real books:
  ///
  /// - **Length won.** A chunk twice as long contains every term twice, so it
  ///   outranked chunks that were actually about the question. BM25's length
  ///   normalisation removes that bias; a long chunk has to earn its rank.
  /// - **A common term could carry a passage.** The score summed per-term
  ///   contributions, so a chunk matching 「区别」「什么」 ranked alongside one
  ///   matching 「虚拟内存」. IDF makes the rare term dominate by itself.
  ///
  /// `k1` and `b` are BM25's usual 1.2 / 0.75. The only departure is the cap
  /// on term frequency: these chunks are up to 1,200 characters and a word
  /// repeated twenty times says nothing the fifth mention did not.
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
      // Smoothed IDF, clamped at 0 for a term in every chunk: it cannot tell
      // one chunk from another, and a negative weight would be nonsense here.
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
    // Covering more of the question beats repeating one word of it. BM25 sums
    // independent terms, so on its own a chunk hitting one term thirteen
    // times beats one hitting three terms once each — which is backwards.
    // The multiplier grows with coverage, and the weight is large enough that
    // it decides: measured on a real book, 0.3 still put the malloc/garbage
    // collector chapter first for 「链表和数组有什么区别」, because it says
    // 「链表」 thirteen times.
    return score * (1 + (matched - 1) * _coverageWeight);
  }

  static const _bm25K1 = 1.2;
  static const _bm25B = 0.75;

  /// How much a term beyond the first is worth. See [_score].
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

  /// Turns ranked candidates into a small, non-redundant set.
  ///
  /// Three things happen here, and each one answers a failure of plain
  /// top-K-by-score:
  ///
  /// 1. **Neighbour expansion.** Chunks are cut at 1,200 characters, often
  ///    mid-sentence, so a match at the end of one chunk leaves the passage
  ///    that explains it in the next. The neighbour is pulled in whole rather
  ///    than excerpted, because what matters is the part that did not match.
  /// 2. **Per-book cap.** In a folder, one book that restates the topic in
  ///    every page would otherwise fill every slot. Two per book keeps the
  ///    answer grounded in more than one source. Ranking is global, so a
  ///    lower-ranked chunk of another book takes the slot the capped book
  ///    cannot; only when nothing else matches does a book go unfilled.
  /// 3. **Adjacency collapse.** Two nearby chunks out of one book are usually
  ///    one passage already taken, and offering them separately spends two of
  ///    five slots on text the reader has already seen.
  List<_Candidate> _select(
    List<_Candidate> hits, {
    required Map<String, _Candidate> allById,
    required int limit,
  }) {
    final ranked = [...hits]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        // Stable, deterministic tie-break: same book, earlier in the book first.
        // Without it the same question could reorder references between runs.
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

    // A table of contents mentions a topic a dozen times without saying
    // anything about it. Measured on a real book, its contents pages are the
    // only chunks dense in dots (leader dots) — 0.43–0.47 of the characters —
    // while running text and code sit at 0.02 or below. Without this, a
    // question about linked lists returns the contents line instead of the
    // chapter.
    final navigable = ranked.where(
      (hit) => !_looksLikeContents(hit.chunk.text),
    );
    final pool = navigable.length >= 2 ? navigable : ranked;

    for (final hit in pool) {
      if (chosen.length >= limit) break;
      if ((perBook[hit.bookId] ?? 0) >= 2) continue;
      // Already covered: either this chunk was pulled in as a neighbour, or a
      // chunk next to it was selected and the reader would be seeing the same
      // passage twice.
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
      // Pull in the following chunk when the match sits at the very end of
      // this one: the sentence that explains it is in the next.
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

    // Reading order within each book reads more naturally than score order,
    // and the reader is going to check these against the book.
    chosen.sort((a, b) {
      final byBook = a.bookId.compareTo(b.bookId);
      if (byBook != 0) return byBook;
      return a.chunk.sortOrder.compareTo(b.chunk.sortOrder);
    });
    return chosen;
  }

  /// Whether a chunk is dense enough in dots and numbers to be navigation.
  ///
  /// Deliberately narrow: a real passage about notation, or a page of code,
  /// must not be mistaken for one. Only the leader-dot shape of a printed
  /// contents page clears both thresholds by a wide margin.
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

  /// The id of the chunk that follows [id] in the same book.
  ///
  /// `SearchIndexer` builds ids as `<bookId>:<format>:<pageOrChapter>:<index>`;
  /// only the trailing position is bumped here, and a miss simply returns an
  /// id nobody has, which the caller treats as "no neighbour".
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

  /// Cuts a chunk down so the match is near the start of what is shown.
  ///
  /// Not centred, and applied even to chunks that fit the budget: a reader
  /// glancing at a retrieved reference has to see why it is there. A 1,200
  /// character chunk whose match is on its last line reads as unrelated text
  /// followed by the thing they asked about, if they scroll far enough. A
  /// lead of ~15% keeps the sentence before the match for context.
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
    // Already near the top: nothing to cut from the front.
    if (first <= _excerptLead) {
      return trimmed.length <= maxBlockChars
          ? trimmed
          : trimmed.substring(0, maxBlockChars).trim();
    }
    final start = first - _excerptLead;
    final end = (start + maxBlockChars).clamp(0, trimmed.length);
    return trimmed.substring(start, end).trim();
  }

  /// Characters kept before the first match in an excerpt.
  static const _excerptLead = 180;

  /// CJK bigrams that appear in nearly every question and carry no retrieval
  /// signal. Kept deliberately short: dropping a real word here silently
  /// removes it from every query, and the rarity weighting already discounts
  /// common pairs without losing them.
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

  /// Characters that almost never carry a topic on their own. A pair made of
  /// one of these and a neighbour is a clause fragment, not a keyword.
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

  /// Index in the book's chunk list, used for adjacency checks.
  final int position;
  final double score;
}
