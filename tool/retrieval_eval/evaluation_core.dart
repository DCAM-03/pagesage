import 'dart:convert';
import 'dart:math' as math;

/// The question set and scoring model for the offline retrieval comparison.
///
/// This file deliberately contains no file, database, or Flutter access. The
/// executable evaluator supplies real references; tests can exercise the
/// evidence and aggregation rules with small in-memory fixtures.
final class RetrievalEvalDataset {
  const RetrievalEvalDataset({
    required this.version,
    required this.description,
    required this.books,
    required this.questions,
  });

  factory RetrievalEvalDataset.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('评测集根节点必须是对象');
    }
    return RetrievalEvalDataset.fromJson(decoded);
  }

  factory RetrievalEvalDataset.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version is! int || version <= 0) {
      throw const FormatException('version 必须是正整数');
    }
    final rawBooks = json['books'];
    if (rawBooks is! Map<String, Object?>) {
      throw const FormatException('books 必须是对象');
    }
    final books = <String, RetrievalEvalBook>{};
    for (final entry in rawBooks.entries) {
      final value = entry.value;
      if (value is! Map<String, Object?>) {
        throw FormatException('books.${entry.key} 必须是对象');
      }
      books[entry.key] = RetrievalEvalBook.fromJson(entry.key, value);
    }

    final rawQuestions = json['questions'];
    if (rawQuestions is! List<Object?>) {
      throw const FormatException('questions 必须是数组');
    }
    final questions = <RetrievalEvalQuestion>[];
    final seenIds = <String>{};
    for (var index = 0; index < rawQuestions.length; index += 1) {
      final value = rawQuestions[index];
      if (value is! Map<String, Object?>) {
        throw FormatException('questions[$index] 必须是对象');
      }
      final question = RetrievalEvalQuestion.fromJson(value);
      if (!books.containsKey(question.bookKey)) {
        throw FormatException('questions[$index] 引用了不存在的书 ${question.bookKey}');
      }
      if (!seenIds.add(question.id)) {
        throw FormatException('重复的问题 id: ${question.id}');
      }
      questions.add(question);
    }
    if (questions.isEmpty) {
      throw const FormatException('评测集至少需要一个问题');
    }

    return RetrievalEvalDataset(
      version: version,
      description: json['description'] as String? ?? '',
      books: Map<String, RetrievalEvalBook>.unmodifiable(books),
      questions: List<RetrievalEvalQuestion>.unmodifiable(questions),
    );
  }

  final int version;
  final String description;
  final Map<String, RetrievalEvalBook> books;
  final List<RetrievalEvalQuestion> questions;
}

final class RetrievalEvalBook {
  const RetrievalEvalBook({
    required this.key,
    required this.bookId,
    required this.title,
  });

  factory RetrievalEvalBook.fromJson(String key, Map<String, Object?> json) {
    final bookId = json['bookId'];
    final title = json['title'];
    if (bookId is! String || bookId.trim().isEmpty) {
      throw FormatException('books.$key.bookId 必须是非空字符串');
    }
    if (title is! String || title.trim().isEmpty) {
      throw FormatException('books.$key.title 必须是非空字符串');
    }
    return RetrievalEvalBook(
      key: key,
      bookId: bookId.trim(),
      title: title.trim(),
    );
  }

  final String key;
  final String bookId;
  final String title;
}

final class RetrievalEvalQuestion {
  const RetrievalEvalQuestion({
    required this.id,
    required this.bookKey,
    required this.category,
    required this.query,
    required this.evidenceSets,
    required this.notes,
    required this.expectEmpty,
  });

