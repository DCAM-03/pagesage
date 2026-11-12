import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_document_loader.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';

void main() {
  testWidgets('a picture in a book is drawn, not dropped', (tester) async {
    // The book is built in the test's real async zone: a zip file cannot
    // be written from inside the fake-async zone of `testWidgets`.
    final loader = await tester.runAsync(
      () => _loaderFor(_archiveWithPicture()),
    );
    await _pumpReader(tester, loader: loader!);

    // The picture is in the book and in the reader.
    expect(find.byType(Image), findsOneWidget);
    // The words around it are there too.
    expect(find.textContaining('前文'), findsOneWidget);
    expect(find.textContaining('第二段'), findsOneWidget);
  });

  testWidgets('a picture that is not in the book says so', (tester) async {
    final loader = await tester.runAsync(
      () => _loaderFor(_archiveWithPicture(picturePath: 'images/gone.png')),
    );
    await _pumpReader(tester, loader: loader!);

    // A blank space would be a lie: the reader is told what is missing and
    // what the book said the picture was.
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('图片不在书中'), findsOneWidget);
    expect(find.textContaining('A picture'), findsOneWidget);
  });

  testWidgets('an available picture shows its alt caption once', (
    tester,
  ) async {
    final loader = await tester.runAsync(
      () => _loaderFor(_archiveWithPicture()),
    );
    await _pumpReader(tester, loader: loader!);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('A picture'), findsOneWidget);
    expect(find.text('图注文字。'), findsOneWidget);
  });
}

/// A loader that hands the renderer a document built outside the test's
/// fake-async zone.
Future<_StubLoader> _loaderFor(Archive archive) async {
  final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_ui_');
  final bookFile = File('${tempDir.path}/book.epub');
  await bookFile.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  final document = await EpubDocumentLoader().load(bookFile.path);
  return _StubLoader(document);
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required EpubDocumentLoader loader,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EpubRendererView(
          book: Book(
            id: 'book-1',
            title: '有图的一章',
            format: BookFormat.epub,
            libraryFilePath: '/unused.epub',
            fileHash: 'hash',
            fileSize: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
          settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
          initialProgress: null,
          annotations: const [],
          onEvent: (_) {},
          documentLoader: loader,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _StubLoader extends EpubDocumentLoader {
  const _StubLoader(this.document);

  final EpubDocument document;

  @override
  Future<EpubDocument> load(String filePath) async => document;
}

Archive _archiveWithPicture({String? picturePath}) {
  final src = picturePath ?? 'images/pic.png';
  return Archive()
    ..addFile(
      ArchiveFile.string('META-INF/container.xml', '''
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        '''),
    )
    ..addFile(
      ArchiveFile.string('OEBPS/content.opf', '''
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <manifest>
            <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
            <item id="pic" href="images/pic.png" media-type="image/png"/>
          </manifest>
          <spine>
            <itemref idref="chapter1"/>
          </spine>
        </package>
        '''),
    )
    ..addFile(
      ArchiveFile.string('OEBPS/chapter1.xhtml', '''
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>有图的一章</title></head>
          <body>
            <h1>有图的一章</h1>
            <p>前文。</p>
            <figure>
              <img src="$src" alt="A picture"/>
              <figcaption>图注文字。</figcaption>
            </figure>
            <p id="s1">第二段。</p>
          </body>
        </html>
        '''),
    )
    ..addFile(
      ArchiveFile.bytes(
        'OEBPS/images/pic.png',
        _pngBytes(width: 40, height: 20),
      ),
    );
}

/// A PNG with the given size, built so it decodes.
///
/// The picture is drawn by the test, so it has to be a real PNG and not
/// just a header: one grey row of pixels.
List<int> _pngBytes({required int width, required int height}) {
  final bytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    0x00, 0x00, 0x00, 0x0D, // IHDR length
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, colour, compression
  ];
  // The image data: a filter byte and one row of grey pixels, stored
  // (uncompressed) inside a zlib stream.
  final raw = <int>[0];
  for (var i = 0; i < width; i++) {
    raw.addAll([0x80, 0x80, 0x80]);
  }
  bytes.addAll(_chunk('IDAT', _zlibStore(raw)));
  bytes.addAll(_chunk('IEND', const []));
  return bytes;
}

/// Wraps [raw] in a zlib stream with no compression.
///
/// A PNG reader wants a zlib stream; the stored form is the simplest one
/// that a decoder accepts, and the test does not care about the size.
List<int> _zlibStore(List<int> raw) {
  final out = <int>[0x78, 0x01];
  var offset = 0;
  while (offset < raw.length) {
    final block = raw.sublist(
      offset,
      offset + 65535 > raw.length ? raw.length : offset + 65535,
    );
    final isLast = offset + block.length >= raw.length;
    out.add(isLast ? 1 : 0);
    out.add(block.length & 0xFF);
    out.add((block.length >> 8) & 0xFF);
    out.add((~block.length) & 0xFF);
    out.add(((~block.length) >> 8) & 0xFF);
    out.addAll(block);
    offset += block.length;
  }
  // The Adler-32 of the raw data.
  var a = 1;
  var b = 0;
  for (final byte in raw) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  final checksum = ((b << 16) | a) & 0xFFFFFFFF;
  out.addAll([
    (checksum >> 24) & 0xFF,
    (checksum >> 16) & 0xFF,
    (checksum >> 8) & 0xFF,
    checksum & 0xFF,
  ]);
  return out;
}

List<int> _chunk(String type, List<int> data) {
  final out = <int>[
    (data.length >> 24) & 0xFF,
    (data.length >> 16) & 0xFF,
    (data.length >> 8) & 0xFF,
    data.length & 0xFF,
  ];
  out.addAll(type.codeUnits);
  out.addAll(data);
  return out;
}
