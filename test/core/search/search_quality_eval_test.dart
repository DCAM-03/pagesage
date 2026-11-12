import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/search/cjk_search.dart';
import 'package:pagesage/domain/search/search_models.dart';

void main() {
  group('group matching', () {
    const parser = SearchQueryParserV1();

    test('normalization maps UTF-16 units after emoji and folded spaces', () {
      const normalizer = SearchTextNormalizerV1();
      const source = '😀  ＡＩ 阅读';
      final normalized = normalizer.normalize(source);
      expect(normalized.text, '😀 ai 阅读');
      expect(normalized.offsets.length, normalized.text.length);
      final start = normalized.text.indexOf('ai');
      final range = normalizer.originalRange(normalized, start, start + 2);
      expect(source.substring(range.start, range.end), 'ＡＩ');
      expect(normalizer.normalize('İＡ').text, 'İa');
    });

    test('a long CJK group needs overlapping bigram coverage', () {
      final query = parser.parse('知识管理');

      expect(matchesSearchGroups(query, '', '知识管理需要持续整理'), isTrue);
      expect(matchesSearchGroups(query, '', '知识很重要但管理另说'), isFalse);
    });

    test('whitespace-separated groups are AND', () {
      final query = parser.parse('Flutter 状态管理');

      expect(matchesSearchGroups(query, '', 'flutter 的状态管理'), isTrue);
      expect(matchesSearchGroups(query, '', 'flutter 动画'), isFalse);
    });

    test('full-width Latin is folded before matching', () {
      final query = parser.parse('ＡＩ 阅读');

      expect(matchesSearchGroups(query, '', 'ai 阅读器'), isTrue);
    });
  });

  group('60-question Chinese search evaluation', () {
    late AppDatabase database;
    late DriftSearchRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftSearchRepository(database.searchDao);
      await repository.indexTexts([
        for (final entry in _corpus.entries)
          SearchIndexEntry(
            sourceType: 'book',
            sourceId: entry.key,
            bookId: entry.value.category,
            title: entry.value.title,
            text: entry.value.text,
            sortOrder: entry.value.order,
          ),
      ]);
    });

    tearDown(() => database.close());

    test('Recall@10 stays at or above 95 percent', () async {
      var hits = 0;
      final misses = <String>[];
      for (final item in _questions) {
        final results = await repository.search(
          SearchQuery(query: item.query, limit: 10),
        );
        if (results.any((result) => result.sourceId == item.sourceId)) {
          hits += 1;
        } else {
          misses.add('${item.query} -> ${item.sourceId}');
        }
      }

      final recall = hits / _questions.length;
      expect(
        recall,
        greaterThanOrEqualTo(0.95),
        reason: 'misses: ${misses.join(', ')}',
      );
    });

    test('repeated queries keep the same order', () async {
      for (final item in _questions.take(10)) {
        final first = await repository.search(
          SearchQuery(query: item.query, limit: 10),
        );
        final second = await repository.search(
          SearchQuery(query: item.query, limit: 10),
        );
        expect(
          second.map((result) => result.id),
          first.map((result) => result.id),
          reason: item.query,
        );
      }
    });
  });
}

final class _Doc {
  const _Doc(this.title, this.text, this.category, this.order);

  final String title;
  final String text;
  final String category;
  final int order;
}

final class _Question {
  const _Question(this.query, this.sourceId);

  final String query;
  final String sourceId;
}