  factory RetrievalEvalQuestion.fromJson(Map<String, Object?> json) {
    String requiredString(String field) {
      final value = json[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('question.$field 必须是非空字符串');
      }
      return value.trim();
    }

    final expectEmpty = json['expectEmpty'] ?? false;
    if (expectEmpty is! bool) {
      throw const FormatException('question.expectEmpty 必须是布尔值');
    }

    final rawSets = json['evidenceSets'];
    if (rawSets is! List<Object?>) {
      throw const FormatException('question.evidenceSets 必须是数组');
    }
    final evidenceSets = <List<String>>[];
    for (var setIndex = 0; setIndex < rawSets.length; setIndex += 1) {
      final rawSet = rawSets[setIndex];
      if (rawSet is! List<Object?> || rawSet.isEmpty) {
        throw FormatException('question.evidenceSets[$setIndex] 必须是非空字符串数组');
      }
      final snippets = <String>[];
      for (
        var snippetIndex = 0;
        snippetIndex < rawSet.length;
        snippetIndex += 1
      ) {
        final snippet = rawSet[snippetIndex];
        if (snippet is! String || snippet.trim().isEmpty) {
          throw FormatException(
            'question.evidenceSets[$setIndex][$snippetIndex] 必须是非空字符串',
          );
        }
        snippets.add(snippet);
      }
      evidenceSets.add(List<String>.unmodifiable(snippets));
    }
    if (!expectEmpty && evidenceSets.isEmpty) {
      throw const FormatException('需要答案的问题必须提供 evidenceSets');
    }
    if (expectEmpty && evidenceSets.isNotEmpty) {
      throw const FormatException('expectEmpty 问题不能提供 evidenceSets');
    }

    return RetrievalEvalQuestion(
      id: requiredString('id'),
      bookKey: requiredString('book'),
      category: requiredString('category'),
      query: requiredString('query'),
      evidenceSets: List<List<String>>.unmodifiable(evidenceSets),
      notes: json['notes'] as String? ?? '',
      expectEmpty: expectEmpty,
    );
  }

  final String id;
  final String bookKey;
  final String category;
  final String query;

  /// Each inner list is one complete, alternative evidence set.
  final List<List<String>> evidenceSets;
  final String notes;
  final bool expectEmpty;
}

/// The only part of a context reference this evaluator needs.
final class EvaluationReference {
  const EvaluationReference({
    required this.id,
    required this.title,
    required this.text,
    required this.hasLocator,
    this.sourceKey,
    this.startOffset,
    this.endOffset,
  });

  final String id;
  final String title;
  final String text;
  final bool hasLocator;
  final String? sourceKey;
  final int? startOffset;
  final int? endOffset;

  bool get hasSourceRange =>
      sourceKey != null &&
      sourceKey!.isNotEmpty &&
      startOffset != null &&
      endOffset != null &&
      endOffset! > startOffset!;
}

final class EvaluationOutcome {
  const EvaluationOutcome({
    required this.references,
    required this.elapsedMicros,
    required this.joinedText,
  });

  final List<EvaluationReference> references;
  final int elapsedMicros;
  final String joinedText;
}

final class EvidenceMatch {
  const EvidenceMatch({
    required this.setIndex,
    required this.found,
    required this.occurrences,
  });

  final int setIndex;
  final List<bool> found;
  final List<int> occurrences;

  int get foundCount => found.where((value) => value).length;

  double get recall => found.isEmpty ? 0 : foundCount / found.length;

  bool get complete => found.isNotEmpty && foundCount == found.length;
}

final class EvaluationArmResult {
  const EvaluationArmResult({
    required this.evidence,
    required this.expectEmpty,
    required this.referenceCount,
    required this.payloadChars,
    required this.evidenceChars,
    required this.sourceRangeReferenceCount,
    required this.sourceRangeCoverageRate,
    required this.contextSpanChars,
    required this.contextDuplicateChars,
    required this.locatorPresentCount,
    required this.latencyMicros,
    required this.titles,
  });

