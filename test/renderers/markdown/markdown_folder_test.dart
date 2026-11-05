import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/markdown/markdown_document_loader.dart';
import 'package:pagesage/renderers/markdown/markdown_folder.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pagesage_md_folder_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  Directory folder(String name) =>
      Directory(p.join(root.path, name))..createSync(recursive: true);

  File note(Directory dir, String name, String body) {
    final file = File(p.join(dir.path, name))..writeAsStringSync(body);
    return file;
  }

  test('a folder reads as one book, in path order', () async {
    final dir = folder('notes');
    folder('notes/sub');
    note(dir, 'b-第二篇.md', '# 乙\n\n第二篇的正文。');
    note(dir, 'a-第一篇.md', '# 甲\n\n第一篇的正文。');
    note(folder('notes/sub'), 'c.md', '没有标题的一篇。');

    final document = await const MarkdownFolderLoader().load(dir.path);

    expect(document.chapters.map((chapter) => chapter.title), ['甲', '乙', 'c']);
    expect(document.chapters.first.text, contains('第一篇的正文'));
    expect(document.chapters[1].text, contains('第二篇的正文'));
    expect(document.chapters[2].title, 'c');

    // Each chapter remembers the file it came from, so a saved position can
    // name the note the reader was in.
    expect(document.chapters[0].href, 'a-第一篇.md');
    expect(document.chapters[1].href, 'b-第二篇.md');
    expect(document.chapters[2].href, 'sub/c.md');
  });

  test('hidden folders and dependency trees are not chapters', () async {
    final dir = folder('notes');
    folder('notes/.git');
    folder('notes/.obsidian');
    folder('notes/node_modules/pkg');
    note(dir, 'note.md', '# 正文\n\n只有这一篇是笔记。');
    note(folder('notes/.git'), 'HEAD.md', '# 版本库');
    note(folder('notes/.obsidian'), 'workspace.md', '# 编辑器配置');
    note(folder('notes/node_modules/pkg'), 'readme.md', '# 依赖');

    final document = await const MarkdownFolderLoader().load(dir.path);

    expect(document.chapters, hasLength(1));
    expect(document.chapters.single.title, '正文');
  });

  test('the table of contents keeps each file\'s chapters in place', () async {
    final dir = folder('notes');
    note(dir, '1.md', '# 一章\n\n正文一。\n\n## 小节\n\n正文二。');
    note(dir, '2.md', '# 二章\n\n正文三。');

    final document = await const MarkdownFolderLoader().load(dir.path);

    expect(document.toc.map((item) => item.title), ['一章', '二章']);
    expect(document.toc[0].chapterIndex, 0);
    expect(document.toc[0].children.single.title, '小节');
    expect(document.toc[0].children.single.chapterIndex, 0);
    // The second file's heading points at the version of the chapter that is
    // actually second in the book.
    expect(document.toc[1].chapterIndex, 1);
  });

  test('a picture is resolved beside the note that points at it', () async {
    final dir = folder('notes');
    final sub = folder('notes/pictures');
    note(dir, 'note.md', '# 图\n\n![一张图](pictures/pic.png)');
    File(p.join(sub.path, 'pic.png')).writeAsBytesSync(_pngHeader(8, 4));

    final document = await const MarkdownFolderLoader().load(dir.path);
    final image = document.chapters.single.blocks
        .whereType<EpubImageBlock>()
        .single
        .image;

    expect(image.isAvailable, isTrue);
    expect(image.pixelWidth, 8);
    expect(image.pixelHeight, 4);
  });

  test('an unreadable file is named at the end instead of vanishing', () async {
    final dir = folder('notes');
    note(dir, 'good.md', '# 好的一篇\n\n正文。');
    File(p.join(dir.path, 'bad.md')).writeAsBytesSync([0xff, 0xfe, 0x00, 0x01]);

    final document = await const MarkdownFolderLoader().load(dir.path);

    expect(document.chapters, hasLength(2));
    final last = document.chapters.last;
    expect(last.title, '无法读取的文件');
    expect(last.text, contains('bad.md'));
    // The text and its blocks agree about where the names are.
    for (final block in last.blocks.whereType<EpubTextBlock>()) {
      expect(
        last.text.substring(block.startOffset, block.endOffset),
        block.text,
      );
    }
  });

  test('an empty folder says why it cannot be opened', () async {
    final dir = folder('empty');
    note(dir, 'readme.txt', 'not markdown');
    await expectLater(
      const MarkdownFolderLoader().load(dir.path),
      throwsA(
        isA<MarkdownFolderException>().having(
          (error) => error.message,
          'message',
          contains('没有 Markdown 文件'),
        ),
      ),
    );
  });

  test('the reader\'s loader opens a directory as a folder book', () async {
    final dir = folder('notes');
    note(dir, 'one.md', '# 唯一一篇\n\n正文。');

    final document = await const MarkdownDocumentLoader().load(dir.path);

    expect(document.chapters.single.title, '唯一一篇');
  });

  test('a folder that moved is reported, not shown as an empty book', () async {
    await expectLater(
      const MarkdownDocumentLoader().load('/nowhere/does-not-exist'),
      throwsA(
        isA<MarkdownLoadException>().having(
          (error) => error.message,
          'message',
          contains('找不到'),
        ),
      ),
    );
  });
}

/// A PNG header with the given size; the parser reads only the header.
List<int> _pngHeader(int width, int height) {
  return <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, //
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
