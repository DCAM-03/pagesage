import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../domain/annotations/image_anchor.dart';
import 'app_paths.dart';

/// Where a marked-up picture is kept on disk.
///
/// Pictures are cut out of the book's pages on demand and stored under the
/// app cache, never in the library and never next to the book file: the
/// original file is the reader's, and these are derived from it.
///
/// The file name is derived from the *identity* of the picture (page, ordinal,
/// resource name) rather than from the rectangle, so the same picture keeps
/// one file even if it is re-marked with a slightly different box. A rectangle
/// would make a second, near-identical file for every drag.
///
/// Not `final`: a widget test substitutes an in-memory store, because a real
/// write never settles inside the fake-async zone of `testWidgets`.
class CachedImageStore {
  const CachedImageStore({required this.appPaths});

  final AppPaths appPaths;

  /// The `images` folder inside the app cache.
  Future<Directory> rootDirectory() async {
    final cache = await appPaths.cacheDirectory();
    return Directory(p.join(cache.path, 'images'));
  }

  /// File name for one picture, without an extension.
  ///
  /// Exposed separately because the export writes the same name next to the
  /// Markdown file, and the two must agree or the relative links break.
  static String fileNameFor(ImageAnchor anchor) {
    final key = switch (anchor) {
      PdfImageAnchor() =>
        'p${anchor.page}_o${anchor.ordinal ?? 0}_${anchor.resourceName ?? 'x'}',
      EpubImageAnchor() => 'e${anchor.ordinal}_${_slug(anchor.href)}',
    };
    // A hash keeps the name filesystem-safe and short; the readable prefix
    // stays so a folder of these can still be browsed by eye.
    final digest = sha1.convert(utf8.encode(key)).toString().substring(0, 10);
    return '${_slug(key)}_$digest';
  }

  /// Where the picture for [anchor] lives under [bookId].
  Future<File> fileFor({
    required String bookId,
    required ImageAnchor anchor,
  }) async {
    final root = await rootDirectory();
    final dir = Directory(p.join(root.path, bookId));
    await dir.create(recursive: true);
    return File(p.join(dir.path, '${fileNameFor(anchor)}.png'));
  }

  /// Store [bytes] as the picture for [anchor], replacing an older copy.
  ///
  /// Written to a `.part` file first so a crash mid-write cannot leave a
  /// truncated PNG that looks like a valid picture later.
  Future<File> put({
    required String bookId,
    required ImageAnchor anchor,
    required Uint8List bytes,
  }) async {
    final file = await fileFor(bookId: bookId, anchor: anchor);
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
    return file;
  }

  /// The cached picture for [anchor], or null when it was never extracted.
  Future<File?> get({
    required String bookId,
    required ImageAnchor anchor,
  }) async {
    final file = await fileFor(bookId: bookId, anchor: anchor);
    if (!await file.exists()) {
      return null;
    }
    return file;
  }

  /// Drop every picture cached for one book.
  ///
  /// Called when the book is removed: the pictures are derived from a file
  /// the app no longer manages, so keeping them would be keeping garbage.
  Future<void> deleteBook(String bookId) async {
    final root = await rootDirectory();
    final dir = Directory(p.join(root.path, bookId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Drop the cached picture for one anchor, if there is one.
  Future<void> delete({
    required String bookId,
    required ImageAnchor anchor,
  }) async {
    final file = await fileFor(bookId: bookId, anchor: anchor);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Remove every cached picture of every book.
  Future<void> clear() async {
    final root = await rootDirectory();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  static String _slug(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (cleaned.isEmpty) return 'img';
    return cleaned.length <= 48 ? cleaned : cleaned.substring(0, 48);
  }
}
