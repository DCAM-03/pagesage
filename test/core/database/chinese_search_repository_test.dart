import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/search/cjk_search.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/epub/epub_jump.dart';

void main() {
  late AppDatabase database;
  late DriftSearchRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSearchRepository(database.searchDao);
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-cjk:chapter-1',
      bookId: 'book-cjk',
      title: '知识管理',
      text: '知识管理需要持续整理笔记。ＡＩ 阅读器支持全角字符。',
    );
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'book-cjk:chapter-2',
      bookId: 'book-cjk',
      title: '其他章节',
      text: '这一章只谈普通阅读，不讨论知识内容。',
    );
  });

  tearDown(() => database.close());

  test('finds CJK phrases and highlights original text', () async {
    final results = await repository.search(const SearchQuery(query: '知识管理'));
    expect(results, isNotEmpty);
    expect(results.first.matchKind, SearchMatchKind.exact);
    expect(results.first.snippet, contains('<mark>知识管理</mark>'));
    expect(results.first.matchRanges, isNotEmpty);
  });

  test(
    'jump highlights exact original offsets within a Markdown file',
    () async {
      const text = '  前言😀  ＡＩ   阅读正文，后面是知识管理。';
      await repository.indexText(
        sourceType: 'book',
        sourceId: 'offset.md',
        bookId: 'offset-book',
        title: '文件',
        text: text,
        locator: ReadingLocator.markdown(
          href: 'nested/offset.md',
          chapterIndex: 2,
          chapterOffset: 500,
          folderFileLocal: true,
        ),
      );
      final hit = (await repository.search(
        const SearchQuery(query: 'AI 阅读', bookId: 'offset-book'),
      )).single;
      final locator = hit.locator!;
      expect(locator.href, 'nested/offset.md');
      expect(locator.folderFileLocal, isTrue);
      expect(locator.chapterOffset, 500 + text.indexOf('ＡＩ'));
      expect(locator.chapterEndOffset, 500 + text.indexOf('ＡＩ') + 2);
      expect(locator.excerpt, 'ＡＩ');
      final focus = epubFocusRangeFor(locator)!;
      expect(focus.start, locator.chapterOffset);
      expect(focus.end, locator.chapterEndOffset);
      expect(hit.snippet, contains('<mark>ＡＩ</mark>'));
      expect(hit.snippet, contains('<mark>阅读</mark>'));
    },
  );

  test('query group order does not lose earlier highlights', () async {
    await repository.indexText(
      sourceType: 'book',
      sourceId: 'order',
      bookId: 'order',
      text: '阅读之后再学 Flutter',
    );
    final hit = (await repository.search(
      const SearchQuery(query: 'Flutter 阅读', bookId: 'order'),
    )).single;
    expect(hit.snippet, contains('<mark>阅读</mark>'));
    expect(hit.snippet, contains('<mark>Flutter</mark>'));
  });

  test('warm queries never rebuild or rewrite existing term documents', () async {
    await database.customStatement(
      'CREATE TABLE term_writes (count INTEGER NOT NULL)',
    );
    await database.customStatement('INSERT INTO term_writes VALUES (0)');
    await database.customStatement(
      'CREATE TRIGGER count_term_updates AFTER UPDATE ON search_term_documents '
      'BEGIN UPDATE term_writes SET count = count + 1; END',
    );
    await database.customStatement(
      'CREATE TRIGGER count_term_inserts AFTER INSERT ON search_term_documents '
      'BEGIN UPDATE term_writes SET count = count + 1; END',
    );
    for (var index = 0; index < 3; index++) {
      expect(
        await repository.search(const SearchQuery(query: '知识')),
        isNotEmpty,
      );
    }
    expect(
      (await database.customSelect('SELECT count FROM term_writes').getSingle())
          .read<int>('count'),
      0,
    );
    await database.customStatement(
      "UPDATE search_term_documents SET normalizer_version = 'normalizer-v1'",
    );
    await database.customStatement('UPDATE term_writes SET count = 0');
    await repository.search(const SearchQuery(query: '知识'));
    final updated =
        (await database
                .customSelect('SELECT count FROM term_writes')
                .getSingle())
            .read<int>('count');
    expect(updated, 2);
    await repository.search(const SearchQuery(query: '知识'));
    expect(
      (await database.customSelect('SELECT count FROM term_writes').getSingle())
          .read<int>('count'),
      updated,
    );
  });

  test('normalizes full-width Latin and keeps AND semantics', () async {
    final results = await repository.search(const SearchQuery(query: 'ＡＩ 阅读'));
    expect(results, isNotEmpty);
    expect(results.first.snippet, contains('ＡＩ'));
    expect(results.first.snippet, contains('阅读'));
  });

  test('rejects query syntax without SQL injection or exception', () async {
    final results = await repository.search(
      const SearchQuery(query: 'a" OR 1=1'),
    );
    expect(results, isEmpty);
  });

  test('returns a versioned response with request epoch', () async {
    final response = await repository.searchResponse(
      const SearchQuery(query: '知识', requestEpoch: 7),
    );
    expect(response.requestEpoch, 7);
    expect(response.snapshotId, isNotEmpty);
    expect(response.indexState, SearchIndexState.ready);
  });

  test('a new generation is invisible until published', () async {
    final generation = await repository.beginBookGeneration('book-cjk');
    await repository.indexGenerationTexts(generation.id, const [
      SearchIndexEntry(
        sourceType: 'book',
        sourceId: 'book-cjk:chapter-3',
        bookId: 'book-cjk',
        title: '新版本',
        text: '这一版只讨论版本二的内容。',
      ),
    ]);

    expect(await repository.search(const SearchQuery(query: '版本二')), isEmpty);
    expect(
      await repository.search(const SearchQuery(query: '知识管理')),
      isNotEmpty,
    );

    await repository.publishBookGeneration(generation.id);

    expect(
      await repository.search(const SearchQuery(query: '版本二')),
      isNotEmpty,
    );
    expect(await repository.search(const SearchQuery(query: '知识管理')), isEmpty);
  });

  test('discarding a generation keeps the active index intact', () async {
    final first = await repository.beginBookGeneration('book-cjk');
    await repository.indexGenerationTexts(first.id, const [
      SearchIndexEntry(
        sourceType: 'book',
        sourceId: 'book-cjk:chapter-3',
        bookId: 'book-cjk',
        title: '可用版本',
        text: '当前可搜索的稳定正文。',
      ),
    ]);
    await repository.publishBookGeneration(first.id);

    final second = await repository.beginBookGeneration('book-cjk');
    await repository.indexGenerationTexts(second.id, const [
      SearchIndexEntry(
        sourceType: 'book',
        sourceId: 'book-cjk:chapter-4',
        bookId: 'book-cjk',
        title: '半成品',
        text: '这段内容不应该被搜索到。',
      ),
    ]);
    await repository.discardBookGeneration(second.id);

    expect(
      await repository.search(const SearchQuery(query: '稳定正文')),
      isNotEmpty,
    );
    expect(await repository.search(const SearchQuery(query: '不应该')), isEmpty);
  });

  test('book chunks only come from the active generation', () async {
    final first = await repository.beginBookGeneration('book-cjk');
    await repository.indexGenerationTexts(first.id, const [
      SearchIndexEntry(
        sourceType: 'book',
        sourceId: 'book-cjk:chapter-3',
        bookId: 'book-cjk',
        title: '当前',
        text: '当前代正文。',
      ),
    ]);
    await repository.publishBookGeneration(first.id);

    final second = await repository.beginBookGeneration('book-cjk');
    await repository.indexGenerationTexts(second.id, const [
      SearchIndexEntry(
        sourceType: 'book',
        sourceId: 'book-cjk:chapter-4',
        bookId: 'book-cjk',
        title: '构建中',
        text: '构建中的正文。',
      ),
    ]);

    final chunks = await repository.bookChunks(bookIds: const ['book-cjk']);
    expect(chunks.single.chunks.map((chunk) => chunk.text), ['当前代正文。']);

    await repository.discardBookGeneration(second.id);
  });
}