  factory EvaluationArmResult.measure({
    required RetrievalEvalQuestion question,
    required EvaluationOutcome outcome,
  }) {
    final references = outcome.references;
    final payloadChars = outcome.joinedText.length;
    final evidence = _bestEvidenceMatch(question, outcome.joinedText);
    final evidenceChars = question.expectEmpty
        ? 0
        : evidence.occurrences.fold<int>(0, (total, count) => total + count);
    final measuredReferences = references
        .where((reference) => reference.hasSourceRange)
        .toList(growable: false);
    final sourceRangeReferenceCount = measuredReferences.length;
    final sourceRangeCoverageRate = references.isEmpty
        ? null
        : sourceRangeReferenceCount / references.length;
    final contextSpanChars = measuredReferences.isEmpty
        ? null
        : _contextSpanChars(measuredReferences);
    final contextDuplicateChars = measuredReferences.isEmpty
        ? null
        : _contextDuplicateChars(measuredReferences);
    return EvaluationArmResult(
      evidence: evidence,
      expectEmpty: question.expectEmpty,
      referenceCount: references.length,
      payloadChars: payloadChars,
      evidenceChars: evidenceChars,
      sourceRangeReferenceCount: sourceRangeReferenceCount,
      sourceRangeCoverageRate: sourceRangeCoverageRate,
      contextSpanChars: contextSpanChars,
      contextDuplicateChars: contextDuplicateChars,
      locatorPresentCount: references
          .where((reference) => reference.hasLocator)
          .length,
      latencyMicros: outcome.elapsedMicros,
      titles: List<String>.unmodifiable(
        references.map((reference) => reference.title),
      ),
    );
  }

  final EvidenceMatch evidence;
  final bool expectEmpty;
  final int referenceCount;

  /// Characters in the payload actually sent, including labels and separators.
  final int payloadChars;

  /// Total characters in the evidence snippets for the best-matching set.
  ///
  /// This is not a precision score: surrounding explanation is often exactly
  /// what makes a passage usable. It is reported next to emitted size only to
  /// expose contexts that grew without adding any gold evidence.
  final int evidenceChars;

  /// References that declare a usable source identity and half-open range.
  ///
  /// The rate's denominator is all references. References with unknown spans
  /// are counted here, not treated as zero-length source ranges.
  final int sourceRangeReferenceCount;
  final double? sourceRangeCoverageRate;

  /// Declared source-range characters and overlap between those ranges.
  ///
  /// This is not a count of golden snippets appearing more than once: a
  /// repeated phrase may be genuine source text, while two references that
  /// cover the same range are duplicated context. Only measured references
  /// enter either value; missing metadata produces `null` duplicate rate.
  final int? contextSpanChars;
  final int? contextDuplicateChars;

  /// References with a non-null locator. Presence is not jump correctness.
  final int locatorPresentCount;
  final int latencyMicros;
  final List<String> titles;

  double get evidenceDensity => payloadChars == 0
      ? 0
      : evidenceChars.clamp(0, payloadChars) / payloadChars;

  double? get contextDuplicateRate {
    final spanChars = contextSpanChars;
    final duplicateChars = contextDuplicateChars;
    return spanChars == null || spanChars == 0 || duplicateChars == null
        ? null
        : duplicateChars / spanChars;
  }

  double get locatorPresentRate {
    return referenceCount == 0 ? 0 : locatorPresentCount / referenceCount;
  }

  bool get allLocatorsPresent {
    return referenceCount > 0 && locatorPresentCount == referenceCount;
  }

  bool get success => expectEmpty ? referenceCount == 0 : evidence.complete;
}

final class EvaluationQuestionResult {
  const EvaluationQuestionResult({
    required this.question,
    required this.baseline,
    required this.candidate,
  });

  final RetrievalEvalQuestion question;
  final EvaluationArmResult baseline;
  final EvaluationArmResult candidate;

  /// True when the candidate satisfies the question and the baseline does not.
  bool get candidateWin => candidate.success && !baseline.success;

  /// True when the baseline satisfies the question and the candidate does not.
  bool get candidateLoss => baseline.success && !candidate.success;

