import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../common/book_document_loader.dart';
import '../epub/epub_document.dart';
import 'markdown_parser.dart';

/// The folder facts a reader session needs, without tying the manifest loader
/// to a particular application controller.
abstract interface class MarkdownFolderSource {
  Future<MarkdownFolderManifest> loadManifest(String folderPath);

  Future<({String relativePath, int chapterIndex})?> resolveLegacyPosition(
    String folderPath,
    int legacyChapterIndex,
  );
}

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
  // sees in a file manager, which is what makes reading order predictable.
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

/// One Markdown file in a folder book.
final class MarkdownFolderFile {
  const MarkdownFolderFile({
    required this.relativePath,
    required this.absolutePath,
    required this.title,
    required this.size,
    required this.modified,
  });

  /// Path inside the folder, always with `/` separators.
  final String relativePath;
  final String absolutePath;

  /// The file name without its extension, used when the file has no heading.
  final String title;
  final int size;
  final DateTime modified;

  int get weight => size > 0 ? size : 1;
}

/// A row in the folder panel.
sealed class MarkdownFolderNode {
  const MarkdownFolderNode({required this.name, required this.relativePath});

  final String name;
  final String relativePath;
}

/// A directory in the folder panel.
final class MarkdownFolderDirectory extends MarkdownFolderNode {
  const MarkdownFolderDirectory({
    required super.name,
    required super.relativePath,
    required this.children,
  });

  final List<MarkdownFolderNode> children;
}

/// A Markdown file in the folder panel.
final class MarkdownFolderDocument extends MarkdownFolderNode {
  MarkdownFolderDocument({required super.name, required this.file})
    : super(relativePath: file.relativePath);

  final MarkdownFolderFile file;
}

/// What a folder book contains, without reading any of its body text.
///
/// The reader only needs this to draw the file tree and to translate between
/// a file-local position and the book-wide progress shown in the library. The
/// document for the selected file is loaded separately.
final class MarkdownFolderManifest {
  const MarkdownFolderManifest({
    required this.rootPath,
    required this.files,
    required this.roots,
    required this.totalBytes,
  });

  final String rootPath;
  final List<MarkdownFolderFile> files;
  final List<MarkdownFolderNode> roots;
  final int totalBytes;

  bool get isEmpty => files.isEmpty;

  int indexOf(String relativePath) {
    final normalized = normalizeFolderHref(relativePath);
    for (var index = 0; index < files.length; index += 1) {
      if (files[index].relativePath == normalized) {
        return index;
      }
    }
    return -1;
  }

  MarkdownFolderFile? fileForHref(String? href) {
    if (href == null || href.isEmpty) {
      return null;
    }
    final index = indexOf(href);
    return index < 0 ? null : files[index];
  }

  MarkdownFolderFile? get firstFile => files.isEmpty ? null : files.first;

  /// The folder-wide progress of a position inside [relativePath].
  double progressForFile(String relativePath, double localProgress) {
    final index = indexOf(relativePath);
    if (index < 0 || totalBytes <= 0) {
      return localProgress.clamp(0, 1).toDouble();
    }
    var before = 0;
    for (var i = 0; i < index; i += 1) {
      before += files[i].weight;
    }
    final current = before + files[index].weight * localProgress.clamp(0, 1);
    return (current / totalBytes).clamp(0, 1).toDouble();
  }

  /// The position inside [relativePath] for a folder-wide progress.
  double localProgressForFile(String relativePath, double progress) {
    final index = indexOf(relativePath);
    if (index < 0 || totalBytes <= 0) {
      return progress.clamp(0, 1).toDouble();
    }
    var before = 0;
    for (var i = 0; i < index; i += 1) {
      before += files[i].weight;
    }
    final weight = files[index].weight;
    return ((progress.clamp(0, 1) * totalBytes - before) / weight)
        .clamp(0, 1)
        .toDouble();
  }

  /// The file a folder-wide progress falls in.
  MarkdownFolderFile? fileAtProgress(double progress) {
    if (files.isEmpty) {
      return null;
    }
    if (totalBytes <= 0) {
      return files.first;
    }
    final target = progress.clamp(0, 1) * totalBytes;
    var cursor = 0;
    for (final file in files) {
      cursor += file.weight;
      if (target < cursor) {
        return file;
      }
    }
    return files.last;
  }
}

/// Normalizes a path stored in a folder locator.
String normalizeFolderHref(String value) {
  var href = value.split('#').first.split('?').first.replaceAll('\\', '/');
  while (href.startsWith('./')) {
    href = href.substring(2);
  }
  if (href.isEmpty) {
    return href;
  }
  return p.posix.normalize(href);
}

/// Opens a whole folder of Markdown files as one book.
///
/// Discovery and the panel tree are cheap: they read paths and stat data, not
/// the notes. [loadLegacyDocument] is retained only to translate a position
/// saved by the old merged-document reader; the reading path never calls it.
final class MarkdownFolderLoader implements MarkdownFolderSource {
  const MarkdownFolderLoader();

  static final Map<String, _ManifestCacheEntry> _manifestCache =
      <String, _ManifestCacheEntry>{};
  static final Map<String, _FolderCacheEntry> _legacyCache =
      <String, _FolderCacheEntry>{};

  /// Forgets every folder manifest and legacy document. Used by tests and by
  /// "重建索引".
  static void clearCache() {
    _manifestCache.clear();
    _legacyCache.clear();
  }

  @override
  Future<MarkdownFolderManifest> loadManifest(String folderPath) async {
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

    final signature = await _signature(files, folderPath);
    final cached = _manifestCache[folderPath];
    if (cached != null && cached.signature == signature) {
      return cached.manifest;
    }

    final manifest = _buildManifest(folderPath, files);
    _manifestCache[folderPath] = _ManifestCacheEntry(signature, manifest);
    _evict();
    return manifest;
  }

