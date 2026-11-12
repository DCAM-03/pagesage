import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../domain/books/reading_position.dart';
import 'markdown_folder.dart';

final class MarkdownFolderSnapshot {
  const MarkdownFolderSnapshot({
    required this.manifest,
    required this.contentHashes,
    required this.observedAt,
    this.metadataRevisions = const {},
  });

  final MarkdownFolderManifest manifest;
  final Map<String, String> contentHashes;
  final Map<String, String> metadataRevisions;
  final int observedAt;
}

enum MarkdownFolderChangeKind { added, changed, removed, renamed }

final class MarkdownFolderChange {
  const MarkdownFolderChange({
    required this.kind,
    required this.path,
    this.previousPath,
  });

  final MarkdownFolderChangeKind kind;
  final String path;
  final String? previousPath;
}

final class MarkdownFolderDiff {
  const MarkdownFolderDiff({required this.changes, required this.renameHints});

  final List<MarkdownFolderChange> changes;
  final Map<String, String> renameHints;

  bool get isEmpty => changes.isEmpty;
  bool involves(String path) => changes.any(
    (change) => change.path == path || change.previousPath == path,
  );

  /// Replaces a difference caused only by swapping a metadata placeholder for
  /// a content hash with the path's last meaningful state.
  MarkdownFolderDiff withMetadataOnlyChanges(
    MarkdownFolderSnapshot previous,
    MarkdownFolderSnapshot current,
  ) {
    final filtered = <MarkdownFolderChange>[];
    for (final change in changes) {
      if (change.kind != MarkdownFolderChangeKind.changed) {
        filtered.add(change);
        continue;
      }
      final oldValue = previous.contentHashes[change.path] ?? '';
      final newValue = current.contentHashes[change.path] ?? '';
      if (oldValue == 'metadata:${previous.metadataRevisions[change.path]}' &&
          !newValue.startsWith('metadata:') &&
          previous.metadataRevisions[change.path] ==
              current.metadataRevisions[change.path]) {
        continue;
      }
      filtered.add(change);
    }
    return MarkdownFolderDiff(
      changes: List.unmodifiable(filtered),
      renameHints: renameHints,
    );
  }

  static MarkdownFolderDiff compute(
    MarkdownFolderSnapshot previous,
    MarkdownFolderSnapshot current, {
    Map<String, String> moveHints = const {},
  }) {
    final oldPaths = previous.manifest.files
        .map((file) => file.relativePath)
        .toSet();
    final newPaths = current.manifest.files
        .map((file) => file.relativePath)
        .toSet();
    final removed = oldPaths.difference(newPaths).toList()..sort();
    final added = newPaths.difference(oldPaths).toList()..sort();
    final surviving = oldPaths.intersection(newPaths).toList()..sort();
    final changes = <MarkdownFolderChange>[];
    final renameHints = <String, String>{};
    final claimed = <String>{};
    for (final oldPath in removed) {
      final hint = moveHints[oldPath];
      if (hint != null &&
          added.contains(hint) &&
          !claimed.contains(hint) &&
          previous.contentHashes[oldPath] != null &&
          previous.contentHashes[oldPath] == current.contentHashes[hint]) {
        claimed.add(hint);
        renameHints[oldPath] = hint;
        changes.add(
          MarkdownFolderChange(
            kind: MarkdownFolderChangeKind.renamed,
            path: hint,
            previousPath: oldPath,
          ),
        );
      }
    }
    for (final path in removed) {
      if (renameHints.containsKey(path)) continue;
      changes.add(
        MarkdownFolderChange(
          kind: MarkdownFolderChangeKind.removed,
          path: path,
        ),
      );
    }
    for (final path in added) {
      if (claimed.contains(path)) continue;
      changes.add(
        MarkdownFolderChange(kind: MarkdownFolderChangeKind.added, path: path),
      );
    }
    for (final path in surviving) {
      if (previous.contentHashes[path] != current.contentHashes[path]) {
        changes.add(
          MarkdownFolderChange(
            kind: MarkdownFolderChangeKind.changed,
            path: path,
          ),
        );
      }
    }
    return MarkdownFolderDiff(
      changes: List.unmodifiable(changes),
      renameHints: Map.unmodifiable(renameHints),
    );
  }
}

