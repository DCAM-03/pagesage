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
/// A single Markdown file is opened here. A folder book first asks
/// [MarkdownFolderLoader] for its manifest, then opens the selected file with
/// [loadWithHref] so the document still names the folder-relative path.
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
      // A folder is a shelf of files, not one document. Callers must pick a
      // file from the manifest; merging every note again would bring back the
      // flat table of contents P7 removed.
      throw const MarkdownLoadException('文件夹书需要先选择一个 Markdown 文件');
    }
    if (stat.type == FileSystemEntityType.notFound) {
      throw const MarkdownLoadException('找不到这个 Markdown 文件或文件夹');
    }
    return _loadFile(filePath);
  }

  /// Opens one file of a folder book and stamps its chapters with [href].
  ///
  /// The parser does not know where a file sits in a folder, and it should
  /// not: its job is to read one note. The relative path is attached here so
  /// progress, search and AI can point back at the right note.
  Future<EpubDocument> loadWithHref(String filePath, String href) async {
    final document = await load(filePath);
    return _withHref(document, href);
  }

  Future<EpubDocument> _loadFile(String filePath) async {
    final stat = await File(filePath).stat();
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

  EpubDocument _withHref(EpubDocument document, String href) {
    return EpubDocument(
      chapters: List<EpubChapter>.unmodifiable([
        for (final chapter in document.chapters)
          EpubChapter(
            index: chapter.index,
            href: href,
            title: chapter.title,
            text: chapter.text,
            blocks: chapter.blocks,
            anchors: chapter.anchors,
          ),
      ]),
      toc: List<EpubTocItem>.unmodifiable([
        for (final item in document.toc) _withHrefItem(item, href),
      ]),
    );
  }

  EpubTocItem _withHrefItem(EpubTocItem item, String href) {
    return EpubTocItem(
      title: item.title,
      href: href,
      chapterIndex: item.chapterIndex,
      fragment: item.fragment,
      chapterOffset: item.chapterOffset,
      children: item.children
          .map((child) => _withHrefItem(child, href))
          .toList(growable: false),
    );
  }
}

/// Loads one file of a folder book with its folder-relative path.
final class MarkdownFileDocumentLoader implements BookDocumentLoader {
  const MarkdownFileDocumentLoader({required this.relativePath});

  final String relativePath;

  @override
  Future<EpubDocument> load(String filePath) {
    return const MarkdownDocumentLoader().loadWithHref(filePath, relativePath);
  }
}

final class _FileCacheEntry {
  _FileCacheEntry(this.signature, this.document);

  final String signature;
  final Future<EpubDocument> document;
}
