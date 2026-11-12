import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:pagesage/core/search/pdf_text_extractor.dart';
import 'package:pagesage/core/search/structure_chunker.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/domain/ai/ai_context_reference.dart';
import 'package:pagesage/features/ai/application/context_retriever.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_document_loader.dart';
import 'package:pagesage/renderers/markdown/markdown_document_loader.dart';
import 'package:pagesage/renderers/markdown/markdown_folder.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'retrieval_eval/evaluation_core.dart';
import 'retrieval_eval/legacy_context_retriever.dart';

/// Runs a reproducible, local-only A/B retrieval evaluation.
///
/// Baseline: the frozen pre-parent/child retriever over 1,200-character hard
/// chunks. Candidate: the current retriever over StructureAwareChunker output.
/// Both arms read the same source units, questions, limits, and final labels.
///
/// This command never writes to the PageSage database, never calls an AI
/// provider, and never launches the reader.
Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final datasetFile = File(options.datasetPath);
  if (!datasetFile.existsSync()) {
    stderr.writeln('找不到评测集: ${datasetFile.path}');
    exitCode = 1;
    return;
  }
  final databaseFile = File(options.databasePath);
  if (!databaseFile.existsSync()) {
    stderr.writeln('找不到 PageSage 数据库: ${databaseFile.path}');
    exitCode = 1;
    return;
  }

  final datasetText = await datasetFile.readAsString();
  final datasetContentHash = sha256
      .convert(utf8.encode(datasetText))
      .toString();
  final dataset = RetrievalEvalDataset.fromJsonString(datasetText);
  final database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
  try {
    final loadedBooks = <String, _LoadedBook>{};
    for (final book in dataset.books.values) {
      stdout.writeln('读取 ${book.title} …');
      loadedBooks[book.key] = await _loadBook(database, book);
    }

    for (final question in dataset.questions) {
      final book = loadedBooks[question.bookKey]!;
      _validateEvidence(question, book);
    }

    const legacyRetriever = LegacyContextRetriever();
    const candidateRetriever = ContextRetriever();
    final results = <EvaluationQuestionResult>[];
    for (var index = 0; index < dataset.questions.length; index += 1) {
      final question = dataset.questions[index];
      final book = loadedBooks[question.bookKey]!;
      final baseline = _measure(
        question: question,
        armName: '旧基线',
        iterations: options.iterations,
        retrieve: () => legacyRetriever.retrieve(
          books: [
            SearchBookChunks(bookId: book.bookId, chunks: book.legacyChunks),
          ],
          query: question.query,
          limit: options.limit,
        ),
      );
      final candidate = _measure(
        question: question,
        armName: '父子块',
        iterations: options.iterations,
        retrieve: () => candidateRetriever.retrieve(
          books: [
            SearchBookChunks(
              bookId: book.bookId,
              chunks: book.structuredChunks,
            ),
          ],
          query: question.query,
          limit: options.limit,
        ),
      );
      results.add(
        EvaluationQuestionResult(
          question: question,
          baseline: baseline,
          candidate: candidate,
        ),
      );
      stdout.writeln(
        '${index + 1}/${dataset.questions.length} '
        '${question.id} '
        '${baseline.success ? '基线✓' : '基线×'} '
        '${candidate.success ? '候选✓' : '候选×'}',
      );
    }

    final comparison = EvaluationComparison.fromResults(results);
    final output = {
      'generatedAt': DateTime.now().toIso8601String(),
      'dataset': {
        'path': p.normalize(datasetFile.absolute.path),
        'contentSha256': datasetContentHash,
        'version': dataset.version,
        'description': dataset.description,
        'questionCount': dataset.questions.length,
        'bookCount': dataset.books.length,
      },
      'database': {
        'path': p.normalize(databaseFile.absolute.path),
        'schemaVersion': _schemaVersion(database),
      },
      'books': [for (final book in loadedBooks.values) book.toJson()],
      'configuration': {
        'limit': options.limit,
        'iterations': options.iterations,
        'baselineChunkTargetChars': 1200,
        'baselineContextMaxChars': LegacyContextRetriever.maxBlockChars,
        'candidateParentTargetChars': 2400,
        'candidateParentMaxChars': 3200,
        'candidateChildTargetChars': 900,
        'candidateChildMaxChars': 1200,
        'candidateContextMaxChars': ContextRetriever.maxBlockChars,
      },
      'comparison': comparison.toJson(),
    };
    final outputFile = File(options.outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(output),
    );

    _printSummary(comparison, outputFile);
  } finally {
    database.close();
  }
}

