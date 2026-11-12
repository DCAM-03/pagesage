import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';

void main() {
  test(
    '10k chunks preserve filtered Chinese matches and locators',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'pagesage-search-scale-',
      );
      final file = File('${root.path}/search.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      var repository = DriftSearchRepository(database.searchDao);
      const topics = ['线性代数', '知识管理', '阅读方法', '矩阵运算', '状态管理'];
      var utf16Count = 0;
      var utf8Count = 0;
      final buildWatch = Stopwatch()..start();
      try {
        for (var batch = 0; batch < 100; batch++) {
          final entries = <SearchIndexEntry>[];
          for (var offset = 0; offset < 100; offset++) {
            final index = batch * 100 + offset;
            final bookId = 'book-${index ~/ 100}';
            final seed =
                '${topics[index % topics.length]}的定义、例题与证明。'
                '第$index节讨论 ＡＩ 阅读和 Flutter 状态管理。';
            final text = List.filled((1100 / seed.length).ceil(), seed).join();
            utf16Count += text.length;
            utf8Count += utf8.encode(text).length;
            entries.add(
              SearchIndexEntry(
                sourceType: 'book',
                sourceId: 'source-$index',
                bookId: bookId,
                title: '第$index节',
                text: text,
                locator: ReadingLocator.epub(
                  href: 'chapter-${index % 100}.md',
                  chapterIndex: index % 100,
                ),
                sortOrder: index % 100,
              ),
            );
          }
          await repository.indexTexts(entries);
        }
        buildWatch.stop();
        expect(utf16Count, greaterThanOrEqualTo(10000000));
        await database.close();
        final bytes = await file.length();
        database = AppDatabase.forTesting(NativeDatabase(file));
        repository = DriftSearchRepository(database.searchDao);
        final cases = <String, SearchQuery>{
          'phrase': const SearchQuery(query: '线性代数'),
          'single': const SearchQuery(query: '数'),
          'mixed': const SearchQuery(query: 'Flutter 状态管理'),
          'fullWidth': const SearchQuery(query: 'AI 阅读'),
          'filtered': const SearchQuery(query: '线性代数', bookId: 'book-99'),
          'absent': const SearchQuery(query: '火星地质'),
        };
        final measurements = <String, Object?>{};
        for (final entry in cases.entries) {
          await database.close();
          database = AppDatabase.forTesting(NativeDatabase(file));
          repository = DriftSearchRepository(database.searchDao);
          final coldWatch = Stopwatch()..start();
          final cold = await repository.search(entry.value);
          coldWatch.stop();
          final expectedIds = cold.map((result) => result.id).toList();
          for (var iteration = 0; iteration < 5; iteration++) {
            await repository.search(entry.value);
          }
          final times = <double>[];
          for (var iteration = 0; iteration < 30; iteration++) {
            final watch = Stopwatch()..start();
            final results = await repository.search(entry.value);
            watch.stop();
            times.add(watch.elapsedMicroseconds / 1000);
            expect(results.map((result) => result.id), expectedIds);
            if (entry.key == 'absent') {
              expect(results, isEmpty);
            } else {
              expect(results, isNotEmpty);
            }
            for (final result in results) {
              final index = int.parse(result.sourceId!.split('-').last);
              expect(result.bookId, 'book-${index ~/ 100}');
              expect(result.locator?.href, 'chapter-${index % 100}.md');
              if (entry.value.bookId != null) {
                expect(result.bookId, entry.value.bookId);
              }
              expect(result.matchRanges, isNotEmpty);
            }
          }
          times.sort();
          measurements[entry.key] = {
            'reopenedConnectionMs': coldWatch.elapsedMicroseconds / 1000,
            'warmP50Ms': times[14],
            'warmP95Ms': times[(times.length * .95).ceil() - 1],
            'warmMaxMs': times.reduce(max),
            'results': cold.length,
          };
          expect(
            times[(times.length * .95).ceil() - 1],
            lessThanOrEqualTo(300),
            reason: entry.key,
          );
          expect(
            coldWatch.elapsedMilliseconds,
            lessThanOrEqualTo(1000),
            reason: entry.key,
          );
        }
        expect(bytes / utf8Count, lessThanOrEqualTo(10));
        final report = {
          'runtime': 'flutter test debug; not a release or OS-cold benchmark',
          'os': Platform.operatingSystemVersion,
          'dart': Platform.version,
          'sqlite':
              (await database
                      .customSelect('SELECT sqlite_version() AS version')
                      .getSingle())
                  .read<String>('version'),
          'percentile': 'nearest-rank',
          'chunks': 10000,
          'utf16': utf16Count,
          'utf8Bytes': utf8Count,
          'databaseBytes': bytes,
          'databaseToBodyRatio': bytes / utf8Count,
          'indexBuildMs': buildWatch.elapsedMilliseconds,
          'warmups': 5,
          'iterations': 30,
          'queries': measurements,
        };
        final output = File(
          Platform.environment['PAGESAGE_SEARCH_REPORT'] ??
              '/tmp/pagesage-search-scale.json',
        );
        await output.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
        );
      } finally {
        await database.close();
        await root.delete(recursive: true);
      }
    },
    skip: Platform.environment['PAGESAGE_SEARCH_BENCHMARK'] != 'true',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
