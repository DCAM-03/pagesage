# -*- coding: utf-8 -*-
from pathlib import Path

path = Path("lib/features/library/presentation/library_page.dart")
text = path.read_text(encoding="utf-8")

# --- Header actions: add grid size control ---
old_header_ctor = """  const _LibraryHeaderActions({
    required this.isImporting,
    required this.sort,
    required this.viewMode,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onSearch,
    required this.onImport,
    required this.onImportFolder,
  });

  final bool isImporting;
  final LibrarySort sort;
  final LibraryViewMode viewMode;
  final ValueChanged<LibrarySort> onSortChanged;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final VoidCallback onSearch;
  final VoidCallback onImport;
  final VoidCallback onImportFolder;
"""
new_header_ctor = """  const _LibraryHeaderActions({
    required this.isImporting,
    required this.sort,
    required this.viewMode,
    required this.gridSize,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onGridSizeChanged,
    required this.onSearch,
    required this.onImport,
    required this.onImportFolder,
  });

  final bool isImporting;
  final LibrarySort sort;
  final LibraryViewMode viewMode;
  final LibraryGridSize gridSize;
  final ValueChanged<LibrarySort> onSortChanged;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final ValueChanged<LibraryGridSize> onGridSizeChanged;
  final VoidCallback onSearch;
  final VoidCallback onImport;
  final VoidCallback onImportFolder;
"""
if old_header_ctor not in text:
    raise SystemExit("header ctor not found")
text = text.replace(old_header_ctor, new_header_ctor, 1)

old_view_menu = """        PopupMenuButton<LibraryViewMode>(
          tooltip: '视图',
          initialValue: viewMode,
          onSelected: onViewModeChanged,
          itemBuilder: (context) => viewMenuItems,
          icon: compact ? Icon(_viewModeIcon(viewMode)) : null,
          child: compact
              ? null
              : _HeaderMenuChip(
                  icon: _viewModeIcon(viewMode),
                  label: viewMode.label,
                ),
        ),
"""
new_view_menu = """        PopupMenuButton<LibraryViewMode>(
          tooltip: '视图',
          initialValue: viewMode,
          onSelected: onViewModeChanged,
          itemBuilder: (context) => viewMenuItems,
          icon: compact ? Icon(_viewModeIcon(viewMode)) : null,
          child: compact
              ? null
              : _HeaderMenuChip(
                  icon: _viewModeIcon(viewMode),
                  label: viewMode.label,
                ),
        ),
        if (viewMode == LibraryViewMode.grid)
          PopupMenuButton<LibraryGridSize>(
            tooltip: '封面大小',
            initialValue: gridSize,
            onSelected: onGridSizeChanged,
            itemBuilder: (context) => LibraryGridSize.values
                .map(
                  (size) => PopupMenuItem(
                    value: size,
                    child: Text('封面${size.label}'),
                  ),
                )
                .toList(growable: false),
            icon: compact ? const Icon(Icons.photo_size_select_large_outlined) : null,
            child: compact
                ? null
                : _HeaderMenuChip(
                    icon: Icons.photo_size_select_large_outlined,
                    label: '封面${gridSize.label}',
                  ),
          ),
"""
if old_view_menu not in text:
    raise SystemExit("view menu block not found")
text = text.replace(old_view_menu, new_view_menu, 1)

# Pass gridSize into header call sites
text = text.replace(
"""                      _LibraryHeaderActions(
                        isImporting: _isImporting,
                        sort: libraryState.sort,
                        viewMode: libraryState.viewMode,
                        onSortChanged: libraryController.setSort,
                        onViewModeChanged: libraryController.setViewMode,
                        onSearch: () => context.go('/search'),
                        onImport: () => _pickAndImport(context),
                        onImportFolder: () => _pickAndImportFolder(context),
                      ),
""",
"""                      _LibraryHeaderActions(
                        isImporting: _isImporting,
                        sort: libraryState.sort,
                        viewMode: libraryState.viewMode,
                        gridSize: libraryState.gridSize,
                        onSortChanged: libraryController.setSort,
                        onViewModeChanged: libraryController.setViewMode,
                        onGridSizeChanged: libraryController.setGridSize,
                        onSearch: () => context.go('/search'),
                        onImport: () => _pickAndImport(context),
                        onImportFolder: () => _pickAndImportFolder(context),
                      ),
""",
)