  int get recognitionDelta =>
      candidate.success == baseline.success ? 0 : (candidate.success ? 1 : -1);
}

final class RatingSummary {
  const RatingSummary({
    required this.questions,
    required this.successes,
    required this.meanEvidenceRecall,
    required this.meanPayloadChars,
    required this.meanReferenceCount,
    required this.meanEvidenceDensity,
    required this.referenceCount,
    required this.sourceRangeReferenceCount,
    required this.sourceRangeCoverageRate,
    required this.measuredContextQuestionCount,
    required this.contextSpanChars,
    required this.contextDuplicateChars,
    required this.meanContextDuplicateChars,
    required this.meanContextDuplicateRate,
    required this.locatorPresentRate,
    required this.latencyP50Micros,
    required this.latencyP95Micros,
    required this.completeWhenAnswerable,
    required this.emptyNoAnswerResults,
    required this.answerableCount,
    required this.noAnswerCount,
  });

  final int questions;
  final int successes;
  final double meanEvidenceRecall;
  final double meanPayloadChars;
  final double meanReferenceCount;
  final double meanEvidenceDensity;
  final int referenceCount;
  final int sourceRangeReferenceCount;
  final double? sourceRangeCoverageRate;
  final int measuredContextQuestionCount;
  final int? contextSpanChars;
  final int? contextDuplicateChars;
  final double? meanContextDuplicateChars;
  final double? meanContextDuplicateRate;
  final double locatorPresentRate;
  final int latencyP50Micros;
  final int latencyP95Micros;
  final int completeWhenAnswerable;
  final int emptyNoAnswerResults;
  final int answerableCount;
  final int noAnswerCount;

  double get successRate => questions == 0 ? 0 : successes / questions;

  Map<String, Object?> toJson() {
    return {
      'questions': questions,
      'successes': successes,
      'successRate': _round4(successRate),
      'meanEvidenceRecall': _round4(meanEvidenceRecall),
      'meanPayloadChars': _round2(meanPayloadChars),
      'meanReferenceCount': _round2(meanReferenceCount),
      'meanEvidenceDensity': _round4(meanEvidenceDensity),
      'referenceCount': referenceCount,
      'sourceRangeReferenceCount': sourceRangeReferenceCount,
      'sourceRangeCoverageRate': _round4Nullable(sourceRangeCoverageRate),
      'measuredContextQuestionCount': measuredContextQuestionCount,
      'contextSpanChars': contextSpanChars,
      'contextDuplicateChars': contextDuplicateChars,
      'meanContextDuplicateChars': _round2Nullable(meanContextDuplicateChars),
      'meanContextDuplicateRate': _round4Nullable(meanContextDuplicateRate),
      'locatorPresentRate': _round4(locatorPresentRate),
      'latencyP50Micros': latencyP50Micros,
      'latencyP95Micros': latencyP95Micros,
      'completeWhenAnswerable': completeWhenAnswerable,
      'answerableCount': answerableCount,
      'emptyOnNoAnswer': emptyNoAnswerResults,
      'nonEmptyOnNoAnswer': noAnswerCount - emptyNoAnswerResults,
      'noAnswerCount': noAnswerCount,
    };
  }
}

final class CategoryComparison {
  const CategoryComparison({
    required this.category,
    required this.count,
    required this.baseline,
    required this.candidate,
    required this.wins,
    required this.losses,
    required this.ties,
  });

  final String category;
  final int count;
  final RatingSummary baseline;
  final RatingSummary candidate;
  final int wins;
  final int losses;
  final int ties;

  Map<String, Object?> toJson() {
    return {
      'category': category,
      'count': count,
      'baseline': baseline.toJson(),
      'candidate': candidate.toJson(),
      'wins': wins,
      'losses': losses,
      'ties': ties,
    };
  }
}

final class EvaluationComparison {
  const EvaluationComparison({
    required this.results,
    required this.baseline,
    required this.candidate,
    required this.categories,
    required this.wins,
    required this.losses,
    required this.ties,
  });

