import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/markdown/markdown_folder.dart';
import 'package:pagesage/renderers/markdown/markdown_folder_diff.dart';

void main() {
  test('diff reports added, removed, renamed, and changed files', () {
    final previous = _snapshot({
      'old.md': 'hash-old',
      'keep.md': 'hash-keep',
      'edit.md': 'hash-before',
    });
    final current = _snapshot({
      'new.md': 'hash-new',
      'renamed.md': 'hash-old',
      'keep.md': 'hash-keep',
      'edit.md': 'hash-after',
    });

    final diff = MarkdownFolderDiff.compute(
      previous,
      current,
      moveHints: {'old.md': 'renamed.md'},
    );

    expect(diff.renameHints, {'old.md': 'renamed.md'});
    expect(diff.involves('renamed.md'), isTrue);
    expect(diff.involves('old.md'), isTrue);
    expect(
      diff.changes.map((change) => '${change.kind.name}:${change.path}'),
      containsAll(['renamed:renamed.md', 'added:new.md', 'changed:edit.md']),
    );
    expect(
      diff.changes.where(
        (change) => change.kind == MarkdownFolderChangeKind.removed,
      ),
      isEmpty,
    );
  });

  test('metadata placeholder swap is not reported as content change', () {
    final previous = MarkdownFolderSnapshot(
      manifest: _manifest(['edit.md']),
      contentHashes: const {'edit.md': 'metadata:10:1'},
      metadataRevisions: const {'edit.md': '10:1'},
      observedAt: 1,
    );
    final current = MarkdownFolderSnapshot(
      manifest: _manifest(['edit.md']),
      contentHashes: const {'edit.md': 'sha-edit'},
      metadataRevisions: const {'edit.md': '10:1'},
      observedAt: 2,
    );

    final filtered = MarkdownFolderDiff.compute(
      previous,
      current,
    ).withMetadataOnlyChanges(previous, current);

    expect(filtered.isEmpty, isTrue);
  });

  test('content change still survives metadata filtering', () {
    final previous = MarkdownFolderSnapshot(
      manifest: _manifest(['edit.md']),
      contentHashes: const {'edit.md': 'sha-before'},
      metadataRevisions: const {'edit.md': '10:1'},
      observedAt: 1,
    );
    final current = MarkdownFolderSnapshot(
      manifest: _manifest(['edit.md']),
      contentHashes: const {'edit.md': 'sha-after'},
      metadataRevisions: const {'edit.md': '20:2'},
      observedAt: 2,
    );

    final filtered = MarkdownFolderDiff.compute(
      previous,
      current,
    ).withMetadataOnlyChanges(previous, current);

    expect(filtered.changes, hasLength(1));
    expect(filtered.changes.single.kind, MarkdownFolderChangeKind.changed);
  });
}

MarkdownFolderSnapshot _snapshot(Map<String, String> hashes) {
  return MarkdownFolderSnapshot(
    manifest: _manifest(hashes.keys.toList()),
    contentHashes: Map.unmodifiable(hashes),
    metadataRevisions: {
      for (final path in hashes.keys) path: '${hashes[path]!.length}:1',
    },
    observedAt: 1,
  );
}

MarkdownFolderManifest _manifest(List<String> paths) {
  final files = [
    for (final path in paths)
      MarkdownFolderFile(
        relativePath: path,
        absolutePath: '/notes/$path',
        title: path,
        size: 10,
        modified: DateTime.fromMillisecondsSinceEpoch(1),
      ),
  ];
  return MarkdownFolderManifest(
    rootPath: '/notes',
    files: files,
    roots: const [],
    totalBytes: files.length * 10,
  );
}