# two occurrences - empty and non-empty; replace_all
# already did one pattern twice? use replace without count for both identical blocks
# The second header is slightly different indent with same fields - already covered if identical

# Fix subtitle to show grid size when grid
text = text.replace(
"""                  subtitle:
                      '${visibleBooks.length} 本 · ${libraryState.sort.label} · ${libraryState.viewMode.label}',
""",
"""                  subtitle:
                      '${visibleBooks.length} 本 · ${libraryState.sort.label} · ${libraryState.viewMode.label}'
                      '${libraryState.viewMode == LibraryViewMode.grid ? ' · 封面${libraryState.gridSize.label}' : ''}',
""",
)

# FilteredLibraryContent pass gridSize
old_filtered_call = """                  child: _FilteredLibraryContent(
                    books: visibleBooks,
                    selectedTagId: libraryState.tagId,
                    hasNotesOnly: libraryState.hasNotesOnly,
                    hasBookmarksOnly: libraryState.hasBookmarksOnly,
                    selectedBookId: libraryState.selectedBookId,
                    viewMode: libraryState.viewMode,
                    onBookSelected: libraryController.selectBook,
                    filters: _LibraryFilters(
"""
new_filtered_call = """                  child: _FilteredLibraryContent(
                    books: visibleBooks,
                    selectedTagId: libraryState.tagId,
                    hasNotesOnly: libraryState.hasNotesOnly,
                    hasBookmarksOnly: libraryState.hasBookmarksOnly,
                    selectedBookId: libraryState.selectedBookId,
                    viewMode: libraryState.viewMode,
                    gridSize: libraryState.gridSize,
                    onBookSelected: libraryController.selectBook,
                    filters: _LibraryFilters(
"""
if old_filtered_call not in text:
    raise SystemExit("filtered call not found")
text = text.replace(old_filtered_call, new_filtered_call, 1)

# Update _FilteredLibraryContent class fields
old_fl = """  const _FilteredLibraryContent({
    required this.books,
    required this.selectedTagId,
    required this.hasNotesOnly,
    required this.hasBookmarksOnly,
    required this.selectedBookId,
    required this.viewMode,
    required this.onBookSelected,
    required this.filters,
  });

  final List<LibraryBook> books;
  final String? selectedTagId;
  final bool hasNotesOnly;
  final bool hasBookmarksOnly;
  final String? selectedBookId;
  final LibraryViewMode viewMode;
  final ValueChanged<String?> onBookSelected;
  final _LibraryFilters filters;
"""
new_fl = """  const _FilteredLibraryContent({
    required this.books,
    required this.selectedTagId,
    required this.hasNotesOnly,
    required this.hasBookmarksOnly,
    required this.selectedBookId,
    required this.viewMode,
    required this.gridSize,
    required this.onBookSelected,
    required this.filters,
  });

  final List<LibraryBook> books;
  final String? selectedTagId;
  final bool hasNotesOnly;
  final bool hasBookmarksOnly;
  final String? selectedBookId;
  final LibraryViewMode viewMode;
  final LibraryGridSize gridSize;
  final ValueChanged<String?> onBookSelected;
  final _LibraryFilters filters;
"""
if old_fl not in text:
    raise SystemExit("filtered class fields not found")
text = text.replace(old_fl, new_fl, 1)

