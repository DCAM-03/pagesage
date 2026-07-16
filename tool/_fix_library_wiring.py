# -*- coding: utf-8 -*-
from pathlib import Path
import re

path = Path("lib/features/library/presentation/library_page.dart")
text = path.read_text(encoding="utf-8")

# Fix remaining header without gridSize
text = text.replace(
    """                    _LibraryHeaderActions(
                      isImporting: _isImporting,
                      sort: libraryState.sort,
                      viewMode: libraryState.viewMode,
                      onSortChanged: libraryController.setSort,
                      onViewModeChanged: libraryController.setViewMode,
                      onSearch: () => context.go('/search'),
                      onImport: () => _pickAndImport(context),
                      onImportFolder: () => _pickAndImportFolder(context),
                    ),""",
    """                    _LibraryHeaderActions(
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
                    ),""",
)

old = """final class _LibraryWithFilters extends StatelessWidget {
  const _LibraryWithFilters({
    required this.books,
    required this.selectedBookId,
    required this.viewMode,
    required this.onBookSelected,
    required this.filters,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final LibraryViewMode viewMode;
  final ValueChanged<String?> onBookSelected;
  final _LibraryFilters filters;

  @override
  Widget build(BuildContext context) {
    final content = books.isEmpty
        ? const _NoFilteredBooks()
        : _LibraryContent(
            books: books,
            selectedBookId: selectedBookId,
            viewMode: viewMode,
            onBookSelected: onBookSelected,
          );
"""

new = """final class _LibraryWithFilters extends ConsumerWidget {
  const _LibraryWithFilters({
    required this.books,
    required this.selectedBookId,
    required this.viewMode,
    required this.gridSize,
    required this.onBookSelected,
    required this.filters,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final LibraryViewMode viewMode;
  final LibraryGridSize gridSize;
  final ValueChanged<String?> onBookSelected;
  final _LibraryFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    String? folderTitle;
    final categoryId = filters.categoryId;
    if (categoryId == '__uncategorized__') {
      folderTitle = '未分类';
    } else if (categoryId != null) {
      for (final category in categories) {
        if (category.id == categoryId) {
          folderTitle = category.name;
          break;
        }
      }
      folderTitle ??= '书架文件夹';
    }

    final content = books.isEmpty
        ? const _NoFilteredBooks()
        : _LibraryContent(
            books: books,
            selectedBookId: selectedBookId,
            viewMode: viewMode,
            gridSize: gridSize,
            onBookSelected: onBookSelected,
            categoryId: categoryId,
            folderTitle: folderTitle,
            onOpenFolder: filters.onCategoryChanged,
            onBackFromFolder: categoryId == null
                ? null
                : () => filters.onCategoryChanged(null),
            onCreateFolder: () => _createLibraryCategory(context, ref),
          );
"""

if old not in text:
    raise SystemExit("LibraryWithFilters block not found")
text = text.replace(old, new, 1)

text = text.replace(
    """      return _LibraryWithFilters(
        books: widget.books,
        selectedBookId: widget.selectedBookId,
        viewMode: widget.viewMode,
        onBookSelected: widget.onBookSelected,
        filters: widget.filters,
      );
""",
    """      return _LibraryWithFilters(
        books: widget.books,
        selectedBookId: widget.selectedBookId,
        viewMode: widget.viewMode,
        gridSize: widget.gridSize,
        onBookSelected: widget.onBookSelected,
        filters: widget.filters,
      );
""",
)

text = text.replace(
    """        return _LibraryWithFilters(
          books: books,
          selectedBookId: widget.selectedBookId,
          viewMode: widget.viewMode,
          onBookSelected: widget.onBookSelected,
          filters: widget.filters,
        );
""",
    """        return _LibraryWithFilters(
          books: books,
          selectedBookId: widget.selectedBookId,
          viewMode: widget.viewMode,
          gridSize: widget.gridSize,
          onBookSelected: widget.onBookSelected,
          filters: widget.filters,
        );
""",
)

pat = re.compile(
    r"    if \(onBackFromFolder != null && folderTitle != null\) \{.*?\n    return body;\n  \}\n\}\n",
    re.S,
)
if not pat.search(text):
    raise SystemExit("LibraryContent return block not found")
repl = """    if (onBackFromFolder != null && folderTitle != null) {
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
  }
}
"""
text = pat.sub(repl, text, count=1)

# Cleanup unused _folderTitle helper if present
text = re.sub(
    r"\n  String\? _folderTitle\(String\? categoryId\) \{.*?\n  \}\n",
    "\n",
    text,
    count=1,
    flags=re.S,
)

path.write_text(text, encoding="utf-8")
print("fixed")