EvaluationArmResult _measure({
  required RetrievalEvalQuestion question,
  required String armName,
  required int iterations,
  required List<AiContextReference> Function() retrieve,
}) {
  // Warm the per-book corpus once; the first call in otherwise identical
  // loops would otherwise absorb JIT and allocation noise asymmetrically.
  final warmReferences = retrieve();
  final timings = <int>[];
  for (var index = 0; index < iterations; index += 1) {
    final stopwatch = Stopwatch()..start();
    retrieve();
    stopwatch.stop();
    timings.add(stopwatch.elapsedMicroseconds);
  }
  timings.sort();
  final elapsed = timings[timings.length ~/ 2];
  final joinedText = joinContextReferences(warmReferences);
  final outcome = EvaluationOutcome(
    references: [
      for (final reference in warmReferences)
        EvaluationReference(
          id: reference.id,
          title: reference.label,
          text: reference.text,
          hasLocator: reference.locator != null,
          sourceKey: reference.sourceKey,
          startOffset: reference.startOffset,
          endOffset: reference.endOffset,
        ),
    ],
    elapsedMicros: elapsed,
    joinedText: joinedText,
  );
  return EvaluationArmResult.measure(question: question, outcome: outcome);
}

void _validateEvidence(RetrievalEvalQuestion question, _LoadedBook book) {
  final missing = <String>[];
  var duplicateOccurrences = 0;
  for (final set in question.evidenceSets) {
    for (final snippet in set) {
      final count = _occurrences(book.allText, snippet);
      if (count == 0) {
        missing.add(snippet);
      } else if (count > 1) {
        duplicateOccurrences += 1;
      }
    }
  }
  if (missing.isNotEmpty) {
    throw FormatException(
      '${question.id} 的证据片段不在 ${book.title} 的当前源文中：\n'
      '${missing.map((snippet) => '  - $snippet').join('\n')}',
    );
  }
  if (duplicateOccurrences > 0) {
    stdout.writeln(
      '提示：${question.id} 有 $duplicateOccurrences 个证据片段在源文出现多次，'
      '覆盖判定仍按存在性计算。',
    );
  }
}

int _occurrences(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var index = haystack.indexOf(needle);
  while (index >= 0) {
    count += 1;
    index = haystack.indexOf(needle, index + needle.length);
  }
  return count;
}

