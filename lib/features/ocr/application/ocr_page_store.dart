import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../domain/ocr/ocr_models.dart';

/// Local persistence for recognized PDF pages (text + geometry).
abstract interface class OcrPageStore {
  Future<OcrPageResult?> getPage(String bookId, int pageNumber);

  Future<List<OcrStoredPage>> listPages(String bookId);

  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
    String? sourceRevision,
    String? cacheSignature,
    String? textRevision,
    String? engineVersion,
    String pipelineVersion = 'ocr-text-v1',
    String resultState = 'recognized',
    String indexState = 'pending',
  });

  Future<void> deleteBook(String bookId);

  Future<void> deletePages(String bookId, Iterable<int> pageNumbers);
}

final class DriftOcrPageStore implements OcrPageStore {
  DriftOcrPageStore(this._dao);

  final OcrPageDao _dao;
  static const _uuid = Uuid();

  @override
  Future<OcrPageResult?> getPage(String bookId, int pageNumber) async {
    final row = await _dao.getPage(bookId, pageNumber);
    if (row == null) {
      return null;
    }
    return _fromRow(row);
  }

  @override
  Future<List<OcrStoredPage>> listPages(String bookId) async {
    final rows = await _dao.listByBook(bookId);
    return rows
        .map(
          (row) =>
              OcrStoredPage(pageNumber: row.pageNumber, result: _fromRow(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
    String? sourceRevision,
    String? cacheSignature,
    String? textRevision,
    String? engineVersion,
    String pipelineVersion = 'ocr-text-v1',
    String resultState = 'recognized',
    String indexState = 'pending',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _dao.getPage(bookId, pageNumber);
    final id = existing?.id ?? _uuid.v4();
    await _dao.upsertPage(
      OcrPagesCompanion.insert(
        id: id,
        bookId: bookId,
        pageNumber: pageNumber,
        body: result.text,
        language: Value(result.language),
        engine: Value(result.engine),
        confidence: Value(result.confidence),
        blocksJson: _encodeBlocks(result.blocks),
        imageWidth: Value(result.imageWidth),
        imageHeight: Value(result.imageHeight),
        sourceRevision: Value(sourceRevision),
        cacheSignature: Value(cacheSignature),
        textRevision: Value(textRevision),
        engineVersion: Value(engineVersion),
        pipelineVersion: Value(pipelineVersion),
        resultState: Value(resultState),
        indexState: Value(indexState),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> deleteBook(String bookId) {
    return _dao.deleteByBook(bookId);
  }

  @override
  Future<void> deletePages(String bookId, Iterable<int> pageNumbers) {
    return _dao.deletePages(bookId, pageNumbers);
  }

  OcrPageResult _fromRow(OcrPageRow row) {
    return OcrPageResult(
      text: row.body,
      language: row.language ?? '',
      engine: row.engine ?? '',
      confidence: row.confidence,
      blocks: _decodeBlocks(row.blocksJson),
      imageWidth: row.imageWidth,
      imageHeight: row.imageHeight,
      sourceRevision: row.sourceRevision,
      cacheSignature: row.cacheSignature,
      textRevision: row.textRevision,
      engineVersion: row.engineVersion,
      pipelineVersion: row.pipelineVersion,
      resultState: row.resultState,
      indexState: row.indexState,
    );
  }

  String _encodeBlocks(List<OcrTextBlock> blocks) {
    final payload = blocks
        .map((block) => block.toJson())
        .toList(growable: false);
    return jsonEncode(payload);
  }

  List<OcrTextBlock> _decodeBlocks(String raw) {
    if (raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final blocks = <OcrTextBlock>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final map = item.cast<Object?, Object?>();
        final text = map['text']?.toString() ?? '';
        if (text.isEmpty) {
          continue;
        }
        double? asDouble(Object? value) {
          if (value is num) {
            return value.toDouble();
          }
          return double.tryParse(value?.toString() ?? '');
        }

        blocks.add(
          OcrTextBlock(
            text: text,
            left: asDouble(map['left']),
            top: asDouble(map['top']),
            width: asDouble(map['width']),
            height: asDouble(map['height']),
          ),
        );
      }
      return blocks;
    } on Object {
      return const [];
    }
  }
}

final class MemoryOcrPageStore implements OcrPageStore {
  final Map<String, OcrPageResult> _pages = {};

  static String _key(String bookId, int pageNumber) => '$bookId:$pageNumber';

  @override
  Future<OcrPageResult?> getPage(String bookId, int pageNumber) async {
    return _pages[_key(bookId, pageNumber)];
  }

  @override
  Future<List<OcrStoredPage>> listPages(String bookId) async {
    final prefix = '$bookId:';
    return _pages.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) {
          final pageNumber = int.tryParse(entry.key.substring(prefix.length));
          if (pageNumber == null) {
            return null;
          }
          return OcrStoredPage(pageNumber: pageNumber, result: entry.value);
        })
        .whereType<OcrStoredPage>()
        .toList(growable: false)
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  @override
  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
    String? sourceRevision,
    String? cacheSignature,
    String? textRevision,
    String? engineVersion,
    String pipelineVersion = 'ocr-text-v1',
    String resultState = 'recognized',
    String indexState = 'pending',
  }) async {
    _pages[_key(bookId, pageNumber)] = result.copyWith(
      sourceRevision: sourceRevision,
      cacheSignature: cacheSignature,
      textRevision: textRevision,
      engineVersion: engineVersion,
      pipelineVersion: pipelineVersion,
      resultState: resultState,
      indexState: indexState,
    );
  }

  @override
  Future<void> deleteBook(String bookId) async {
    _pages.removeWhere((key, _) => key.startsWith('$bookId:'));
  }

  @override
  Future<void> deletePages(String bookId, Iterable<int> pageNumbers) async {
    for (final pageNumber in pageNumbers) {
      _pages.remove(_key(bookId, pageNumber));
    }
  }
}