  factory EvaluationComparison.fromResults(
    List<EvaluationQuestionResult> results,
  ) {
    final baseline = summarize(
      results.map((result) => result.baseline).toList(growable: false),
    );
    final candidate = summarize(
      results.map((result) => result.candidate).toList(growable: false),
    );

    final categories = <String, List<EvaluationQuestionResult>>{};
    for (final result in results) {
      categories
          .putIfAbsent(
            result.question.category,
            () => <EvaluationQuestionResult>[],
          )
          .add(result);
    }
    final categoryComparisons = <CategoryComparison>[];
    for (final entry in categories.entries) {
      final group = entry.value;
      categoryComparisons.add(
        CategoryComparison(
          category: entry.key,
          count: group.length,
          baseline: summarize(
            group.map((result) => result.baseline).toList(growable: false),
          ),
          candidate: summarize(
            group.map((result) => result.candidate).toList(growable: false),
          ),
          wins: group.where((result) => result.candidateWin).length,
          losses: group.where((result) => result.candidateLoss).length,
          ties: group
              .where(
                (result) => result.baseline.success == result.candidate.success,
              )
              .length,
        ),
      );
    }
    categoryComparisons.sort((a, b) => a.category.compareTo(b.category));

    return EvaluationComparison(
      results: List<EvaluationQuestionResult>.unmodifiable(results),
      baseline: baseline,
      candidate: candidate,
      categories: List<CategoryComparison>.unmodifiable(categoryComparisons),
      wins: results.where((result) => result.candidateWin).length,
      losses: results.where((result) => result.candidateLoss).length,
      ties: results
          .where(
            (result) => result.baseline.success == result.candidate.success,
          )
          .length,
    );
  }

  final List<EvaluationQuestionResult> results;
  final RatingSummary baseline;
  final RatingSummary candidate;
  final List<CategoryComparison> categories;
  final int wins;
  final int losses;
  final int ties;

  Map<String, Object?> toJson() {
    return {
      'baseline': baseline.toJson(),
      'candidate': candidate.toJson(),
      'wins': wins,
      'losses': losses,
      'ties': ties,
      'categories': [for (final category in categories) category.toJson()],
      'results': [
        for (final result in results)
          {
            'id': result.question.id,
            'category': result.question.category,
            'query': result.question.query,
            'expectEmpty': result.question.expectEmpty,
            'baseline': _armToJson(result.baseline),
            'candidate': _armToJson(result.candidate),
            'candidateWin': result.candidateWin,
            'candidateLoss': result.candidateLoss,
          },
      ],
    };
  }
}

