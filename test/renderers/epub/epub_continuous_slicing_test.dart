import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/book_document_loader.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/epub/epub_renderer_view.dart';

void main() {
  testWidgets('a long chapter is laid out row by row, not in one frame', (
    tester,
  ) async {
    final paragraphs = <String>[
      for (var index = 0; index < 300; index += 1) '第$index段的正文。',
    ];
    final text = paragraphs.join('\n\n');
    final blocks = <EpubBlock>[];
    var offset = 0;
    for (final paragraph in paragraphs) {
      blocks.add(
        EpubTextBlock(
          startOffset: offset,
          endOffset: offset + paragraph.length,
          text: paragraph,
          type: EpubBlockType.paragraph,
        ),
      );
      offset += paragraph.length + 2;
    }
    final document = EpubDocument(
      chapters: [
        EpubChapter(
          index: 0,
          href: 'note.md',
          title: '笔记',
          text: text,
          blocks: blocks,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'long-note',
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
            documentLoader: _StubLoader(document),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // What is on screen is built; the rest of the chapter is not, even though
    // it belongs to the same chapter.
    expect(find.textContaining('第0段的正文'), findsOneWidget);
    expect(find.textContaining('第280段的正文'), findsNothing);

    // Scrolling reaches it, so nothing was dropped.
    await tester.scrollUntilVisible(
      find.textContaining('第280段的正文'),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 300,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('第280段的正文'), findsOneWidget);
  });

  testWidgets('a saved chapter opens in continuous mode, late rows included', (
    tester,
  ) async {
    // Three chapters of many paragraphs each: one chapter is many rows now,
    // so the saved chapter has to be found by its first row, not its index.
    final chapters = <EpubChapter>[];
    for (var chapter = 0; chapter < 3; chapter += 1) {
      final paragraphs = <String>[
        for (var index = 0; index < 20; index += 1) '第$chapter章第$index段。',
      ];
      final text = paragraphs.join('\n\n');
      final blocks = <EpubBlock>[];
      var offset = 0;
      for (final paragraph in paragraphs) {
        blocks.add(
          EpubTextBlock(
            startOffset: offset,
            endOffset: offset + paragraph.length,
            text: paragraph,
            type: EpubBlockType.paragraph,
          ),
        );
        offset += paragraph.length + 2;
      }
      chapters.add(
        EpubChapter(
          index: chapter,
          href: 'chapter$chapter.md',
          title: '第$chapter章',
          text: text,
          blocks: blocks,
        ),
      );
    }
    final document = EpubDocument(chapters: chapters);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubRendererView(
            book: Book(
              id: 'saved-note',
              title: '笔记',
              format: BookFormat.markdown,
              libraryFilePath: '/unused.md',
              fileHash: 'hash',
              fileSize: 1,
              createdAt: 0,
              updatedAt: 0,
            ),
            settings: const ReaderSettings(fontSize: 18, lineHeight: 1.7),
            initialProgress: ReadingProgressSnapshot(
              bookId: 'saved-note',
              locator: const ReadingLocator(
                type: ReadingLocatorType.markdown,
                chapterIndex: 2,
                chapterOffset: 0,
              ),
              progress: 0.9,
              updatedAt: 0,
            ),
            annotations: const [],
            onEvent: (_) {},
            documentLoader: _StubLoader(document),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('第2章第0段'), findsOneWidget);
    expect(find.textContaining('第0章第0段'), findsNothing);
  });
}

final class _StubLoader implements BookDocumentLoader {
  const _StubLoader(this.document);

  final EpubDocument document;

  @override
  Future<EpubDocument> load(String filePath) async => document;
}
