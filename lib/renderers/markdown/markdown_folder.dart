import 'dart:io';

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
final class MarkdownFolderLoader {
  const MarkdownFolderLoader();

  /// The most files one folder book may hold.
  static const int maxFiles = 2000;

  /// The most bytes of Markdown one folder book may hold.
  static const int maxTotalBytes = 64 * 1024 * 1024;

  Future<EpubDocument> load(String folderPath) async {
    final files = await discoverMarkdownFiles(folderPath);
    if (files.isEmpty) {
      throw const MarkdownFolderException('这个文件夹里没有 Markdown 文件');
    }
    if (files.length > maxFiles) {
      throw MarkdownFolderException(
        '文件夹里有 ${files.length} 个 Markdown 文件，超过 $maxFiles 个上限',
      );
    }

    final chapters = <EpubChapter>[];
    final toc = <EpubTocItem>[];
    final unreadable = <String>[];
    var totalBytes = 0;

    for (final file in files) {
      final relative = _relative(file, folderPath);
      final String raw;
      try {
        totalBytes += await file.length();
        if (totalBytes > maxTotalBytes) {
          throw MarkdownFolderException(
            '文件夹里的 Markdown 超过 ${maxTotalBytes ~/ (1024 * 1024)} MB，已放弃打开',
          );
        }
        raw = await file.readAsString();
      } on MarkdownFolderException {
        rethrow;
      } on Object {
        // One unreadable file does not take the folder with it; the reader
        // says which files were left out at the end of the book.
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