  /// Reads the old merged document, only to map a legacy locator.
  ///
  /// A position saved before P7 calls the whole folder's flattened chapter
  /// indexes "chapterIndex". Loading that document once is the honest way to
  /// learn which file and which heading it meant; after the next save the
  /// position is file-local and this path is no longer used.
  Future<EpubDocument> loadLegacyDocument(String folderPath) async {
    final files = await discoverMarkdownFiles(folderPath);
    if (files.isEmpty) {
      throw const MarkdownFolderException('这个文件夹里没有 Markdown 文件');
    }
    final relativePaths = <String>[
      for (final file in files) _relative(file, folderPath),
    ];
    final signature = await _signature(files, folderPath);
    final cached = _legacyCache[folderPath];
    if (cached != null && cached.signature == signature) {
      return cached.document;
    }
    final entry = _FolderCacheEntry(
      signature,
      Isolate.run(() => _parseLegacyFolder(folderPath, relativePaths)),
    );
    _legacyCache[folderPath] = entry;
    _evict();
    try {
      return await entry.document;
    } on Object {
      if (identical(_legacyCache[folderPath], entry)) {
        _legacyCache.remove(folderPath);
      }
      rethrow;
    }
  }

  /// Maps a legacy merged chapter index to a file-local position.
  ///
  /// Returns null when the legacy document no longer has that chapter (the
  /// folder was edited since the position was saved).
  @override
  Future<({String relativePath, int chapterIndex})?> resolveLegacyPosition(
    String folderPath,
    int legacyChapterIndex,
  ) async {
    final document = await loadLegacyDocument(folderPath);
    if (legacyChapterIndex < 0 ||
        legacyChapterIndex >= document.chapters.length) {
      return null;
    }
    final chapter = document.chapters[legacyChapterIndex];
    if (chapter.href.isEmpty) {
      return null;
    }
    var localIndex = 0;
    for (var index = 0; index < legacyChapterIndex; index += 1) {
      if (document.chapters[index].href == chapter.href) {
        localIndex += 1;
      }
    }
    return (relativePath: chapter.href, chapterIndex: localIndex);
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
    while (_manifestCache.length > 4) {
      _manifestCache.remove(_manifestCache.keys.first);
    }
    while (_legacyCache.length > 2) {
      _legacyCache.remove(_legacyCache.keys.first);
    }
  }
}

final class _ManifestCacheEntry {
  _ManifestCacheEntry(this.signature, this.manifest);

  final String signature;
  final MarkdownFolderManifest manifest;
}

final class _FolderCacheEntry {
  _FolderCacheEntry(this.signature, this.document);

  final String signature;
  final Future<EpubDocument> document;
}

MarkdownFolderManifest _buildManifest(String folderPath, List<File> files) {
  final entries = <MarkdownFolderFile>[];
  var totalBytes = 0;
  for (final file in files) {
    final stat = file.statSync();
    final relative = _relative(file, folderPath);
    final size = stat.size;
    totalBytes += size > 0 ? size : 1;
    entries.add(
      MarkdownFolderFile(
        relativePath: relative,
        absolutePath: file.path,
        title: p.basenameWithoutExtension(relative),
        size: size,
        modified: stat.modified,
      ),
    );
  }
  if (totalBytes > markdownFolderMaxBytes) {
    throw MarkdownFolderException(
      '文件夹里的 Markdown 超过 '
      '${markdownFolderMaxBytes ~/ (1024 * 1024)} MB，已放弃打开',
    );
  }

  final root = _DirectoryBuilder('');
  for (final entry in entries) {
    final segments = p.posix.split(entry.relativePath);
    var directory = root;
    for (var index = 0; index < segments.length - 1; index += 1) {
      directory = directory.directories.putIfAbsent(
        segments[index],
        () => _DirectoryBuilder(segments[index]),
      );
    }
    directory.files.add(entry);
  }

  return MarkdownFolderManifest(
    rootPath: folderPath,
    files: List<MarkdownFolderFile>.unmodifiable(entries),
    roots: List<MarkdownFolderNode>.unmodifiable(root.toNodes('')),
    totalBytes: totalBytes,
  );
}

final class _DirectoryBuilder {
  _DirectoryBuilder(this.name);

  final String name;
  final Map<String, _DirectoryBuilder> directories =
      <String, _DirectoryBuilder>{};
  final List<MarkdownFolderFile> files = <MarkdownFolderFile>[];

  List<MarkdownFolderNode> toNodes(String parentPath) {
    final relativePath = parentPath.isEmpty
        ? name
        : (name.isEmpty ? parentPath : '$parentPath/$name');
    final nodes = <MarkdownFolderNode>[];
    final directoryNames = directories.keys.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final directoryName in directoryNames) {
      final child = directories[directoryName]!;
      nodes.add(
        MarkdownFolderDirectory(
          name: child.name,
          relativePath: relativePath.isEmpty
              ? child.name
              : '$relativePath/${child.name}',
          children: List<MarkdownFolderNode>.unmodifiable(
            child.toNodes(relativePath),
          ),
        ),
      );
    }
    final sortedFiles = files.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    for (final file in sortedFiles) {
      nodes.add(
        MarkdownFolderDocument(
          name: p.posix.basename(file.relativePath),
          file: file,
        ),
      );
    }
    return nodes;
  }
}

/// Reads and parses the folder as the old merged document. Runs in its own
/// isolate and is only used for locating pre-P7 positions.
Future<EpubDocument> _parseLegacyFolder(
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