# Pass gridSize into _LibraryContent from filtered content - find occurrences
text = text.replace(
"""        viewMode: widget.viewMode,
        onBookSelected: widget.onBookSelected,
""",
"""        viewMode: widget.viewMode,
        gridSize: widget.gridSize,
        onBookSelected: widget.onBookSelected,
""",
)

# There may be another call without widget.
text = text.replace(
"""          viewMode: widget.viewMode,
          onBookSelected: widget.onBookSelected,
""",
"""          viewMode: widget.viewMode,
          gridSize: widget.gridSize,
          onBookSelected: widget.onBookSelected,
""",
)

# _LibraryContent class
old_lc = """final class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.books,
    required this.selectedBookId,
    required this.viewMode,
    required this.onBookSelected,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final LibraryViewMode viewMode;
  final ValueChanged<String?> onBookSelected;
"""
new_lc = """final class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.books,
    required this.selectedBookId,
    required this.viewMode,
    required this.gridSize,
    required this.onBookSelected,
    this.categoryId,
    this.onOpenFolder,
    this.onBackFromFolder,
    this.folderTitle,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final LibraryViewMode viewMode;
  final LibraryGridSize gridSize;
  final ValueChanged<String?> onBookSelected;
  final String? categoryId;
  final ValueChanged<String?>? onOpenFolder;
  final VoidCallback? onBackFromFolder;
  final String? folderTitle;
"""
if old_lc not in text:
    raise SystemExit("LibraryContent class not found")
text = text.replace(old_lc, new_lc, 1)

# Update LibraryContent build grid branch and add folder chrome
old_lc_build = """  @override
  Widget build(BuildContext context) {
    final expanded = context.appBreakpoint.isExpanded;
    // On phone/tablet, selection panel is not shown — single tap opens the book.
    void handleSelect(String? id) {
      if (expanded) {
        onBookSelected(id);
        return;
      }
      if (id == null) {
        return;
      }
      context.goNamed('reader', pathParameters: {'bookId': id});
    }

    final padding = expanded
        ? const EdgeInsets.fromLTRB(24, 16, 24, 96)
        : const EdgeInsets.fromLTRB(16, 16, 16, 96);

    return switch (viewMode) {
      LibraryViewMode.grid => _BookGrid(
        books: books,
        selectedBookId: expanded ? selectedBookId : null,
        onBookSelected: expanded ? onBookSelected : null,
        padding: padding,
        minTileWidth: expanded ? 150 : null,
        crossAxisCount: expanded
            ? null
            : (context.appBreakpoint.isCompact ? 2 : 3),
      ),
      LibraryViewMode.list => _DesktopLibraryList(
        books: books,
        selectedBookId: expanded ? selectedBookId : null,
        onBookSelected: handleSelect,
        compact: false,
      ),
      LibraryViewMode.compact => _DesktopLibraryList(
        books: books,
        selectedBookId: expanded ? selectedBookId : null,
        onBookSelected: handleSelect,
        compact: true,
      ),
    };
  }
}
"""
new_lc_build = """  @override
  Widget build(BuildContext context) {
    final expanded = context.appBreakpoint.isExpanded;
    // On phone/tablet, selection panel is not shown — single tap opens the book.
    void handleSelect(String? id) {
      if (expanded) {
        onBookSelected(id);
        return;
      }
      if (id == null) {
        return;
      }
      context.goNamed('reader', pathParameters: {'bookId': id});
    }

    final padding = expanded
        ? const EdgeInsets.fromLTRB(24, 16, 24, 96)
        : const EdgeInsets.fromLTRB(16, 16, 16, 96);

    final body = switch (viewMode) {
      LibraryViewMode.grid => _BookGrid(
        books: books,
        selectedBookId: expanded ? selectedBookId : null,
        onBookSelected: expanded ? onBookSelected : null,
        padding: padding,
        minTileWidth: gridSize.minTileWidth,
      ),
      LibraryViewMode.list => _DesktopLibraryList(
        books: books,
        selectedBookId: expanded ? selectedBookId : null,
        onBookSelected: handleSelect,
        compact: false,
      ),
      LibraryViewMode.compact => _DesktopLibraryList(
        books: books,
        selectedBookId: expanded ? selectedBookId : null,
        onBookSelected: handleSelect,
        compact: true,
      ),
    };

    if (onBackFromFolder != null && folderTitle != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onBackFromFolder,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('返回书架'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folderTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${books.length} 本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      );
    }

    return body;
  }
}
"""
if old_lc_build not in text:
    raise SystemExit("LibraryContent build not found")