Future<_LoadedBook> _loadBook(
  Database database,
  RetrievalEvalBook reference,
) async {
  final rows = database.select(
    '''
    SELECT id, title, format, library_file_path, file_hash, file_size
    FROM books
    WHERE id = ?
    ''',
    [reference.bookId],
  );
  if (rows.isEmpty) {
    throw StateError('数据库中没有书 ${reference.bookId}');
  }
  final row = rows.first;
  final storedTitle = row['title'] as String? ?? '未命名';
  if (storedTitle != reference.title) {
    stdout.writeln(
      '提示：评测集书名「${reference.title}」与数据库「$storedTitle」不同，'
      '按 id 匹配。',
    );
  }
  final formatValue = row['format'] as String? ?? '';
  final format = BookFormat.fromValue(formatValue);
  if (format == null) {
    throw StateError('${reference.title} 的格式无法识别: $formatValue');
  }
  final path = row['library_file_path'] as String? ?? '';
  if (path.isEmpty) {
    throw StateError('${reference.title} 没有库路径');
  }
  final source = FileSystemEntity.typeSync(path);
  if (source == FileSystemEntityType.notFound) {
    throw StateError('${reference.title} 的源文件不存在: $path');
  }

  final units = <_SourceUnit>[];
  switch (format) {
    case BookFormat.pdf:
      final document = await const PdfTextExtractorService().extract(path);
      for (var index = 0; index < document.pages.length; index += 1) {
        final page = document.pages[index];
        units.add(
          _SourceUnit(
            title: '第 ${page.pageNumber} 页',
            href: '',
            chapterIndex: 0,
            pageNumber: page.pageNumber,
            text: page.text,
            blocks: const <StructuralBlock>[],
            progress: document.pages.isEmpty
                ? 0
                : index / document.pages.length,
          ),
        );
      }
    case BookFormat.epub:
      final document = await const EpubDocumentLoader().load(path);
      for (var index = 0; index < document.chapters.length; index += 1) {
        final chapter = document.chapters[index];
        units.add(
          _SourceUnit(
            title: chapter.title,
            href: chapter.href,
            chapterIndex: chapter.index,
            text: chapter.text,
            blocks: _structuralBlocks(chapter),
            progress: document.progressForChapter(chapterIndex: chapter.index),
          ),
        );
      }
    case BookFormat.markdown:
      final extension = p.extension(path).toLowerCase();
      final isFolder = extension != '.md' && extension != '.markdown';
      if (isFolder) {
        final manifest = await const MarkdownFolderLoader().loadManifest(path);
        for (final file in manifest.files) {
          final document = await const MarkdownDocumentLoader().load(
            file.absolutePath,
          );
          for (final chapter in document.chapters) {
            final title = chapter.title == file.title
                ? file.title
                : '${file.title} · ${chapter.title}';
            units.add(
              _SourceUnit(
                title: title,
                href: file.relativePath,
                chapterIndex: chapter.index,
                text: chapter.text,
                blocks: _structuralBlocks(chapter),
                progress: manifest.progressForFile(
                  file.relativePath,
                  document.progressForChapter(chapterIndex: chapter.index),
                ),
                folderFileLocal: true,
              ),
            );
          }
        }
      } else {
        final document = await const MarkdownDocumentLoader().load(path);
        for (var index = 0; index < document.chapters.length; index += 1) {
          final chapter = document.chapters[index];
          units.add(
            _SourceUnit(
              title: chapter.title,
              href: chapter.href,
              chapterIndex: chapter.index,
              text: chapter.text,
              blocks: _structuralBlocks(chapter),
              progress: document.progressForChapter(
                chapterIndex: chapter.index,
              ),
            ),
          );
        }
      }
  }

  final allText = units.map((unit) => unit.text).join('\n');
  final sourceStat =
      FileSystemEntity.typeSync(path) == FileSystemEntityType.file
      ? File(path).statSync()
      : Directory(path).statSync();
  final fingerprint =
      format == BookFormat.markdown &&
          p.extension(path).toLowerCase() != '.md' &&
          p.extension(path).toLowerCase() != '.markdown'
      ? _folderFingerprint(Directory(path))
      : (row['file_hash'] as String? ?? '');

  return _LoadedBook(
    bookId: reference.bookId,
    title: reference.title,
    format: format,
    sourcePath: p.normalize(File(path).absolute.path),
    sourceFileHash: row['file_hash'] as String? ?? '',
    sourceSize: row['file_size'] as int? ?? 0,
    sourceModifiedAt: sourceStat.modified.toIso8601String(),
    sourceFingerprint: fingerprint,
    units: List<_SourceUnit>.unmodifiable(units),
    allText: allText,
    legacyChunks: _legacyChunks(
      bookId: reference.bookId,
      title: reference.title,
      format: format,
      units: units,
    ),
    structuredChunks: _structuredChunks(
      bookId: reference.bookId,
      title: reference.title,
      format: format,
      units: units,
    ),
  );
}

