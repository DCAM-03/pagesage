import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'markdown_folder.dart';
import 'markdown_folder_diff.dart';

enum MarkdownFolderVerification { metadata, full }

final class MarkdownFolderSnapshotLoader {
  const MarkdownFolderSnapshotLoader(this._source);

  final MarkdownFolderSource _source;

  Future<MarkdownFolderSnapshot> load(
    String rootPath, {
    MarkdownFolderVerification verification =
        MarkdownFolderVerification.metadata,
    Set<String> contentPaths = const {},
    MarkdownFolderSnapshot? previous,
  }) async {
    final manifest = await _source.loadManifest(rootPath);
    final hashes = <String, String>{};
    final metadata = <String, String>{};
    for (final file in manifest.files) {
      final path = file.relativePath;
      final metadataRevision = _metadataRevision(file);
      metadata[path] = metadataRevision;
      final previousMetadata = previous?.metadataRevisions[path];
      final previousHash = previous?.contentHashes[path];
      final canCarry =
          previousMetadata == metadataRevision &&
          previousHash != null &&
          !previousHash.startsWith('metadata:');
      if (verification == MarkdownFolderVerification.full ||
          contentPaths.contains(path)) {
        hashes[path] = await _stableContentRevision(rootPath, file);
      } else if (canCarry) {
        hashes[path] = previousHash;
      } else {
        hashes[path] = 'metadata:$metadataRevision';
      }
    }
    return MarkdownFolderSnapshot(
      manifest: manifest,
      contentHashes: Map<String, String>.unmodifiable(hashes),
      metadataRevisions: Map<String, String>.unmodifiable(metadata),
      observedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String> _stableContentRevision(
    String rootPath,
    MarkdownFolderFile file,
  ) async {
    final relative = p.posix.normalize(file.relativePath);
    if (relative.startsWith('..') || p.posix.isAbsolute(relative)) {
      throw const MarkdownFolderException('Markdown 文件路径越界');
    }
    final absolute = p.join(rootPath, p.posix.joinAll(p.posix.split(relative)));
    if (!p.isWithin(rootPath, absolute)) {
      throw const MarkdownFolderException('Markdown 文件路径越界');
    }
    final handle = File(absolute);
    if (await FileSystemEntity.isLink(absolute)) {
      throw const MarkdownFolderException('Markdown 文件是链接');
    }
    for (var attempt = 0; attempt < 3; attempt += 1) {
      final before = await handle.stat();
      final bytes = await handle.readAsBytes();
      final after = await handle.stat();
      if (before.size == after.size &&
          before.modified.millisecondsSinceEpoch ==
              after.modified.millisecondsSinceEpoch) {
        return sha256.convert(bytes).toString();
      }
      await Future<void>.delayed(Duration(milliseconds: 200 * (1 << attempt)));
    }
    throw const MarkdownFolderException('Markdown 文件仍在变化，请稍后刷新');
  }

  String _metadataRevision(MarkdownFolderFile file) =>
      '${file.size}:${file.modified.millisecondsSinceEpoch}';
}