text = text.replace(old_lc_build, new_lc_build, 1)

# Update BookGrid to prefer minTileWidth always
old_grid_build = """  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final resolvedCount =
        crossAxisCount ??
        (width / (minTileWidth ?? 168)).floor().clamp(2, 6).toInt();
    // Wider cards when fewer columns; keep cover-friendly proportions.
    final aspectRatio = switch (resolvedCount) {
      <= 2 => 0.62,
      3 => 0.58,
      4 => 0.56,
      _ => 0.54,
    };
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: resolvedCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final item = books[index];
        return _BookCard(
          item: item,
          selected: selectedBookId == item.book.id,
          onSelect: onBookSelected,
        );
      },
    );
  }
}
"""
new_grid_build = """  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = (minTileWidth ?? 150).clamp(100, 240).toDouble();
    final resolvedCount =
        crossAxisCount ??
        (width / (tileWidth + 12)).floor().clamp(2, 8).toInt();
    // Wider cards when fewer columns; keep cover-friendly proportions.
    final aspectRatio = switch (resolvedCount) {
      <= 2 => 0.64,
      3 => 0.60,
      4 => 0.57,
      5 => 0.55,
      _ => 0.53,
    };
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: resolvedCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final item = books[index];
        return _BookCard(
          item: item,
          selected: selectedBookId == item.book.id,
          onSelect: onBookSelected,
        );
      },
    );
  }
}
"""
if old_grid_build not in text:
    raise SystemExit("BookGrid build not found")
text = text.replace(old_grid_build, new_grid_build, 1)

# --- Bookshelf folders in FilteredLibraryContentState build ---
# Find where it returns library layout and inject folder-aware body.
# We'll replace the desktop/mobile content construction carefully.

# Add helper widgets before _BookGrid
folder_widgets = """
final class _BookshelfFoldersStrip extends ConsumerWidget {
  const _BookshelfFoldersStrip({
    required this.books,
    required this.onOpenFolder,
    required this.onCreateFolder,
  });

  final List<LibraryBook> books;
  final ValueChanged<String?> onOpenFolder;
  final Future<BookCategory?> Function() onCreateFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      data: (categories) {
        final counts = <String?, int>{};
        for (final item in books) {
          final key = item.book.categoryId;
          counts[key] = (counts[key] ?? 0) + 1;
        }
        final uncategorized = counts[null] ?? 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '书架文件夹',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final category = await onCreateFolder();
                      if (category != null) {
                        onOpenFolder(category.id);
                      }
                    },
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('新建'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FolderCard(
                      title: '未分类',
                      subtitle: '$uncategorized 本',
                      icon: Icons.folder_off_outlined,
                      onTap: () => onOpenFolder('__uncategorized__'),
                    ),
                    ...categories.map(
                      (category) => _FolderCard(
                        title: category.name,
                        subtitle: '${counts[category.id] ?? 0} 本',
                        icon: Icons.folder_outlined,
                        onTap: () => onOpenFolder(category.id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '全部书籍',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

final class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colorScheme.appBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: SizedBox(
            width: 132,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: colorScheme.primary),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

"""

if "final class _BookshelfFoldersStrip" not in text:
    anchor = "final class _BookGrid extends StatelessWidget {"
    if anchor not in text:
        raise SystemExit("BookGrid anchor missing")
    text = text.replace(anchor, folder_widgets + anchor, 1)

