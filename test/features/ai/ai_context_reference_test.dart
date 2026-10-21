import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/features/ai/application/ai_context_reference.dart';

AiContextReference _ref({
  String id = 'ref-1',
  String title = '选中文本',
  String text = '正文',
  String? bookTitle,
  bool isSelection = false,
}) {
  return AiContextReference(
    id: id,
    title: title,
    text: text,
    bookTitle: bookTitle,
    isSelection: isSelection,
  );
}

void main() {
  group('payload joining', () {
    test('a single block is sent bare', () {
      final joined = joinContextReferences([_ref(text: '  选中的句子  ')]);

      expect(joined, '选中的句子');
      expect(joined, isNot(contains('【')));
    });

    test('several blocks each carry a heading', () {
      final joined = joinContextReferences([
        _ref(text: '选中的句子', isSelection: true),
        _ref(id: 'ref-2', title: '第 3 章', text: '章节正文'),
      ]);

      expect(joined, contains('【选中文本】\n选中的句子'));
      expect(joined, contains('【第 3 章】\n章节正文'));
      // The selection is listed first, so the question's subject leads.
      expect(joined.indexOf('选中文本'), lessThan(joined.indexOf('第 3 章')));
    });

    test('a reference from another book names that book', () {
      final joined = joinContextReferences([
        _ref(text: '甲'),
        _ref(id: 'ref-2', title: '第 2 章', text: '乙', bookTitle: '另一本书'),
      ]);

      expect(joined, contains('【另一本书 · 第 2 章】'));
    });

    test(
      'empty references are left out rather than sent as blank headings',
      () {
        final joined = joinContextReferences([
          _ref(text: '甲'),
          _ref(id: 'ref-2', title: '空的', text: '   '),
          _ref(id: 'ref-3', title: '乙', text: '乙正文'),
        ]);

        expect(joined, isNot(contains('空的')));
        expect(joined, contains('【乙】'));
      },
    );

    test('one visible block among blanks is still sent bare', () {
      final joined = joinContextReferences([
        _ref(text: '  '),
        _ref(id: 'ref-2', title: '第 1 章', text: '只有这段'),
      ]);

      expect(joined, '只有这段');
    });

    test('nothing to send joins to an empty string', () {
      expect(joinContextReferences(const []), '');
      expect(joinContextReferences([_ref(text: '  ')]), '');
    });
  });

  test('copyWith keeps identity and origin, changing only the text', () {
    final original = _ref(text: '原文', title: '第 4 章', bookTitle: '书');
    final edited = original.copyWith(text: '改过');

    expect(edited.id, original.id);
    expect(edited.title, '第 4 章');
    expect(edited.bookTitle, '书');
    expect(edited.text, '改过');
    expect(original.text, '原文');
  });
}
