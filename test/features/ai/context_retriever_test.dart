import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ai/application/context_retriever.dart';

SearchChunk _chunk(
  String id,
  String text, {
  String title = '第一章',
  int sortOrder = 0,
  int? page,
}) {
  return SearchChunk(
    id: id,
    bookId: 'book-1',
    title: title,
    text: text,
    sortOrder: sortOrder,
    locator: page == null ? null : ReadingLocator.pdf(page: page),
  );
}

SearchBookChunks _book(List<SearchChunk> chunks, {String id = 'book-1'}) {
  return SearchBookChunks(bookId: id, chunks: chunks);
}

void main() {
  const retriever = ContextRetriever();

  group('search terms', () {
    test('a Chinese clause becomes its adjacent character pairs', () {
      // Nothing segments Chinese here, and punctuation separates clauses, so
      // 「抽象数据类型」 as one term would match nothing in the book.
      expect(ContextRetriever.searchTerms('抽象数据类型'), [
        '抽象',
        '象数',
        '数据',
        '据类',
        '类型',
        '抽象数据类型',
      ]);
    });

    test('punctuation separates runs, so no pair straddles it', () {
      final terms = ContextRetriever.searchTerms('链表？指针！');
      expect(terms, ['链表', '指针']);
    });

    test('a one-character run stays a term of its own', () {
      expect(ContextRetriever.searchTerms('书'), ['书']);
    });

    test('question scaffolding is dropped', () {
      final terms = ContextRetriever.searchTerms('什么是内存');
      expect(terms, isNot(contains('什么')));
      expect(terms, contains('内存'));
    });

    test('keeps English words that carry meaning', () {
      expect(ContextRetriever.searchTerms('in the GC'), ['gc']);
    });

    test('returns nothing for a query of nothing but punctuation', () {
      expect(ContextRetriever.searchTerms('？？！'), isEmpty);
      expect(ContextRetriever.searchTerms('   '), isEmpty);
    });
  });

  group('retrieval', () {
    test('picks the chunks that match and leaves the rest out', () {
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk('c1', '这一节讲链表如何分配节点。', page: 3),
            _chunk('c2', '完全无关的章节，讨论排版。', page: 9),
          ]),
        ],
        query: '链表',
      );

      expect(references.map((reference) => reference.id), ['retrieved-c1']);
      expect(references.single.text, contains('链表'));
      expect(references.single.locator?.page, 3);
    });

    test(
      'chunks that cover more of the question outrank one repeated word',
      () {
        final references = retriever.retrieve(
          books: [
            _book([
              _chunk('repeat', '内存 内存 内存 内存 内存 内存'),
              _chunk('cover', '内存分配与指针回收都会影响程序行为。'),
            ]),
          ],
          query: '内存 指针 程序',
          limit: 1,
        );

        expect(references.single.id, 'retrieved-cover');
      },
    );

    test('a chunk that matches nothing at all yields no references', () {
      final references = retriever.retrieve(
        books: [
          _book([_chunk('c1', '完全无关的段落')]),
        ],
        query: '量子纠缠',
      );

      expect(references, isEmpty);
    });

    test('nearby chunks collapse into one passage', () {
      // Two adjacent chunks of the same passage: showing both would spend two
      // of five slots on text the reader is going to read once.
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk('c1', '链表插入只需要改两个指针。', sortOrder: 1),
            _chunk('c2', '链表删除同样只需要改指针。', sortOrder: 2),
            _chunk('c3', '附录：术语表。', sortOrder: 9),
          ]),
        ],
        query: '链表 指针',
      );

      expect(references, hasLength(1));
      expect(references.single.title, '第一章');
    });

    test('the next chunk comes along when the match is at the very end', () {
      // Chunks are cut at 1,200 characters, often mid-sentence. The passage
      // that explains a match at the end is in the next chunk.
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk('b:pdf:3:0', '...一直讲到这里才提到链表', sortOrder: 30),
            _chunk('b:pdf:3:1', '接下来解释链表如何分配。', sortOrder: 31),
            _chunk('b:pdf:9:0', '别处的正文。', sortOrder: 90),
          ]),
        ],
        query: '链表',
      );

      // Either half of the passage is a fair answer; what must not happen is
      // both halves arriving as two references.
      expect(references, hasLength(1));
      expect(
        references.single.id,
        anyOf('retrieved-b:pdf:3:0', 'retrieved-b:pdf:3:1'),
      );
    });

    test('no book takes more than two slots', () {
      final references = retriever.retrieve(
        books: [
          _book([
            for (var i = 0; i < 6; i++)
              _chunk('c$i', '第 $i 页都在讲进程调度。', sortOrder: i * 10),
          ]),
        ],
        query: '进程调度',
        limit: 5,
      );

      expect(references.length, lessThanOrEqualTo(2));
    });

    test('a folder search spreads slots across books', () {
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk('a1', '数据 数据 数据', sortOrder: 1),
            _chunk('a2', '数据 数据', sortOrder: 20),
            _chunk('a3', '数据 数据', sortOrder: 40),
          ], id: 'book-a'),
          _book([_chunk('b1', '数据 缓存', sortOrder: 1)], id: 'book-b'),
        ],
        query: '数据',
        bookTitles: {'book-a': '甲书', 'book-b': '乙书'},
      );

      expect(references.map((reference) => reference.bookTitle).toSet(), {
        '甲书',
        '乙书',
      });
      expect(references.first.label, contains('甲书 · '));
    });

    test('the same question returns the same order', () {
      final books = [
        _book([
          _chunk('c1', '内存', sortOrder: 1),
          _chunk('c2', '内存', sortOrder: 50),
          _chunk('c3', '内存', sortOrder: 90),
        ]),
      ];

      final first = retriever.retrieve(books: books, query: '内存');
      final second = retriever.retrieve(books: books, query: '内存');
      expect(
        first.map((reference) => reference.id),
        second.map((reference) => reference.id),
      );
      // Reading order, so the reader can check them against the book.
      expect(first.map((reference) => reference.id), [
        'retrieved-c1',
        'retrieved-c3',
      ]);
    });

    test('an over-long chunk is cut around the match, not off the end', () {
      final filler = '无关内容。' * 400; // 2,000 characters
      final references = retriever.retrieve(
        books: [
          _book([_chunk('c1', '$filler 链表结尾出现的关键句 $filler')]),
        ],
        query: '链表',
      );

      final text = references.single.text;
      expect(text.length, lessThanOrEqualTo(ContextRetriever.maxBlockChars));
      expect(text, contains('链表'));
    });
  });
}