# Wire folder strip into filtered content state build.
# Locate desktop layout where LibraryContent is returned and wrap.
# Easier approach: modify _FilteredLibraryContentState to pass category/back/folder props.

# Find filters usage in filtered content state - read pattern around LibraryContent(
# There are likely 2 call sites in filtered content.

# Add category props when creating LibraryContent from filters
# Search for: _LibraryContent(
# and inject after books/selected/viewMode

# Since we already require gridSize, also require category fields at call sites.

# In FilteredLibraryContentState, filters has categoryId. Use that.

import re

# Replace all _LibraryContent( constructors that include gridSize
# First ensure call sites have gridSize already; then add folder params.

def enrich_library_content_calls(src: str) -> str:
    pattern = re.compile(
        r"_LibraryContent\(\n(?P<body>.*?)\n(?P<indent>\s*)\)",
        re.S,
    )

    def repl(m: re.Match) -> str:
        body = m.group("body")
        indent = m.group("indent")
        if "gridSize:" not in body:
            return m.group(0)
        if "onOpenFolder:" in body:
            return m.group(0)
        # Determine if this is widget.filters context
        extra = (
            f",\n{indent}  categoryId: widget.filters.categoryId,"
            f"\n{indent}  folderTitle: _folderTitle(widget.filters.categoryId),"
            f"\n{indent}  onOpenFolder: widget.filters.onCategoryChanged,"
            f"\n{indent}  onBackFromFolder: widget.filters.categoryId == null\n"
            f"{indent}      ? null\n"
            f"{indent}      : () => widget.filters.onCategoryChanged(null),"
        )
        # insert before last field line by appending before closing
        return f"_LibraryContent(\n{body}{extra}\n{indent})"

    return pattern.sub(repl, src)

text = enrich_library_content_calls(text)

# Add helper method on filtered content state class
helper = """
  String? _folderTitle(String? categoryId) {
    if (categoryId == null) {
      return null;
    }
    if (categoryId == '__uncategorized__') {
      return '未分类';
    }
    final categories = ref.read(categoriesProvider).value;
    if (categories == null) {
      return '文件夹';
    }
    for (final category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return '文件夹';
  }
"""

state_class = "final class _FilteredLibraryContentState"
idx = text.find(state_class)
if idx < 0:
    raise SystemExit("filtered state class missing")
# insert helper before end of class is hard; insert after first method or before build
build_idx = text.find("  @override\n  Widget build(BuildContext context) {", idx)
if build_idx < 0:
    raise SystemExit("filtered state build missing")
if "_folderTitle(" not in text[idx:idx+5000]:
    text = text[:build_idx] + helper + "\n" + text[build_idx:]

# Show folders strip above content when browsing root.
# In _LibraryContent we currently only show back bar in folder. For root grid, wrap with folders strip outside.
# Better: in filtered content layout, when categoryId null and system all, show strip above LibraryContent.

# Patch the return of desktop/mobile bodies is complex. Simpler: change _LibraryContent root body for grid when categoryId==null.
# Update new_lc_build's final return for root:
old_return_body = """    if (onBackFromFolder != null && folderTitle != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onBackFromFolder,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('返回书架'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folderTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${books.length} 本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      );
    }

    return body;
  }
}
"""
new_return_body = """    if (onBackFromFolder != null && folderTitle != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onBackFromFolder,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('返回书架'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folderTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${books.length} 本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      );
    }

    // Root bookshelf: show folder cards above books (WeChat Read style).
    if (categoryId == null && onOpenFolder != null && viewMode == LibraryViewMode.grid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BookshelfFoldersStrip(
            books: books,
            onOpenFolder: onOpenFolder!,
            onCreateFolder: () => _createLibraryCategory(
              // ignore: use_build_context_synchronously
              context,
              // ProviderScope is available through context.
              ProviderScope.containerOf(context) as dynamic,
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return body;
  }
}
"""
# The create folder callback is awkward with ProviderScope. Better pass a callback from parent.