RatingSummary summarize(List<EvaluationArmResult> results) {
  if (results.isEmpty) {
    return const RatingSummary(
      questions: 0,
      successes: 0,
      meanEvidenceRecall: 0,
      meanPayloadChars: 0,
      meanReferenceCount: 0,
      meanEvidenceDensity: 0,
      referenceCount: 0,
      sourceRangeReferenceCount: 0,
      sourceRangeCoverageRate: null,
      measuredContextQuestionCount: 0,
      contextSpanChars: null,
      contextDuplicateChars: null,
      meanContextDuplicateChars: null,
      meanContextDuplicateRate: null,
      locatorPresentRate: 0,
      latencyP50Micros: 0,
      latencyP95Micros: 0,
      completeWhenAnswerable: 0,
      emptyNoAnswerResults: 0,
      answerableCount: 0,
      noAnswerCount: 0,
    );
  }

  var successes = 0;
  var recallTotal = 0.0;
  var payloadTotal = 0;
  var refsTotal = 0;
  var densityTotal = 0.0;
  var sourceRangeReferencesTotal = 0;
  int? contextSpanTotal;
  var measuredContextQuestions = 0;
  int? duplicateCharsTotal;
  var duplicateRateTotal = 0.0;
  var measuredRateCount = 0;
  var locatorPresentTotal = 0;
  var completeWhenAnswerable = 0;
  var emptyNoAnswerResults = 0;
  var answerableCount = 0;
  var noAnswerCount = 0;
  final latencies = <int>[];

  for (var index = 0; index < results.length; index += 1) {
    final result = results[index];
    if (result.success) successes += 1;
    if (!result.expectEmpty) {
      recallTotal += result.evidence.recall;
    }
    payloadTotal += result.payloadChars;
    refsTotal += result.referenceCount;
    densityTotal += result.evidenceDensity;
    sourceRangeReferencesTotal += result.sourceRangeReferenceCount;
    final resultContextSpanChars = result.contextSpanChars;
    if (resultContextSpanChars != null) {
      contextSpanTotal = (contextSpanTotal ?? 0) + resultContextSpanChars;
    }
    if (result.sourceRangeReferenceCount > 0) {
      measuredContextQuestions += 1;
    }
    final resultDuplicateChars = result.contextDuplicateChars;
    if (resultDuplicateChars != null) {
      duplicateCharsTotal = (duplicateCharsTotal ?? 0) + resultDuplicateChars;
    }
    final duplicateRate = result.contextDuplicateRate;
    if (duplicateRate != null) {
      duplicateRateTotal += duplicateRate;
      measuredRateCount += 1;
    }
    locatorPresentTotal += result.locatorPresentCount;
    latencies.add(result.latencyMicros);
    if (result.expectEmpty) {
      noAnswerCount += 1;
      if (result.success) emptyNoAnswerResults += 1;
    } else {
      answerableCount += 1;
      if (result.success) completeWhenAnswerable += 1;
    }
  }
  latencies.sort();

  return RatingSummary(
    questions: results.length,
    successes: successes,
    meanEvidenceRecall: answerableCount == 0
        ? 0
        : recallTotal / answerableCount,
    meanPayloadChars: payloadTotal / results.length,
    meanReferenceCount: refsTotal / results.length,
    meanEvidenceDensity: densityTotal / results.length,
    referenceCount: refsTotal,
    sourceRangeReferenceCount: sourceRangeReferencesTotal,
    sourceRangeCoverageRate: refsTotal == 0
        ? null
        : sourceRangeReferencesTotal / refsTotal,
    measuredContextQuestionCount: measuredContextQuestions,
    contextSpanChars: contextSpanTotal,
    contextDuplicateChars: duplicateCharsTotal,
    meanContextDuplicateChars:
        measuredContextQuestions == 0 || duplicateCharsTotal == null
        ? null
        : duplicateCharsTotal / measuredContextQuestions,
    meanContextDuplicateRate: measuredRateCount == 0
        ? null
        : duplicateRateTotal / measuredRateCount,
    locatorPresentRate: refsTotal == 0 ? 0 : locatorPresentTotal / refsTotal,
    latencyP50Micros: _percentile(latencies, 0.50),
    latencyP95Micros: _percentile(latencies, 0.95),
    completeWhenAnswerable: completeWhenAnswerable,
    emptyNoAnswerResults: emptyNoAnswerResults,
    answerableCount: answerableCount,
    noAnswerCount: noAnswerCount,
  );
}

EvidenceMatch _bestEvidenceMatch(
  RetrievalEvalQuestion question,
  String availableText,
) {
  if (question.expectEmpty) {
    return const EvidenceMatch(setIndex: -1, found: [], occurrences: []);
  }
  var best = const EvidenceMatch(setIndex: -1, found: [], occurrences: []);
  for (var index = 0; index < question.evidenceSets.length; index += 1) {
    final snippets = question.evidenceSets[index];
    final found = <bool>[];
    final occurrences = <int>[];
    for (final snippet in snippets) {
      final count = _occurrences(availableText, snippet);
      found.add(count > 0);
      occurrences.add(count > 0 ? snippet.length : 0);
    }
    final match = EvidenceMatch(
      setIndex: index,
      found: List<bool>.unmodifiable(found),
      occurrences: List<int>.unmodifiable(occurrences),
    );
    // A complete alternative set always wins. Preferring the set with more
    // matched snippets lets a 2/3 partial set beat a 1/1 complete set.
    if (match.complete && !best.complete) {
      best = match;
    } else if (match.complete == best.complete &&
        (match.foundCount > best.foundCount ||
            (match.foundCount == best.foundCount &&
                match.recall > best.recall))) {
      best = match;
    }
  }
  return best;
}

