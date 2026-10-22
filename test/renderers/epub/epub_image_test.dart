import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_document_loader.dart';

void main() {
  test('a picture is read out of the book and put in the flow', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_img_');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = _archiveWithPicture();
    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);
    final chapter = document.chapters.single;

    final images = chapter.blocks.whereType<EpubImageBlock>().toList();
    expect(images, hasLength(1));
    final image = images.single.image;
    expect(image.archivePath, 'OEBPS/images/pic.png');
    expect(image.isAvailable, isTrue);
    expect(image.bytes, isNotEmpty);
    expect(image.pixelWidth, 120);
    expect(image.pixelHeight, 60);
    expect(image.alt, 'A picture');

    // The picture sits between the two paragraphs, and takes no characters.
    final before = chapter.text.substring(0, images.single.startOffset);
    final after = chapter.text.substring(images.single.endOffset);
    expect(before, contains('前文'));
    expect(after, contains('第二段'));
  });

  test('the chapter text is only its words, and every offset agrees', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_off_');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = _archiveWithPicture();
    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);
    final chapter = document.chapters.single;

    // Every text block is exactly the words at its own offsets: a jump
    // that lands on the wrong word is worse than no jump.
    for (final block in chapter.blocks.whereType<EpubTextBlock>()) {
      expect(
        chapter.text.substring(block.startOffset, block.endOffset),
        block.text,
      );
    }
    // And the text is the blocks, separated by blank lines.
    final joined = chapter.blocks
        .whereType<EpubTextBlock>()
        .map((block) => block.text)
        .join('\n\n');
    expect(chapter.text, joined);
    // The picture is not in the text at all.
    expect(chapter.text, isNot(contains('pic.png')));
  });

  test(
    'a missing picture becomes a readable placeholder, not a blank',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pagesage_epub_miss_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final archive = _archiveWithPicture(picturePath: 'OEBPS/images/gone.png');
      final file = File('${tempDir.path}/book.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

      final document = await EpubDocumentLoader().load(file.path);
      final image = document.chapters.single.blocks
          .whereType<EpubImageBlock>()
          .single
          .image;

      expect(image.isAvailable, isFalse);
      expect(image.unavailableReason, isNotNull);
      expect(image.unavailableReason, isNotEmpty);
      // The book's own description survives, so the reader learns what the
      // picture was.
      expect(image.alt, 'A picture');
    },
  );

  test('a remote picture is not fetched', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_net_');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = _archiveWithPicture(
      picturePath: 'https://example.com/remote.png',
    );
    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);
    final image = document.chapters.single.blocks
        .whereType<EpubImageBlock>()
        .single
        .image;

    expect(image.isAvailable, isFalse);
    expect(image.unavailableReason, contains('远程'));
  });

  test('a caption is its own block, quieter than the prose', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_cap_');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = _archiveWithPicture();
    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);
    final types = document.chapters.single.blocks
        .whereType<EpubTextBlock>()
        .map((block) => block.type)
        .toList();

    expect(types, contains(EpubBlockType.caption));
    expect(types, contains(EpubBlockType.paragraph));
  });

  test(
    'an element with an id is remembered at the offset of its text',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pagesage_epub_anc_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final archive = _archiveWithPicture();
      final file = File('${tempDir.path}/book.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

      final document = await EpubDocumentLoader().load(file.path);
      final chapter = document.chapters.single;

      final offset = chapter.anchors['s1'];
      expect(offset, isNotNull);
      expect(chapter.text.substring(offset!), contains('第二段'));
    },
  );
}

/// A one-chapter book with a picture, a caption and an anchored paragraph.
///
/// [picturePath] is the path the markup points at, so a test can make the
/// picture point somewhere that is not in the book.
Archive _archiveWithPicture({String? picturePath}) {
  final src = picturePath ?? 'images/pic.png';
  final archive = Archive()
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
        _pngBytes(width: 120, height: 60),
      ),
    );
  return archive;
}

/// A PNG header with the given size.
///
/// The pixels do not matter: the loader reads the size out of the header
/// and the test never decodes the picture.
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
    0x08, 0x06, 0x00, 0x00, 0x00, // bit depth, colour, compression
  ];
  return bytes;
}
