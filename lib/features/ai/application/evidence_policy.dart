import '../../../core/search/cjk_search.dart';
import '../../../domain/ai/ai_context_reference.dart';

enum AnswerIntent { sourceQuestion, explain, translate, rewrite }

enum EvidenceState { unavailable, none, weak, eligible }

enum AnswerStatus {
  insufficient,
  sourceLinked,
  unverified,
  interrupted,
  failed,
}

enum ScopeCompleteness { ready, partial, unavailable }

final class EvidenceDecision {
  const EvidenceDecision({
    required this.state,
    required this.reasonCodes,
    required this.scopeCompleteness,
  });

  final EvidenceState state;
  final List<String> reasonCodes;
  final ScopeCompleteness scopeCompleteness;
}

final class EvidencePolicyV1 {
  const EvidencePolicyV1([this._parser = const SearchQueryParserV1()]);

  static const String version = 'evidence-policy-v1';
  final SearchQueryParserV1 _parser;

  EvidenceDecision decide({
    required String question,
    required AnswerIntent intent,
    required List<AiContextReference> references,
    required ScopeCompleteness scopeCompleteness,
    required bool explicitSelection,
    bool indexReady = true,
    bool sourceChanged = false,
    bool readFailed = false,
    bool truncated = false,
  }) {
    final reasons = <String>[];
    if (readFailed || !indexReady || sourceChanged) {
      return EvidenceDecision(
        state: EvidenceState.unavailable,
        reasonCodes: [
          if (readFailed) 'read_failed',
          if (!indexReady) 'index_unavailable',
          if (sourceChanged) 'source_changed',
        ],
        scopeCompleteness: ScopeCompleteness.unavailable,
      );
    }
    final visible = references
        .where((reference) => reference.text.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return EvidenceDecision(
        state: scopeCompleteness == ScopeCompleteness.ready
            ? EvidenceState.none
            : EvidenceState.unavailable,
        reasonCodes: [
          if (scopeCompleteness != ScopeCompleteness.ready) 'scope_incomplete',
          'no_text',
        ],
        scopeCompleteness: scopeCompleteness,
      );
    }
    if (intent != AnswerIntent.sourceQuestion) {
      return EvidenceDecision(
        state: EvidenceState.eligible,
        reasonCodes: const ['explicit_text'],
        scopeCompleteness: scopeCompleteness,
      );
    }
    if (explicitSelection) reasons.add('explicit_text');
    ParsedSearchQuery parsed;
    try {
      parsed = _parser.parse(question);
    } on SearchQueryException {
      parsed = const ParsedSearchQuery(groups: [], normalized: '', terms: []);
    }
    final combined = visible.map((reference) => reference.text).join('\n');
    final normalizedCombined = const SearchTextNormalizerV1()
        .normalize(combined)
        .text;
    final anchors = <String>[
      for (final group in parsed.groups)
        if (group.text.length >= 2 || group.kind == SearchGroupKind.mixed)
          group.text,
    ];
    var coverage = 0;
    for (final anchor in anchors) {
      if (normalizedCombined.contains(anchor.toLowerCase())) {
        coverage += 1;
      }
    }
    if (truncated) reasons.add('context_truncated');
    if (scopeCompleteness == ScopeCompleteness.partial) {
      reasons.add('scope_incomplete');
    }
    if (explicitSelection &&
        parsed.groups.length == 1 &&
        parsed.normalized.isNotEmpty &&
        normalizedCombined.isNotEmpty &&
        _questionAnchors(parsed).any(normalizedCombined.contains)) {
      reasons.add('explicit_text');
      return EvidenceDecision(
        state: EvidenceState.eligible,
        reasonCodes: reasons,
        scopeCompleteness: scopeCompleteness,
      );
    }
    if (parsed.isEmpty) {
      reasons.add('no_usable_query_terms');
      return EvidenceDecision(
        state: EvidenceState.weak,
        reasonCodes: reasons,
        scopeCompleteness: scopeCompleteness,
      );
    }
    if (anchors.isEmpty || coverage == 0) {
      reasons.add('question_terms_missing');
      return EvidenceDecision(
        state: EvidenceState.weak,
        reasonCodes: reasons,
        scopeCompleteness: scopeCompleteness,
      );
    }
    if (coverage < anchors.length) {
      reasons.add('partial_question_coverage');
      return EvidenceDecision(
        state: EvidenceState.weak,
        reasonCodes: reasons,
        scopeCompleteness: scopeCompleteness,
      );
    }
    if (!explicitSelection &&
        visible.length < 2 &&
        normalizedCombined.length < 80) {
      reasons.add('single_short_source');
      return EvidenceDecision(
        state: EvidenceState.weak,
        reasonCodes: reasons,
        scopeCompleteness: scopeCompleteness,
      );
    }
    return EvidenceDecision(
      state: EvidenceState.eligible,
      reasonCodes: reasons,
      scopeCompleteness: scopeCompleteness,
    );
  }

  List<String> _questionAnchors(ParsedSearchQuery parsed) {
    return [
      for (final group in parsed.groups)
        if (group.text.length >= 2 || group.kind == SearchGroupKind.mixed)
          group.text,
    ];
  }
}

final class AiContextSerializerV1 {
  const AiContextSerializerV1();

  static const int maxReferences = 8;

  String serialize(List<AiContextReference> references) {
    final visible = _visible(references);
    _validate(visible);
    final buffer = StringBuffer();
    for (var index = 0; index < visible.length; index += 1) {
      final reference = visible[index];
      if (index > 0) buffer.writeln('\n');
      buffer.writeln('[${_id(index)}] ${reference.label}');
      buffer.writeln(reference.text.trim());
    }
    return buffer.toString().trim();
  }