const _corpus = <String, _Doc>{
  'eval:01': _Doc('知识管理', '知识管理需要持续回顾与整理笔记。', 'study', 0),
  'eval:02': _Doc('阅读方法', '阅读方法强调主题阅读和间隔复习。', 'study', 1),
  'eval:03': _Doc('Flutter 状态', 'Flutter 状态管理常用 Riverpod。', 'tech', 2),
  'eval:04': _Doc('Dart 异步', 'Dart 异步编程使用 Future 和 Stream。', 'tech', 3),
  'eval:05': _Doc('SQLite 索引', 'SQLite 全文索引使用 FTS5 虚拟表。', 'tech', 4),
  'eval:06': _Doc('PDF 阅读', 'PDF 阅读器支持缩放、目录和书签。', 'product', 5),
  'eval:07': _Doc('EPUB 排版', 'EPUB 排版需要处理章节和字体。', 'product', 6),
  'eval:08': _Doc('Markdown 笔记', 'Markdown 笔记适合记录代码和链接。', 'product', 7),
  'eval:09': _Doc('批注流程', '批注流程包括选中文本和填写评论。', 'product', 8),
  'eval:10': _Doc('搜索高亮', '搜索高亮回到原文的真实偏移。', 'search', 9),
  'eval:11': _Doc('中文分词', '中文分词采用 unigram 和 bigram 候选。', 'search', 10),
  'eval:12': _Doc('索引重建', '索引重建先写新代再原子切换。', 'search', 11),
  'eval:13': _Doc('隐私边界', '隐私边界要求 AI 上下文范围显式。', 'privacy', 12),
  'eval:14': _Doc('本地优先', '本地优先意味着数据默认留在设备。', 'privacy', 13),
  'eval:15': _Doc('OCR 识别', 'OCR 识别把扫描页转成可搜索文本。', 'ocr', 14),
  'eval:16': _Doc('任务中心', '任务中心展示索引进度和失败原因。', 'ops', 15),
  'eval:17': _Doc('备份恢复', '备份恢复需要校验派生索引一致性。', 'ops', 16),
  'eval:18': _Doc('主题配色', '主题配色支持亮色、暗色和护眼模式。', 'ui', 17),
  'eval:19': _Doc('键盘导航', '键盘导航保证焦点可见，也照顾屏幕阅读器。', 'ui', 18),
  'eval:20': _Doc('Mermaid 图形', 'Mermaid 图形离线绘制流程图和时序图。', 'ui', 19),
};

const _questions = <_Question>[
  _Question('知识管理', 'eval:01'),
  _Question('整理笔记', 'eval:01'),
  _Question('持续回顾', 'eval:01'),
  _Question('阅读方法', 'eval:02'),
  _Question('主题阅读', 'eval:02'),
  _Question('间隔复习', 'eval:02'),
  _Question('Flutter 状态管理', 'eval:03'),
  _Question('Riverpod', 'eval:03'),
  _Question('状态 管理', 'eval:03'),
  _Question('Dart 异步', 'eval:04'),
  _Question('Future Stream', 'eval:04'),
  _Question('异步编程', 'eval:04'),
  _Question('SQLite 索引', 'eval:05'),
  _Question('FTS5', 'eval:05'),
  _Question('虚拟表', 'eval:05'),
  _Question('PDF 阅读器', 'eval:06'),
  _Question('缩放 目录', 'eval:06'),
  _Question('书签', 'eval:06'),
  _Question('EPUB 排版', 'eval:07'),
  _Question('章节 字体', 'eval:07'),
  _Question('字体 处理', 'eval:07'),
  _Question('Markdown 笔记', 'eval:08'),
  _Question('代码 链接', 'eval:08'),
  _Question('记录代码', 'eval:08'),
  _Question('批注流程', 'eval:09'),
  _Question('选中文本', 'eval:09'),
  _Question('填写评论', 'eval:09'),
  _Question('搜索高亮', 'eval:10'),
  _Question('原文 偏移', 'eval:10'),
  _Question('真实偏移', 'eval:10'),
  _Question('中文分词', 'eval:11'),
  _Question('unigram bigram', 'eval:11'),
  _Question('候选', 'eval:11'),
  _Question('索引重建', 'eval:12'),
  _Question('原子切换', 'eval:12'),
  _Question('新代', 'eval:12'),
  _Question('隐私边界', 'eval:13'),
  _Question('上下文范围', 'eval:13'),
  _Question('上下文 显式', 'eval:13'),
  _Question('本地优先', 'eval:14'),
  _Question('数据留在设备', 'eval:14'),
  _Question('默认 设备', 'eval:14'),
  _Question('OCR 识别', 'eval:15'),
  _Question('扫描页', 'eval:15'),
  _Question('可搜索文本', 'eval:15'),
  _Question('任务中心', 'eval:16'),
  _Question('索引进度', 'eval:16'),
  _Question('失败原因', 'eval:16'),
  _Question('备份恢复', 'eval:17'),
  _Question('派生索引', 'eval:17'),
  _Question('一致性校验', 'eval:17'),
  _Question('主题配色', 'eval:18'),
  _Question('护眼模式', 'eval:18'),
  _Question('暗色 护眼', 'eval:18'),
  _Question('键盘导航', 'eval:19'),
  _Question('焦点可见', 'eval:19'),
  _Question('屏幕阅读器', 'eval:19'),
  _Question('Mermaid 图形', 'eval:20'),
  _Question('流程图', 'eval:20'),
  _Question('时序图', 'eval:20'),
];
