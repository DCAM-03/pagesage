import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/common/book_document_loader.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';
import 'package:pagesage/renderers/markdown/markdown_document_loader.dart';

void main() {
  testWidgets('a Markdown book is laid out as prose, not as markup', (
    tester,
  ) async {
    // The file is read in the test's real async zone: file I/O triggered from
    // inside the fake-async zone of `testWidgets` never settles.
    final document = await tester.runAsync(_loadDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-1',
              title: '笔记',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The reader shows the words.
    expect(find.textContaining('正文第一段'), findsWidgets);
    expect(find.textContaining('列表项'), findsWidgets);
    // And not the markup that produced them.
    expect(find.textContaining('# '), findsNothing);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('a folder of notes opens as one book', (tester) async {
    final document = await tester.runAsync(_loadFolderDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'notes-folder',
              title: '笔记库',
              format: BookFormat.markdown,
              libraryFilePath: '/unused-folder',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('第一篇的正文'), findsWidgets);
    expect(find.textContaining('# '), findsNothing);
  });

  testWidgets('a picture in a note is drawn from the file, not from memory', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadPictureDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-picture',
              title: '笔记',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image).first);
    // The document carries the picture's path, not its bytes: a folder of
    // notes with screenshots would otherwise hold every screenshot in memory.
    final resized = image.image as ResizeImage;
    expect((resized.imageProvider as FileImage).file.path, endsWith('pic.png'));
    // And it is decoded at the size the page shows, not at the file's own.
    expect(resized.width, isNotNull);
  });

  testWidgets('a table is drawn as a table, not as lines of pipes', (
    tester,
  ) async {
    final document = await tester.runAsync(_loadTableDocument);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'note-table',
              title: '表格',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: null,
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('苹果'), findsOneWidget);
    // The markup that made the table is not on the page.
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('---'), findsNothing);
  });
}

/// A note with one table in it.
Future<EpubDocument> _loadTableDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_table_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/note.md').writeAsString('''
# 表格

| 名称 | 数量 |
| --- | --- |
| 苹果 | 3 |
| 香蕉 | 12 |
''');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

/// A note with one picture beside it.

/// A note with one picture beside it.
Future<EpubDocument> _loadPictureDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_pic_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/pic.png').writeAsBytes(_pngBytes(32, 16));
  await File('${dir.path}/note.md').writeAsString('# 图\n\n![一张图](pic.png)');
  return const MarkdownDocumentLoader().load('${dir.path}/note.md');
}

List<int> _pngBytes(int width, int height) {
  return <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52,
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    0x08, 0x02, 0x00, 0x00, 0x00,
  ];
}

/// Builds a small folder of notes and opens it the way the app does.
Future<EpubDocument> _loadFolderDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_folder_ui_');
  addTearDown(() => dir.delete(recursive: true));
  await File('${dir.path}/a.md').writeAsString('# 第一篇\n\n第一篇的正文。');
  await File('${dir.path}/b.md').writeAsString('# 第二篇\n\n第二篇的正文。');
  return const MarkdownDocumentLoader().load(dir.path);
}

/// Builds a small Markdown book on disk and opens it the way the app does.
Future<EpubDocument> _loadDocument() async {
  final dir = await Directory.systemTemp.createTemp('pagesage_md_ui_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/note.md');
  await file.writeAsString('''
# 笔记

正文第一段，带**强调**。

- 列表项一
- 列表项二
''');
  return const MarkdownDocumentLoader().load(file.path);
}

/// Hands the renderer a document built outside the fake-async zone.
final class _StubLoader implements BookDocumentLoader {
  const _StubLoader(this.document);

  final EpubDocument document;

  @override
  Future<EpubDocument> load(String filePath) async => document;
}
