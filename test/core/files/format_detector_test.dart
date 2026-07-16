import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/files/format_detector.dart';
import 'package:pagesage/domain/books/book.dart';

void main() {
  test('detects supported EPUB and PDF file extensions', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_format_');
    addTearDown(() => tempDir.delete(recursive: true));

    final epub = File('${tempDir.path}/book.epub');
    await epub.writeAsBytes(
      ZipEncoder().encode(
        Archive()
          ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip')),
      ),
    );
    final pdf = File('${tempDir.path}/book.pdf')..writeAsStringSync('%PDF-');

    final detector = FormatDetector();

    expect(await detector.detect(epub), BookFormat.epub);
    expect(await detector.detect(pdf), BookFormat.pdf);
  });

  test('rejects unsupported formats', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_format_');
    addTearDown(() => tempDir.delete(recursive: true));
    final mobi = File('${tempDir.path}/book.mobi')..writeAsStringSync('mobi');

    expect(
      () => FormatDetector().detect(mobi),
      throwsA(isA<UnsupportedBookFormatException>()),
    );
  });

  test('requires extension and header to agree', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_format_');
    addTearDown(() => tempDir.delete(recursive: true));
    final fakePdfExtension = File('${tempDir.path}/book.pdf')
      ..writeAsStringSync('not a pdf');
    final fakePdfHeader = File('${tempDir.path}/book.txt')
      ..writeAsStringSync('%PDF-');

    final detector = FormatDetector();

    expect(
      () => detector.detect(fakePdfExtension),
      throwsA(isA<UnsupportedBookFormatException>()),
    );
    expect(
      () => detector.detect(fakePdfHeader),
      throwsA(isA<UnsupportedBookFormatException>()),
    );
  });

  test('rejects mismatched MIME type when MIME is provided', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_format_');
    addTearDown(() => tempDir.delete(recursive: true));
    final pdf = File('${tempDir.path}/book.pdf')..writeAsStringSync('%PDF-');

    final detector = FormatDetector();

    expect(
      await detector.detect(pdf, mimeType: 'application/pdf'),
      BookFormat.pdf,
    );
    expect(
      () => detector.detect(pdf, mimeType: 'application/epub+zip'),
      throwsA(isA<UnsupportedBookFormatException>()),
    );
  });
}
