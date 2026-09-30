import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../domain/ocr/ocr_models.dart';

/// Local persistence for recognized PDF pages (text + geometry).
abstract interface class OcrPageStore {
  Future<OcrPageResult?> getPage(String bookId, int pageNumber);

  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
  });

  Future<void> deleteBook(String bookId);
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
  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
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
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> deleteBook(String bookId) {
    return _dao.deleteByBook(bookId);
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
  Future<void> putPage({
    required String bookId,
    required int pageNumber,
    required OcrPageResult result,
  }) async {
    _pages[_key(bookId, pageNumber)] = result;
  }

  @override
  Future<void> deleteBook(String bookId) async {
    _pages.removeWhere((key, _) => key.startsWith('$bookId:'));
  }
}