List<StructuralBlock> _structuralBlocks(EpubChapter chapter) {
  final blocks = <StructuralBlock>[];
  for (final block in chapter.blocks) {
    if (block is EpubTextBlock) {
      final kind = switch (block.type) {
        EpubBlockType.heading => StructuralBlockKind.heading,
        EpubBlockType.code => StructuralBlockKind.code,
        EpubBlockType.quote => StructuralBlockKind.quote,
        EpubBlockType.table => StructuralBlockKind.table,
        _ when block.listMarker != null => StructuralBlockKind.list,
        _ => StructuralBlockKind.paragraph,
      };
      blocks.add(
        StructuralBlock(
          startOffset: block.startOffset,
          endOffset: block.endOffset,
          kind: kind,
          headingLevel: block.headingLevel,
        ),
      );
    } else if (block is EpubTableBlock) {
      blocks.add(
        StructuralBlock(
          startOffset: block.startOffset,
          endOffset: block.endOffset,
          kind: StructuralBlockKind.table,
        ),
      );
    }
  }
  return blocks;
}

List<SearchChunk> _legacyChunks({
  required String bookId,
  required String title,
  required BookFormat format,
  required List<_SourceUnit> units,
}) {
  final chunks = <SearchChunk>[];
  var sortOrder = 0;
  for (var unitIndex = 0; unitIndex < units.length; unitIndex += 1) {
    final unit = units[unitIndex];
    final parts = _legacySplit(unit.text, targetLength: 1200);
    for (var index = 0; index < parts.length; index += 1) {
      final part = parts[index];
      final locator = _locatorFor(
        format: format,
        unit: unit,
        start: part.startOffset,
        end: part.startOffset + part.text.length,
        progress: unit.progress,
      );
      chunks.add(
        SearchChunk(
          id: '$bookId:eval:u$unitIndex:$index',
          bookId: bookId,
          title: format == BookFormat.pdf
              ? '$title - ${unit.title}'
              : unit.title,
          text: part.text,
          sortOrder: sortOrder,
          locator: locator,
        ),
      );
      sortOrder += 1;
    }
  }
  return List<SearchChunk>.unmodifiable(chunks);
}

List<SearchChunk> _structuredChunks({
  required String bookId,
  required String title,
  required BookFormat format,
  required List<_SourceUnit> units,
}) {
  const chunker = StructureAwareChunker();
  final chunks = <SearchChunk>[];
  var sortOrder = 0;
  for (var unitIndex = 0; unitIndex < units.length; unitIndex += 1) {
    final unit = units[unitIndex];
    final structured = chunker.chunk(
      text: unit.text,
      chapterTitle: format == BookFormat.pdf ? unit.title : unit.title,
      blocks: unit.blocks,
    );
    for (final parent in structured.parents) {
      final parentId = '$bookId:eval:u$unitIndex:p${parent.ordinal}';
      final parentLocator = _locatorFor(
        format: format,
        unit: unit,
        start: parent.span.startOffset,
        end: parent.span.endOffset,
        progress: unit.progress,
      );
      var childIndex = 0;
      for (final child in parent.children) {
        chunks.add(
          SearchChunk(
            id: '$bookId:eval:u$unitIndex:${parent.ordinal}:$childIndex',
            bookId: bookId,
            title: parent.titlePath,
            text: child.text,
            sortOrder: sortOrder,
            locator: _locatorFor(
              format: format,
              unit: unit,
              start: child.span.startOffset,
              end: child.span.endOffset,
              progress: unit.progress,
            ),
            parentId: parentId,
            parentTitle: parent.titlePath,
            parentText: parent.text,
            parentLocator: parentLocator,
          ),
        );
        sortOrder += 1;
        childIndex += 1;
      }
    }
  }
  return List<SearchChunk>.unmodifiable(chunks);
}