# Fix: change onCreateFolder to VoidCallback that parent handles, or ValueGetter.
# Simpler: folders strip only needs onCreateFolder Future from parent.

# Revert complex create and instead pass onCreateFolder from filters.

# Update LibraryContent fields again: replace onCreate via parent.
# Actually change strip to take Future<void> Function()? onCreateFolder that opens dialog via parent.

# Let's simplify root strip create button to call onOpenFolder after parent creates.
# Change strip API:
# onCreateFolder: Future<void> Function()

# Rewrite folder strip create to callback Future<BookCategory?> Function(BuildContext)

# Patch the awkward part out if we inserted it, by rewriting LibraryContent return again carefully.

# First fix LibraryContent root section to not use ProviderScope.
if "ProviderScope.containerOf" in text:
    text = text.replace(
"""    // Root bookshelf: show folder cards above books (WeChat Read style).
    if (categoryId == null && onOpenFolder != null && viewMode == LibraryViewMode.grid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BookshelfFoldersStrip(
            books: books,
            onOpenFolder: onOpenFolder!,
            onCreateFolder: () => _createLibraryCategory(
              // ignore: use_build_context_synchronously
              context,
              // ProviderScope is available through context.
              ProviderScope.containerOf(context) as dynamic,
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return body;
""",
"""    // Root bookshelf: show folder cards above books (WeChat Read style).
    if (categoryId == null &&
        onOpenFolder != null &&
        onCreateFolder != null &&
        viewMode == LibraryViewMode.grid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BookshelfFoldersStrip(
            books: books,
            onOpenFolder: onOpenFolder!,
            onCreateFolder: onCreateFolder!,
          ),
          Expanded(child: body),
        ],
      );
    }

    return body;
""",
    )

# Ensure onCreateFolder field exists on LibraryContent
if "final Future<BookCategory?> Function()? onCreateFolder;" not in text:
    text = text.replace(
        "  final VoidCallback? onBackFromFolder;\n  final String? folderTitle;\n",
        "  final VoidCallback? onBackFromFolder;\n  final String? folderTitle;\n  final Future<BookCategory?> Function()? onCreateFolder;\n",
        1,
    )
    text = text.replace(
        "    this.onBackFromFolder,\n    this.folderTitle,\n  });\n",
        "    this.onBackFromFolder,\n    this.folderTitle,\n    this.onCreateFolder,\n  });\n",
        1,
    )

# Add onCreateFolder to call sites enrichment if missing
if "onCreateFolder:" not in text:
    text = text.replace(
        "  onBackFromFolder: widget.filters.categoryId == null\n      ? null\n      : () => widget.filters.onCategoryChanged(null),",
        "  onBackFromFolder: widget.filters.categoryId == null\n      ? null\n      : () => widget.filters.onCategoryChanged(null),\n  onCreateFolder: () => _createLibraryCategory(context, ref),",
    )

# Ensure import for library_controller grid size is available - it's in same package via library_controller export?
# library_page imports library_controller? check
if "library_controller.dart" not in text:
    # likely imports library_providers and controller via relative
    if "import '../application/library_controller.dart';" not in text:
        text = text.replace(
            "import '../application/library_providers.dart';",
            "import '../application/library_controller.dart';\nimport '../application/library_providers.dart';",
            1,
        )

# Sidebar labels: 分类 -> 书架 for user-facing
text = text.replace("label: '分类',", "label: '书架',")
text = text.replace("tooltip: '新建分类',", "tooltip: '新建书架文件夹',")
text = text.replace("label: '全部分类',", "label: '全部书架',")
text = text.replace("title: Text('移动到分类'),", "title: Text('移动到书架文件夹'),")
text = text.replace("title: const Text('移动到分类'),", "title: const Text('移动到书架文件夹'),")

path.write_text(text, encoding="utf-8")
print("library grid size + bookshelf folders patched")
