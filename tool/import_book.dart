import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:pagesage/core/files/format_detector.dart';
import 'package:pagesage/core/files/hash_service.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

/// Copies a book into the local PageSage library and records it.
///
/// The app's own import path needs a Flutter binding for the file picker,
/// so a command-line tool cannot use it. This does the same thing by hand:
/// copy the file into the library, read its metadata, and write one row.
///
/// Usage:
///
/// ```text
/// dart run tool/import_book.dart <book file> [data root]
/// ```
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      '用法: dart run tool/import_book.dart <book file> [data root]',
    );
    exitCode = 1;
    return;
  }
  final source = File(args.first);
  if (!source.existsSync()) {
    stderr.writeln('找不到文件: ${source.path}');
    exitCode = 1;
    return;
  }
  final root = args.length > 1
      ? Directory(args[1])
      : Directory(
          '${Platform.environment['HOME']}/.local/share/dev.pagesage.pagesage/PageSageData',
        );
  if (!root.existsSync()) {
    stderr.writeln('找不到数据目录: ${root.path}');
    exitCode = 1;
    return;
  }

  final dbFile = File(p.join(root.path, 'database', 'pagesage.sqlite'));
  final db = sqlite3.open(dbFile.path);
  try {
    final format = await FormatDetector().detect(source);
    final hash = await HashService().sha256File(source);
    final id = const Uuid().v4();

    // The library mirrors the app's own layout: two levels of hash
    // prefix, then the book's own id.
    final booksDir = Directory(
      p.join(
        root.path,
        'library',
        'books',
        hash.substring(0, 2),
        hash.substring(0, 4),
      ),
    );
    await booksDir.create(recursive: true);
    final libraryPath = p.join(booksDir.path, '$id${p.extension(source.path)}');
    await source.copy(libraryPath);

    final metadata = format == BookFormat.epub
        ? await _readEpubMetadata(libraryPath)
        : const _Metadata();

    final now = DateTime.now().millisecondsSinceEpoch;
    db.execute(
      '''
      INSERT INTO books (
        id, title, original_title, author, format, original_format,
        original_file_path, library_file_path, cover_path, file_hash,
        file_size, language, description, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        metadata.title ?? source.uri.pathSegments.last,
        metadata.title,
        metadata.author,
        format.value,
        format.value,
        source.absolute.path,
        libraryPath,
        null,
        hash,
        source.lengthSync(),
        metadata.language,
        null,
        now,
        now,
      ],
    );
    stdout.writeln('已导入: ${metadata.title ?? source.path}');
    stdout.writeln('  id: $id');
    stdout.writeln('  文件: $libraryPath');
  } finally {
    db.close();
  }
}

final class _Metadata {
  const _Metadata({this.title, this.author, this.language});

  final String? title;
  final String? author;
  final String? language;
}

/// Reads the title, author and language out of an EPUB's package file.
Future<_Metadata> _readEpubMetadata(String path) async {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    ArchiveFile? opf;
    for (final entry in archive.files) {
      if (entry.name.endsWith('.opf')) {
        opf ??= entry;
      }
    }
    if (opf == null) {
      return const _Metadata();
    }
    final document = XmlDocument.parse(
      String.fromCharCodes(opf.content),
      entityMapping: const XmlDefaultEntityMapping.html5(),
    );
    String? title;
    String? author;
    String? language;
    for (final element in document.findAllElements(
      'metadata',
      namespace: '*',
    )) {
      for (final child in element.children.whereType<XmlElement>()) {
        switch (child.name.local) {
          case 'title':
            title ??= child.innerText.trim();
          case 'creator':
            author ??= child.innerText.trim();
          case 'language':
            language ??= child.innerText.trim();
        }
      }
    }
    return _Metadata(
      title: (title == null || title.isEmpty) ? null : title,
      author: (author == null || author.isEmpty) ? null : author,
      language: (language == null || language.isEmpty) ? null : language,
    );
  } on Object {
    return const _Metadata();
  } finally {
    await input.close();
  }
}
