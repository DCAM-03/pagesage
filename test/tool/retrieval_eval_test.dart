import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/ai/ai_context_reference.dart';

import '../../tool/retrieval_eval/evaluation_core.dart';

void main() {
  test('public example uses the evaluation input contract', () {
    final dataset = RetrievalEvalDataset.fromJsonString(
      File('tool/retrieval_eval/example.json').readAsStringSync(),
    );

    expect(dataset.books.keys, ['example']);
    expect(dataset.books['example']!.bookId, 'example-book');
    expect(dataset.questions, hasLength(2));
    expect(dataset.questions.first.evidenceSets, [
      ['示例仓库设有三个独立货架'],
    ]);
    expect(dataset.questions.last.expectEmpty, isTrue);
    expect(dataset.questions.last.evidenceSets, isEmpty);
  });

  group('evidence scoring', () {
    test('requires every snippet in one evidence set', () {
      final question = _question(
        evidenceSets: [
          ['alpha', 'beta'],
        ],
      );
      final partial = _arm(question, 'alpha appears here');
      final complete = _arm(question, 'alpha and beta both appear');

      expect(partial.evidence.recall, 0.5);
      expect(partial.success, isFalse);
      expect(complete.evidence.recall, 1);
      expect(complete.success, isTrue);
    });

    test('accepts any complete alternative evidence set', () {
      final question = _question(
        evidenceSets: [
          ['alpha', 'beta', 'missing'],
          ['gamma'],
        ],
      );
      final result = _arm(question, 'alpha beta gamma');

      // The old scorer preferred set 0 because it matched two snippets;
      // a complete 1/1 alternative must still win.
      expect(result.evidence.setIndex, 1);
      expect(result.evidence.complete, isTrue);
      expect(result.success, isTrue);
    });

    test('requires an empty result for a no-answer question', () {
      final question = _question(expectEmpty: true, evidenceSets: []);
      final empty = _arm(question, '', referenceCount: 0);
      final unrelated = _arm(question, 'a nearby passage');

      expect(empty.success, isTrue);
      expect(unrelated.success, isFalse);
    });

    test('does not call repeated golden phrases duplicated context', () {
      final question = _question(
        evidenceSets: [
          ['alpha'],
        ],
      );
      final result = EvaluationArmResult.measure(
        question: question,
        outcome: const EvaluationOutcome(
          references: [
            EvaluationReference(
              id: 'source',
              title: '来源',
              text: 'alpha alpha alpha',
              hasLocator: true,
              sourceKey: 'book:p1',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
          elapsedMicros: 10,
          joinedText: 'alpha alpha alpha',
        ),
      );

      expect(result.contextDuplicateChars, 0);
      expect(result.contextDuplicateRate, 0);
    });

    test('counts overlapping source spans as duplicated context', () {
      final question = _question(
        evidenceSets: [
          ['alpha'],
        ],
      );
      final result = EvaluationArmResult.measure(
        question: question,
        outcome: const EvaluationOutcome(
          references: [
            EvaluationReference(
              id: 'first',
              title: '来源',
              text: 'first context',
              hasLocator: true,
              sourceKey: 'book:p1',
              startOffset: 0,
              endOffset: 100,
            ),
            EvaluationReference(
              id: 'second',
              title: '来源',
              text: 'overlapping context',
              hasLocator: true,
              sourceKey: 'book:p1',
              startOffset: 60,
              endOffset: 160,
            ),
          ],
          elapsedMicros: 10,
          joinedText: 'first context\n\noverlapping context',
        ),
      );

      expect(result.contextDuplicateChars, 40);
      expect(result.contextDuplicateRate, 40 / 200);
      expect(result.sourceRangeReferenceCount, 2);
      expect(result.sourceRangeCoverageRate, 1);
      expect(result.contextSpanChars, 200);
    });

    test('leaves duplicate rate unmeasured when source spans are missing', () {
      final question = _question(
        evidenceSets: [
          ['alpha'],
        ],
      );
      final result = EvaluationArmResult.measure(
        question: question,
        outcome: const EvaluationOutcome(
          references: [
            EvaluationReference(
              id: 'first',
              title: '来源',
              text: 'alpha',
              hasLocator: true,
            ),
            EvaluationReference(
              id: 'second',
              title: '来源',
              text: 'alpha again',
              hasLocator: true,
            ),
          ],
          elapsedMicros: 10,
          joinedText: 'alpha alpha again',
        ),
      );

      expect(result.sourceRangeReferenceCount, 0);
      expect(result.sourceRangeCoverageRate, 0);
      expect(result.contextDuplicateChars, isNull);
      expect(result.contextDuplicateRate, isNull);
    });

    test('measures only references with source spans', () {
      final question = _question(
        evidenceSets: [
          ['alpha'],
        ],
      );
      final result = EvaluationArmResult.measure(
        question: question,
        outcome: const EvaluationOutcome(
          references: [
            EvaluationReference(
              id: 'measured',
              title: '来源',
              text: 'alpha',
              hasLocator: true,
              sourceKey: 'book:p1',
              startOffset: 10,
              endOffset: 50,
            ),
            EvaluationReference(
              id: 'unknown',
              title: '来源',
              text: 'alpha again',
              hasLocator: true,
            ),
          ],
          elapsedMicros: 10,
          joinedText: 'alpha alpha again',
        ),
      );

      expect(result.sourceRangeReferenceCount, 1);
      expect(result.sourceRangeCoverageRate, 0.5);
      expect(result.contextSpanChars, 40);
      expect(result.contextDuplicateChars, 0);
      expect(result.contextDuplicateRate, 0);
    });

    test('reports a measured zero when source ranges do not overlap', () {
      final question = _question(
        evidenceSets: [
          ['alpha'],
        ],
      );
      final result = EvaluationArmResult.measure(
        question: question,
        outcome: const EvaluationOutcome(
          references: [
            EvaluationReference(
              id: 'first',
              title: '来源',
              text: 'alpha',
              hasLocator: true,
              sourceKey: 'book:p1',
              startOffset: 0,
              endOffset: 100,
            ),
            EvaluationReference(
              id: 'second',
              title: '来源',
              text: 'alpha again',
              hasLocator: true,
              sourceKey: 'book:p1',
              startOffset: 100,
              endOffset: 200,
            ),
          ],
          elapsedMicros: 10,
          joinedText: 'alpha alpha again',
        ),
      );

      expect(result.sourceRangeReferenceCount, 2);
      expect(result.sourceRangeCoverageRate, 1);
      expect(result.contextSpanChars, 200);
      expect(result.contextDuplicateChars, 0);
      expect(result.contextDuplicateRate, 0);
    });

    test('measures the payload actually sent with titles and separators', () {
      const references = [
        AiContextReference(id: 'first', title: '第一章', text: 'alpha'),
        AiContextReference(id: 'second', title: '第二章', text: 'beta'),
      ];
      final joinedText = joinContextReferences(references);
      final question = _question(
        evidenceSets: [
          ['alpha', 'beta'],
        ],
      );
      final result = EvaluationArmResult.measure(
        question: question,
        outcome: EvaluationOutcome(
          references: const [
            EvaluationReference(
              id: 'first',
              title: '第一章',
              text: 'alpha',
              hasLocator: false,
            ),
            EvaluationReference(
              id: 'second',
              title: '第二章',
              text: 'beta',
              hasLocator: true,
            ),
          ],
          elapsedMicros: 10,
          joinedText: joinedText,
        ),
      );

      expect(result.payloadChars, joinedText.length);
      expect(result.payloadChars, greaterThan('alpha'.length + 'beta'.length));
      expect(result.locatorPresentRate, 0.5);
    });
  });

  group('comparison summary', () {
    test('counts wins, losses, ties, and claimable complete evidence', () {
      final questions = [
        _question(
          id: 'q1',
          evidenceSets: [
            ['one'],
          ],
        ),
        _question(
          id: 'q2',
          evidenceSets: [
            ['two'],
          ],
        ),
        _question(
          id: 'q3',
          evidenceSets: [
            ['three'],
          ],
        ),
      ];
      final results = [
        EvaluationQuestionResult(
          question: questions[0],
          baseline: _arm(questions[0], 'missing'),
          candidate: _arm(questions[0], 'one'),
        ),
        EvaluationQuestionResult(
          question: questions[1],
          baseline: _arm(questions[1], 'two'),
          candidate: _arm(questions[1], 'missing'),
        ),
        EvaluationQuestionResult(
          question: questions[2],
          baseline: _arm(questions[2], 'three'),
          candidate: _arm(questions[2], 'three'),
        ),
      ];

      final comparison = EvaluationComparison.fromResults(results);

      expect(comparison.wins, 1);
      expect(comparison.losses, 1);
      expect(comparison.ties, 1);
      expect(comparison.baseline.successes, 2);
      expect(comparison.candidate.successes, 2);
      expect(comparison.candidate.completeWhenAnswerable, 2);
    });

    test('does not summarize unknown source spans as measured zero', () {
      final question = _question(expectEmpty: true, evidenceSets: []);
      final summary = summarize([
        _arm(question, 'unrelated passage', referenceCount: 1),
        _arm(question, '', referenceCount: 0),
      ]);

      expect(summary.referenceCount, 1);
      expect(summary.sourceRangeReferenceCount, 0);
      expect(summary.sourceRangeCoverageRate, 0);
      expect(summary.measuredContextQuestionCount, 0);
      expect(summary.contextSpanChars, isNull);
      expect(summary.contextDuplicateChars, isNull);
      expect(summary.meanContextDuplicateChars, isNull);
      expect(summary.meanContextDuplicateRate, isNull);
    });
  });
}

RetrievalEvalQuestion _question({
  String id = 'question',
  List<List<String>> evidenceSets = const [],
  bool expectEmpty = false,
}) {
  return RetrievalEvalQuestion(
    id: id,
    bookKey: 'book',
    category: 'test',
    query: 'query',
    evidenceSets: evidenceSets,
    notes: '',
    expectEmpty: expectEmpty,
  );
}

EvaluationArmResult _arm(
  RetrievalEvalQuestion question,
  String joinedText, {
  int referenceCount = 1,
}) {
  final references = referenceCount == 0
      ? const <EvaluationReference>[]
      : [
          EvaluationReference(
            id: 'reference',
            title: '来源',
            text: joinedText,
            hasLocator: true,
          ),
        ];
  return EvaluationArmResult.measure(
    question: question,
    outcome: EvaluationOutcome(
      references: references,
      elapsedMicros: 10,
      joinedText: joinedText,
    ),
  );
}
