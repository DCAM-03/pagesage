import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/ai/ai_context_reference.dart';
import 'package:pagesage/features/ai/application/evidence_policy.dart';

AiContextReference _reference(String text) =>
    AiContextReference(id: text, title: '来源', text: text);

void main() {
  test('missing scope gives a distinct unavailable state', () {
    final decision = EvidencePolicyV1().decide(
      question: '知识管理是什么',
      intent: AnswerIntent.sourceQuestion,
      references: const [],
      scopeCompleteness: ScopeCompleteness.partial,
      explicitSelection: false,
    );
    expect(decision.state, EvidenceState.unavailable);
    expect(decision.reasonCodes, contains('scope_incomplete'));
  });

  test('explicit text remains eligible for explanation mode', () {
    final decision = EvidencePolicyV1().decide(
      question: '解释这段文字',
      intent: AnswerIntent.explain,
      references: [_reference('很短的原文')],
      scopeCompleteness: ScopeCompleteness.ready,
      explicitSelection: true,
    );
    expect(decision.state, EvidenceState.eligible);
  });

  test('source questions still require query coverage for explicit text', () {
    final decision = EvidencePolicyV1().decide(
      question: '量子纠错怎样实现',
      intent: AnswerIntent.sourceQuestion,
      references: [_reference('一段关于园艺的短文')],
      scopeCompleteness: ScopeCompleteness.ready,
      explicitSelection: true,
    );
    expect(decision.state, EvidenceState.weak);
    expect(decision.reasonCodes, contains('question_terms_missing'));
  });

  test('citation verifier rejects unknown and uncited paragraphs', () {
    final references = [_reference('原文证据')];
    final verifier = AnswerCitationVerifierV1();
    final good = verifier.verify(
      answer: '根据原文可以确认。[R1]',
      references: references,
    );
    expect(good.valid, isTrue);
    final bad = verifier.verify(
      answer: '没有引用。\n\n[R9] 伪造引用',
      references: references,
    );
    expect(bad.valid, isFalse);
    expect(bad.unknownIds, {'R9'});
    expect(bad.uncitedParagraphs, isNotEmpty);
    expect(
      verifier.status(
        intent: AnswerIntent.sourceQuestion,
        evidenceState: EvidenceState.eligible,
        interrupted: false,
        check: bad,
      ),
      AnswerStatus.unverified,
    );
  });

  test('serializer emits bounded citation ids and exact source text', () {
    final references = [_reference('第一段'), _reference('第二段')];
    final serializer = AiContextSerializerV1();
    final payload = serializer.serialize(references);
    expect(payload, contains('[R1]'));
    expect(payload, contains('[R2]'));
    expect(serializer.citationMap(references)['R2'], '第二段');
  });

  test('serializer rejects more than eight visible references', () {
    final serializer = AiContextSerializerV1();
    final references = [
      for (var index = 0; index < 9; index += 1) _reference('第${index + 1}段'),
    ];
    expect(
      () => serializer.serialize(references),
      throwsA(isA<AiContextSerializationException>()),
    );
  });

  test('citation verifier ignores citations inside code', () {
    final references = [_reference('原文证据')];
    final verifier = AnswerCitationVerifierV1();
    final check = verifier.verify(
      answer: '```text\n[R9]\n```\n\n`[R9]`\n\n根据原文可以确认。[R1]',
      references: references,
    );
    expect(check.valid, isTrue);
    expect(check.unknownIds, isEmpty);
    expect(check.citationIds, {'R1'});
  });

  test('weak evidence never becomes source linked', () {
    final status = AnswerCitationVerifierV1().status(
      intent: AnswerIntent.sourceQuestion,
      evidenceState: EvidenceState.weak,
      interrupted: false,
      check: const CitationCheck(
        valid: true,
        citationIds: {'R1'},
        unknownIds: {},
        uncitedParagraphs: [],
        quoteMismatches: [],
      ),
    );
    expect(status, AnswerStatus.unverified);
  });
}
