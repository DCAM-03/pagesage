import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/features/reader/application/markdown_folder_refresh_coordinator.dart';
import 'package:pagesage/renderers/markdown/markdown_folder.dart';
import 'package:pagesage/renderers/markdown/markdown_folder_diff.dart';
import 'package:pagesage/renderers/markdown/markdown_folder_snapshot.dart';

void main() {
  late Directory root;

  setUp(() async {
    MarkdownFolderLoader.clearCache();
    root = await Directory.systemTemp.createTemp('pagesage_folder_refresh_');
    await File('${root.path}/a.md').writeAsString('# 甲\n\n正文。');
    await Directory('${root.path}/sub').create();
    await File('${root.path}/sub/b.md').writeAsString('# 乙\n\n正文。');
  });

  tearDown(() async {
    MarkdownFolderLoader.clearCache();
    await root.delete(recursive: true);
  });

  test(
    'metadata scan carries unchanged hashes and hashes changed files',
    () async {
      const loader = MarkdownFolderSnapshotLoader(MarkdownFolderLoader());
      final first = await loader.load(
        root.path,
        verification: MarkdownFolderVerification.full,
      );
      final before = first.contentHashes['a.md'];

      await File('${root.path}/a.md').writeAsString('# 甲\n\n外部修改。');
      final metadata = await loader.load(
        root.path,
        verification: MarkdownFolderVerification.metadata,
        previous: first,
      );
      final diff = MarkdownFolderDiff.compute(first, metadata);

      expect(
        metadata.contentHashes['sub/b.md'],
        first.contentHashes['sub/b.md'],
      );
      expect(metadata.contentHashes['a.md'], startsWith('metadata:'));
      expect(metadata.contentHashes['a.md'], isNot(before));
      expect(diff.involves('a.md'), isTrue);
    },
  );

  test('coordinator reports external edits on a full refresh', () async {
    final coordinator = MarkdownFolderRefreshCoordinator(
      rootPath: root.path,
      debounce: const Duration(seconds: 30),
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(coordinator.dispose);

    final first = await coordinator.start();
    expect(first.diff.isEmpty, isTrue);
    expect(first.state, MarkdownFolderRefreshState.ready);

    await File('${root.path}/a.md').writeAsString('# 甲\n\n外部修改。');
    final event = await coordinator.refresh(full: true);

    expect(event.diff.involves('a.md'), isTrue);
    expect(
      event.diff.changes.where((change) => change.path == 'a.md').single.kind,
      MarkdownFolderChangeKind.changed,
    );
  });

  test('coordinator reports removal without dropping the snapshot', () async {
    final coordinator = MarkdownFolderRefreshCoordinator(
      rootPath: root.path,
      debounce: const Duration(seconds: 30),
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();

    await File('${root.path}/a.md').delete();
    final event = await coordinator.refresh(full: true);

    expect(event.diff.involves('a.md'), isTrue);
    expect(event.snapshot.manifest.fileForHref('a.md'), isNull);
    expect(event.snapshot.manifest.fileForHref('sub/b.md'), isNotNull);
  });
}
