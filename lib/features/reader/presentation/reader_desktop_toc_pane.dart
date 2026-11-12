import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/reading_position.dart';
import '../../../renderers/common/book_document_loader.dart';
import '../../../renderers/common/renderer_event.dart';
import '../../../renderers/epub/epub_document.dart';
import '../../../renderers/markdown/markdown_document_loader.dart';
import '../../../renderers/markdown/markdown_folder.dart';
import 'reader_context_empty_state.dart';
import 'reader_pdf_outline_selection.dart';
import 'reader_toc_tree.dart';

final class DesktopTocPane extends StatefulWidget {
  const DesktopTocPane({
    required this.book,
    required this.documentLoader,
    required this.folderManifest,
    required this.activeFolderFile,
    required this.onFolderFileSelected,
    required this.pdfOutline,
    required this.totalPages,
    required this.currentLocator,
    required this.locationListenable,
    required this.onSelected,
    required this.onClose,
    this.onRefresh,
    this.refreshState,
    super.key,
  });

  final Book book;
  final BookDocumentLoader documentLoader;
  final MarkdownFolderManifest? folderManifest;
  final String? activeFolderFile;
  final ValueChanged<MarkdownFolderFile> onFolderFileSelected;
  final List<RendererOutlineItem> pdfOutline;
  final int? totalPages;
  final ReadingLocator? currentLocator;
  final ValueListenable<RendererLocationChanged?> locationListenable;
  final ValueChanged<ReadingLocator> onSelected;
  final VoidCallback onClose;
  final VoidCallback? onRefresh;
  final String? refreshState;

  @override
  State<DesktopTocPane> createState() => _DesktopTocPaneState();
}

final class _DesktopTocPaneState extends State<DesktopTocPane> {
  Future<EpubDocument>? _epubDocumentFuture;
  final _filterController = TextEditingController();
  final _filterFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Set<String> _expandedTocKeys = {};
  final Set<String> _expandedFolderKeys = {};
  FolderTocTab _folderTab = FolderTocTab.files;
  Future<EpubDocument>? _folderOutlineFuture;
  ({String path, int size, DateTime modified})? _folderOutlineKey;
  String _filter = '';
  String _appliedFilter = '';
  Timer? _filterDebounce;
  int? _lastAutoScrolledChapter;
  int? _lastAutoScrolledPage;
  bool _seededExpanded = false;

