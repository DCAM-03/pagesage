import 'dart:convert';

import '../books/reading_position.dart';

final class AiContextReference {
  const AiContextReference({
    required this.id,
    required this.title,
    required this.text,
    this.locator,
    this.bookTitle,
    this.bookId,
    this.isSelection = false,
    this.sourceKey,
    this.startOffset,
    this.endOffset,
    this.citationId,
    this.provenanceKind,
    this.documentSourceId,
    this.sourceRevision,
    this.textRevision,
    this.generationId,
    this.precision,
  });

  final String id;
  final String title;
  final String text;
  final ReadingLocator? locator;
  final String? bookTitle;
  final String? bookId;
  final bool isSelection;
  final String? sourceKey;
  final int? startOffset;
  final int? endOffset;
  final String? citationId;
  final String? provenanceKind;
  final String? documentSourceId;
  final String? sourceRevision;
  final String? textRevision;
  final String? generationId;
  final String? precision;

  String get label => bookTitle == null ? title : '$bookTitle · $title';
  int get charCount => text.trim().length;

  AiContextReference copyWith({String? text}) {
    final edited = text != null && text != this.text;
    return AiContextReference(
      id: id,
      title: title,
      text: text ?? this.text,
      locator: locator,
      bookTitle: bookTitle,
      bookId: bookId,
      isSelection: isSelection,
      sourceKey: edited ? null : sourceKey,
      startOffset: edited ? null : startOffset,
      endOffset: edited ? null : endOffset,
      citationId: citationId,
      provenanceKind: edited ? 'userProvided' : provenanceKind,
      documentSourceId: edited ? null : documentSourceId,
      sourceRevision: edited ? null : sourceRevision,
      textRevision: edited ? null : textRevision,
      generationId: edited ? null : generationId,
      precision: edited ? null : precision,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'locator': locator?.toJson(),
    'bookTitle': bookTitle,
    'bookId': bookId,
    'isSelection': isSelection,
    'sourceKey': sourceKey,
    'startOffset': startOffset,
    'endOffset': endOffset,
    if (citationId != null) 'citationId': citationId,
    if (provenanceKind != null) 'provenanceKind': provenanceKind,
    if (documentSourceId != null) 'documentSourceId': documentSourceId,
    if (sourceRevision != null) 'sourceRevision': sourceRevision,
    if (textRevision != null) 'textRevision': textRevision,
    if (generationId != null) 'generationId': generationId,
    if (precision != null) 'precision': precision,
  };

  factory AiContextReference.fromJson(Map<String, Object?> json) {
    final locator = json['locator'] as Map<String, Object?>?;
    return AiContextReference(
      id: json['id'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
      locator: locator == null ? null : ReadingLocator.fromJson(locator),
      bookTitle: json['bookTitle'] as String?,
      bookId: json['bookId'] as String?,
      isSelection: json['isSelection'] as bool,
      sourceKey: json['sourceKey'] as String?,
      startOffset: json['startOffset'] as int?,
      endOffset: json['endOffset'] as int?,
      citationId: json['citationId'] as String?,
      provenanceKind: json['provenanceKind'] as String?,
      documentSourceId: json['documentSourceId'] as String?,
      sourceRevision: json['sourceRevision'] as String?,
      textRevision: json['textRevision'] as String?,
      generationId: json['generationId'] as String?,
      precision: json['precision'] as String?,
    );
  }
}

final class AiContextSnapshot {
  AiContextSnapshot({
    required this.range,
    required List<AiContextReference> references,
    this.truncated = false,
    this.version = 2,
    this.answerStatus,
    this.evidenceState,
    this.answerIntent,
  }) : references = List.unmodifiable(references);

  final String range;
  final List<AiContextReference> references;
  final bool truncated;
  final int version;
  final String? answerStatus;
  final String? evidenceState;
  final String? answerIntent;

  String toJsonText() => jsonEncode({
    'version': version,
    'range': range,
    'truncated': truncated,
    if (answerStatus != null) 'answerStatus': answerStatus,
    if (evidenceState != null) 'evidenceState': evidenceState,
    if (answerIntent != null) 'answerIntent': answerIntent,
    'references': references.map((reference) => reference.toJson()).toList(),
  });

  factory AiContextSnapshot.fromJsonText(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    final version = json['version'] as int?;
    if (version == null ||
        (version != 1 && version != 2) ||
        json['range'] is! String ||
        json['truncated'] is! bool ||
        json['references'] is! List) {
      throw const FormatException('不支持的 AI 来源快照版本');
    }
    final references = (json['references'] as List<Object?>)
        .map(
          (value) => AiContextReference.fromJson(value as Map<String, Object?>),
        )
        .toList(growable: false);
    if (version == 2) {
      final citationIds = <String>{};
      for (final reference in references) {
        final citationId = reference.citationId;
        if (citationId != null && !citationIds.add(citationId)) {
          throw const FormatException('来源快照存在重复引用编号');
        }
      }
      if (references.length > 8 || citationIds.length > 8) {
        throw const FormatException('来源快照引用数量超出上限');
      }
    }
    return AiContextSnapshot(
      range: json['range'] as String,
      truncated: json['truncated'] as bool,
      version: version,
      answerStatus: json['answerStatus'] as String?,
      evidenceState: json['evidenceState'] as String?,
      answerIntent: json['answerIntent'] as String?,
      references: references,
    );
  }
}

final class AiAnswerMeta {
  const AiAnswerMeta({
    required this.intent,
    required this.evidenceState,
    required this.answerStatus,
    required this.policyVersion,
    required this.reasonCodes,
    required this.citations,
    required this.claimChecks,
    required this.scopeCompleteness,
    required this.truncated,
    this.producer = 'provider',
  });

  final String intent;
  final String evidenceState;
  final String answerStatus;
  final String policyVersion;
  final List<String> reasonCodes;
  final List<String> citations;
  final List<int> claimChecks;
  final String scopeCompleteness;
  final bool truncated;
  final String producer;

  Map<String, Object?> toJson() => {
    'version': 1,
    'intent': intent,
    'evidenceState': evidenceState,
    'answerStatus': answerStatus,
    'policyVersion': policyVersion,
    'reasonCodes': reasonCodes,
    'citations': citations,
    'claimChecks': claimChecks,
    'scopeCompleteness': scopeCompleteness,
    'truncated': truncated,
    'producer': producer,
  };

  String toJsonText() => jsonEncode(toJson());

  factory AiAnswerMeta.fromJsonText(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    if (json['version'] != 1) {
      throw const FormatException('不支持的回答核验版本');
    }
    return AiAnswerMeta(
      intent: json['intent'] as String,
      evidenceState: json['evidenceState'] as String,
      answerStatus: json['answerStatus'] as String,
      policyVersion: json['policyVersion'] as String,
      reasonCodes: (json['reasonCodes'] as List<Object?>)
          .map((value) => value as String)
          .toList(),
      citations: (json['citations'] as List<Object?>)
          .map((value) => value as String)
          .toList(),
      claimChecks: (json['claimChecks'] as List<Object?>)
          .map((value) => value as int)
          .toList(),
      scopeCompleteness: json['scopeCompleteness'] as String,
      truncated: json['truncated'] as bool,
      producer: json['producer'] as String? ?? 'provider',
    );
  }
}

String joinContextReferences(List<AiContextReference> references) {
  final visible = references
      .where((reference) => reference.text.trim().isNotEmpty)
      .toList(growable: false);
  if (visible.isEmpty) return '';
  if (visible.length == 1) return visible.first.text.trim();
  return visible
      .map((reference) => '【${reference.label}】\n${reference.text.trim()}')
      .join('\n\n');
}
