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
    MarkdownDocumentLoader.clearCache();
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

  test('a folder manifest keeps directories and files apart', () async {
    final dir = folder('notes');
    final sub = folder('notes/sub');
    final deep = folder('notes/sub/deep');
    note(dir, 'a.md', '# 甲\n\n第一篇。');
    note(sub, 'b.md', '# 乙\n\n第二篇。');
    note(deep, 'c.md', '没有标题的一篇。');

    final manifest = await const MarkdownFolderLoader().loadManifest(dir.path);

    expect(manifest.files.map((file) => file.relativePath), [
      'a.md',
      'sub/b.md',
      'sub/deep/c.md',
    ]);
    expect(manifest.roots.first, isA<MarkdownFolderDirectory>());
    final subNode = manifest.roots.first as MarkdownFolderDirectory;
    expect(subNode.name, 'sub');
    expect(subNode.children.first, isA<MarkdownFolderDirectory>());
    final deepNode = subNode.children.first as MarkdownFolderDirectory;
    expect(deepNode.name, 'deep');
    expect(deepNode.children.single, isA<MarkdownFolderDocument>());
    expect(
      (deepNode.children.single as MarkdownFolderDocument).file.relativePath,
      'sub/deep/c.md',
    );
    expect(
      manifest.roots.whereType<MarkdownFolderDocument>().single.name,
      'a.md',
    );
  });

  test('hidden folders and dependency trees are not in the manifest', () async {
    final dir = folder('notes');
    folder('notes/.git');
    folder('notes/.obsidian');
    folder('notes/node_modules/pkg');
    note(dir, 'note.md', '# 正文\n\n只有这一篇是笔记。');
    note(folder('notes/.git'), 'HEAD.md', '# 版本库');
    note(folder('notes/.obsidian'), 'workspace.md', '# 编辑器配置');
    note(folder('notes/node_modules/pkg'), 'readme.md', '# 依赖');

    final manifest = await const MarkdownFolderLoader().loadManifest(dir.path);

    expect(manifest.files.map((file) => file.relativePath), ['note.md']);
    expect(manifest.roots.single, isA<MarkdownFolderDocument>());
  });

  test('folder progress is shared across files', () async {
    final dir = folder('notes');
    final first = note(dir, 'a.md', '# 甲\n\n${'a' * 100}');
    final second = note(dir, 'b.md', '# 乙\n\n${'b' * 40}');
    final firstSize = first.lengthSync();
    final secondSize = second.lengthSync();
    final total = firstSize + secondSize;

    final manifest = await const MarkdownFolderLoader().loadManifest(dir.path);

    expect(manifest.progressForFile('a.md', 0), 0);
    expect(
      manifest.progressForFile('a.md', 1),
      closeTo(firstSize / total, 0.000001),
    );
    expect(
      manifest.progressForFile('b.md', 0),
      closeTo(firstSize / total, 0.000001),
    );
    expect(
      manifest.localProgressForFile(
        'b.md',
        manifest.progressForFile('b.md', 0.5),
      ),
      closeTo(0.5, 0.000001),
    );
    expect(manifest.fileAtProgress(0.99)?.relativePath, 'b.md');
  });

  test('a folder file outline only names its own headings', () async {
    final dir = folder('notes');
    final first = note(dir, 'a.md', '# 甲章\n\n## 甲小节\n\n正文。');
    final second = note(dir, 'b.md', '# 乙章\n\n## 乙小节\n\n正文。');

    final a = await const MarkdownDocumentLoader().loadWithHref(
      first.path,
      'a.md',
    );
    final b = await const MarkdownDocumentLoader().loadWithHref(
      second.path,
      'b.md',
    );

    expect(a.toc.map((item) => item.title), ['甲章']);
    expect(a.toc.single.children.map((item) => item.title), ['甲小节']);
    expect(b.toc.map((item) => item.title), ['乙章']);
    expect(b.toc.single.children.map((item) => item.title), ['乙小节']);
    expect(a.chapters.every((chapter) => chapter.href == 'a.md'), isTrue);
    expect(b.chapters.every((chapter) => chapter.href == 'b.md'), isTrue);
  });

  test('a picture is resolved beside the note that points at it', () async {
    final dir = folder('notes');
    final sub = folder('notes/pictures');
    final file = note(dir, 'note.md', '# 图\n\n![一张图](pictures/pic.png)');
    File(p.join(sub.path, 'pic.png')).writeAsBytesSync(_pngHeader(8, 4));

    final document = await const MarkdownDocumentLoader().loadWithHref(
      file.path,
      'note.md',
    );
    final image = document.chapters.single.blocks
        .whereType<EpubImageBlock>()
        .single
        .image;

    expect(image.isAvailable, isTrue);
    expect(image.pixelWidth, 8);
    expect(image.pixelHeight, 4);
  });

  test('a legacy merged position maps to a file-local position', () async {
    final dir = folder('notes');
    note(dir, '1.md', '# 一章\n\n正文一。\n\n# 二章\n\n正文二。');
    note(dir, '2.md', '# 三章\n\n正文三。');

    final legacy = await const MarkdownFolderLoader().loadLegacyDocument(
      dir.path,
    );
    expect(legacy.chapters.map((chapter) => chapter.href), [
      '1.md',
      '1.md',
      '2.md',
    ]);

    final resolved = await const MarkdownFolderLoader().resolveLegacyPosition(
      dir.path,
      2,
    );

    expect(resolved?.relativePath, '2.md');
    expect(resolved?.chapterIndex, 0);
  });

  test('an empty folder says why it cannot be opened', () async {
    final dir = folder('empty');
    note(dir, 'readme.txt', 'not markdown');
    await expectLater(
      const MarkdownFolderLoader().loadManifest(dir.path),
      throwsA(
        isA<MarkdownFolderException>().having(
          (error) => error.message,
          'message',
          contains('没有 Markdown 文件'),
        ),
      ),
    );
  });

  test('the document loader refuses to merge a folder', () async {
    final dir = folder('notes');
    note(dir, 'one.md', '# 唯一一篇\n\n正文。');

    await expectLater(
      const MarkdownDocumentLoader().load(dir.path),
      throwsA(
        isA<MarkdownLoadException>().having(
          (error) => error.message,
          'message',
          contains('先选择一个 Markdown 文件'),
        ),
      ),
    );
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

  test('a folder over the byte budget is refused before parsing', () async {
    final dir = folder('too-large');
    final file = File(p.join(dir.path, 'huge.md'));
    final handle = file.openSync(mode: FileMode.write);
    handle.truncateSync(markdownFolderMaxBytes + 1);
    handle.closeSync();

    await expectLater(
      const MarkdownFolderLoader().loadManifest(dir.path),
      throwsA(
        isA<MarkdownFolderException>().having(
          (error) => error.message,
          'message',
          contains('64 MB'),
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