ReadingLocator _locatorFor({
  required BookFormat format,
  required _SourceUnit unit,
  required int start,
  required int end,
  required double progress,
}) {
  if (format == BookFormat.pdf) {
    final length = unit.text.isEmpty ? 1 : unit.text.length;
    return ReadingLocator.pdf(
      page: unit.pageNumber,
      scrollOffset: (start.clamp(0, length) / length) * 800,
      progress: progress,
      excerpt: _locatorExcerpt(unit.text, start, end),
    );
  }
  if (format == BookFormat.markdown) {
    return ReadingLocator.markdown(
      href: unit.href,
      chapterIndex: unit.chapterIndex,
      chapterOffset: start,
      chapterEndOffset: end,
      progress: progress,
      excerpt: _locatorExcerpt(unit.text, start, end),
      folderFileLocal: unit.folderFileLocal,
    );
  }
  return ReadingLocator.epub(
    href: unit.href,
    chapterIndex: unit.chapterIndex,
    chapterOffset: start,
    chapterEndOffset: end,
    progress: progress,
    excerpt: _locatorExcerpt(unit.text, start, end),
  );
}

String? _locatorExcerpt(String text, int start, int end) {
  if (text.isEmpty || start < 0 || end <= start || start >= text.length) {
    return null;
  }
  final safeEnd = end.clamp(start, text.length);
  final slice = text.substring(start, safeEnd).trim();
  if (slice.isEmpty) return null;
  return slice.length <= 80 ? slice : '${slice.substring(0, 80)}…';
}

/// Frozen version of the previous 1,200-character chunker.
List<({String text, int startOffset})> _legacySplit(
  String text, {
  required int targetLength,
}) {
  final normalized = text;
  if (normalized.trim().isEmpty) {
    return const [];
  }
  if (normalized.trim().length <= targetLength) {
    final start = _firstNonWhitespace(normalized);
    return [(text: normalized.trim(), startOffset: start < 0 ? 0 : start)];
  }

  final chunks = <({String text, int startOffset})>[];
  final matches = RegExp(r'\S[\s\S]*?(?=\n\s*\n+|$)').allMatches(normalized);
  final buffer = StringBuffer();
  var bufferStart = -1;

  void flushBuffer() {
    if (buffer.isEmpty || bufferStart < 0) {
      return;
    }
    final raw = buffer.toString();
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      final leading = raw.indexOf(RegExp(r'\S'));
      chunks.add((
        text: trimmed,
        startOffset: bufferStart + (leading < 0 ? 0 : leading),
      ));
    }
    buffer.clear();
    bufferStart = -1;
  }

  if (matches.isEmpty) {
    for (var offset = 0; offset < normalized.length; offset += targetLength) {
      final end = (offset + targetLength).clamp(0, normalized.length);
      final slice = normalized.substring(offset, end);
      final trimmed = slice.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final leading = slice.indexOf(RegExp(r'\S'));
      chunks.add((
        text: trimmed,
        startOffset: offset + (leading < 0 ? 0 : leading),
      ));
    }
    return chunks;
  }

  for (final match in matches) {
    final paragraph = match.group(0) ?? '';
    final paragraphStart = match.start;
    if (paragraph.trim().isEmpty) {
      continue;
    }
    if (buffer.length + paragraph.length > targetLength && buffer.isNotEmpty) {
      flushBuffer();
    }
    if (paragraph.trim().length > targetLength) {
      flushBuffer();
      for (var offset = 0; offset < paragraph.length; offset += targetLength) {
        final end = (offset + targetLength).clamp(0, paragraph.length);
        final slice = paragraph.substring(offset, end);
        final trimmed = slice.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final leading = slice.indexOf(RegExp(r'\S'));
        chunks.add((
          text: trimmed,
          startOffset: paragraphStart + offset + (leading < 0 ? 0 : leading),
        ));
      }
    } else {
      if (buffer.isEmpty) {
        bufferStart = paragraphStart;
      }
      buffer.writeln(paragraph.trim());
      buffer.writeln();
    }
  }
  flushBuffer();
  return chunks;
}

