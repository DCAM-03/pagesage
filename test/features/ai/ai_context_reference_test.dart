import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/ai/ai_context_reference.dart';

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
  test('snapshot restores every source field without changing the payload', () {
    final source = AiContextReference(
      id: 'ref-9',
      title: '第 42 页',
      text: '另一册的原文',
      bookId: 'book-b',
      bookTitle: '乙书',
      locator: ReadingLocator.pdf(page: 42, excerpt: '另一册的原文'),
      sourceKey: 'book-b:pdf:42',
      startOffset: 12,
      endOffset: 19,
    );
    final snapshot = AiContextSnapshot(
      range: 'folder',
      references: [source],
      truncated: true,
    );
    final restored = AiContextSnapshot.fromJsonText(snapshot.toJsonText());
    expect(restored.toJsonText(), snapshot.toJsonText());
    expect(restored.references.single.toJson(), source.toJson());
    expect(
      joinContextReferences(restored.references),
      joinContextReferences(snapshot.references),
    );
    expect(restored.range, 'folder');
    expect(restored.truncated, isTrue);
    expect(() => restored.references.clear(), throwsUnsupportedError);
  });

  test('unknown snapshot version fails instead of inventing sources', () {
    expect(
      () => AiContextSnapshot.fromJsonText('{"version":2}'),
      throwsFormatException,
    );
  });

  test(
    'editing source text invalidates exact span but keeps its jump origin',
    () {
      final source = AiContextReference(
        id: 'ref-1',
        title: '来源',
        text: '原文',
        bookId: 'book-b',
        locator: ReadingLocator.pdf(page: 42),
        sourceKey: 'book-b:42',
        startOffset: 4,
        endOffset: 6,
      );
      expect(source.copyWith(text: '原文').sourceKey, source.sourceKey);
      final edited = source.copyWith(text: '修改的内容');
      expect(edited.sourceKey, isNull);
      expect(edited.startOffset, isNull);
      expect(edited.endOffset, isNull);
      expect(edited.bookId, 'book-b');
      expect(edited.locator?.page, 42);
    },
  );

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
