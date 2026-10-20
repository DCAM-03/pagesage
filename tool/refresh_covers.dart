import 'dart:io';

import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/metadata_extractor.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Re-extract covers for all books in the local PageSage library.
///
/// Usage:
///   dart run tool/refresh_covers.dart
///   dart run tool/refresh_covers.dart --root "C:/path/to/PageSageData"
Future<void> main(List<String> args) async {
  final root = _resolveRoot(args);
  if (root == null || !root.existsSync()) {
    stderr.writeln('找不到 PageSageData 目录');
    exitCode = 1;
    return;
  }

  final appPaths = AppPaths(overrideRoot: root);
  final dbFile = await appPaths.databaseFile();
  if (!dbFile.existsSync()) {
    stderr.writeln('找不到数据库: ${dbFile.path}');
    exitCode = 1;
    return;
  }

  stdout.writeln('数据目录: ${root.path}');
  stdout.writeln('数据库: ${dbFile.path}');

  final db = sqlite3.open(dbFile.path);
  try {
    final rows = db.select(
      'SELECT id, title, format, library_file_path, cover_path FROM books',
    );
    stdout.writeln('共 ${rows.length} 本书\n');

    final extractor = MetadataExtractor(appPaths: appPaths);
    var ok = 0;
    var fail = 0;
    var skip = 0;

    for (final row in rows) {
      final id = row['id'] as String;
      final title = row['title'] as String? ?? id;
      final formatValue = row['format'] as String? ?? '';
      final libraryPath = row['library_file_path'] as String? ?? '';
      final format = BookFormat.fromValue(formatValue);
      if (format == null) {
        stdout.writeln('→ $title ($formatValue)');
        stdout.writeln('  跳过：未知格式 $formatValue');
        skip += 1;
        continue;
      }
      final file = File(libraryPath);

      stdout.writeln('→ $title ($formatValue)');
      if (!file.existsSync()) {
        stdout.writeln('  跳过：库文件不存在 $libraryPath');
        skip += 1;
        continue;
      }

      try {
        final metadata = await extractor.extract(
          file: file,
          format: format,
          bookId: id,
        );
        final coverPath = metadata.coverPath;
        if (coverPath == null || coverPath.isEmpty) {
          stdout.writeln('  未找到封面');
          fail += 1;
          continue;
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        db.execute(
          'UPDATE books SET cover_path = ?, updated_at = ? WHERE id = ?',
          [coverPath, now, id],
        );
        stdout.writeln('  已更新: $coverPath');
        ok += 1;
      } catch (error) {
        stdout.writeln('  失败: $error');
        fail += 1;
      }
    }

    stdout.writeln('\n完成：成功 $ok，未找到/失败 $fail，跳过 $skip');
  } finally {
    db.close();
  }
}

Directory? _resolveRoot(List<String> args) {
  for (var i = 0; i < args.length; i += 1) {
    if (args[i] == '--root' && i + 1 < args.length) {
      return Directory(args[i + 1]);
    }
  }

  final roaming = Platform.environment['APPDATA'];
  if (roaming != null && roaming.isNotEmpty) {
    final candidate = Directory(
      p.join(roaming, 'PageSage', 'PageSage', 'PageSageData'),
    );
    if (candidate.existsSync()) {
      return candidate;
    }
  }
  return null;
}
