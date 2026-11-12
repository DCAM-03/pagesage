import 'package:flutter/material.dart';

import '../../../renderers/epub/epub_document.dart';
import '../../../renderers/markdown/markdown_folder.dart';

enum FolderTocTab { files, outline }

final class TocTreeRow {
  const TocTreeRow({
    required this.item,
    required this.level,
    required this.key,
  });

  final EpubTocItem item;
  final int level;
  final String key;
}

final class FolderTocTreeRow {
  const FolderTocTreeRow({required this.node, required this.level});

  final MarkdownFolderNode node;
  final int level;
}

/// The parent folder of a nested row, or null at the root.
///
/// A root row's title already is the whole name, so repeating it in a
/// subtitle only adds noise. Nested rows keep their location so two files
/// with the same name stay distinguishable.
Widget? folderRowLocation(String relativePath, int level) {
  if (level == 0) {
    return null;
  }
  final slash = relativePath.lastIndexOf('/');
  if (slash <= 0) {
    return null;
  }
  return Text(
    relativePath.substring(0, slash),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

List<FolderTocTreeRow> flattenFolderRows(
  List<MarkdownFolderNode> nodes, {
  required Set<String> expanded,
  required String filter,
  int level = 0,
}) {
  final rows = <FolderTocTreeRow>[];
  for (final node in nodes) {
    if (node is MarkdownFolderDirectory) {
      final childRows = flattenFolderRows(
        node.children,
        expanded: expanded,
        filter: filter,
        level: level + 1,
      );
      if (filter.isNotEmpty && childRows.isEmpty) {
        continue;
      }
      rows.add(FolderTocTreeRow(node: node, level: level));
      if (filter.isNotEmpty || expanded.contains(node.relativePath)) {
        rows.addAll(childRows);
      }
      continue;
    }
    final file = (node as MarkdownFolderDocument).file;
    if (filter.isNotEmpty &&
        !file.relativePath.toLowerCase().contains(filter) &&
        !file.title.toLowerCase().contains(filter)) {
      continue;
    }
    rows.add(FolderTocTreeRow(node: node, level: level));
  }
  return rows;
}

List<TocTreeRow> flattenTocRows(
  List<EpubTocItem> items, {
  required Set<String> expanded,
  required String filter,
  int level = 0,
  String prefix = '',
}) {
  final rows = <TocTreeRow>[];
  for (var index = 0; index < items.length; index += 1) {
    final item = items[index];
    final key = prefix.isEmpty ? '$index' : '$prefix.$index';
    final titleMatches =
        filter.isEmpty ||
        item.title.toLowerCase().contains(filter) ||
        (item.chapterIndex != null &&
            '${item.chapterIndex! + 1}'.contains(filter));
    final childRows = flattenTocRows(
      item.children,
      expanded: expanded,
      filter: filter,
      level: level + 1,
      prefix: key,
    );
    if (filter.isNotEmpty) {
      if (titleMatches) {
        rows.add(TocTreeRow(item: item, level: level, key: key));
      }
      rows.addAll(childRows);
      continue;
    }
    rows.add(TocTreeRow(item: item, level: level, key: key));
    if (expanded.contains(key)) {
      rows.addAll(childRows);
    }
  }
  return rows;
}

Set<String> tocAncestorKeys(List<EpubTocItem> items, int? chapterIndex) {
  if (chapterIndex == null) {
    return {};
  }
  final path = <String>[];
  bool visit(List<EpubTocItem> nodes, String prefix) {
    for (var index = 0; index < nodes.length; index += 1) {
      final key = prefix.isEmpty ? '$index' : '$prefix.$index';
      final item = nodes[index];
      if (item.chapterIndex == chapterIndex) {
        return true;
      }
      if (visit(item.children, key)) {
        path.add(key);
        return true;
      }
    }
    return false;
  }

  visit(items, '');
  return path.toSet();
}
