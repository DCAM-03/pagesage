import 'package:flutter/material.dart';

import '../../../domain/books/reading_position.dart';
import '../../../renderers/epub/epub_document.dart';
import '../../../renderers/markdown/markdown_document_loader.dart';
import '../../../renderers/markdown/markdown_folder.dart';
import 'reader_context_empty_state.dart';
import 'reader_toc_tree.dart';

final class EpubTocSheet extends StatefulWidget {
  const EpubTocSheet({
    this.document,
    this.folderManifest,
    this.activeFolderFile,
    this.onFolderFileSelected,
    this.onFolderLocatorSelected,
    required this.currentChapterIndex,
    this.onSelected,
    super.key,
  });

  final EpubDocument? document;
  final MarkdownFolderManifest? folderManifest;
  final String? activeFolderFile;
  final ValueChanged<MarkdownFolderFile>? onFolderFileSelected;
  final ValueChanged<ReadingLocator>? onFolderLocatorSelected;
  final int? currentChapterIndex;
  final ValueChanged<EpubTocItem>? onSelected;

  @override
  State<EpubTocSheet> createState() => _EpubTocSheetState();
}

final class _EpubTocSheetState extends State<EpubTocSheet> {
  final Set<String> _expanded = {};
  final Set<String> _expandedFolders = {};
  FolderTocTab _folderTab = FolderTocTab.files;
  String? _activeFolderFile;
  Future<EpubDocument>? _folderOutlineFuture;
  String? _folderOutlinePath;

  @override
  void initState() {
    super.initState();
    _activeFolderFile = widget.activeFolderFile;
    if (widget.document != null) {
      _expanded.addAll(
        tocAncestorKeys(widget.document!.toc, widget.currentChapterIndex),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.folderManifest;
    if (manifest == null) {
      return SafeArea(child: _buildOutlineList(context, widget.document!));
    }
    _ensureFolderOutline(manifest);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Text('目录', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                SegmentedButton<FolderTocTab>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: FolderTocTab.files,
                      icon: Icon(Icons.account_tree_outlined, size: 18),
                      label: Text('文件'),
                    ),
                    ButtonSegment(
                      value: FolderTocTab.outline,
                      icon: Icon(Icons.toc, size: 18),
                      label: Text('大纲'),
                    ),
                  ],
                  selected: {_folderTab},
                  onSelectionChanged: (selection) {
                    setState(() => _folderTab = selection.single);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _folderTab == FolderTocTab.files
                ? _buildFolderFiles(context, manifest)
                : _buildFolderOutline(context, manifest),
          ),
        ],
      ),
    );
  }

  void _ensureFolderOutline(MarkdownFolderManifest manifest) {
    final file = manifest.fileForHref(_activeFolderFile) ?? manifest.firstFile;
    if (file == null || _folderOutlinePath == file.relativePath) {
      return;
    }
    _folderOutlinePath = file.relativePath;
    _folderOutlineFuture = const MarkdownDocumentLoader().load(
      file.absolutePath,
    );
  }

  Widget _buildFolderFiles(
    BuildContext context,
    MarkdownFolderManifest manifest,
  ) {
    final rows = flattenFolderRows(
      manifest.roots,
      expanded: _expandedFolders,
      filter: '',
    );
    if (rows.isEmpty) {
      return const ReaderContextEmptyState(
        icon: Icons.folder_open,
        message: '文件夹是空的',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final node = row.node;
        if (node is MarkdownFolderDirectory) {
          final expanded = _expandedFolders.contains(node.relativePath);
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.only(
              left: 8.0 + row.level * 16,
              right: 8,
            ),
            leading: Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
              size: 20,
            ),
            title: Text(
              node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: folderRowLocation(node.relativePath, row.level),
            onTap: () => setState(() {
              if (expanded) {
                _expandedFolders.remove(node.relativePath);
              } else {
                _expandedFolders.add(node.relativePath);
              }
            }),
          );
        }
        final file = (node as MarkdownFolderDocument).file;
        final selected = file.relativePath == _activeFolderFile;
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          selected: selected,
          contentPadding: EdgeInsets.only(left: 8.0 + row.level * 16, right: 8),
          leading: const Icon(Icons.article_outlined, size: 20),
          title: Text(file.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: folderRowLocation(file.relativePath, row.level),
          onTap: () {
            setState(() {
              _activeFolderFile = file.relativePath;
              _folderOutlinePath = null;
            });
            widget.onFolderFileSelected?.call(file);
          },
        );
      },
    );
  }

  Widget _buildFolderOutline(
    BuildContext context,
    MarkdownFolderManifest manifest,
  ) {
    final future = _folderOutlineFuture;
    final file = manifest.fileForHref(_activeFolderFile) ?? manifest.firstFile;
    if (future == null || file == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<EpubDocument>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ReaderContextEmptyState(
            icon: Icons.error_outline,
            message: '无法读取这个文件',
          );
        }
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildOutlineList(
          context,
          document,
          showHeader: false,
          folderFile: file,
          manifest: manifest,
        );
      },
    );
  }

  Widget _buildOutlineList(
    BuildContext context,
    EpubDocument document, {
    bool showHeader = true,
    MarkdownFolderFile? folderFile,
    MarkdownFolderManifest? manifest,
  }) {
    final rows = flattenTocRows(document.toc, expanded: _expanded, filter: '');
    if (rows.isEmpty) {
      return const ReaderContextEmptyState(
        icon: Icons.toc,
        message: '这个文件没有标题',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: rows.length + (showHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (showHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text('目录', style: Theme.of(context).textTheme.titleLarge),
          );
        }
        final row = rows[index - (showHeader ? 1 : 0)];
        final item = row.item;
        final expandable = item.children.isNotEmpty;
        final expanded = _expanded.contains(row.key);
        return ListTile(
          selected: widget.currentChapterIndex == item.chapterIndex,
          contentPadding: EdgeInsets.only(
            left: 12.0 + row.level * 18,
            right: 12,
          ),
          leading: IconButton(
            tooltip: expanded ? '折叠' : '展开',
            onPressed: expandable
                ? () => setState(() {
                    if (expanded) {
                      _expanded.remove(row.key);
                    } else {
                      _expanded.add(row.key);
                    }
                  })
                : null,
            icon: Icon(
              expandable
                  ? (expanded ? Icons.keyboard_arrow_down : Icons.chevron_right)
                  : Icons.article_outlined,
            ),
          ),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.chapterIndex == null ? '目录项暂不可跳转' : item.href,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          enabled: item.chapterIndex != null,
          onTap: item.chapterIndex == null
              ? null
              : () {
                  if (folderFile != null && manifest != null) {
                    final localProgress = document.progressForChapter(
                      chapterIndex: item.chapterIndex!,
                      chapterOffset: item.chapterOffset ?? 0,
                    );
                    widget.onFolderLocatorSelected?.call(
                      ReadingLocator.markdown(
                        href: folderFile.relativePath,
                        chapterIndex: item.chapterIndex,
                        chapterOffset: item.chapterOffset,
                        progress: manifest.progressForFile(
                          folderFile.relativePath,
                          localProgress,
                        ),
                        folderFileLocal: true,
                      ),
                    );
                    return;
                  }
                  widget.onSelected?.call(item);
                },
        );
      },
    );
  }
}