int _firstNonWhitespace(String value) {
  final match = RegExp(r'\S').firstMatch(value);
  return match?.start ?? 0;
}

String _folderFingerprint(Directory root) {
  final rows = <String>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = p
        .relative(entity.path, from: root.path)
        .replaceAll('\\', '/');
    final stat = entity.statSync();
    rows.add('$relative|${stat.size}|${stat.modified.millisecondsSinceEpoch}');
  }
  rows.sort();
  return sha256.convert(utf8.encode(rows.join('\n'))).toString();
}

int? _schemaVersion(Database database) {
  final rows = database.select('PRAGMA user_version');
  if (rows.isEmpty) return null;
  final value = rows.first.values.first;
  return value is int ? value : int.tryParse(value?.toString() ?? '');
}

void _printSummary(EvaluationComparison comparison, File outputFile) {
  final baseline = comparison.baseline;
  final candidate = comparison.candidate;
  String percent(int value, int total) =>
      total == 0 ? '—' : '${(value * 100 / total).toStringAsFixed(1)}%';
  String nullablePercent(double? value) =>
      value == null ? '未测量' : '${(value * 100).toStringAsFixed(1)}%';
  String nullableChars(double? value) =>
      value == null ? '未测量' : value.toStringAsFixed(0);

  stdout
    ..writeln('')
    ..writeln('父子分块效果验证')
    ..writeln(
      '完整证据覆盖：旧 ${baseline.successes}/${baseline.questions} '
      '(${percent(baseline.successes, baseline.questions)}) → '
      '新 ${candidate.successes}/${candidate.questions} '
      '(${percent(candidate.successes, candidate.questions)})',
    )
    ..writeln(
      '可答题完整率：旧 ${baseline.completeWhenAnswerable}/'
      '${baseline.answerableCount}，新 ${candidate.completeWhenAnswerable}/'
      '${candidate.answerableCount}',
    )
    ..writeln(
      '无答案题空结果：旧 ${baseline.emptyNoAnswerResults}/'
      '${baseline.noAnswerCount}，新 ${candidate.emptyNoAnswerResults}/'
      '${candidate.noAnswerCount}',
    )
    ..writeln(
      '逐题胜负平：新胜 ${comparison.wins} / 新负 ${comparison.losses} / '
      '平 ${comparison.ties}',
    )
    ..writeln(
      '证据召回均值：旧 ${(baseline.meanEvidenceRecall * 100).toStringAsFixed(1)}% '
      '→ 新 ${(candidate.meanEvidenceRecall * 100).toStringAsFixed(1)}%',
    )
    ..writeln(
      '平均实际 payload 字符：旧 '
      '${baseline.meanPayloadChars.toStringAsFixed(0)} '
      '→ 新 ${candidate.meanPayloadChars.toStringAsFixed(0)}；'
      '平均引用数：旧 ${baseline.meanReferenceCount.toStringAsFixed(2)} '
      '→ 新 ${candidate.meanReferenceCount.toStringAsFixed(2)}',
    )
    ..writeln(
      '上下文重复字符均值：旧 '
      '${nullableChars(baseline.meanContextDuplicateChars)} '
      '→ 新 ${nullableChars(candidate.meanContextDuplicateChars)}；'
      '上下文重复率：旧 ${nullablePercent(baseline.meanContextDuplicateRate)} '
      '→ 新 ${nullablePercent(candidate.meanContextDuplicateRate)}；'
      '可测引用：旧 ${baseline.sourceRangeReferenceCount}/'
      '${baseline.referenceCount}，新 ${candidate.sourceRangeReferenceCount}/'
      '${candidate.referenceCount}；'
      'locator 非空率：旧 '
      '${(baseline.locatorPresentRate * 100).toStringAsFixed(1)}% '
      '→ 新 ${(candidate.locatorPresentRate * 100).toStringAsFixed(1)}%'
      '（非跳转正确率）',
    )
    ..writeln(
      '检索 p50/p95：旧 ${baseline.latencyP50Micros}µs/'
      '${baseline.latencyP95Micros}µs，新 ${candidate.latencyP50Micros}µs/'
      '${candidate.latencyP95Micros}µs',
    )
    ..writeln('结果已写入 ${outputFile.path}');
}

