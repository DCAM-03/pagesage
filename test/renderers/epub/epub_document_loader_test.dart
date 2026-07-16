import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/epub/epub_document_loader.dart';

void main() {
  test('loads spine chapters from a minimal EPUB package', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_');
    addTearDown(() => tempDir.delete(recursive: true));

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
              <item id="chapter2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
            </manifest>
            <spine>
              <itemref idref="chapter1"/>
              <itemref idref="chapter2"/>
            </spine>
          </package>
          '''),
      )
      ..addFile(
        ArchiveFile.string(
          'OEBPS/chapter1.xhtml',
          '<html><head><title>One</title></head><body><h1>第一章</h1><p>正文一</p></body></html>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'OEBPS/chapter2.xhtml',
          '<html><head><title>Two</title></head><body><h1>第二章</h1><p>正文二</p></body></html>',
        ),
      );

    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);

    expect(document.chapters, hasLength(2));
    expect(document.chapters.first.title, '第一章');
    expect(document.chapters.first.text, contains('正文一'));
    expect(document.chapters.last.href, 'OEBPS/chapter2.xhtml');
    expect(document.progressForChapterIndex(0), 0);
    expect(document.progressForChapterIndex(1), greaterThan(0));
    expect(
      document.chapterForProgress(document.progressForChapterIndex(1)).index,
      1,
    );
  });

  test('loads hierarchical EPUB3 nav.xhtml table of contents', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_nav_');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = _baseArchive(
      manifestExtras:
          '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
      extraFiles: [
        ArchiveFile.string('OEBPS/nav.xhtml', '''
          <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <body>
              <nav epub:type="toc">
                <ol>
                  <li><a href="chapter1.xhtml">第一部分</a>
                    <ol><li><a href="chapter2.xhtml#s1">第二章小节</a></li></ol>
                  </li>
                </ol>
              </nav>
            </body>
          </html>
        '''),
      ],
    );
    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);

    expect(document.toc, hasLength(1));
    expect(document.toc.single.title, '第一部分');
    expect(document.toc.single.chapterIndex, 0);
    expect(document.toc.single.children.single.title, '第二章小节');
    expect(document.toc.single.children.single.chapterIndex, 1);
    expect(document.toc.single.children.single.fragment, 's1');
    expect(document.toc.single.children.single.chapterOffset, isNotNull);
    expect(
      document.progressForChapter(
        chapterIndex: 1,
        chapterOffset: document.toc.single.children.single.chapterOffset ?? 0,
      ),
      greaterThan(document.progressForChapterIndex(1)),
    );
  });

  test('resolves TOC href by basename and keeps empty spine items', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pagesage_epub_href_',
    );
    addTearDown(() => tempDir.delete(recursive: true));

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
              <item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>
              <item id="c1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
              <item id="c2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
              <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            </manifest>
            <spine>
              <itemref idref="cover"/>
              <itemref idref="c1"/>
              <itemref idref="c2"/>
            </spine>
          </package>
        '''),
      )
      ..addFile(
        ArchiveFile.string(
          'OEBPS/cover.xhtml',
          '<html><body><img alt="cover"/></body></html>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'OEBPS/Text/chapter1.xhtml',
          '<html><body><h1>第一章</h1><p>正文一</p></body></html>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'OEBPS/Text/chapter2.xhtml',
          '<html><body><p>前言</p><h1 id="part2">第二章</h1><p>正文二</p></body></html>',
        ),
      )
      ..addFile(
        ArchiveFile.string('OEBPS/nav.xhtml', '''
          <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
              <nav role="doc-toc">
                <ol>
                  <li><a href="cover.xhtml">封面</a></li>
                  <li><a href="chapter1.xhtml">第一章</a></li>
                  <li><a href="Text/chapter2.xhtml#part2">第二章</a></li>
                </ol>
              </nav>
            </body>
          </html>
        '''),
      );

    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    final document = await EpubDocumentLoader().load(file.path);

    expect(document.chapters, hasLength(3));
    expect(document.chapters.first.text.trim(), isEmpty);
    expect(document.toc.map((item) => item.title), ['封面', '第一章', '第二章']);
    expect(document.toc[0].chapterIndex, 0);
    expect(document.toc[1].chapterIndex, 1);
    expect(document.toc[2].chapterIndex, 2);
    expect(document.toc[2].fragment, 'part2');
    expect(document.toc[2].chapterOffset, isNotNull);
    expect(document.toc[2].chapterOffset, greaterThan(0));
  });

  test('loads NCX table of contents when nav document is absent', () async {
    final tempDir = await Directory.systemTemp.createTemp('pagesage_epub_ncx_');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = _baseArchive(
      manifestExtras:
          '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
      spineAttributes: 'toc="ncx"',
      extraFiles: [
        ArchiveFile.string('OEBPS/toc.ncx', '''
          <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
            <navMap>
              <navPoint id="n1"><navLabel><text>NCX 第一章</text></navLabel><content src="chapter1.xhtml"/></navPoint>
              <navPoint id="n2"><navLabel><text>NCX 第二章</text></navLabel><content src="chapter2.xhtml"/></navPoint>
            </navMap>
          </ncx>
        '''),
      ],
    );
    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final document = await EpubDocumentLoader().load(file.path);

    expect(document.toc.map((item) => item.title), ['NCX 第一章', 'NCX 第二章']);
    expect(document.toc.last.chapterIndex, 1);
  });

  test('falls back to chapter list when EPUB has no explicit TOC', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pagesage_epub_fallback_',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final file = File('${tempDir.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(_baseArchive()), flush: true);

    final document = await EpubDocumentLoader().load(file.path);

    expect(document.toc, hasLength(2));
    expect(document.toc.first.title, '第一章');
    expect(document.toc.last.chapterIndex, 1);
  });
}

Archive _baseArchive({
  String manifestExtras = '',
  String spineAttributes = '',
  List<ArchiveFile> extraFiles = const [],
}) {
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
            <item id="chapter2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
            $manifestExtras
          </manifest>
          <spine $spineAttributes>
            <itemref idref="chapter1"/>
            <itemref idref="chapter2"/>
          </spine>
        </package>
        '''),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/chapter1.xhtml',
        '<html><head><title>One</title></head><body><h1>第一章</h1><p>正文一</p></body></html>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/chapter2.xhtml',
        '<html><head><title>Two</title></head><body><p>前言</p><h1 id="s1">第二章</h1><p>正文二</p></body></html>',
      ),
    );
  for (final file in extraFiles) {
    archive.addFile(file);
  }
  return archive;
}
