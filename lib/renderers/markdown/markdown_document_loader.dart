import 'dart:io';

import 'package:path/path.dart' as p;

import '../common/book_document_loader.dart';
import '../epub/epub_document.dart';
import 'markdown_folder.dart';
import 'markdown_parser.dart';

/// A Markdown document that could not be opened.
final class MarkdownLoadException implements BookLoadException {
  const MarkdownLoadException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

/// Opens a Markdown source into the reader's document model.
///
/// Both shapes of a Markdown book are here: a single file, and a folder of
/// files read as one book. The distinction is the path's own — a directory is
/// a folder book — so every caller that already asks for a Markdown document
/// gets whichever one the path names without learning about a second loader.
///
/// The book's title comes from the file itself when it says one (front matter)
/// and from the file name when it does not. A file with nothing to read is an
/// error rather than an empty page: an empty chapter looks like a broken
/// renderer, and saying so is kinder than showing a blank screen.
///
/// A parsed document is kept until the source changes. Opening a book asks
/// for it more than once — the table of contents, the renderer, the index —
/// and parsing the same file three times is time the reader spends looking
/// at a spinner.
final class MarkdownDocumentLoader implements BookDocumentLoader {
  const MarkdownDocumentLoader();

  static final Map<String, _FileCacheEntry> _cache =
      <String, _FileCacheEntry>{};

  /// Forgets every parsed Markdown document. Used by tests and by "重建索引".
  static void clearCache() {
    _cache.clear();
    MarkdownFolderLoader.clearCache();
  }

  @override
  Future<EpubDocument> load(String filePath) async {
    final stat = await File(filePath).stat();
    if (stat.type == FileSystemEntityType.directory) {
      return const MarkdownFolderLoader().load(filePath);
    }
    if (stat.type == FileSystemEntityType.notFound) {
      throw const MarkdownLoadException('找不到这个 Markdown 文件或文件夹');
    }

    final signature = '${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    final cached = _cache[filePath];
    if (cached != null && cached.signature == signature) {
      return cached.document;
    }

    final entry = _FileCacheEntry(signature, _parseFile(filePath));
    _cache[filePath] = entry;
    _evict();
    try {
      return await entry.document;
    } on Object {
      if (identical(_cache[filePath], entry)) {
        _cache.remove(filePath);
      }
      rethrow;
    }
  }

  static void _evict() {
    while (_cache.length > 4) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<EpubDocument> _parseFile(String filePath) async {
    final file = File(filePath);
    final String raw;
    try {
      raw = await file.readAsString();
    } on Object {
      throw const MarkdownLoadException('Markdown 文件无法读取');
    }

    final document = await MarkdownParser(
      basePath: p.dirname(filePath),
    ).parse(raw, fallbackTitle: p.basenameWithoutExtension(filePath));

    if (document.chapters.isEmpty || document.totalTextLength == 0) {
      throw const MarkdownLoadException('这个 Markdown 文件没有可读的正文');
    }
    return document;
  }
}

final class _FileCacheEntry {
  _FileCacheEntry(this.signature, this.document);

  final String signature;
  final Future<EpubDocument> document;
}