  Map<String, String> citationMap(List<AiContextReference> references) {
    final visible = _visible(references);
    _validate(visible);
    return {
      for (var index = 0; index < visible.length; index += 1)
        _id(index): visible[index].text.trim(),
    };
  }

  List<AiContextReference> withCitationIds(
    List<AiContextReference> references,
  ) {
    final visible = _visible(references);
    _validate(visible);
    var index = 0;
    return [
      for (final reference in references)
        if (reference.text.trim().isNotEmpty)
          _withCitation(reference, _id(index++))
        else
          reference,
    ];
  }

  List<AiContextReference> _visible(List<AiContextReference> references) {
    return references
        .where((reference) => reference.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _validate(List<AiContextReference> visible) {
    if (visible.length > maxReferences) {
      throw const AiContextSerializationException('引用超过 8 段，请删减引用或缩小上下文范围');
    }
    final seen = <String>{};
    for (final reference in visible) {
      final id = reference.citationId;
      if (id != null && !seen.add(id)) {
        throw const AiContextSerializationException('引用编号重复');
      }
    }
  }

  String _id(int index) => 'R${index + 1}';

  AiContextReference _withCitation(
    AiContextReference reference,
    String citationId,
  ) {
    return AiContextReference(
      id: reference.id,
      title: reference.title,
      text: reference.text,
      locator: reference.locator,
      bookTitle: reference.bookTitle,
      bookId: reference.bookId,
      isSelection: reference.isSelection,
      sourceKey: reference.sourceKey,
      startOffset: reference.startOffset,
      endOffset: reference.endOffset,
      citationId: citationId,
      provenanceKind: reference.provenanceKind,
      documentSourceId: reference.documentSourceId,
      sourceRevision: reference.sourceRevision,
      textRevision: reference.textRevision,
      generationId: reference.generationId,
      precision: reference.precision,
    );
  }
}

final class AiContextSerializationException implements Exception {
  const AiContextSerializationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CitationCheck {
  const CitationCheck({
    required this.valid,
    required this.citationIds,
    required this.unknownIds,
    required this.uncitedParagraphs,
    required this.quoteMismatches,
  });

  final bool valid;
  final Set<String> citationIds;
  final Set<String> unknownIds;
  final List<int> uncitedParagraphs;
  final List<String> quoteMismatches;
}

final class AnswerCitationVerifierV1 {
  const AnswerCitationVerifierV1();

  CitationCheck verify({
    required String answer,
    required List<AiContextReference> references,
    AnswerIntent intent = AnswerIntent.sourceQuestion,
  }) {
    Map<String, String> allowed;
    try {
      allowed = AiContextSerializerV1().citationMap(references);
    } on AiContextSerializationException {
      return const CitationCheck(
        valid: false,
        citationIds: {},
        unknownIds: {},
        uncitedParagraphs: [],
        quoteMismatches: [],
      );
    }
    final readableAnswer = answer.replaceAllMapped(
      RegExp(r'```[\s\S]*?```|`[^`\n]*`'),
      (match) => match.group(0)!.replaceAll(RegExp(r'[^\n]'), ' '),
    );
    final paragraphs = _splitParagraphs(answer);
    final readableParagraphs = _splitParagraphs(readableAnswer);
    final found = <String>{};
    final unknown = <String>{};
    final uncited = <int>[];
    final quoteMismatches = <String>[];
    final citation = RegExp(r'\[R(\d+)\]');
    for (var index = 0; index < paragraphs.length; index += 1) {
      final paragraph = paragraphs[index];
      final clean = index < readableParagraphs.length
          ? readableParagraphs[index]
          : paragraph;
      if (intent != AnswerIntent.sourceQuestion) continue;
      if (clean.trim().isEmpty) continue;
      final ids = citation
          .allMatches(clean)
          .map((match) => 'R${match.group(1)}')
          .toSet();
      for (final id in ids) {
        if (allowed.containsKey(id)) {
          found.add(id);
        } else {
          unknown.add(id);
        }
      }
      if (ids.isEmpty || ids.any((id) => !allowed.containsKey(id))) {
        uncited.add(index);
      }
      final quotes = RegExp(r'[“"]([^”"\n]{2,})[”"]');
      for (final match in quotes.allMatches(clean)) {
        final quote = match.group(1)!.trim();
        final source = allowed.entries
            .where((entry) => ids.contains(entry.key))
            .map((entry) => entry.value)
            .join('\n');
        if (source.isEmpty || !source.contains(quote)) {
          quoteMismatches.add(quote);
        }
      }
    }
    return CitationCheck(
      valid: intent == AnswerIntent.sourceQuestion
          ? unknown.isEmpty &&
                uncited.isEmpty &&
                quoteMismatches.isEmpty &&
                found.isNotEmpty
          : true,
      citationIds: found,
      unknownIds: unknown,
      uncitedParagraphs: uncited,
      quoteMismatches: quoteMismatches,
    );
  }

  List<String> _splitParagraphs(String source) {
    return source
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .toList(growable: false);
  }

  AnswerStatus status({
    required AnswerIntent intent,
    required EvidenceState evidenceState,
    required bool interrupted,
    required CitationCheck check,
  }) {
    if (interrupted) return AnswerStatus.interrupted;
    if (evidenceState == EvidenceState.none ||
        evidenceState == EvidenceState.unavailable) {
      return AnswerStatus.insufficient;
    }
    if (evidenceState == EvidenceState.weak) {
      return AnswerStatus.unverified;
    }
    if (intent != AnswerIntent.sourceQuestion) {
      return AnswerStatus.unverified;
    }
    return check.valid ? AnswerStatus.sourceLinked : AnswerStatus.unverified;
  }
}
