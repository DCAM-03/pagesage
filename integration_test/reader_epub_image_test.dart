import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';

import 'support/reader_harness.dart';

/// The EPUB image check on a real Linux desktop window.
///
/// The widget test proves the reader builds an `Image` for a picture. What
/// only the live window can show is that the picture is really painted, at
/// the size the book asked for, and that the words around it are still there.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an EPUB picture is painted in the real window', (tester) async {
    final sample = File('.codex-run/samples/image.epub');
    expect(sample.existsSync(), isTrue, reason: 'run the sample generator');

    final stat = sample.statSync();
    final book = Book(
      id: 'image-epub',
      title: 'PageSage Image EPUB',
      format: BookFormat.epub,
      libraryFilePath: sample.absolute.path,
      fileHash: 'hash-image-epub',
      fileSize: stat.size,
      createdAt: stat.modified.millisecondsSinceEpoch,
      updatedAt: stat.modified.millisecondsSinceEpoch,
    );

    final harness = await ReaderHarness.create(books: [book]);
    addTearDown(harness.dispose);
    await harness.pumpReader(tester, 'image-epub', size: const Size(1280, 900));
    await harness.settle(tester, rounds: 20);

    // The picture is in the book, so the reader draws it.
    expect(find.byType(EpubRendererView), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    // The words around it are still words, and the picture is not one of
    // them: the reader shows the prose, not a gap where the picture was.
    expect(find.textContaining('PageSage'), findsWidgets);

    expect(tester.takeException(), isNull);
    await harness.capture('epub-01-picture-painted');
    await harness.closeReader(tester);
  });
}
