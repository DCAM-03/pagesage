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
  ReadingLocator? locator,
  String? parentId,
  String? parentTitle,
  String? parentText,
  ReadingLocator? parentLocator,
}) {
  return SearchChunk(
    id: id,
    bookId: 'book-1',
    title: title,
    text: text,
    sortOrder: sortOrder,
    locator: locator ?? (page == null ? null : ReadingLocator.pdf(page: page)),
    parentId: parentId,
    parentTitle: parentTitle,
    parentText: parentText,
    parentLocator: parentLocator,
  );
}

SearchBookChunks _book(List<SearchChunk> chunks, {String id = 'book-1'}) {
  return SearchBookChunks(bookId: id, chunks: chunks);
}

ReadingLocator _markdownRange(int start, int end) {
  return ReadingLocator.markdown(
    chapterIndex: 0,
    chapterOffset: start,
    chapterEndOffset: end,
  );
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

    test('only joins a sibling that belongs to the same parent', () {
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'c1',
              '${'前文。' * 20}链表的关键说明到这里',
              sortOrder: 1,
              parentId: 'p1',
              parentTitle: '第一章 › 链表',
              parentText: '${'前文。' * 20}链表的关键说明到这里。下一步解释节点。',
            ),
            _chunk(
              'c2',
              '下一步解释节点。',
              sortOrder: 2,
              parentId: 'p1',
              parentTitle: '第一章 › 链表',
              parentText: '${'前文。' * 20}链表的关键说明到这里。下一步解释节点。',
            ),
            _chunk(
              'c3',
              '另一个小节讨论附录，但和上一段没有结构关系。',
              sortOrder: 3,
              parentId: 'p2',
              parentTitle: '第一章 › 附录',
            ),
          ]),
        ],
        query: '链表',
        limit: 1,
      );

      expect(references, hasLength(1));
      expect(references.single.text, contains('下一步解释节点'));
      expect(references.single.text, isNot(contains('另一个小节')));
      expect(references.single.title, '第一章 › 链表');
    });

    test('does not guess a neighbour from the chunk id', () {
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'b:md:1:0',
              '${'说明。' * 60}链表在这里结束',
              sortOrder: 1,
              parentId: 'p1',
              parentText: '${'说明。' * 60}链表在这里结束',
            ),
            _chunk(
              'b:md:1:1',
              '这一段属于新的小节，不应该根据编号被拉进来。',
              sortOrder: 2,
              parentId: 'p2',
              parentText: '这一段属于新的小节，不应该根据编号被拉进来。',
            ),
          ]),
        ],
        query: '链表',
        limit: 1,
      );

      expect(references.single.text, contains('链表在这里结束'));
      expect(references.single.text, isNot(contains('新的小节')));
    });

    test('uses the parent text as bounded context for one child hit', () {
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'c1',
              '第二句给出结论。',
              sortOrder: 1,
              parentId: 'p1',
              parentTitle: '第二章 › 因果',
              parentText: '第一句给出条件。第二句给出结论。',
            ),
          ]),
        ],
        query: '结论',
      );

      expect(references.single.text, contains('第一句给出条件'));
      expect(references.single.text, contains('第二句给出结论'));
      expect(references.single.title, '第二章 › 因果');
    });

    test(
      'keeps a complete bounded parent instead of cutting earlier facts',
      () {
        final earlyFact = '示例仓库设有三个独立货架。';
        final parentText =
            '$earlyFact${'这一段是虚构的仓库布置和货架编号说明。' * 18}'
            '示例仓库使用独立货架，每个货架对应一个配送区域；'
            '某个货架盘点时，其他货架仍然可以继续出库。';
        final references = retriever.retrieve(
          books: [
            _book([
              _chunk(
                'c1',
                parentText,
                sortOrder: 1,
                parentId: 'p1',
                parentTitle: '第三章 › 示例仓库',
                parentText: parentText,
              ),
            ]),
          ],
          query: '仓库 货架 盘点',
        );

        expect(parentText.length, greaterThan(380));
        expect(parentText.length, lessThan(ContextRetriever.maxBlockChars));
        expect(references.single.text, startsWith(earlyFact));
        expect(references.single.text, contains('其他货架仍然可以继续出库'));
      },
    );

    test('uses a complete parent even when sibling expansion was selected', () {
      final earlyFact = '示例仓库设有三个独立货架。';
      final parentText =
          '$earlyFact${'这一段是虚构的仓库布置和货架编号说明。' * 18}'
          '示例仓库使用独立货架，每个货架对应一个配送区域。';
      final splitAt = parentText.indexOf('示例仓库使用');
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'c1',
              parentText.substring(0, splitAt + 12),
              sortOrder: 1,
              parentId: 'p1',
              parentTitle: '第三章 › 示例仓库',
              parentText: parentText,
            ),
            _chunk(
              'c2',
              parentText.substring(splitAt + 12),
              sortOrder: 2,
              parentId: 'p1',
              parentTitle: '第三章 › 示例仓库',
              parentText: parentText,
            ),
          ]),
        ],
        query: '仓库 货架 盘点',
      );

      expect(references.single.text, startsWith(earlyFact));
      expect(references.single.text, contains('示例仓库使用独立货架'));
    });

    test('uses a bounded parent window when the parent exceeds the budget', () {
      final childText = '${'前文铺垫。' * 156}链表定位词在这里。';
      final continuation = '续文完整答案就在这里。${'后文说明。' * 200}';
      final parentText = '$childText$continuation';
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'c1',
              childText,
              sortOrder: 1,
              parentId: 'p1',
              parentTitle: '第四章 › 链表',
              parentText: parentText,
            ),
            _chunk(
              'c2',
              continuation,
              sortOrder: 2,
              parentId: 'p1',
              parentTitle: '第四章 › 链表',
              parentText: parentText,
            ),
          ]),
        ],
        query: '链表定位词',
        limit: 1,
      );

      expect(parentText.length, greaterThan(ContextRetriever.maxBlockChars));
      expect(references.single.text, contains('链表定位词'));
      expect(references.single.text, contains('续文完整答案就在这里'));
      expect(
        references.single.text.length,
        lessThanOrEqualTo(ContextRetriever.maxBlockChars),
      );
    });

    test(
      'deduplicates a complete parent selected by non-adjacent siblings',
      () {
        final first = 'needle ${List.filled(125, 'a ').join()}';
        final middle = List.filled(400, 'b ').join();
        final last = 'needle ${List.filled(125, 'c ').join()}';
        final parentText = '$first\n$middle\n$last';
        final lastOffset = parentText.indexOf(last);

        final references = retriever.retrieve(
          books: [
            _book([
              _chunk(
                'first',
                first,
                sortOrder: 0,
                locator: _markdownRange(0, first.length),
                parentId: 'p1',
                parentText: parentText,
                parentLocator: _markdownRange(0, parentText.length),
              ),
              _chunk(
                'middle',
                middle,
                sortOrder: 1,
                locator: _markdownRange(
                  first.length + 1,
                  first.length + 1 + middle.length,
                ),
                parentId: 'p1',
                parentText: parentText,
                parentLocator: _markdownRange(0, parentText.length),
              ),
              _chunk(
                'last',
                last,
                sortOrder: 2,
                locator: _markdownRange(lastOffset, lastOffset + last.length),
                parentId: 'p1',
                parentText: parentText,
                parentLocator: _markdownRange(0, parentText.length),
              ),
            ]),
          ],
          query: 'needle',
        );

        expect(parentText.length, lessThan(ContextRetriever.maxBlockChars));
        expect(references, hasLength(1));
        expect(references.single.text, parentText);
      },
    );

    test('keeps non-overlapping evidence from adjacent siblings', () {
      final first = 'alpha ${List.filled(60, 'a ').join()}';
      final second = 'beta ${List.filled(60, 'b ').join()}';
      final middle = List.filled(1500, 'm ').join();
      final parentText = '$first\n$middle\n$second';
      final secondOffset = parentText.indexOf(second);

      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'first',
              first,
              sortOrder: 0,
              locator: _markdownRange(0, first.length),
              parentId: 'p1',
              parentTitle: '长父块',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
            _chunk(
              'second',
              second,
              sortOrder: 1,
              locator: _markdownRange(
                secondOffset,
                secondOffset + second.length,
              ),
              parentId: 'p1',
              parentTitle: '长父块',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
          ]),
        ],
        query: 'alpha beta',
      );

      expect(parentText.length, greaterThan(ContextRetriever.maxBlockChars));
      expect(references, hasLength(2));
      expect(references[0].text, contains('alpha'));
      expect(references[0].text, isNot(contains('beta')));
      expect(references[1].text, contains('beta'));
      expect(references[1].text, isNot(contains('alpha')));
      expect(references[1].locator?.chapterOffset, secondOffset - 180);
    });

    test('splits overlapping same-parent windows between their hits', () {
      final before = List.filled(300, 'q').join();
      final first = 'alpha ${List.filled(20, 'a ').join()}';
      final second = 'beta ${List.filled(20, 'b ').join()}';
      final secondTargetOffset = before.length + 1700;
      final between = List.filled(
        secondTargetOffset - before.length - first.length,
        'm',
      ).join();
      final after = List.filled(900, 'z ').join();
      final parentText = '$before$first$between$second$after';
      final firstOffset = parentText.indexOf(first);
      final secondOffset = parentText.indexOf(second);

      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'first',
              first,
              sortOrder: 0,
              locator: _markdownRange(firstOffset, firstOffset + first.length),
              parentId: 'p1',
              parentTitle: '重叠父块',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
            _chunk(
              'second',
              second,
              sortOrder: 1,
              locator: _markdownRange(
                secondOffset,
                secondOffset + second.length,
              ),
              parentId: 'p1',
              parentTitle: '重叠父块',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
          ]),
        ],
        query: 'alpha beta',
      );

      expect(parentText.length, greaterThan(ContextRetriever.maxBlockChars));
      expect(references, hasLength(2));
      expect(references[0].text, contains('alpha'));
      expect(references[1].text, contains('beta'));
      expect(
        references[0].locator!.chapterEndOffset,
        lessThanOrEqualTo(references[1].locator!.chapterOffset!),
      );
    });

    test('uses the stored offset when the child text occurs twice', () {
      final repeated = 'needle ${List.filled(150, 'x ').join()}';
      final parentText =
          'FIRST_CONTEXT $repeated ${List.filled(1800, 'z').join()} '
          'SECOND_CONTEXT $repeated';
      final actualOffset = parentText.lastIndexOf(repeated);

      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'repeated',
              repeated,
              locator: _markdownRange(
                actualOffset,
                actualOffset + repeated.length,
              ),
              parentId: 'p1',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
          ]),
        ],
        query: 'needle',
      );

      final reference = references.single;
      expect(parentText.indexOf(repeated), isNot(actualOffset));
      expect(reference.text, contains('SECOND_CONTEXT'));
      expect(reference.text, isNot(contains('FIRST_CONTEXT')));
      expect(reference.locator?.chapterOffset, actualOffset - 180);
      expect(
        reference.locator?.chapterEndOffset,
        reference.locator!.chapterOffset! + reference.text.length,
      );
    });

    test('never splits a surrogate pair at the window end', () {
      final prefix = 'needle ${List.filled(1592, 'a').join()}';
      final parentText = '$prefix😀${List.filled(300, 'b').join()}';

      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'unicode-end',
              prefix.substring(0, 300),
              locator: _markdownRange(0, 300),
              parentId: 'p1',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
          ]),
        ],
        query: 'needle',
      );

      final text = references.single.text;
      final lastUnit = text.codeUnitAt(text.length - 1);
      expect(lastUnit >= 0xD800 && lastUnit <= 0xDBFF, isFalse);
      expect(text.length, lessThanOrEqualTo(ContextRetriever.maxBlockChars));
    });

    test('never splits a surrogate pair at the window start', () {
      final beforeEmoji = List.filled(179, 'a').join();
      final afterEmoji = List.filled(179, 'b').join();
      final childText = 'needle ${List.filled(500, 'c ').join()}';
      final parentText =
          '$beforeEmoji😀$afterEmoji$childText${List.filled(3000, 'd').join()}';
      const childOffset = 360;
      const rawWindowStart = childOffset - 180;

      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'unicode-start',
              childText,
              locator: _markdownRange(
                childOffset,
                childOffset + childText.length,
              ),
              parentId: 'p1',
              parentText: parentText,
              parentLocator: _markdownRange(0, parentText.length),
            ),
          ]),
        ],
        query: 'needle',
      );

      final reference = references.single;
      final text = reference.text;
      final firstUnit = text.codeUnitAt(0);
      final secondUnit = text.codeUnitAt(1);
      expect(parentText.codeUnitAt(rawWindowStart) >= 0xDC00, isTrue);
      expect(firstUnit >= 0xD800 && firstUnit <= 0xDBFF, isTrue);
      expect(secondUnit >= 0xDC00 && secondUnit <= 0xDFFF, isTrue);
      expect(reference.locator?.chapterOffset, rawWindowStart - 1);
      expect(text.length, lessThanOrEqualTo(ContextRetriever.maxBlockChars));
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

    test('legacy excerpt keeps a whole surrogate and shifts its locator', () {
      final text =
          '${List.filled(209, 'a').join()}😀'
          '${List.filled(179, 'b').join()}needle '
          '${List.filled(500, 'c').join()}';
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'legacy-start',
              text,
              locator: _markdownRange(1000, 1000 + text.length),
            ),
          ]),
        ],
        query: 'needle',
      );

      final reference = references.single;
      final start = reference.startOffset!;
      final end = reference.endOffset!;
      expect(reference.text.codeUnitAt(0), inInclusiveRange(0xD800, 0xDBFF));
      expect(reference.text.codeUnitAt(1), inInclusiveRange(0xDC00, 0xDFFF));
      expect(text.substring(start, end), reference.text);
      expect(end - start, reference.text.length);
      expect(reference.locator?.chapterOffset, 1000 + start);
      expect(reference.locator?.chapterEndOffset, 1000 + end);
      expect(
        reference.text.length,
        lessThanOrEqualTo(ContextRetriever.maxBlockChars),
      );
    });

    test('legacy excerpt never ends on a high surrogate', () {
      final text =
          'needle ${List.filled(1592, 'a').join()}😀'
          '${List.filled(300, 'b').join()}';
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'legacy-end',
              text,
              locator: _markdownRange(1000, 1000 + text.length),
            ),
          ]),
        ],
        query: 'needle',
      );

      final reference = references.single;
      final end = reference.endOffset!;
      expect(
        reference.text.codeUnitAt(reference.text.length - 1),
        isNot(inInclusiveRange(0xD800, 0xDBFF)),
      );
      expect(text.substring(reference.startOffset!, end), reference.text);
      expect(end - reference.startOffset!, reference.text.length);
      expect(reference.locator?.chapterEndOffset, 1000 + end);
      expect(
        reference.text.length,
        lessThanOrEqualTo(ContextRetriever.maxBlockChars),
      );
    });

    test('ambiguous PDF fallback keeps a whole start surrogate', () {
      final text =
          '${List.filled(209, 'a').join()}😀'
          '${List.filled(179, 'b').join()}needle '
          '${List.filled(500, 'c').join()}';
      final parentText = '$text\n$text';
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'pdf-start',
              text,
              page: 3,
              parentId: 'parent',
              parentText: parentText,
              parentLocator: ReadingLocator.pdf(page: 3),
            ),
          ]),
        ],
        query: 'needle',
      );

      final reference = references.single;
      final start = reference.startOffset!;
      final end = reference.endOffset!;
      expect(reference.text.codeUnitAt(0), inInclusiveRange(0xD800, 0xDBFF));
      expect(text.substring(start, end), reference.text);
      expect(end - start, reference.text.length);
      expect(reference.locator?.type, ReadingLocatorType.pdf);
      expect(reference.locator?.page, 3);
      expect(reference.locator?.chapterOffset, isNull);
      expect(
        reference.text.length,
        lessThanOrEqualTo(ContextRetriever.maxBlockChars),
      );
    });

    test('ambiguous PDF fallback never ends on a high surrogate', () {
      final text =
          'needle ${List.filled(1592, 'a').join()}😀'
          '${List.filled(300, 'b').join()}';
      final parentText = '$text\n$text';
      final references = retriever.retrieve(
        books: [
          _book([
            _chunk(
              'pdf-end',
              text,
              page: 3,
              parentId: 'parent',
              parentText: parentText,
              parentLocator: ReadingLocator.pdf(page: 3),
            ),
          ]),
        ],
        query: 'needle',
      );

      final reference = references.single;
      final start = reference.startOffset!;
      final end = reference.endOffset!;
      expect(
        reference.text.codeUnitAt(reference.text.length - 1),
        isNot(inInclusiveRange(0xD800, 0xDBFF)),
      );
      expect(text.substring(start, end), reference.text);
      expect(end - start, reference.text.length);
      expect(reference.locator?.type, ReadingLocatorType.pdf);
      expect(reference.locator?.page, 3);
      expect(
        reference.text.length,
        lessThanOrEqualTo(ContextRetriever.maxBlockChars),
      );
    });
  });
}
