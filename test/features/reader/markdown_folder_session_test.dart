import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/reader/application/markdown_folder_session.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/markdown/markdown_folder.dart';
import 'package:pagesage/renderers/markdown/markdown_folder_diff.dart';

void main() {
  late Directory root;
  late Book book;

  setUp(() async {
    MarkdownFolderLoader.clearCache();
    root = await Directory.systemTemp.createTemp('pagesage_folder_session_');
    await File('${root.path}/a.md').writeAsString('# 甲章\n\n甲篇正文。');
    await Directory('${root.path}/sub').create();
    await File('${root.path}/sub/b.md').writeAsString('# 乙章\n\n乙篇正文。');
    book = Book(
      id: 'folder-session',
      title: '笔记库',
      format: BookFormat.markdown,
      libraryFilePath: root.path,
      fileHash: 'hash',
      fileSize: 1,
      createdAt: 0,
      updatedAt: 0,
    );
  });

  tearDown(() async {
    MarkdownFolderLoader.clearCache();
    await root.delete(recursive: true);
  });

  test('a saved file opens with its own outline coordinates', () async {
    final controller = MarkdownFolderSessionController();
    final session = await controller.load(
      book: book,
      initialLocator: ReadingLocator.markdown(
        href: 'sub/b.md',
        chapterIndex: 1,
        chapterOffset: 6,
        progress: 0.75,
        folderFileLocal: true,
      ),
    );

    expect(session.activeFile.relativePath, 'sub/b.md');
    expect(session.initialLocator?.href, 'sub/b.md');
    expect(session.initialLocator?.chapterIndex, 1);
    expect(session.initialLocator?.chapterOffset, 6);
    expect(
      controller.activeFile?.absolutePath,
      p.join(root.path, 'sub', 'b.md'),
    );
  });

  test('switching a file keeps a jump on its requested file', () async {
    final controller = MarkdownFolderSessionController();
    await controller.load(book: book, initialLocator: null);
    final target = controller.manifest!.fileForHref('sub/b.md')!;
    final locator = ReadingLocator.markdown(
      href: 'sub/b.md',
      chapterIndex: 2,
      chapterOffset: 12,
      progress: 0.6,
      folderFileLocal: true,
    );

    expect(controller.switchesFile(locator), isTrue);
    final selected = controller.selectFile(target, locator: locator);

    expect(controller.activeFile?.relativePath, 'sub/b.md');
    expect(selected.href, 'sub/b.md');
    expect(selected.chapterIndex, 2);
    expect(selected.chapterOffset, 12);
    expect(selected.folderFileLocal, isTrue);
  });

  test('folder progress becomes local progress for the renderer', () async {
    final controller = MarkdownFolderSessionController();
    await controller.load(
      book: book,
      initialLocator: ReadingLocator.markdown(
        href: 'sub/b.md',
        progress: 0.75,
        folderFileLocal: true,
      ),
    );
    final snapshot = ReadingProgressSnapshot(
      bookId: book.id,
      locator: ReadingLocator.markdown(
        href: 'sub/b.md',
        progress: 0.75,
        folderFileLocal: true,
      ),
      progress: 0.75,
      updatedAt: 123,
    );

    final rendererProgress = controller.rendererProgress(
      bookId: book.id,
      snapshot: snapshot,
      jumpProgress: null,
    )!;

    expect(rendererProgress.locator.href, 'sub/b.md');
    expect(rendererProgress.locator.folderFileLocal, isTrue);
    expect(rendererProgress.progress, isNot(0.75));
    expect(
      controller.manifest!.progressForFile(
        'sub/b.md',
        rendererProgress.progress,
      ),
      closeTo(0.75, 0.0001),
    );
  });

  test('renderer locations become folder-wide locations', () async {
    final controller = MarkdownFolderSessionController();
    await controller.load(book: book, initialLocator: null);
    final local = ReadingLocator.markdown(
      href: 'sub/b.md',
      chapterIndex: 0,
      chapterOffset: 4,
      progress: 0.5,
    );

    final normalized =
        controller.normalizeEvent(
              RendererLocationChanged(locator: local, progress: local.progress),
            )
            as RendererLocationChanged;

    expect(normalized.locator.href, 'sub/b.md');
    expect(normalized.locator.folderFileLocal, isTrue);
    expect(normalized.locator.chapterOffset, 4);
    expect(
      normalized.locator.progress,
      controller.manifest!.progressForFile('sub/b.md', 0.5),
    );
  });

  test('a legacy merged chapter maps back to a file', () async {
    final controller = MarkdownFolderSessionController();
    final session = await controller.load(
      book: book,
      initialLocator: ReadingLocator.markdown(
        chapterIndex: 1,
        chapterOffset: 3,
        progress: 0.8,
      ),
    );

    expect(session.activeFile.relativePath, 'sub/b.md');
    expect(session.initialLocator?.href, 'sub/b.md');
    expect(session.initialLocator?.chapterIndex, 0);
    expect(session.initialLocator?.chapterOffset, 3);
    expect(session.initialLocator?.folderFileLocal, isTrue);
  });

  test('loading the same book reuses its active session', () async {
    final controller = MarkdownFolderSessionController();
    final first = controller.load(book: book, initialLocator: null);
    final second = controller.load(
      book: book,
      initialLocator: ReadingLocator.markdown(href: 'sub/b.md'),
    );

    expect(identical(first, second), isTrue);
    await second;
    expect(controller.activeFile?.relativePath, 'a.md');
  });

  test('an older book load does not replace the current session', () async {
    final nextRoot = await Directory.systemTemp.createTemp(
      'pagesage_folder_session_next_',
    );
    addTearDown(() => nextRoot.delete(recursive: true));
    await File('${nextRoot.path}/only.md').writeAsString('# Only\n\n内容。');
    final nextBook = Book(
      id: 'folder-session-next',
      title: '另一笔记库',
      format: BookFormat.markdown,
      libraryFilePath: nextRoot.path,
      fileHash: 'hash-next',
      fileSize: 1,
      createdAt: 0,
      updatedAt: 0,
    );
    final gate = Completer<void>();
    final slowFirst = _SlowManifestLoader(
      delegate: const MarkdownFolderLoader(),
      gate: gate.future,
    );
    final slowController = MarkdownFolderSessionController(source: slowFirst);
    final stale = slowController.load(book: book, initialLocator: null);
    final current = MarkdownFolderSessionController(source: slowFirst);
    final next = current.load(book: nextBook, initialLocator: null);
    gate.complete();
    final nextSession = await next;
    await stale;

    expect(slowController.activeFile?.relativePath, 'a.md');
    expect(nextSession.activeFile.relativePath, 'only.md');
    expect(current.activeFile?.relativePath, 'only.md');
  });

  test(
    'removing the active file keeps its last view and reports a notice',
    () async {
      final controller = MarkdownFolderSessionController();
      await controller.load(book: book, initialLocator: null);
      final manifest = controller.manifest!;

      controller.replaceManifest(
        MarkdownFolderManifest(
          rootPath: manifest.rootPath,
          files: manifest.files
              .where((file) => file.relativePath != 'a.md')
              .toList(growable: false),
          roots: const [],
          totalBytes: manifest.totalBytes,
        ),
      );

      expect(controller.activeFile?.relativePath, 'a.md');
      expect(controller.folderNotice, contains('移除'));
    },
  );

  test('restoring the removed file clears the notice', () async {
    final controller = MarkdownFolderSessionController();
    await controller.load(book: book, initialLocator: null);
    final manifest = controller.manifest!;
    controller.replaceManifest(
      MarkdownFolderManifest(
        rootPath: manifest.rootPath,
        files: manifest.files
            .where((file) => file.relativePath != 'a.md')
            .toList(growable: false),
        roots: const [],
        totalBytes: manifest.totalBytes,
      ),
    );

    controller.replaceManifest(manifest);

    expect(controller.activeFile?.relativePath, 'a.md');
    expect(controller.folderNotice, isNull);
  });

  test('folder session reanchors a changed active file', () async {
    final controller = MarkdownFolderSessionController();
    await controller.load(book: book, initialLocator: null);

    final result = controller.reanchor(
      ReadingLocator.markdown(
        href: 'a.md',
        chapterOffset: 2,
        chapterEndOffset: 6,
        progress: 0.2,
        folderFileLocal: true,
      ),
      oldText: '开头重点结尾',
      newText: '新增开头重点结尾',
    );

    expect(result.precision, ReadingAnchorPrecision.reanchored);
    expect(result.locator.chapterOffset, 4);
  });
}

final class _SlowManifestLoader implements MarkdownFolderSource {
  const _SlowManifestLoader({required this.delegate, required this.gate});

  final MarkdownFolderLoader delegate;
  final Future<void> gate;

  @override
  Future<MarkdownFolderManifest> loadManifest(String folderPath) async {
    await gate;
    return delegate.loadManifest(folderPath);
  }

  @override
  Future<({String relativePath, int chapterIndex})?> resolveLegacyPosition(
    String folderPath,
    int legacyChapterIndex,
  ) {
    return delegate.resolveLegacyPosition(folderPath, legacyChapterIndex);
  }
}