final class _SourceUnit {
  const _SourceUnit({
    required this.title,
    required this.href,
    required this.chapterIndex,
    required this.text,
    required this.blocks,
    required this.progress,
    this.pageNumber = 0,
    this.folderFileLocal = false,
  });

  final String title;
  final String href;
  final int chapterIndex;
  final int pageNumber;
  final String text;
  final List<StructuralBlock> blocks;
  final double progress;
  final bool folderFileLocal;
}

final class _LoadedBook {
  const _LoadedBook({
    required this.bookId,
    required this.title,
    required this.format,
    required this.sourcePath,
    required this.sourceFileHash,
    required this.sourceSize,
    required this.sourceModifiedAt,
    required this.sourceFingerprint,
    required this.units,
    required this.allText,
    required this.legacyChunks,
    required this.structuredChunks,
  });

  final String bookId;
  final String title;
  final BookFormat format;
  final String sourcePath;
  final String sourceFileHash;
  final int sourceSize;
  final String sourceModifiedAt;
  final String sourceFingerprint;
  final List<_SourceUnit> units;
  final String allText;
  final List<SearchChunk> legacyChunks;
  final List<SearchChunk> structuredChunks;

  int get legacyParentCount => 0;

  int get structuredParentCount => {
    for (final chunk in structuredChunks)
      if (chunk.parentId != null) chunk.parentId!,
  }.length;

  Map<String, Object?> toJson() {
    return {
      'bookId': bookId,
      'title': title,
      'format': format.value,
      'sourcePath': sourcePath,
      'sourceFileHash': sourceFileHash,
      'sourceSize': sourceSize,
      'sourceModifiedAt': sourceModifiedAt,
      'sourceFingerprint': sourceFingerprint,
      'units': units.length,
      'sourceChars': allText.length,
      'legacyChunks': legacyChunks.length,
      'structuredChildren': structuredChunks.length,
      'structuredParents': structuredParentCount,
    };
  }
}

final class _Options {
  const _Options({
    required this.datasetPath,
    required this.databasePath,
    required this.outputPath,
    required this.limit,
    required this.iterations,
  });

  factory _Options.parse(List<String> args) {
    String value(String name, String fallback) {
      for (var index = 0; index < args.length; index += 1) {
        if (args[index] == name) {
          if (index + 1 >= args.length) {
            throw FormatException('$name 缺少参数');
          }
          return args[index + 1];
        }
        if (args[index].startsWith('$name=')) {
          return args[index].substring(name.length + 1);
        }
      }
      return fallback;
    }

    int positiveInt(String name, int fallback) {
      final raw = value(name, '$fallback');
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed <= 0) {
        throw FormatException('$name 必须是正整数');
      }
      return parsed;
    }

    final home = Platform.environment['HOME'] ?? '';
    final defaultDatabase =
        Platform.environment['PAGESAGE_DATABASE'] ??
        p.join(
          home,
          '.local',
          'share',
          'dev.pagesage.pagesage',
          'PageSageData',
          'database',
          'pagesage.sqlite',
        );
    return _Options(
      datasetPath: value(
        '--dataset',
        '.local-data/retrieval-eval/real_books_2026-11-08.json',
      ),
      databasePath: value('--database', defaultDatabase),
      outputPath: value(
        '--output',
        'docs/eval/retrieval-effect-2026-11-08-v1-audit.json',
      ),
      limit: positiveInt('--limit', ContextRetriever.defaultLimit),
      iterations: positiveInt('--iterations', 5),
    );
  }

  final String datasetPath;
  final String databasePath;
  final String outputPath;
  final int limit;
  final int iterations;
}