enum ReadingAnchorPrecision {
  exact,
  reanchored,
  approximate,
  missing,
  ambiguous,
}

final class ReadingAnchorResult {
  const ReadingAnchorResult({required this.precision, required this.locator});

  final ReadingAnchorPrecision precision;
  final ReadingLocator locator;
}

final class ReadingAnchorResolver {
  const ReadingAnchorResolver();

  ReadingAnchorResult resolve(
    ReadingLocator oldLocator, {
    required String oldText,
    required String newText,
    bool textRevisionChanged = true,
  }) {
    if (!textRevisionChanged) {
      return ReadingAnchorResult(
        precision: ReadingAnchorPrecision.exact,
        locator: oldLocator,
      );
    }
    final offset = oldLocator.chapterOffset;
    if (offset != null && offset >= 0 && offset <= newText.length) {
      final quoteLength = (oldLocator.chapterEndOffset ?? offset) - offset;
      if (quoteLength > 0 && offset + quoteLength <= oldText.length) {
        final quote = oldText.substring(offset, offset + quoteLength);
        final first = newText.indexOf(quote);
        if (first >= 0 && newText.indexOf(quote, first + 1) < 0) {
          return ReadingAnchorResult(
            precision: ReadingAnchorPrecision.reanchored,
            locator: _copy(
              oldLocator,
              chapterOffset: first,
              chapterEndOffset: first + quoteLength,
            ),
          );
        }
        if (first >= 0) {
          return ReadingAnchorResult(
            precision: ReadingAnchorPrecision.ambiguous,
            locator: _copy(oldLocator, chapterOffset: 0),
          );
        }
      }
    }
    final excerpt = oldLocator.excerpt?.trim();
    if (excerpt != null && excerpt.isNotEmpty) {
      final first = newText.indexOf(excerpt);
      if (first >= 0 && newText.indexOf(excerpt, first + 1) < 0) {
        return ReadingAnchorResult(
          precision: ReadingAnchorPrecision.reanchored,
          locator: _copy(oldLocator, chapterOffset: first),
        );
      }
    }
    final ratio = oldLocator.progress.clamp(0, 1);
    final approximate = (newText.length * ratio).floor();
    return ReadingAnchorResult(
      precision: newText.isEmpty
          ? ReadingAnchorPrecision.missing
          : ReadingAnchorPrecision.approximate,
      locator: _copy(oldLocator, chapterOffset: approximate),
    );
  }

  ReadingLocator _copy(
    ReadingLocator locator, {
    int? chapterOffset,
    int? chapterEndOffset,
  }) {
    if (locator.type == ReadingLocatorType.pdf) {
      return ReadingLocator.pdf(
        page: locator.page ?? 1,
        scrollOffset: locator.scrollOffset ?? 0,
        pageOffsetFraction: locator.pageOffsetFraction,
        zoom: locator.zoom ?? 1,
        progress: locator.progress,
        excerpt: locator.excerpt,
        selectionRects: locator.selectionRects,
      );
    }
    return ReadingLocator.markdown(
      href: locator.href,
      chapterIndex: locator.chapterIndex,
      chapterOffset: chapterOffset ?? locator.chapterOffset,
      chapterEndOffset: chapterEndOffset ?? locator.chapterEndOffset,
      progress: locator.progress,
      excerpt: locator.excerpt,
      selectionRects: locator.selectionRects,
      folderFileLocal: locator.folderFileLocal,
    );
  }
}

String markdownContentHash(List<int> bytes) => sha256.convert(bytes).toString();

String markdownSnapshotRevision(MarkdownFolderSnapshot snapshot) {
  final encoded = jsonEncode({
    for (final file in snapshot.manifest.files)
      file.relativePath: {
        'metadata': snapshot.metadataRevisions[file.relativePath] ?? '',
        'content': snapshot.contentHashes[file.relativePath] ?? '',
      },
  });
  return sha256.convert(utf8.encode(encoded)).toString();
}