  @override
  void initState() {
    super.initState();
    _updateDocumentFuture();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _filterController.dispose();
    _filterFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DesktopTocPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.libraryFilePath != widget.book.libraryFilePath) {
      _seededExpanded = false;
      _expandedTocKeys.clear();
      _expandedFolderKeys.clear();
      _lastAutoScrolledChapter = null;
      _lastAutoScrolledPage = null;
      _folderTab = FolderTocTab.files;
      _folderOutlineFuture = null;
      _folderOutlineKey = null;
      _filterController.clear();
      _filter = '';
      _appliedFilter = '';
      _updateDocumentFuture();
    }
    if (oldWidget.activeFolderFile != widget.activeFolderFile) {
      _lastAutoScrolledChapter = null;
      _folderOutlineKey = null;
    }
  }

  void _updateDocumentFuture() {
    if (widget.folderManifest != null) {
      _epubDocumentFuture = null;
      return;
    }
    _epubDocumentFuture = widget.book.format.isReflowable
        ? widget.documentLoader.load(widget.book.libraryFilePath)
        : null;
  }

  void _onFilterChanged(String value) {
    final next = value.trim();
    // Keep raw text in the field; only rebuild the list after a short debounce
    // so typing stays responsive and the caret doesn't fight rebuilds.
    _filter = next;
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _appliedFilter == next) {
        return;
      }
      setState(() => _appliedFilter = next);
    });
    // Rebuild trailing clear button immediately when emptiness flips.
    final hadFilter = _appliedFilter.isNotEmpty || _filter.isNotEmpty;
    final hasFilter = next.isNotEmpty;
    if (hadFilter != hasFilter) {
      setState(() {});
    }
  }

  void _clearFilter() {
    _filterDebounce?.cancel();
    _filterController.clear();
    setState(() {
      _filter = '';
      _appliedFilter = '';
    });
    _filterFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFilter = _filter.isNotEmpty || _appliedFilter.isNotEmpty;
    return AppSidePanel(
      title: widget.book.format == BookFormat.pdf ? 'PDF 目录' : '目录',
      border: AppSidePanelBorder.right,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onRefresh != null)
            IconButton(
              tooltip: '刷新文件夹',
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: '收起目录',
            onPressed: widget.onClose,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
      child: Column(
        children: [
          if (widget.refreshState != null)
            Semantics(
              label: '文件夹状态：${widget.refreshState}',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x3,
                  AppSpacing.x1,
                  AppSpacing.x3,
                  AppSpacing.x1,
                ),
                child: Text(
                  widget.refreshState!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x3,
              AppSpacing.x2,
              AppSpacing.x3,
              AppSpacing.x2,
            ),
            child: TextField(
              controller: _filterController,
              focusNode: _filterFocusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onFilterChanged,
              onSubmitted: (value) {
                _filterDebounce?.cancel();
                final next = value.trim();
                if (_appliedFilter != next) {
                  setState(() {
                    _filter = next;
                    _appliedFilter = next;
                  });
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.book.format == BookFormat.pdf
                    ? '过滤标题或页码'
                    : widget.folderManifest != null
                    ? (_folderTab == FolderTocTab.files ? '过滤文件路径' : '过滤当前文件标题')
                    : '过滤章节标题',
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: hasFilter
                    ? IconButton(
                        tooltip: '清空',
                        onPressed: _clearFilter,
                        icon: const Icon(Icons.close, size: 18),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.book.format == BookFormat.pdf
                ? _buildPdfToc(context)
                : widget.folderManifest != null
                ? _buildFolderToc(context)
                : _buildEpubToc(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderToc(BuildContext context) {
    final manifest = widget.folderManifest;
    if (manifest == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            AppSpacing.x1,
            AppSpacing.x3,
            AppSpacing.x2,
          ),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<FolderTocTab>(
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
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _folderTab == FolderTocTab.files
              ? _buildFolderFiles(context, manifest)
              : _buildFolderOutline(context, manifest),
        ),
      ],
    );
  }

  Widget _buildFolderFiles(
    BuildContext context,
    MarkdownFolderManifest manifest,
  ) {
    final filter = _appliedFilter.toLowerCase();
    final rows = flattenFolderRows(
      manifest.roots,
      expanded: _expandedFolderKeys,
      filter: filter,
    );
    if (rows.isEmpty) {
      return const ReaderContextEmptyState(
        icon: Icons.folder_open,
        message: '没有匹配的文件',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final node = row.node;
        if (node is MarkdownFolderDirectory) {
          final expanded =
              filter.isNotEmpty ||
              _expandedFolderKeys.contains(node.relativePath);
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.only(
              left: 4.0 + row.level * 14,
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
            onTap: filter.isEmpty
                ? () => setState(() {
                    if (_expandedFolderKeys.contains(node.relativePath)) {
                      _expandedFolderKeys.remove(node.relativePath);
                    } else {
                      _expandedFolderKeys.add(node.relativePath);
                    }
                  })
                : null,
          );
        }
        final file = (node as MarkdownFolderDocument).file;
        final selected = widget.activeFolderFile == file.relativePath;
        return ListTile(
          selected: selected,
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.only(left: 4.0 + row.level * 14, right: 8),
          leading: const Icon(Icons.article_outlined, size: 20),
          title: Text(file.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: folderRowLocation(file.relativePath, row.level),
          onTap: () {
            widget.onFolderFileSelected(file);
          },
        );
      },
    );
  }

  Widget _buildFolderOutline(
    BuildContext context,
    MarkdownFolderManifest manifest,
  ) {
    final file =
        manifest.fileForHref(widget.activeFolderFile) ?? manifest.firstFile;
    if (file == null) {
      return const SizedBox.shrink();
    }
    final key = (
      path: file.absolutePath,
      size: file.size,
      modified: file.modified,
    );
    if (_folderOutlineKey != key) {
      _folderOutlineKey = key;
      _folderOutlineFuture = const MarkdownDocumentLoader().load(
        file.absolutePath,
      );
    }
    final future = _folderOutlineFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<EpubDocument>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('无法读取这个文件'));
        }
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<RendererLocationChanged?>(
          valueListenable: widget.locationListenable,
          builder: (context, location, _) {
            final locator = location?.locator ?? widget.currentLocator;
            final sameFile =
                normalizeFolderHref(locator?.href ?? '') ==
                normalizeFolderHref(file.relativePath);
            final currentChapter = sameFile ? locator?.chapterIndex : null;
            final filter = _appliedFilter.toLowerCase();
            final rows = flattenTocRows(
              document.toc,
              expanded: _expandedTocKeys,
              filter: filter,
            );
            if (rows.isEmpty) {
              return const ReaderContextEmptyState(
                icon: Icons.toc,
                message: '这个文件没有标题',
              );
            }
            if (filter.isEmpty &&
                currentChapter != null &&
                currentChapter != _lastAutoScrolledChapter &&
                !_filterFocusNode.hasFocus) {
              _lastAutoScrolledChapter = currentChapter;
              _scrollSelectedIntoView(
                rows.indexWhere(
                  (row) => row.item.chapterIndex == currentChapter,
                ),
              );
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final item = row.item;
                final selected = currentChapter == item.chapterIndex;
                final expandable = item.children.isNotEmpty && filter.isEmpty;
                final expanded = _expandedTocKeys.contains(row.key);
                return ListTile(
                  selected: selected,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  enabled: item.chapterIndex != null,
                  contentPadding: EdgeInsets.only(
                    left: 4.0 + row.level * 14,
                    right: 8,
                  ),
                  leading: IconButton(
                    tooltip: expandable ? (expanded ? '折叠' : '展开') : null,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: expandable
                        ? () => setState(() {
                            if (expanded) {
                              _expandedTocKeys.remove(row.key);
                            } else {
                              _expandedTocKeys.add(row.key);
                            }
                          })
                        : null,
                    icon: Icon(
                      item.children.isEmpty
                          ? Icons.article_outlined
                          : expanded || filter.isNotEmpty
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.chapterIndex == null
                        ? '目录项暂不可跳转'
                        : '${(document.progressForChapterIndex(item.chapterIndex!) * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: item.chapterIndex == null
                      ? null
                      : () {
                          final localProgress = document.progressForChapter(
                            chapterIndex: item.chapterIndex!,
                            chapterOffset: item.chapterOffset ?? 0,
                          );
                          widget.onSelected(
                            ReadingLocator.markdown(
                              href: file.relativePath,
                              chapterIndex: item.chapterIndex,
                              chapterOffset: item.chapterOffset,
                              progress: manifest.progressForFile(
                                file.relativePath,
                                localProgress,
                              ),
                              folderFileLocal: true,
                            ),
                          );
                        },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEpubToc(BuildContext context) {
    final future = _epubDocumentFuture;
    if (future == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<EpubDocument>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('无法读取目录'));
        }
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<RendererLocationChanged?>(
          valueListenable: widget.locationListenable,
          builder: (context, location, _) {
            final currentChapter =
                location?.locator.chapterIndex ??
                widget.currentLocator?.chapterIndex;
            final filter = _appliedFilter.toLowerCase();
            if (!_seededExpanded) {
              _seededExpanded = true;
              _expandedTocKeys.addAll(
                tocAncestorKeys(document.toc, currentChapter),
              );
            } else if (filter.isEmpty && currentChapter != null) {
              // Expand ancestors of the current chapter without collapsing user state.
              _expandedTocKeys.addAll(
                tocAncestorKeys(document.toc, currentChapter),
              );
            }
            final rows = flattenTocRows(
              document.toc,
              expanded: _expandedTocKeys,
              filter: filter,
            );
            if (rows.isEmpty) {
              return const ReaderContextEmptyState(
                icon: Icons.toc,
                message: '没有匹配的章节',
              );
            }
            // Only auto-scroll when not filtering, and only when the chapter changes.
            if (filter.isEmpty &&
                currentChapter != null &&
                currentChapter != _lastAutoScrolledChapter &&
                !_filterFocusNode.hasFocus) {
              _lastAutoScrolledChapter = currentChapter;
              _scrollSelectedIntoView(
                rows.indexWhere(
                  (row) => row.item.chapterIndex == currentChapter,
                ),
              );
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final item = row.item;
                final selected = currentChapter == item.chapterIndex;
                final expandable = item.children.isNotEmpty && filter.isEmpty;
                final expanded = _expandedTocKeys.contains(row.key);
                return ListTile(
                  selected: selected,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  enabled: item.chapterIndex != null,
                  contentPadding: EdgeInsets.only(
                    left: 4.0 + row.level * 14,
                    right: 8,
                  ),
                  leading: IconButton(
                    tooltip: expandable ? (expanded ? '折叠' : '展开') : null,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: expandable
                        ? () => setState(() {
                            if (expanded) {
                              _expandedTocKeys.remove(row.key);
                            } else {
                              _expandedTocKeys.add(row.key);
                            }
                          })
                        : null,
                    icon: Icon(
                      item.children.isEmpty
                          ? Icons.article_outlined
                          : expanded || filter.isNotEmpty
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.chapterIndex == null
                        ? '目录项暂不可跳转'
                        : '${(document.progressForChapterIndex(item.chapterIndex!) * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: item.chapterIndex == null
                      ? null
                      : () {
                          widget.onSelected(
                            ReadingLocator.epub(
                              href: item.href,
                              chapterIndex: item.chapterIndex,
                              chapterOffset: item.chapterOffset,
                              progress: document.progressForChapter(
                                chapterIndex: item.chapterIndex!,
                                chapterOffset: item.chapterOffset ?? 0,
                              ),
                            ),
                          );
                        },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPdfToc(BuildContext context) {
    final totalPages = widget.totalPages ?? 0;
    final items = widget.pdfOutline.isEmpty
        ? [
            for (var page = 1; page <= totalPages; page += 1)
              RendererOutlineItem(title: '第 $page 页', page: page),
          ]
        : widget.pdfOutline;
    if (items.isEmpty) {
      return const Center(child: Text('页码准备中'));
    }
    return ValueListenableBuilder<RendererLocationChanged?>(
      valueListenable: widget.locationListenable,
      builder: (context, location, _) {
        final filter = _appliedFilter.toLowerCase();
        final filtered = items
            .where((item) {
              if (filter.isEmpty) {
                return true;
              }
              return item.title.toLowerCase().contains(filter) ||
                  '${item.page}'.contains(filter);
            })
            .toList(growable: false);
        if (filtered.isEmpty) {
          return const ReaderContextEmptyState(
            icon: Icons.toc,
            message: '没有匹配的目录项',
          );
        }
        final currentLocator = location?.locator ?? widget.currentLocator;
        final currentPage =
            location?.pageNumber ??
            currentLocator?.page ??
            widget.currentLocator?.page;
        final activeIndex = activePdfOutlineIndex(
          items: filtered,
          currentPage: currentPage,
          currentPageOffsetFraction: currentLocator?.pageOffsetFraction,
        );
        if (filter.isEmpty &&
            currentPage != null &&
            currentPage != _lastAutoScrolledPage &&
            !_filterFocusNode.hasFocus) {
          _lastAutoScrolledPage = currentPage;
          _scrollSelectedIntoView(activeIndex ?? -1);
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return ListTile(
              selected: activeIndex == index,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.only(
                left: 8.0 + item.level * 14.0,
                right: 8,
              ),
              leading: SizedBox(
                width: 36,
                child: Text(
                  '${item.page}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('第 ${item.page} 页'),
              onTap: () {
                widget.onSelected(
                  ReadingLocator.pdf(
                    page: item.page,
                    progress: _pdfPageProgress(item.page, totalPages),
                    pageOffsetFraction: item.offsetFraction,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  double _pdfPageProgress(int page, int totalPages) {
    if (totalPages <= 1) {
      return 1;
    }
    return ((page - 1) / (totalPages - 1)).clamp(0, 1).toDouble();
  }

  void _scrollSelectedIntoView(int index) {
    if (index < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      const estimatedTileHeight = 56.0;
      final target = (index * estimatedTileHeight - 96).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      if ((_scrollController.offset - target).abs() < estimatedTileHeight) {
        return;
      }
      _scrollController.jumpTo(target.toDouble());
    });
  }
}