int _contextSpanChars(List<EvaluationReference> references) {
  var total = 0;
  for (final reference in references) {
    if (!reference.hasSourceRange) continue;
    total += reference.endOffset! - reference.startOffset!;
  }
  return total;
}

int _contextDuplicateChars(List<EvaluationReference> references) {
  final rangesBySource = <String, List<({int start, int end})>>{};
  for (final reference in references) {
    final sourceKey = reference.sourceKey;
    final start = reference.startOffset;
    final end = reference.endOffset;
    if (sourceKey == null || start == null || end == null || end <= start) {
      continue;
    }
    (rangesBySource[sourceKey] ??= []).add((start: start, end: end));
  }

  var duplicated = 0;
  for (final ranges in rangesBySource.values) {
    ranges.sort((a, b) => a.start.compareTo(b.start));
    var coveredEnd = ranges.first.start;
    var total = 0;
    var union = 0;
    for (final range in ranges) {
      total += range.end - range.start;
      if (range.start > coveredEnd) {
        coveredEnd = range.start;
      }
      final added = math.max(0, range.end - coveredEnd);
      union += added;
      if (range.end > coveredEnd) {
        coveredEnd = range.end;
      }
    }
    duplicated += total - union;
  }
  return duplicated;
}

int _occurrences(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var index = haystack.indexOf(needle);
  while (index >= 0) {
    count += 1;
    index = haystack.indexOf(needle, index + needle.length);
  }
  return count;
}

int _percentile(List<int> sortedValues, double percentile) {
  if (sortedValues.isEmpty) return 0;
  if (sortedValues.length == 1) return sortedValues.first;
  final position = (sortedValues.length - 1) * percentile;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sortedValues[lower];
  final fraction = position - lower;
  return (sortedValues[lower] * (1 - fraction) + sortedValues[upper] * fraction)
      .round();
}

Map<String, Object?> _armToJson(EvaluationArmResult result) {
  return {
    'success': result.success,
    'evidenceRecall': _round4(result.evidence.recall),
    'evidenceSetIndex': result.evidence.setIndex,
    'evidenceFound': result.evidence.found,
    'referenceCount': result.referenceCount,
    'payloadChars': result.payloadChars,
    'evidenceChars': result.evidenceChars,
    'evidenceDensity': _round4(result.evidenceDensity),
    'sourceRangeReferenceCount': result.sourceRangeReferenceCount,
    'sourceRangeCoverageRate': _round4Nullable(result.sourceRangeCoverageRate),
    'contextSpanChars': result.contextSpanChars,
    'contextDuplicateChars': result.contextDuplicateChars,
    'contextDuplicateRate': _round4Nullable(result.contextDuplicateRate),
    'locatorPresentCount': result.locatorPresentCount,
    'allLocatorsPresent': result.allLocatorsPresent,
    'noAnswerResult': result.expectEmpty
        ? (result.referenceCount == 0 ? 'empty' : 'nonEmpty')
        : null,
    'latencyMicros': result.latencyMicros,
    'titles': result.titles,
  };
}

double _round2(double value) => (value * 100).round() / 100;

double _round4(double value) => (value * 10000).round() / 10000;

double? _round2Nullable(double? value) {
  return value == null ? null : _round2(value);
}

double? _round4Nullable(double? value) {
  return value == null ? null : _round4(value);
}
