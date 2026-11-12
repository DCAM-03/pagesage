import 'dart:collection';

import '../../../domain/ocr/ocr_models.dart';

/// Process-lifetime OCR page cache with O(1) LRU.
final class OcrSessionCache {
  OcrSessionCache({this.maxEntries = 48});

  final int maxEntries;

  /// LinkedHashMap preserves insertion order; on access we re-insert for LRU.
  final LinkedHashMap<String, OcrPageResult> _pages =
      LinkedHashMap<String, OcrPageResult>();

  static String _key(String bookId, int pageNumber) => '$bookId:$pageNumber';

  OcrPageResult? get(String bookId, int pageNumber) {
    final key = _key(bookId, pageNumber);
    final hit = _pages.remove(key);
    if (hit == null) {
      return null;
    }
    _pages[key] = hit;
    return hit;
  }

  void put(String bookId, int pageNumber, OcrPageResult result) {
    final key = _key(bookId, pageNumber);
    _pages.remove(key);
    _pages[key] = result;
    while (_pages.length > maxEntries) {
      _pages.remove(_pages.keys.first);
    }
  }

  void clearAll() {
    _pages.clear();
  }

  void removePages(String bookId, Iterable<int> pageNumbers) {
    for (final pageNumber in pageNumbers) {
      _pages.remove(_key(bookId, pageNumber));
    }
  }

  int get length => _pages.length;
}
