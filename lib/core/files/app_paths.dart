import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/books/book.dart';

final class AppPaths {
  AppPaths({this.overrideRoot});

  /// When set, all data paths resolve under this directory (tests).
  final Directory? overrideRoot;

  Future<Directory> dataRoot() async {
    final override = overrideRoot;
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory(p.join(supportDir.path, 'PageSageData'));
    await root.create(recursive: true);
    return root;
  }

  Future<File> databaseFile() async {
    final root = await dataRoot();
    return File(p.join(root.path, 'database', 'pagesage.sqlite'));
  }

  Future<Directory> libraryBooksDirectoryForHash(String fileHash) async {
    final root = await dataRoot();
    final first = fileHash.substring(0, 2);
    final second = fileHash.substring(0, 4);
    final dir = Directory(p.join(root.path, 'library', 'books', first, second));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> libraryDirectory() async {
    final root = await dataRoot();
    return Directory(p.join(root.path, 'library'));
  }

  Future<Directory> coversDirectory() async {
    final root = await dataRoot();
    final dir = Directory(p.join(root.path, 'library', 'covers'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> coverPath({
    required String bookId,
    required String extension,
  }) async {
    final dir = await coversDirectory();
    final normalized = extension.replaceFirst('.', '').toLowerCase();
    return p.join(
      dir.path,
      '$bookId.${normalized.isEmpty ? 'img' : normalized}',
    );
  }

  Future<Directory> cacheDirectory() async {
    final root = await dataRoot();
    return Directory(p.join(root.path, 'cache'));
  }

  /// Extracted pictures for one book.
  ///
  /// These are derived data: every one of them can be rebuilt from the book
  /// by cropping the page again, so they live under the cache and never in
  /// the library. A book that is removed takes its folder with it.
  Future<Directory> imagesCacheDirectoryForBook(String bookId) async {
    final root = await cacheDirectory();
    final dir = Directory(p.join(root.path, 'images', bookId));
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> libraryBookPath({
    required String bookId,
    required String fileHash,
    required BookFormat format,
  }) async {
    final dir = await libraryBooksDirectoryForHash(fileHash);
    return p.join(dir.path, '$bookId.${format.value}');
  }

  Future<Directory> exportsDirectory() async {
    final root = await dataRoot();
    final dir = Directory(p.join(root.path, 'exports'));
    await dir.create(recursive: true);
    return dir;
  }
}
