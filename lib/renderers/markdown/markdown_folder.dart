import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../common/book_document_loader.dart';
import '../epub/epub_document.dart';
import 'markdown_parser.dart';

/// A folder of Markdown files that could not be read as one book.
final class MarkdownFolderException implements BookLoadException {
  const MarkdownFolderException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

/// The most files one folder book may hold.
const int markdownFolderMaxFiles = 2000;

/// The most bytes of Markdown one folder book may hold.
const int markdownFolderMaxBytes = 64 * 1024 * 1024;

/// The Markdown files under [rootPath], in reading order.
///
/// A folder book is read in place: the files stay where the writer keeps
/// them, so an edit shows up the next time the book is opened. That also
/// means the walk has to respect the writer's own layout — hidden folders
/// (`.git`, `.obsidian`, `.trash`) and dependency trees are not chapters.
Future<List<File>> discoverMarkdownFiles(String rootPath) async {
  final root = Directory(rootPath);
  if (!await root.exists()) {
    return const <File>[];
  }
  final files = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final relative = p.relative(entity.path, from: rootPath);
    if (_isIgnored(relative)) {
      continue;
    }
    final extension = p.extension(entity.path).toLowerCase();
    if (extension == '.md' || extension == '.markdown') {
      files.add(entity);
    }
  }
  // The path is the only order a folder has. It is also the order the writer
  // sees in a file manager, which is what makes the table of contents
  // predictable.
  files.sort(
    (a, b) => _relative(a, rootPath).compareTo(_relative(b, rootPath)),
  );
  return files;
}

/// Whether [relativePath] belongs to something that is not the writer's text.
bool _isIgnored(String relativePath) {
  for (final segment in p.split(relativePath)) {
    // A hidden entry is the tool's, not the book's: version control, an
    // editor's cache, a trash folder.
    if (segment.startsWith('.')) {
      return true;
    }
    if (segment == 'node_modules') {
      return true;
    }
  }
  return false;
}

String _relative(File file, String rootPath) {
  return p.split(p.relative(file.path, from: rootPath)).join('/');
}

/// Opens a whole folder of Markdown files as one book.
///
/// Each file contributes its chapters — the same way it would if it had been
/// imported on its own — and the files are stitched in path order. The text
/// offsets stay inside each chapter, so search, progress and jumps need to
/// know nothing about the folder; a chapter's [EpubChapter.href] carries the
/// file it came from, which is what lets a reader jump back to it later.
///
/// Reading and parsing a folder is the one heavy thing a Markdown book can
/// do, so it happens off the UI isolate and the result is kept until the
/// folder changes. Without the cache, opening a book parses it once for the
/// table of contents and again for the text; without the isolate, a real
/// notes folder freezes the window for seconds.
final class MarkdownFolderLoader {
  const MarkdownFolderLoader();

  static final Map<String, _FolderCacheEntry> _cache =
      <String, _FolderCacheEntry>{};

  /// Forgets every parsed folder. Used by tests and by "重建索引".
  static void clearCache() => _cache.clear();

  Future<EpubDocument> load(String folderPath) async {
    final files = await discoverMarkdownFiles(folderPath);
    if (files.isEmpty) {
      throw const MarkdownFolderException('这个文件夹里没有 Markdown 文件');
    }
    if (files.length > markdownFolderMaxFiles) {
      throw MarkdownFolderException(
        '文件夹里有 ${files.length} 个 Markdown 文件，'
        '超过 $markdownFolderMaxFiles 个上限',
      );
    }

    final relativePaths = <String>[
      for (final file in files) _relative(file, folderPath),
    ];
    final signature = await _signature(files, folderPath);

    final cached = _cache[folderPath];
    if (cached != null && cached.signature == signature) {
      return cached.document;
    }

    final entry = _FolderCacheEntry(
      signature,
      Isolate.run(() => _parseFolder(folderPath, relativePaths)),
    );
    _cache[folderPath] = entry;
    _evict();
    try {
      return await entry.document;
    } on Object {
      if (identical(_cache[folderPath], entry)) {
        _cache.remove(folderPath);
      }
      rethrow;
    }
  }

