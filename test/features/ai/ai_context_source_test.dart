import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/ai/application/ai_context_range.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/features/ai/application/ai_context_source.dart';

/// Writes a two-chapter EPUB into [dir] and returns its path.
Future<String> _writeEpub(Directory dir) async {
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
        '<html><head><title>第一章</title></head>'
            '<body><h1>第一章</h1><p>第一段正文</p><p>第二段正文</p></body></html>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/chapter2.xhtml',
        '<html><head><title>第二章</title></head>'
            '<body><h1>第二章</h1><p>另一章正文</p></body></html>',
      ),
    );

  final file = File('${dir.path}/book.epub');
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file.path;
}

void main() {
  const source = AiContextSource();

  test('selected text needs no book read', () async {
    final loaded = await source.load(
      range: AiContextRange.selectedText,
      bookPath: '/does/not/exist.epub',
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter1.xhtml',
        chapterIndex: 0,
        chapterOffset: 0,
        progress: 0,
      ),
      format: BookFormat.epub,
    );

    expect(loaded, isNull);
  });

  test('reads the chapter the locator points at', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_ai_ctx_');
    addTearDown(() => dir.delete(recursive: true));
    final path = await _writeEpub(dir);

    final loaded = await source.load(
      range: AiContextRange.currentChapter,
      bookPath: path,
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter2.xhtml',
        chapterIndex: 1,
        chapterOffset: 0,
        progress: 1,
      ),
      format: BookFormat.epub,
    );

    expect(loaded, isNotNull);
    expect(loaded!.title, '第二章');
    expect(loaded.text, contains('另一章正文'));
    expect(loaded.text, isNot(contains('第一段正文')));
    expect(loaded.locator?.chapterIndex, 1);
  });

  test('an out-of-range chapter index clamps to the last chapter', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_ai_ctx_');
    addTearDown(() => dir.delete(recursive: true));
    final path = await _writeEpub(dir);

    final loaded = await source.load(
      range: AiContextRange.currentChapter,
      bookPath: path,
      locator: ReadingLocator.epub(
        href: 'OEBPS/chapter2.xhtml',
        chapterIndex: 99,
        chapterOffset: 0,
        progress: 1,
      ),
      format: BookFormat.epub,
    );

    expect(loaded?.title, '第二章');
  });

  test('a missing book file reports the book, not an empty page', () async {
    // The two are different messages to the reader: a missing file means
    // something is wrong with the library, an empty page means a scan.
    await expectLater(
      source.load(
        range: AiContextRange.currentChapter,
        bookPath: '/does/not/exist.epub',
        locator: ReadingLocator.epub(
          href: 'OEBPS/chapter1.xhtml',
          chapterIndex: 0,
          chapterOffset: 0,
          progress: 0,
        ),
        format: BookFormat.epub,
      ),
      throwsA(isA<BookUnreadableException>()),
    );
  });

  test('a missing PDF file reports the book, not an empty page', () async {
    await expectLater(
      source.load(
        range: AiContextRange.currentPage,
        bookPath: '/does/not/exist.pdf',
        locator: ReadingLocator.pdf(page: 1),
        format: BookFormat.pdf,
      ),
      throwsA(isA<BookUnreadableException>()),
    );
  });

  test('reads one PDF page of real text', () async {
    final file = File('poc_pdf_canvas/samples/chinese-embedded.pdf');
    if (!file.existsSync()) {
      markTestSkipped('sample PDF not present');
      return;
    }

    final loaded = await source.load(
      range: AiContextRange.currentPage,
      bookPath: file.path,
      locator: ReadingLocator.pdf(page: 1),
      format: BookFormat.pdf,
    );

    expect(loaded, isNotNull);
    expect(loaded!.title, '第 1 页');
    expect(loaded.text.trim(), isNotEmpty);
    expect(loaded.locator?.page, 1);
  });

  test('a PDF page past the end yields no source', () async {
    final file = File('poc_pdf_canvas/samples/chinese-embedded.pdf');
    if (!file.existsSync()) {
      markTestSkipped('sample PDF not present');
      return;
    }

    final loaded = await source.load(
      range: AiContextRange.currentPage,
      bookPath: file.path,
      locator: ReadingLocator.pdf(page: 9999),
      format: BookFormat.pdf,
    );

    expect(loaded, isNull);
  });

  test('a PDF locator without a page yields no source', () async {
    final loaded = await source.load(
      range: AiContextRange.currentPage,
      bookPath: 'poc_pdf_canvas/samples/chinese-embedded.pdf',
      locator: null,
      format: BookFormat.pdf,
    );

    expect(loaded, isNull);
  });

  test('a folder chapter is read from its own file', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_ai_folder_');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/a.md').writeAsString('# 甲\n\n甲篇正文。');
    final sub = Directory('${dir.path}/sub')..createSync();
    await File('${sub.path}/b.md').writeAsString('# 乙\n\n乙篇正文。');

    final loaded = await source.load(
      range: AiContextRange.currentChapter,
      bookPath: dir.path,
      locator: ReadingLocator.markdown(
        href: 'sub/b.md',
        chapterIndex: 0,
        chapterOffset: 0,
        progress: 0.8,
        folderFileLocal: true,
      ),
      format: BookFormat.markdown,
    );

    expect(loaded, isNotNull);
    expect(loaded!.title, contains('乙'));
    expect(loaded.text, contains('乙篇正文'));
    expect(loaded.text, isNot(contains('甲篇正文')));
    expect(loaded.locator?.href, 'sub/b.md');
    expect(loaded.locator?.folderFileLocal, isTrue);
    expect(loaded.locator?.progress, greaterThan(0));
  });
}
