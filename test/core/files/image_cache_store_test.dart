import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/image_cache_store.dart';
import 'package:pagesage/domain/annotations/image_anchor.dart';
import 'package:pagesage/domain/books/reading_position.dart';

void main() {
  late Directory tempDir;
  late CachedImageStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pagesage-image-cache-');
    store = CachedImageStore(appPaths: AppPaths(overrideRoot: tempDir));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  const anchor = PdfImageAnchor(
    page: 12,
    ordinal: 3,
    resourceName: 'Im1',
    rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
  );

  test('stores a picture under the book folder in the cache', () async {
    final file = await store.put(
      bookId: 'book-1',
      anchor: anchor,
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(file.path, contains('cache'));
    expect(file.path, contains('images'));
    expect(file.path, contains('book-1'));
    expect(await file.readAsBytes(), [1, 2, 3]);

    final read = await store.get(bookId: 'book-1', anchor: anchor);
    expect(read, isNotNull);
    expect(await read!.readAsBytes(), [1, 2, 3]);
  });

  test('the same picture keeps one file across boxes', () async {
    // The identity of an image is page + ordinal + resource name. A second
    // drag with a slightly different rectangle is the same picture, so it
    // must not leave a second near-identical file behind.
    final other = PdfImageAnchor(
      page: 12,
      ordinal: 3,
      resourceName: 'Im1',
      rect: ReaderRect(x: 0.11, y: 0.21, width: 0.3, height: 0.4),
    );

    final first = await store.put(
      bookId: 'book-1',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );
    final second = await store.put(
      bookId: 'book-1',
      anchor: other,
      bytes: Uint8List.fromList([2]),
    );

    expect(second.path, first.path);
    expect(await second.readAsBytes(), [2]);
  });

  test('different pictures get different files', () async {
    final other = PdfImageAnchor(
      page: 13,
      ordinal: 1,
      resourceName: 'Im2',
      rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
    );

    final first = await store.put(
      bookId: 'book-1',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );
    final second = await store.put(
      bookId: 'book-1',
      anchor: other,
      bytes: Uint8List.fromList([2]),
    );

    expect(second.path, isNot(first.path));
  });

  test('the file name is safe on any filesystem', () async {
    final awkward = EpubImageAnchor(
      href: '../章节/一 & 二?.xhtml',
      ordinal: 0,
      rect: ReaderRect(x: 0, y: 0, width: 1, height: 1),
    );

    final file = await store.put(
      bookId: 'book-1',
      anchor: awkward,
      bytes: Uint8List.fromList([1]),
    );

    final name = file.uri.pathSegments.last;
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('?')));
    expect(name, endsWith('.png'));
  });

  test('deleting one picture leaves the others alone', () async {
    final other = PdfImageAnchor(
      page: 13,
      ordinal: 1,
      resourceName: 'Im2',
      rect: ReaderRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
    );
    await store.put(
      bookId: 'book-1',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );
    await store.put(
      bookId: 'book-1',
      anchor: other,
      bytes: Uint8List.fromList([2]),
    );

    await store.delete(bookId: 'book-1', anchor: anchor);

    expect(await store.get(bookId: 'book-1', anchor: anchor), isNull);
    expect(await store.get(bookId: 'book-1', anchor: other), isNotNull);
  });

  test('deleting a book takes its whole folder', () async {
    await store.put(
      bookId: 'book-1',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );
    await store.put(
      bookId: 'book-2',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );

    await store.deleteBook('book-1');

    expect(await store.get(bookId: 'book-1', anchor: anchor), isNull);
    expect(await store.get(bookId: 'book-2', anchor: anchor), isNotNull);
  });

  test('clearing removes every cached picture', () async {
    await store.put(
      bookId: 'book-1',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );
    await store.put(
      bookId: 'book-2',
      anchor: anchor,
      bytes: Uint8List.fromList([1]),
    );

    await store.clear();

    expect(await store.get(bookId: 'book-1', anchor: anchor), isNull);
    expect(await store.get(bookId: 'book-2', anchor: anchor), isNull);
  });
}