  /// What the folder looked like: every file's path, size and modification
  /// time. An edit, a new note or a deleted one all change it, which is what
  /// keeps the cache from serving yesterday's notes.
  Future<String> _signature(List<File> files, String rootPath) async {
    final buffer = StringBuffer();
    for (final file in files) {
      final stat = await file.stat();
      buffer
        ..write(_relative(file, rootPath))
        ..write('|')
        ..write(stat.size)
        ..write('|')
        ..write(stat.modified.millisecondsSinceEpoch)
        ..write('\n');
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  static void _evict() {
    while (_cache.length > 2) {
      _cache.remove(_cache.keys.first);
    }
  }
}

final class _FolderCacheEntry {
  _FolderCacheEntry(this.signature, this.document);

  final String signature;
  final Future<EpubDocument> document;
}

/// Reads and parses the folder. Runs in its own isolate.
Future<EpubDocument> _parseFolder(
  String folderPath,
  List<String> relativePaths,
) async {
  final chapters = <EpubChapter>[];
  final toc = <EpubTocItem>[];
  final unreadable = <String>[];
  var totalBytes = 0;

  for (final relative in relativePaths) {
    final file = File(p.join(folderPath, relative));
    final String raw;
    try {
      totalBytes += await file.length();
      if (totalBytes > markdownFolderMaxBytes) {
        throw MarkdownFolderException(
          '文件夹里的 Markdown 超过 '
          '${markdownFolderMaxBytes ~/ (1024 * 1024)} MB，已放弃打开',
        );
      }
      raw = await file.readAsString();
    } on MarkdownFolderException {
      rethrow;
    } on Object {
      // One unreadable file does not take the folder with it; the reader says
      // which files were left out at the end of the book.
      unreadable.add(relative);
      continue;
    }
    if (raw.trim().isEmpty) {
      continue;
    }

    final EpubDocument parsed;
    try {
      parsed = await MarkdownParser(
        basePath: p.dirname(file.path),
      ).parse(raw, fallbackTitle: p.basenameWithoutExtension(file.path));
    } on Object {
      unreadable.add(relative);
      continue;
    }

    final shift = chapters.length;
    for (final chapter in parsed.chapters) {
      chapters.add(
        EpubChapter(
          index: chapters.length,
          href: relative,
          title: chapter.title,
          text: chapter.text,
          blocks: chapter.blocks,
          anchors: chapter.anchors,
        ),
      );
    }
    for (final item in parsed.toc) {
      toc.add(_shiftChapterIndex(item, shift));
    }
  }

  if (chapters.isEmpty) {
    throw const MarkdownFolderException('这个文件夹里的 Markdown 没有可读的正文');
  }
  if (unreadable.isNotEmpty) {
    chapters.add(_unreadableChapter(chapters.length, unreadable));
  }

  return EpubDocument(
    chapters: List<EpubChapter>.unmodifiable(chapters),
    toc: List<EpubTocItem>.unmodifiable(toc),
  );
}

/// Moves a table-of-contents entry to its place in the whole folder.
EpubTocItem _shiftChapterIndex(EpubTocItem item, int shift) {
  return EpubTocItem(
    title: item.title,
    href: item.href,
    chapterIndex: item.chapterIndex == null ? null : item.chapterIndex! + shift,
    fragment: item.fragment,
    chapterOffset: item.chapterOffset,
    children: item.children
        .map((child) => _shiftChapterIndex(child, shift))
        .toList(growable: false),
  );
}

/// The closing chapter that names the files which could not be read.
///
/// Dropping them silently would make a folder look complete when it is not;
/// a reader who cannot find a note needs to be told it was left out.
EpubChapter _unreadableChapter(int index, List<String> files) {
  const title = '无法读取的文件';
  final blocks = <EpubBlock>[];
  final text = StringBuffer();
  for (final file in files) {
    if (text.isNotEmpty) {
      text.write('\n\n');
    }
    final start = text.length;
    final line = '• $file';
    text.write(line);
    blocks.add(
      EpubTextBlock(
        startOffset: start,
        endOffset: text.length,
        text: line,
        type: EpubBlockType.paragraph,
      ),
    );
  }
  return EpubChapter(
    index: index,
    href: '',
    title: title,
    text: text.toString(),
    blocks: List<EpubBlock>.unmodifiable(blocks),
  );
}
