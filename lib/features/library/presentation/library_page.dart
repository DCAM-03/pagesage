import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/platform/platform_providers.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/bookmark.dart';
import '../../../domain/books/category.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/books/tag.dart';
import '../../import/application/import_intent.dart';
import '../../import/application/import_providers.dart';
import '../../import/application/import_result.dart';
import '../application/library_controller.dart';
import '../application/library_providers.dart';

final class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

final class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _isImporting = false;
  late final _dropImportService = ref.read(windowDropImportServiceProvider);

  @override
  void initState() {
    super.initState();
    _dropImportService.start(_importDroppedFiles);
    // Handle an import intent that may already be pending when this page mounts
    // (e.g. user pressed Import from another shell page).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleImportIntent();
    });
  }

  @override
  void dispose() {
    _dropImportService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subsequent import intents while the library stays mounted. The callback
    // only reacts to a fresh request (0 -> N); the value is consumed below.
    ref.listen(importIntentProvider, (previous, next) {
      if (next == 0 || next == previous) return;
      _handleImportIntent();
    });
    final books = ref.watch(libraryBooksProvider);
    final libraryState = ref.watch(libraryControllerProvider);
    final libraryController = ref.read(libraryControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: books.when(
          data: (items) {
            if (items.isEmpty) {
              return Column(
                children: [
                  AppPageHeader(
                    title: '书库',
                    subtitle: '本地 EPUB/PDF 阅读库',
                    showThemeMode: true,
                    actions: [
                      _LibraryHeaderActions(
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
                    ],
                  ),
                  Expanded(
                    child: _EmptyLibrary(
                      isImporting: _isImporting,
                      onImport: () => _pickAndImport(context),
                      onImportFolder: () => _pickAndImportFolder(context),
                    ),
                  ),
                ],
              );
            }
            final visibleBooks = sortLibraryBooks(
              filterLibraryBooks(
                items,
                systemFilter: libraryState.systemFilter,
                format: libraryState.format,
                categoryId: libraryState.categoryId,
              ),
              libraryState.sort,
            );
            return Column(
              children: [
                AppPageHeader(
                  title: '书库',
                  showThemeMode: true,
                  subtitle:
                      '${visibleBooks.length} 本 · ${libraryState.sort.label} · ${libraryState.viewMode.label}'
                      '${libraryState.viewMode == LibraryViewMode.grid ? ' · 封面${libraryState.gridSize.label}' : ''}',
                  actions: [
                    _LibraryHeaderActions(
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
                  ],
                ),
                Expanded(
                  child: _FilteredLibraryContent(
                    books: visibleBooks,
                    selectedTagId: libraryState.tagId,
                    hasNotesOnly: libraryState.hasNotesOnly,
                    hasBookmarksOnly: libraryState.hasBookmarksOnly,
                    selectedBookId: libraryState.selectedBookId,
                    viewMode: libraryState.viewMode,
                    gridSize: libraryState.gridSize,
                    onBookSelected: libraryController.selectBook,
                    filters: _LibraryFilters(
                      systemFilter: libraryState.systemFilter,
                      format: libraryState.format,
                      categoryId: libraryState.categoryId,
                      tagId: libraryState.tagId,
                      hasNotesOnly: libraryState.hasNotesOnly,
                      hasBookmarksOnly: libraryState.hasBookmarksOnly,
                      onSystemChanged: libraryController.setSystemFilter,
                      onFormatChanged: libraryController.setFormat,
                      onCategoryChanged: libraryController.setCategory,
                      onTagChanged: libraryController.setTag,
                      onHasNotesChanged: libraryController.setHasNotesOnly,
                      onHasBookmarksChanged:
                          libraryController.setHasBookmarksOnly,
                      onClear: libraryController.clearFilters,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Column(
            children: [
              AppPageHeader(title: '书库', subtitle: '正在读取本地书库'),
              Expanded(child: _LibraryLoadingState()),
            ],
          ),
          error: (error, stackTrace) => Column(
            children: [
              const AppPageHeader(title: '书库', subtitle: '本地 EPUB/PDF 阅读库'),
              Expanded(
                child: _LibraryError(
                  message: '无法读取书库',
                  onRetry: () => ref.invalidate(libraryBooksProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndImport(BuildContext context) async {
    setState(() => _isImporting = true);
    try {
      final result = await ref.read(importUseCaseProvider).pickAndImportMany();
      if (!context.mounted) {
        return;
      }
      await _handleImportBooksResult(context, result);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
        // Drain a request that arrived while the previous import was busy.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleImportIntent();
          }
        });
      }
    }
  }

  Future<void> _pickAndImportFolder(BuildContext context) async {
    setState(() => _isImporting = true);
    try {
      final result = await ref
          .read(importUseCaseProvider)
          .pickAndImportFolder();
      if (!context.mounted) {
        return;
      }
      if (result.cancelled) {
        return;
      }
      if (result.successes.isEmpty &&
          result.duplicates.isEmpty &&
          result.failures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该文件夹中没有找到 EPUB 或 PDF 文件')),
        );
        return;
      }
      await _handleImportBooksResult(context, result);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// Opens the picker if a request is pending and nothing else is importing.
  ///
  /// The request is consumed here, so navigating to the library later does not
  /// replay it: a pending value only ever covers the current mount.
  void _handleImportIntent() {
    if (_isImporting) {
      // Leave the intent pending until the current import finishes.
      return;
    }
    if (ref.read(importIntentProvider.notifier).take() == null) {
      return;
    }
    if (mounted) {
      _pickAndImport(context);
    }
  }

  Future<void> _importDroppedFiles(List<String> paths) async {
    if (_isImporting || !mounted) {
      return;
    }
    final validPaths = paths
        .where((path) => _isSupportedBookPath(path))
        .toList(growable: false);
    final invalidCount = paths.length - validPaths.length;
    if (validPaths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请拖入 EPUB 或 PDF 文件')));
      return;
    }
    setState(() => _isImporting = true);
    try {
      final successes = <Book>[];
      final duplicates = <ImportBookDuplicate>[];
      final failures = <ImportBookFailure>[
        if (invalidCount > 0)
          ImportBookFailure('已跳过 $invalidCount 个非 EPUB/PDF 文件'),
      ];
      for (final path in validPaths) {
        final result = await ref.read(importUseCaseProvider).importPath(path);
        switch (result) {
          case ImportBookSuccess(:final book):
            successes.add(book);
          case ImportBookDuplicate():
            duplicates.add(result);
          case ImportBookFailure():
            failures.add(result);
          case ImportBookCancelled():
            break;
        }
      }
      if (!mounted) {
        return;
      }
      await _handleImportBooksResult(
        context,
        ImportBooksResult(
          successes: successes,
          duplicates: duplicates,
          failures: failures,
          cancelled: false,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  bool _isSupportedBookPath(String path) {
    final extension = p.extension(path).toLowerCase();
    return extension == '.epub' || extension == '.pdf';
  }

  Future<void> _handleImportBooksResult(
    BuildContext context,
    ImportBooksResult result,
  ) async {
    if (result.cancelled) {
      return;
    }
    if (result.total == 1 && result.successes.length == 1) {
      await _handleImportResult(
        context,
        ImportBookSuccess(result.successes.single),
      );
      return;
    }
    if (result.total == 1 && result.duplicates.length == 1) {
      final duplicate = result.duplicates.single;
      await _showDuplicateDialog(
        context,
        duplicate.existingBook,
        duplicate.sourcePath,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        duration: const Duration(seconds: 5),
        content: Text(
          '导入完成：成功 ${result.successes.length}，重复 ${result.duplicates.length}，失败 ${result.failures.length}',
        ),
        action: result.successes.isNotEmpty
            ? SnackBarAction(
                label: '打开',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  context.goNamed(
                    'reader',
                    pathParameters: {'bookId': result.successes.first.id},
                  );
                },
              )
            : result.duplicates.isNotEmpty
            ? SnackBarAction(
                label: '打开已有',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  context.goNamed(
                    'reader',
                    pathParameters: {
                      'bookId': result.duplicates.first.existingBook.id,
                    },
                  );
                },
              )
            : null,
      ),
    );
  }

  Future<void> _handleImportResult(
    BuildContext context,
    ImportBookResult result,
  ) async {
    switch (result) {
      case ImportBookCancelled():
        return;
      case ImportBookSuccess(:final book):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            showCloseIcon: true,
            content: Text('已导入《${book.title}》'),
            action: SnackBarAction(
              label: '打开',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.goNamed('reader', pathParameters: {'bookId': book.id});
              },
            ),
          ),
        );
      case ImportBookDuplicate(:final existingBook, :final sourcePath):
        await _showDuplicateDialog(context, existingBook, sourcePath);
      case ImportBookFailure(:final message):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showDuplicateDialog(
    BuildContext context,
    Book existingBook,
    String sourcePath,
  ) async {
    final action = await showDialog<_DuplicateAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('这本书已经在书库中'),
          content: Text('《${existingBook.title}》已经导入。'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_DuplicateAction.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_DuplicateAction.copy),
              child: const Text('仍然导入副本'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_DuplicateAction.openExisting),
              child: const Text('打开已有书籍'),
            ),
          ],
        );
      },
    );

    if (!context.mounted ||
        action == null ||
        action == _DuplicateAction.cancel) {
      return;
    }

    if (action == _DuplicateAction.openExisting) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.goNamed('reader', pathParameters: {'bookId': existingBook.id});
      return;
    }

    setState(() => _isImporting = true);
    try {
      final result = await ref
          .read(importUseCaseProvider)
          .importPath(sourcePath, allowDuplicate: true);
      if (context.mounted) {
        await _handleImportResult(context, result);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}

enum _DuplicateAction { openExisting, copy, cancel }

final class _LibraryHeaderActions extends StatelessWidget {
  const _LibraryHeaderActions({
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

  @override
  Widget build(BuildContext context) {
    final compact = context.appBreakpoint.isCompact;
    final sortMenuItems = LibrarySort.values
        .map((sort) => PopupMenuItem(value: sort, child: Text(sort.label)))
        .toList(growable: false);
    final viewMenuItems = LibraryViewMode.values
        .map(
          (mode) => PopupMenuItem(
            value: mode,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_viewModeIcon(mode)),
              title: Text(mode.label),
            ),
          ),
        )
        .toList(growable: false);

    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      alignment: WrapAlignment.end,
      children: [
        Tooltip(
          message: '搜索书库和正文',
          child: compact
              ? IconButton(
                  tooltip: '搜索',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                )
              : OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('搜索'),
                ),
        ),
        PopupMenuButton<LibrarySort>(
          tooltip: '排序',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (context) => sortMenuItems,
          icon: compact ? const Icon(Icons.sort) : null,
          child: compact
              ? null
              : _HeaderMenuChip(icon: Icons.sort, label: sort.label),
        ),
        PopupMenuButton<LibraryViewMode>(
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
                  (size) => CheckedPopupMenuItem<LibraryGridSize>(
                    value: size,
                    checked: size == gridSize,
                    child: Text('封面${size.label}'),
                  ),
                )
                .toList(growable: false),
            icon: compact
                ? const Icon(Icons.photo_size_select_large_outlined)
                : null,
            child: compact
                ? null
                : _HeaderMenuChip(
                    icon: Icons.photo_size_select_large_outlined,
                    label: '封面${gridSize.label}',
                  ),
          ),
        if (compact) ...[
          IconButton(
            key: const ValueKey('header-import-books-button'),
            tooltip: '导入 EPUB/PDF',
            onPressed: isImporting ? null : onImport,
            icon: isImporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
          ),
          IconButton(
            key: const ValueKey('header-import-folder-button'),
            tooltip: '扫描文件夹',
            onPressed: isImporting ? null : onImportFolder,
            icon: const Icon(Icons.folder_open_outlined),
          ),
        ] else ...[
          FilledButton.icon(
            key: const ValueKey('header-import-books-button'),
            onPressed: isImporting ? null : onImport,
            icon: isImporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file, size: 18),
            label: const Text('导入'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('header-import-folder-button'),
            onPressed: isImporting ? null : onImportFolder,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('扫描文件夹'),
          ),
        ],
      ],
    );
  }
}

final class _HeaderMenuChip extends StatelessWidget {
  const _HeaderMenuChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

final class _FilteredLibraryContent extends ConsumerStatefulWidget {
  const _FilteredLibraryContent({
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

  @override
  ConsumerState<_FilteredLibraryContent> createState() =>
      _FilteredLibraryContentState();
}

final class _FilteredLibraryContentState
    extends ConsumerState<_FilteredLibraryContent> {
  Future<List<LibraryBook>>? _future;
  String? _futureKey;
  List<LibraryBook>? _lastFilteredBooks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant _FilteredLibraryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books ||
        oldWidget.selectedTagId != widget.selectedTagId ||
        oldWidget.hasNotesOnly != widget.hasNotesOnly ||
        oldWidget.hasBookmarksOnly != widget.hasBookmarksOnly) {
      _ensureFuture(force: true);
    }
  }

  void _ensureFuture({bool force = false}) {
    if (widget.selectedTagId == null &&
        !widget.hasNotesOnly &&
        !widget.hasBookmarksOnly) {
      _future = null;
      _futureKey = null;
      _lastFilteredBooks = widget.books;
      return;
    }
    final key =
        '${widget.selectedTagId}|${widget.hasNotesOnly}|${widget.hasBookmarksOnly}|${widget.books.map((item) => item.book.id).join(',')}';
    if (!force && key == _futureKey && _future != null) {
      return;
    }
    _futureKey = key;
    _future = _applyAsyncFilters(ref, widget.books);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedTagId == null &&
        !widget.hasNotesOnly &&
        !widget.hasBookmarksOnly) {
      return _LibraryWithFilters(
        books: widget.books,
        selectedBookId: widget.selectedBookId,
        viewMode: widget.viewMode,
        gridSize: widget.gridSize,
        onBookSelected: widget.onBookSelected,
        filters: widget.filters,
      );
    }
    return FutureBuilder<List<LibraryBook>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _lastFilteredBooks = snapshot.data;
        }
        final books = snapshot.data ?? _lastFilteredBooks;
        if (books == null) {
          return Column(
            children: [
              widget.filters,
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }
        return _LibraryWithFilters(
          books: books,
          selectedBookId: widget.selectedBookId,
          viewMode: widget.viewMode,
          gridSize: widget.gridSize,
          onBookSelected: widget.onBookSelected,
          filters: widget.filters,
        );
      },
    );
  }

  Future<List<LibraryBook>> _applyAsyncFilters(
    WidgetRef ref,
    List<LibraryBook> books,
  ) async {
    final tagId = widget.selectedTagId;
    final Set<String>? booksWithTag = tagId == null
        ? null
        : await ref.read(tagRepositoryProvider).getBookIdsWithTag(tagId);
    final Set<String>? booksWithNotes = widget.hasNotesOnly
        ? await ref.read(noteRepositoryProvider).getBookIdsWithNotes()
        : null;
    final Set<String>? booksWithBookmarks = widget.hasBookmarksOnly
        ? await ref.read(bookmarkRepositoryProvider).getBookIdsWithBookmarks()
        : null;

    return books
        .where((item) {
          final id = item.book.id;
          if (booksWithTag != null && !booksWithTag.contains(id)) {
            return false;
          }
          if (booksWithNotes != null && !booksWithNotes.contains(id)) {
            return false;
          }
          if (booksWithBookmarks != null && !booksWithBookmarks.contains(id)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}

final class _LibraryWithFilters extends ConsumerWidget {
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
    final content = books.isEmpty
        ? const _NoFilteredBooks()
        : _LibraryContent(
            books: books,
            selectedBookId: selectedBookId,
            viewMode: viewMode,
            gridSize: gridSize,
            onBookSelected: onBookSelected,
            categoryId: filters.categoryId,
            onOpenFolder: filters.onCategoryChanged,
            onBackFromFolder: filters.categoryId == null
                ? null
                : () => filters.onCategoryChanged(null),
            folderTitle: _resolveFolderTitle(filters.categoryId, categories),
            onCreateFolder: () => _createLibraryCategory(context, ref),
          );
    final selectedBook = _findLibraryBook(books, selectedBookId);

    if (context.appBreakpoint.isExpanded) {
      return Row(
        children: [
          SizedBox(
            width: 248,
            child: _DesktopCategoryTree(
              systemFilter: filters.systemFilter,
              categoryId: filters.categoryId,
              onSystemChanged: filters.onSystemChanged,
              onCategoryChanged: filters.onCategoryChanged,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _LibraryFilters(
                  systemFilter: filters.systemFilter,
                  categoryId: filters.categoryId,
                  format: filters.format,
                  tagId: filters.tagId,
                  hasNotesOnly: filters.hasNotesOnly,
                  hasBookmarksOnly: filters.hasBookmarksOnly,
                  onSystemChanged: filters.onSystemChanged,
                  onFormatChanged: filters.onFormatChanged,
                  onCategoryChanged: filters.onCategoryChanged,
                  onTagChanged: filters.onTagChanged,
                  onHasNotesChanged: filters.onHasNotesChanged,
                  onHasBookmarksChanged: filters.onHasBookmarksChanged,
                  onClear: filters.onClear,
                  showSystemFilters: false,
                  showCategoryFilter: false,
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: content),
                      if (selectedBook != null) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 340,
                          child: AppSidePanel(
                            title: '书籍详情',
                            child: _BookDetailsPanel(item: selectedBook),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        filters,
        Expanded(child: content),
      ],
    );
  }
}

String? _resolveFolderTitle(String? categoryId, List<BookCategory> categories) {
  if (categoryId == null) {
    return null;
  }
  if (categoryId == '__uncategorized__') {
    return '未分类';
  }
  for (final category in categories) {
    if (category.id == categoryId) {
      return category.name;
    }
  }
  return '书架文件夹';
}

final class _LibraryFilters extends ConsumerWidget {
  const _LibraryFilters({
    required this.systemFilter,
    required this.format,
    required this.categoryId,
    required this.tagId,
    required this.hasNotesOnly,
    required this.hasBookmarksOnly,
    required this.onSystemChanged,
    required this.onFormatChanged,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onHasNotesChanged,
    required this.onHasBookmarksChanged,
    required this.onClear,
    this.showSystemFilters = true,
    this.showCategoryFilter = true,
  });

  final LibrarySystemFilter systemFilter;
  final BookFormat? format;
  final String? categoryId;
  final String? tagId;
  final bool hasNotesOnly;
  final bool hasBookmarksOnly;
  final ValueChanged<LibrarySystemFilter> onSystemChanged;
  final ValueChanged<BookFormat?> onFormatChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<bool> onHasNotesChanged;
  final ValueChanged<bool> onHasBookmarksChanged;
  final VoidCallback onClear;
  final bool showSystemFilters;
  final bool showCategoryFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(tagsProvider);
    if (context.appBreakpoint.isCompact) {
      return _MobileLibraryFilters(
        systemFilter: systemFilter,
        format: format,
        categoryId: categoryId,
        tagId: tagId,
        hasNotesOnly: hasNotesOnly,
        hasBookmarksOnly: hasBookmarksOnly,
        categories: categories.value ?? const <BookCategory>[],
        tags: tags.value ?? const <BookTag>[],
        categoriesLoading: categories.isLoading,
        tagsLoading: tags.isLoading,
        onSystemChanged: onSystemChanged,
        onFormatChanged: onFormatChanged,
        onCategoryChanged: onCategoryChanged,
        onTagChanged: onTagChanged,
        onHasNotesChanged: onHasNotesChanged,
        onHasBookmarksChanged: onHasBookmarksChanged,
        onClear: onClear,
        onCreateCategory: (context) async {
          final category = await _createLibraryCategory(context, ref);
          if (category != null) {
            onCategoryChanged(category.id);
          }
          return category;
        },
      );
    }
    return AppFilterBar(
      children: [
        if (showSystemFilters)
          ...LibrarySystemFilter.values.map(
            (filter) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x2),
              child: FilterChip(
                label: Text(filter.label),
                selected: systemFilter == filter,
                onSelected: (_) => onSystemChanged(filter),
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.x2),
        _FilterMenuButton<BookFormat?>(
          icon: Icons.description_outlined,
          label: format == null ? '格式' : formatBookFormat(format!),
          onClear: format == null ? null : () => onFormatChanged(null),
          entries: [
            const PopupMenuItem<BookFormat?>(value: null, child: Text('全部格式')),
            ...BookFormat.values.map(
              (format) => PopupMenuItem<BookFormat?>(
                value: format,
                child: Text(formatBookFormat(format)),
              ),
            ),
          ],
          onSelected: onFormatChanged,
        ),
        if (showCategoryFilter) ...[
          const SizedBox(width: AppSpacing.x2),
          categories.when(
            data: (items) => _FilterMenuButton<String?>(
              icon: Icons.folder_outlined,
              label: categoryId == null
                  ? '书架'
                  : _categoryFilterLabel(items, categoryId),
              onClear: categoryId == null
                  ? null
                  : () => onCategoryChanged(null),
              entries: [
                const PopupMenuItem<String?>(value: null, child: Text('全部书架')),
                const PopupMenuItem<String?>(
                  value: '__uncategorized__',
                  child: Text('未分类'),
                ),
                ...items.map(
                  (category) => PopupMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onSelected: onCategoryChanged,
            ),
            loading: () => const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
        const SizedBox(width: AppSpacing.x2),
        tags.when(
          data: (items) => _FilterMenuButton<String?>(
            icon: Icons.label_outline,
            label: tagId == null ? '标签' : _tagFilterLabel(items, tagId),
            onClear: tagId == null ? null : () => onTagChanged(null),
            entries: [
              const PopupMenuItem<String?>(value: null, child: Text('全部标签')),
              ...items.map(
                (tag) => PopupMenuItem<String?>(
                  value: tag.id,
                  child: Text(tag.name),
                ),
              ),
            ],
            onSelected: onTagChanged,
          ),
          loading: () => const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
        ),
        const SizedBox(width: AppSpacing.x2),
        FilterChip(
          avatar: const Icon(Icons.note_alt_outlined, size: 18),
          label: const Text('有笔记'),
          selected: hasNotesOnly,
          onSelected: onHasNotesChanged,
        ),
        const SizedBox(width: AppSpacing.x2),
        FilterChip(
          avatar: const Icon(Icons.bookmark_border, size: 18),
          label: const Text('有书签'),
          selected: hasBookmarksOnly,
          onSelected: onHasBookmarksChanged,
        ),
        const SizedBox(width: AppSpacing.x2),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('清除'),
        ),
      ],
    );
  }
}

final class _MobileLibraryFilters extends StatelessWidget {
  const _MobileLibraryFilters({
    required this.systemFilter,
    required this.format,
    required this.categoryId,
    required this.tagId,
    required this.hasNotesOnly,
    required this.hasBookmarksOnly,
    required this.categories,
    required this.tags,
    required this.categoriesLoading,
    required this.tagsLoading,
    required this.onSystemChanged,
    required this.onFormatChanged,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onHasNotesChanged,
    required this.onHasBookmarksChanged,
    required this.onClear,
    required this.onCreateCategory,
  });

  final LibrarySystemFilter systemFilter;
  final BookFormat? format;
  final String? categoryId;
  final String? tagId;
  final bool hasNotesOnly;
  final bool hasBookmarksOnly;
  final List<BookCategory> categories;
  final List<BookTag> tags;
  final bool categoriesLoading;
  final bool tagsLoading;
  final ValueChanged<LibrarySystemFilter> onSystemChanged;
  final ValueChanged<BookFormat?> onFormatChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<bool> onHasNotesChanged;
  final ValueChanged<bool> onHasBookmarksChanged;
  final VoidCallback onClear;
  final _CreateCategoryCallback onCreateCategory;

  bool get _hasFilters {
    return systemFilter != LibrarySystemFilter.all ||
        format != null ||
        categoryId != null ||
        tagId != null ||
        hasNotesOnly ||
        hasBookmarksOnly;
  }

  @override
  Widget build(BuildContext context) {
    return AppFilterBar(
      children: [
        FilterChip(
          avatar: const Icon(Icons.tune, size: 18),
          label: Text(_hasFilters ? '筛选已应用' : '筛选'),
          selected: _hasFilters,
          onSelected: (_) => _showFilterSheet(context),
        ),
        if (systemFilter != LibrarySystemFilter.all) ...[
          const SizedBox(width: AppSpacing.x2),
          InputChip(
            label: Text(systemFilter.label),
            onDeleted: () => onSystemChanged(LibrarySystemFilter.all),
          ),
        ],
        if (format != null) ...[
          const SizedBox(width: AppSpacing.x2),
          InputChip(
            label: Text(formatBookFormat(format!)),
            onDeleted: () => onFormatChanged(null),
          ),
        ],
        if (categoryId != null) ...[
          const SizedBox(width: AppSpacing.x2),
          InputChip(
            label: Text(_categoryFilterLabel(categories, categoryId)),
            onDeleted: () => onCategoryChanged(null),
          ),
        ],
        if (tagId != null) ...[
          const SizedBox(width: AppSpacing.x2),
          InputChip(
            label: Text(_tagFilterLabel(tags, tagId)),
            onDeleted: () => onTagChanged(null),
          ),
        ],
        if (hasNotesOnly) ...[
          const SizedBox(width: AppSpacing.x2),
          InputChip(
            label: const Text('有笔记'),
            onDeleted: () => onHasNotesChanged(false),
          ),
        ],
        if (hasBookmarksOnly) ...[
          const SizedBox(width: AppSpacing.x2),
          InputChip(
            label: const Text('有书签'),
            onDeleted: () => onHasBookmarksChanged(false),
          ),
        ],
        if (_hasFilters) ...[
          const SizedBox(width: AppSpacing.x2),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('清除'),
          ),
        ],
      ],
    );
  }

  Future<void> _showFilterSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MobileLibraryFilterSheet(
        systemFilter: systemFilter,
        format: format,
        categoryId: categoryId,
        tagId: tagId,
        hasNotesOnly: hasNotesOnly,
        hasBookmarksOnly: hasBookmarksOnly,
        categories: categories,
        tags: tags,
        categoriesLoading: categoriesLoading,
        tagsLoading: tagsLoading,
        onSystemChanged: onSystemChanged,
        onFormatChanged: onFormatChanged,
        onCategoryChanged: onCategoryChanged,
        onTagChanged: onTagChanged,
        onHasNotesChanged: onHasNotesChanged,
        onHasBookmarksChanged: onHasBookmarksChanged,
        onClear: onClear,
        onCreateCategory: onCreateCategory,
      ),
    );
  }
}

final class _MobileLibraryFilterSheet extends StatelessWidget {
  const _MobileLibraryFilterSheet({
    required this.systemFilter,
    required this.format,
    required this.categoryId,
    required this.tagId,
    required this.hasNotesOnly,
    required this.hasBookmarksOnly,
    required this.categories,
    required this.tags,
    required this.categoriesLoading,
    required this.tagsLoading,
    required this.onSystemChanged,
    required this.onFormatChanged,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onHasNotesChanged,
    required this.onHasBookmarksChanged,
    required this.onClear,
    required this.onCreateCategory,
  });

  final LibrarySystemFilter systemFilter;
  final BookFormat? format;
  final String? categoryId;
  final String? tagId;
  final bool hasNotesOnly;
  final bool hasBookmarksOnly;
  final List<BookCategory> categories;
  final List<BookTag> tags;
  final bool categoriesLoading;
  final bool tagsLoading;
  final ValueChanged<LibrarySystemFilter> onSystemChanged;
  final ValueChanged<BookFormat?> onFormatChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<bool> onHasNotesChanged;
  final ValueChanged<bool> onHasBookmarksChanged;
  final VoidCallback onClear;
  final _CreateCategoryCallback onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            AppSpacing.x2,
            AppSpacing.x5,
            AppSpacing.x6,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '筛选书库',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _apply(context, onClear),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('清除'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            _MobileFilterSection(
              title: '阅读状态',
              children: LibrarySystemFilter.values
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(filter.label),
                      selected: systemFilter == filter,
                      onSelected: (_) =>
                          _apply(context, () => onSystemChanged(filter)),
                    ),
                  )
                  .toList(growable: false),
            ),
            _MobileFilterSection(
              title: '格式',
              children: [
                ChoiceChip(
                  label: const Text('全部格式'),
                  selected: format == null,
                  onSelected: (_) =>
                      _apply(context, () => onFormatChanged(null)),
                ),
                ...BookFormat.values.map(
                  (bookFormat) => ChoiceChip(
                    label: Text(formatBookFormat(bookFormat)),
                    selected: format == bookFormat,
                    onSelected: (_) =>
                        _apply(context, () => onFormatChanged(bookFormat)),
                  ),
                ),
              ],
            ),
            _MobileFilterSection(
              title: '书架',
              children: [
                ActionChip(
                  avatar: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('新建书架文件夹'),
                  onPressed: () async {
                    final category = await onCreateCategory(context);
                    if (category != null && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('全部书架'),
                  selected: categoryId == null,
                  onSelected: (_) =>
                      _apply(context, () => onCategoryChanged(null)),
                ),
                ChoiceChip(
                  label: const Text('未分类'),
                  selected: categoryId == '__uncategorized__',
                  onSelected: (_) => _apply(
                    context,
                    () => onCategoryChanged('__uncategorized__'),
                  ),
                ),
                ...categories.map(
                  (category) => ChoiceChip(
                    label: Text(category.name),
                    selected: categoryId == category.id,
                    onSelected: (_) =>
                        _apply(context, () => onCategoryChanged(category.id)),
                  ),
                ),
                if (categoriesLoading)
                  Chip(
                    avatar: const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: const Text('正在读取书架'),
                    backgroundColor: colorScheme.surfaceSubtle,
                  ),
              ],
            ),
            _MobileFilterSection(
              title: '标签',
              children: [
                ChoiceChip(
                  label: const Text('全部标签'),
                  selected: tagId == null,
                  onSelected: (_) => _apply(context, () => onTagChanged(null)),
                ),
                ...tags.map(
                  (tag) => ChoiceChip(
                    label: Text(tag.name),
                    selected: tagId == tag.id,
                    onSelected: (_) =>
                        _apply(context, () => onTagChanged(tag.id)),
                  ),
                ),
                if (tagsLoading)
                  Chip(
                    avatar: const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: const Text('正在读取标签'),
                    backgroundColor: colorScheme.surfaceSubtle,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('只看有笔记的书'),
              value: hasNotesOnly,
              onChanged: (value) =>
                  _apply(context, () => onHasNotesChanged(value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('只看有书签的书'),
              value: hasBookmarksOnly,
              onChanged: (value) =>
                  _apply(context, () => onHasBookmarksChanged(value)),
            ),
          ],
        ),
      ),
    );
  }

  void _apply(BuildContext context, VoidCallback update) {
    update();
    Navigator.of(context).pop();
  }
}

final class _MobileFilterSection extends StatelessWidget {
  const _MobileFilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: children,
          ),
        ],
      ),
    );
  }
}

final class _DesktopCategoryTree extends ConsumerStatefulWidget {
  const _DesktopCategoryTree({
    required this.systemFilter,
    required this.categoryId,
    required this.onSystemChanged,
    required this.onCategoryChanged,
  });

  final LibrarySystemFilter systemFilter;
  final String? categoryId;
  final ValueChanged<LibrarySystemFilter> onSystemChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  ConsumerState<_DesktopCategoryTree> createState() =>
      _DesktopCategoryTreeState();
}

final class _DesktopCategoryTreeState
    extends ConsumerState<_DesktopCategoryTree> {
  final Set<String> _expandedCategoryIds = {};

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Text(
                '浏览',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            _CategoryTreeRow(
              label: '全部书籍',
              icon: Icons.library_books_outlined,
              selected:
                  widget.systemFilter == LibrarySystemFilter.all &&
                  widget.categoryId == null,
              onSelect: () {
                ref.read(libraryControllerProvider.notifier).browseAll();
              },
            ),
            const SizedBox(height: AppSpacing.x2),
            const _SidebarSectionLabel(label: '阅读状态'),
            ...LibrarySystemFilter.values
                .where((filter) => filter != LibrarySystemFilter.all)
                .map(
                  (filter) => _CategoryTreeRow(
                    label: filter.label,
                    icon: switch (filter) {
                      LibrarySystemFilter.recent => Icons.history,
                      LibrarySystemFilter.favorite => Icons.star_border,
                      LibrarySystemFilter.unread =>
                        Icons.radio_button_unchecked,
                      LibrarySystemFilter.reading =>
                        Icons.chrome_reader_mode_outlined,
                      LibrarySystemFilter.finished => Icons.done_all,
                      LibrarySystemFilter.all => Icons.library_books_outlined,
                    },
                    selected: widget.systemFilter == filter,
                    onSelect: () => widget.onSystemChanged(filter),
                  ),
                ),
            const SizedBox(height: AppSpacing.x3),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 0, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: _SidebarSectionLabel(
                      label: '书架',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  IconButton(
                    tooltip: '新建书架文件夹',
                    visualDensity: VisualDensity.compact,
                    onPressed: _createCategory,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            _CategoryTreeRow(
              label: '全部书架',
              icon: Icons.folder_copy_outlined,
              selected: widget.categoryId == null,
              onSelect: () => widget.onCategoryChanged(null),
            ),
            _CategoryTreeRow(
              label: '未分类',
              icon: Icons.folder_off_outlined,
              selected: widget.categoryId == '__uncategorized__',
              onSelect: () => widget.onCategoryChanged('__uncategorized__'),
            ),
            categories.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: Text(
                      '暂无书架文件夹',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: _visibleCategoryNodes(items)
                      .map(
                        (node) => _CategoryTreeRow(
                          label: node.category.name,
                          icon: Icons.folder_outlined,
                          depth: node.depth,
                          selected: widget.categoryId == node.category.id,
                          expanded: _expandedCategoryIds.contains(
                            node.category.id,
                          ),
                          hasChildren: node.hasChildren,
                          onToggle: node.hasChildren
                              ? () => _toggleCategory(node.category.id)
                              : null,
                          onSelect: () =>
                              widget.onCategoryChanged(node.category.id),
                        ),
                      )
                      .toList(growable: false),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
              error: (error, stackTrace) => const Padding(
                padding: EdgeInsets.all(12),
                child: Text('无法读取书架'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final category = await _createLibraryCategory(context, ref);
    if (category != null) {
      widget.onCategoryChanged(category.id);
    }
  }

  void _toggleCategory(String id) {
    setState(() {
      if (!_expandedCategoryIds.add(id)) {
        _expandedCategoryIds.remove(id);
      }
    });
  }

  List<_CategoryTreeNode> _visibleCategoryNodes(List<BookCategory> categories) {
    final childrenByParent = <String?, List<BookCategory>>{};
    final ids = categories.map((category) => category.id).toSet();
    for (final category in categories) {
      final parentId = ids.contains(category.parentId)
          ? category.parentId
          : null;
      childrenByParent.putIfAbsent(parentId, () => []).add(category);
    }
    for (final children in childrenByParent.values) {
      children.sort((a, b) {
        final sortComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortComparison != 0) {
          return sortComparison;
        }
        return a.name.compareTo(b.name);
      });
    }

    final nodes = <_CategoryTreeNode>[];
    void visit(BookCategory category, int depth, Set<String> ancestors) {
      final children = childrenByParent[category.id] ?? const <BookCategory>[];
      nodes.add(
        _CategoryTreeNode(
          category: category,
          depth: depth,
          hasChildren: children.isNotEmpty,
        ),
      );
      if (!_expandedCategoryIds.contains(category.id)) {
        return;
      }
      if (ancestors.contains(category.id)) {
        return;
      }
      final nextAncestors = {...ancestors, category.id};
      for (final child in children) {
        visit(child, depth + 1, nextAncestors);
      }
    }

    for (final category in childrenByParent[null] ?? const <BookCategory>[]) {
      visit(category, 0, const {});
    }
    return nodes;
  }
}

final class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 4),
  });

  final String label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _CategoryTreeNode {
  const _CategoryTreeNode({
    required this.category,
    required this.depth,
    required this.hasChildren,
  });

  final BookCategory category;
  final int depth;
  final bool hasChildren;
}

final class _CategoryTreeRow extends StatelessWidget {
  const _CategoryTreeRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
    this.depth = 0,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggle,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): onSelect,
        const SingleActivator(LogicalKeyboardKey.space): onSelect,
        SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (hasChildren && !expanded) {
            onToggle?.call();
          }
        },
        SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (hasChildren && expanded) {
            onToggle?.call();
          }
        },
        SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            FocusScope.of(context).nextFocus(),
        SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            FocusScope.of(context).previousFocus(),
      },
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onSelect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.accentSubtle
                        : focused
                        ? colorScheme.surfaceSubtle
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: focused
                        ? Border.all(color: colorScheme.primary)
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 8 + depth * 18,
                      right: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 28,
                          child: hasChildren
                              ? IconButton(
                                  tooltip: expanded ? '折叠文件夹' : '展开文件夹',
                                  padding: EdgeInsets.zero,
                                  onPressed: onToggle,
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 20,
                                  ),
                                )
                              : Icon(icon, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: selected
                                ? Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _FilterMenuButton<T> extends StatelessWidget {
  const _FilterMenuButton({
    required this.icon,
    required this.label,
    required this.entries,
    required this.onSelected,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final List<PopupMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<T>(
          tooltip: label,
          onSelected: onSelected,
          itemBuilder: (context) => entries,
          child: Chip(avatar: Icon(icon, size: 18), label: Text(label)),
        ),
        if (onClear != null)
          IconButton(
            tooltip: '清除 $label',
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    );
  }
}

final class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.isImporting,
    required this.onImport,
    required this.onImportFolder,
  });

  final bool isImporting;
  final VoidCallback onImport;
  final VoidCallback onImportFolder;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.local_library_outlined,
      illustrationAsset: 'assets/images/empty-states/empty-library.png',
      title: '还没有书籍',
      message: '导入 EPUB/PDF 文件，或扫描文件夹批量加入书库。',
      action: FilledButton.icon(
        key: const ValueKey('import-books-button'),
        onPressed: isImporting ? null : onImport,
        icon: isImporting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: const Text('导入 EPUB/PDF'),
      ),
      secondaryAction: OutlinedButton.icon(
        key: const ValueKey('import-folder-button'),
        onPressed: isImporting ? null : onImportFolder,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('扫描文件夹'),
      ),
    );
  }
}

final class _NoFilteredBooks extends StatelessWidget {
  const _NoFilteredBooks();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: '没有符合筛选条件的书籍',
      message: '清除筛选或切换书架后再查看。',
      action: OutlinedButton.icon(
        onPressed: () {
          final controller = ProviderScope.containerOf(
            context,
            listen: false,
          ).read(libraryControllerProvider.notifier);
          controller.clearFilters();
        },
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('清除筛选'),
      ),
    );
  }
}

final class _LibraryLoadingState extends StatelessWidget {
  const _LibraryLoadingState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.x6),
      itemCount: 6,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.x3),
      itemBuilder: (context, index) => DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colorScheme.appBorder),
        ),
        child: const SizedBox(height: 88, width: double.infinity),
      ),
    );
  }
}

final class _LibraryContent extends StatelessWidget {
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
    this.onCreateFolder,
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
  final Future<BookCategory?> Function()? onCreateFolder;

  @override
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

    // WeChat Read style: at root, folders and loose (uncategorized) books share
    // one grid. Books already in a folder only appear after opening that folder.
    final isRootShelf =
        categoryId == null &&
        onOpenFolder != null &&
        viewMode == LibraryViewMode.grid;
    final body = switch (viewMode) {
      LibraryViewMode.grid =>
        isRootShelf
            ? _BookshelfRootGrid(
                books: books,
                selectedBookId: expanded ? selectedBookId : null,
                onBookSelected: expanded ? onBookSelected : null,
                onOpenFolder: onOpenFolder!,
                onCreateFolder: onCreateFolder,
                padding: padding,
                minTileWidth: gridSize.minTileWidth,
              )
            : _BookGrid(
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

    // Inside a folder: show back chrome above books.
    // Drag books onto the header drop zone to remove them from the folder.
    if (onBackFromFolder != null && folderTitle != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FolderExitDropBar(
            folderTitle: folderTitle!,
            bookCount: books.length,
            onBack: onBackFromFolder!,
          ),
          const Divider(height: 1),
          Expanded(
            child: viewMode == LibraryViewMode.grid
                ? _BookGrid(
                    books: books,
                    selectedBookId: expanded ? selectedBookId : null,
                    onBookSelected: expanded ? onBookSelected : null,
                    padding: padding,
                    minTileWidth: gridSize.minTileWidth,
                    draggable: true,
                  )
                : body,
          ),
        ],
      );
    }

    return body;
  }
}

/// Root shelf tile model: either a folder or a loose book.
sealed class _ShelfTile {
  const _ShelfTile();
}

final class _ShelfFolderTile extends _ShelfTile {
  const _ShelfFolderTile({
    required this.id,
    required this.title,
    required this.books,
  });

  final String id;
  final String title;
  final List<LibraryBook> books;
}

final class _ShelfBookTile extends _ShelfTile {
  const _ShelfBookTile(this.item);

  final LibraryBook item;
}

final class _BookshelfRootGrid extends ConsumerWidget {
  const _BookshelfRootGrid({
    required this.books,
    required this.selectedBookId,
    required this.onBookSelected,
    required this.onOpenFolder,
    required this.padding,
    this.onCreateFolder,
    this.minTileWidth,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final ValueChanged<String?>? onBookSelected;
  final ValueChanged<String?> onOpenFolder;
  final Future<BookCategory?> Function()? onCreateFolder;
  final EdgeInsetsGeometry padding;
  final double? minTileWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    final byCategory = <String, List<LibraryBook>>{};
    final loose = <LibraryBook>[];
    for (final item in books) {
      final categoryId = item.book.categoryId;
      if (categoryId == null || categoryId.isEmpty) {
        loose.add(item);
      } else {
        byCategory.putIfAbsent(categoryId, () => []).add(item);
      }
    }

    final tiles = <_ShelfTile>[
      // Folders first (WeChat Read style), then loose books.
      for (final category in categories)
        if ((byCategory[category.id] ?? const <LibraryBook>[]).isNotEmpty)
          _ShelfFolderTile(
            id: category.id,
            title: category.name,
            books: byCategory[category.id]!,
          ),
      // Empty custom folders still appear so users can open/manage them.
      for (final category in categories)
        if ((byCategory[category.id] ?? const <LibraryBook>[]).isEmpty)
          _ShelfFolderTile(
            id: category.id,
            title: category.name,
            books: const [],
          ),
      for (final item in loose) _ShelfBookTile(item),
    ];

    // +1 optional "new folder" tile at the end when create is available.
    final showCreate = onCreateFolder != null;
    final itemCount = tiles.length + (showCreate ? 1 : 0);
    final tileWidth = (minTileWidth ?? LibraryGridSize.medium.minTileWidth)
        .clamp(96, 260)
        .toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // Use actual content width (not full window) so sidebars don't hide size changes.
        final count = _gridColumnCount(
          availableWidth: available,
          tileWidth: tileWidth,
        );
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: tileWidth,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: _gridChildAspectRatio(count),
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (showCreate && index == tiles.length) {
              return _NewFolderTile(
                onCreate: () async {
                  final category = await onCreateFolder!();
                  if (category != null) {
                    onOpenFolder(category.id);
                  }
                },
              );
            }
            final tile = tiles[index];
            return switch (tile) {
              _ShelfFolderTile(:final id, :final title, :final books) =>
                _FolderShelfCard(
                  folderId: id,
                  title: title,
                  books: books,
                  onTap: () => onOpenFolder(id),
                ),
              _ShelfBookTile(:final item) => _DraggableBookCard(
                item: item,
                selected: selectedBookId == item.book.id,
                onSelect: onBookSelected,
              ),
            };
          },
        );
      },
    );
  }
}

int _gridColumnCount({
  required double availableWidth,
  required double tileWidth,
}) {
  if (availableWidth <= 0) {
    return 2;
  }
  // Approximate columns for aspect-ratio tuning only.
  return (availableWidth / (tileWidth + 12)).floor().clamp(1, 12).toInt();
}

double _gridChildAspectRatio(int columnCount) {
  return switch (columnCount) {
    <= 2 => 0.66,
    3 => 0.62,
    4 => 0.58,
    5 => 0.56,
    6 => 0.54,
    _ => 0.52,
  };
}

Future<void> _moveBookToFolder(
  WidgetRef ref,
  BuildContext context, {
  required String bookId,
  required String? categoryId,
  String? folderName,
}) async {
  await ref.read(bookRepositoryProvider).updateCategory(bookId, categoryId);
  if (!context.mounted) {
    return;
  }
  final message = categoryId == null ? '已移出到书架' : '已移入「${folderName ?? '文件夹'}」';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Drag data for moving a library book between root shelf and folders.
final class _BookDragData {
  const _BookDragData(this.item);

  final LibraryBook item;
}

final class _DraggableBookCard extends StatelessWidget {
  const _DraggableBookCard({
    required this.item,
    this.selected = false,
    this.onSelect,
  });

  final LibraryBook item;
  final bool selected;
  final ValueChanged<String?>? onSelect;

  @override
  Widget build(BuildContext context) {
    final card = _BookCard(item: item, selected: selected, onSelect: onSelect);
    return LongPressDraggable<_BookDragData>(
      data: _BookDragData(item),
      delay: const Duration(milliseconds: 180),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          width: 110,
          height: 160,
          child: Opacity(opacity: 0.92, child: _BookCard(item: item)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

final class _FolderExitDropBar extends ConsumerWidget {
  const _FolderExitDropBar({
    required this.folderTitle,
    required this.bookCount,
    required this.onBack,
  });

  final String folderTitle;
  final int bookCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<_BookDragData>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        unawaited(
          _moveBookToFolder(
            ref,
            context,
            bookId: details.data.item.book.id,
            categoryId: null,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Material(
          color: hovering
              ? colorScheme.primary.withValues(alpha: 0.10)
              : colorScheme.surface,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: hovering
                      ? colorScheme.primary
                      : colorScheme.appBorder.withValues(alpha: 0.0),
                  width: hovering ? 2 : 0,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(hovering ? '松开放回书架' : '返回书架'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hovering ? '拖到这里移出文件夹' : folderTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hovering ? colorScheme.primary : null,
                      ),
                    ),
                  ),
                  Text(
                    '$bookCount 本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _FolderShelfCard extends ConsumerWidget {
  const _FolderShelfCard({
    required this.folderId,
    required this.title,
    required this.books,
    required this.onTap,
  });

  final String folderId;
  final String title;
  final List<LibraryBook> books;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = books.length;
    final covers = books.take(3).toList(growable: false);

    return DragTarget<_BookDragData>(
      onWillAcceptWithDetails: (details) {
        // Only accept books that are not already in this folder.
        return details.data.item.book.categoryId != folderId;
      },
      onAcceptWithDetails: (details) {
        unawaited(
          _moveBookToFolder(
            ref,
            context,
            bookId: details.data.item.book.id,
            categoryId: folderId,
            folderName: title,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Material(
          color: hovering
              ? colorScheme.primary.withValues(alpha: 0.10)
              : colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: hovering
                  ? colorScheme.primary
                  : colorScheme.appBorder.withValues(alpha: 0.9),
              width: hovering ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x3,
                AppSpacing.x3,
                AppSpacing.x3,
                AppSpacing.x3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        final maxH = constraints.maxHeight;
                        if (maxW <= 0 || maxH <= 0) {
                          return const SizedBox.shrink();
                        }
                        if (hovering) {
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.create_new_folder_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '放入文件夹',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return _FolderCoverStack(
                          covers: covers,
                          width: maxW,
                          height: maxH,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hovering ? '松手移入' : (count == 0 ? '空文件夹' : '$count 本'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hovering
                          ? colorScheme.primary
                          : colorScheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _FolderCoverStack extends StatelessWidget {
  const _FolderCoverStack({
    required this.covers,
    required this.width,
    required this.height,
  });

  final List<LibraryBook> covers;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (covers.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colorScheme.appBorder),
        ),
        child: Center(
          child: Icon(
            Icons.folder_outlined,
            size: 36,
            color: colorScheme.primary.withValues(alpha: 0.85),
          ),
        ),
      );
    }

    // Stack 1–3 mini covers like WeChat Read folder tiles.
    final coverW = width * 0.58;
    final coverH = coverW * 3 / 2;
    final fittedH = coverH > height ? height : coverH;
    final fittedW = fittedH * 2 / 3;
    final offsets = switch (covers.length) {
      1 => const [Offset(0, 0)],
      2 => const [Offset(-10, 6), Offset(12, -4)],
      _ => const [Offset(-14, 10), Offset(0, 0), Offset(14, -8)],
    };

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < covers.length; i++)
              Transform.translate(
                offset: offsets[i],
                child: Transform.rotate(
                  angle: (i - (covers.length - 1) / 2) * 0.06,
                  child: SizedBox(
                    width: fittedW,
                    height: fittedH,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: _BookCover(
                          format: covers[i].book.format,
                          coverPath: covers[i].book.coverPath,
                          semanticLabel: '《${covers[i].book.title}》封面',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _NewFolderTile extends StatelessWidget {
  const _NewFolderTile({required this.onCreate});

  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: colorScheme.appBorder.withValues(alpha: 0.9),
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => unawaited(onCreate()),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.create_new_folder_outlined,
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              '新建文件夹',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

final class _BookGrid extends StatelessWidget {
  const _BookGrid({
    required this.books,
    required this.selectedBookId,
    required this.onBookSelected,
    required this.padding,
    this.minTileWidth,
    this.draggable = false,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final ValueChanged<String?>? onBookSelected;
  final EdgeInsetsGeometry padding;
  final double? minTileWidth;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final tileWidth = (minTileWidth ?? LibraryGridSize.medium.minTileWidth)
        .clamp(96, 260)
        .toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _gridColumnCount(
          availableWidth: constraints.maxWidth,
          tileWidth: tileWidth,
        );
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: tileWidth,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: _gridChildAspectRatio(count),
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final item = books[index];
            if (draggable) {
              return _DraggableBookCard(
                item: item,
                selected: selectedBookId == item.book.id,
                onSelect: onBookSelected,
              );
            }
            return _BookCard(
              item: item,
              selected: selectedBookId == item.book.id,
              onSelect: onBookSelected,
            );
          },
        );
      },
    );
  }
}

final class _DesktopLibraryList extends ConsumerWidget {
  const _DesktopLibraryList({
    required this.books,
    required this.selectedBookId,
    required this.onBookSelected,
    this.compact = false,
  });

  final List<LibraryBook> books;
  final String? selectedBookId;
  final ValueChanged<String?> onBookSelected;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      itemCount: books.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.x2),
      itemBuilder: (context, index) {
        final item = books[index];
        return _BookListRow(
          item: item,
          compact: compact,
          selected: selectedBookId == item.book.id,
          categoryLabel: _categoryLabelForBook(
            categories,
            item.book.categoryId,
          ),
          onSelected: onBookSelected,
        );
      },
    );
  }
}

final class _BookListRow extends ConsumerWidget {
  const _BookListRow({
    required this.item,
    required this.compact,
    required this.selected,
    required this.categoryLabel,
    required this.onSelected,
  });

  final LibraryBook item;
  final bool compact;
  final bool selected;
  final String? categoryLabel;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = item.progress?.progress ?? 0;
    final rowHeight = compact ? 68.0 : 96.0;
    return GestureDetector(
      onSecondaryTapDown: (details) {
        onSelected(item.book.id);
        _BookActionsMenu.showContextMenu(
          context,
          ref,
          item,
          details.globalPosition,
        );
      },
      onDoubleTap: () =>
          context.goNamed('reader', pathParameters: {'bookId': item.book.id}),
      child: Material(
        color: selected ? colorScheme.accentSubtle : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.appBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => onSelected(item.book.id),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.x3 : AppSpacing.x4,
                vertical: compact ? AppSpacing.x2 : AppSpacing.x3,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 420 || compact;
                  final tagsByBook =
                      ref.watch(bookTagsByBookIdProvider).value ??
                      const <String, List<BookTag>>{};
                  final tags = tagsByBook[item.book.id] ?? const <BookTag>[];
                  final titleBlock = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.book.title,
                              maxLines: narrow ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          _FormatBadge(format: item.book.format),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        _bookListSubtitle(
                          item,
                          categoryLabel: categoryLabel,
                          tags: tags,
                        ),
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.textSecondary,
                        ),
                      ),
                    ],
                  );
                  final trailing = Row(
                    children: [
                      Flexible(
                        child: _IndexingStatusChip(
                          status: item.book.indexingStatus,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x1),
                      Expanded(child: _ProgressIndicator(progress: progress)),
                      _BookActionsMenu(item: item),
                    ],
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _BookCover(
                              format: item.book.format,
                              coverPath: item.book.coverPath,
                              semanticLabel: '《${item.book.title}》封面',
                              size: compact
                                  ? const Size(32, 48)
                                  : const Size(40, 60),
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            Expanded(child: titleBlock),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        trailing,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      _BookCover(
                        format: item.book.format,
                        coverPath: item.book.coverPath,
                        semanticLabel: '《${item.book.title}》封面',
                        size: const Size(48, 72),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(child: titleBlock),
                      const SizedBox(width: AppSpacing.x3),
                      SizedBox(width: 200, child: trailing),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _BookCard extends ConsumerWidget {
  const _BookCard({required this.item, this.selected = false, this.onSelect});

  final LibraryBook item;
  final bool selected;
  final ValueChanged<String?>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = item.book;
    final progress = item.progress?.progress ?? 0;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        onSelect?.call(book.id);
        _BookActionsMenu.showContextMenu(
          context,
          ref,
          item,
          details.globalPosition,
        );
      },
      child: Material(
        color: selected
            ? colorScheme.accentSubtle.withValues(alpha: 0.72)
            : colorScheme.surface,
        elevation: selected ? 0 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.55)
                : colorScheme.appBorder.withValues(alpha: 0.9),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            final select = onSelect;
            if (select == null) {
              context.goNamed('reader', pathParameters: {'bookId': book.id});
              return;
            }
            select(book.id);
          },
          onDoubleTap: onSelect == null
              ? null
              : () => context.goNamed(
                  'reader',
                  pathParameters: {'bookId': book.id},
                ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              // Progressive density so short grid cells never bottom-overflow.
              final showMenu = h >= 168;
              final showAuthor = h >= 200;
              final showStatus = h >= 230 && book.indexingStatus != 'done';
              final titleLines = h < 190 ? 1 : 2;
              final pad = h < 180 ? AppSpacing.x2 : AppSpacing.x3;

              return Padding(
                padding: EdgeInsets.fromLTRB(pad, showMenu ? 2 : pad, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showMenu)
                      Align(
                        alignment: Alignment.centerRight,
                        heightFactor: 0.85,
                        child: _BookActionsMenu(item: item),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, coverConstraints) {
                          final maxW = coverConstraints.maxWidth;
                          final maxH = coverConstraints.maxHeight;
                          if (maxW <= 0 || maxH <= 0) {
                            return const SizedBox.shrink();
                          }
                          // Fit 2:3 cover inside available space without overflow.
                          var coverW = maxW;
                          var coverH = coverW * 3 / 2;
                          if (coverH > maxH) {
                            coverH = maxH;
                            coverW = coverH * 2 / 3;
                          }
                          return Center(
                            child: SizedBox(
                              width: coverW,
                              height: coverH,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _BookCover(
                                    format: book.format,
                                    coverPath: book.coverPath,
                                    semanticLabel: '《${book.title}》封面',
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: _FormatBadge(format: book.format),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: h < 180 ? AppSpacing.x1 : AppSpacing.x2),
                    Text(
                      book.title,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        letterSpacing: -0.1,
                        fontSize: w < 120 ? 13 : null,
                      ),
                    ),
                    if (showAuthor) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author?.isNotEmpty == true
                            ? book.author!
                            : formatBookFormat(book.format),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.textSecondary,
                        ),
                      ),
                    ],
                    if (showStatus) ...[
                      const SizedBox(height: AppSpacing.x1),
                      SizedBox(
                        height: 24,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _IndexingStatusChip(
                            status: book.indexingStatus,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x1),
                    _ProgressIndicator(progress: progress, compact: h < 200),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _BookActionsMenu extends ConsumerWidget {
  const _BookActionsMenu({required this.item});

  final LibraryBook item;

  static Future<void> showDetails(
    BuildContext context,
    WidgetRef ref,
    LibraryBook item,
  ) async {
    final bookmarks = await ref
        .read(bookmarkRepositoryProvider)
        .getByBook(item.book.id);
    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _BookDetailsSheet(item: item, bookmarks: bookmarks),
    );
  }

  static Future<void> showContextMenu(
    BuildContext context,
    WidgetRef ref,
    LibraryBook item,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_BookAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: _contextMenuItems(item),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    await _BookActionsMenu(
      item: item,
    )._handleBookAction(context, ref, item, selected);
  }

  static List<PopupMenuEntry<_BookAction>> _contextMenuItems(LibraryBook item) {
    return [
      const PopupMenuItem(
        value: _BookAction.open,
        child: ListTile(
          leading: Icon(Icons.chrome_reader_mode_outlined),
          title: Text('继续阅读'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.startFromBeginning,
        child: ListTile(
          leading: Icon(Icons.restart_alt_outlined),
          title: Text('从头开始阅读'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.details,
        child: ListTile(leading: Icon(Icons.info_outline), title: Text('详情')),
      ),
      const PopupMenuItem(
        value: _BookAction.openLibraryCopyLocation,
        child: ListTile(
          leading: Icon(Icons.folder_copy_outlined),
          title: Text('打开书库副本位置'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.openOriginalFileLocation,
        child: ListTile(
          leading: Icon(Icons.folder_open_outlined),
          title: Text('打开原文件位置'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: _BookAction.rename,
        child: ListTile(
          leading: Icon(Icons.drive_file_rename_outline),
          title: Text('重命名展示标题'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.editAuthor,
        child: ListTile(
          leading: Icon(Icons.person_outline),
          title: Text('修改作者'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.moveCategory,
        child: ListTile(
          leading: Icon(Icons.folder_outlined),
          title: Text('移动到书架文件夹'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.tags,
        child: ListTile(
          leading: Icon(Icons.label_outline),
          title: Text('添加标签'),
        ),
      ),
      PopupMenuItem(
        value: _BookAction.favorite,
        child: ListTile(
          leading: Icon(
            item.book.isFavorite ? Icons.star : Icons.star_border_outlined,
          ),
          title: Text(item.book.isFavorite ? '取消收藏' : '收藏'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.markFinished,
        child: ListTile(leading: Icon(Icons.done_all), title: Text('标记已读')),
      ),
      const PopupMenuItem(
        value: _BookAction.rebuildIndex,
        child: ListTile(
          leading: Icon(Icons.manage_search),
          title: Text('重建索引'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.refreshCover,
        child: ListTile(
          leading: Icon(Icons.image_search_outlined),
          title: Text('重新提取封面'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: _BookAction.delete,
        child: ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('从书库移除'),
        ),
      ),
      const PopupMenuItem(
        value: _BookAction.deleteData,
        child: ListTile(
          leading: Icon(Icons.delete_forever_outlined),
          title: Text('删除应用副本与数据'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_BookAction>(
      tooltip: '书籍操作',
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _BookAction.open,
          child: ListTile(
            leading: Icon(Icons.chrome_reader_mode_outlined),
            title: Text('继续阅读'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.startFromBeginning,
          child: ListTile(
            leading: Icon(Icons.restart_alt_outlined),
            title: Text('从头开始阅读'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.details,
          child: ListTile(leading: Icon(Icons.info_outline), title: Text('详情')),
        ),
        const PopupMenuItem(
          value: _BookAction.openLibraryCopyLocation,
          child: ListTile(
            leading: Icon(Icons.folder_copy_outlined),
            title: Text('打开书库副本位置'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.openOriginalFileLocation,
          child: ListTile(
            leading: Icon(Icons.folder_open_outlined),
            title: Text('打开原文件位置'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.rename,
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('重命名展示标题'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.editAuthor,
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('修改作者'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.moveCategory,
          child: ListTile(
            leading: Icon(Icons.folder_outlined),
            title: Text('移动到书架文件夹'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.tags,
          child: ListTile(
            leading: Icon(Icons.label_outline),
            title: Text('添加标签'),
          ),
        ),
        PopupMenuItem(
          value: _BookAction.favorite,
          child: ListTile(
            leading: Icon(
              item.book.isFavorite ? Icons.star : Icons.star_border_outlined,
            ),
            title: Text(item.book.isFavorite ? '取消收藏' : '收藏'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.markFinished,
          child: ListTile(leading: Icon(Icons.done_all), title: Text('标记已读')),
        ),
        const PopupMenuItem(
          value: _BookAction.rebuildIndex,
          child: ListTile(
            leading: Icon(Icons.manage_search),
            title: Text('重建索引'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.refreshCover,
          child: ListTile(
            leading: Icon(Icons.image_search_outlined),
            title: Text('重新提取封面'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _BookAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('从书库移除'),
          ),
        ),
        const PopupMenuItem(
          value: _BookAction.deleteData,
          child: ListTile(
            leading: Icon(Icons.delete_forever_outlined),
            title: Text('删除应用副本与数据'),
          ),
        ),
      ],
      onSelected: (action) => _handleBookAction(context, ref, item, action),
    );
  }

  Future<void> _handleBookAction(
    BuildContext context,
    WidgetRef ref,
    LibraryBook item,
    _BookAction action,
  ) async {
    switch (action) {
      case _BookAction.open:
        context.goNamed('reader', pathParameters: {'bookId': item.book.id});
      case _BookAction.startFromBeginning:
        context.goNamed(
          'reader',
          pathParameters: {'bookId': item.book.id},
          extra: _startLocatorForBook(item.book),
        );
      case _BookAction.details:
        await showDetails(context, ref, item);
      case _BookAction.rename:
        await _renameBook(context, ref, item.book);
      case _BookAction.editAuthor:
        await _editAuthor(context, ref, item.book);
      case _BookAction.moveCategory:
        await _moveCategory(context, ref, item.book);
      case _BookAction.tags:
        await _editTags(context, ref, item.book);
      case _BookAction.favorite:
        await ref
            .read(bookRepositoryProvider)
            .toggleFavorite(item.book.id, !item.book.isFavorite);
      case _BookAction.markFinished:
        await ref
            .read(bookRepositoryProvider)
            .updateReadStatus(item.book.id, ReadStatus.finished);
      case _BookAction.openLibraryCopyLocation:
        await _openBookLocation(
          context,
          ref,
          item.book.libraryFilePath,
          successMessage: '已打开书库副本位置',
        );
      case _BookAction.openOriginalFileLocation:
        final originalPath = item.book.originalFilePath;
        if (originalPath == null || originalPath.isEmpty) {
          _showSnackBar(context, '没有记录原文件路径');
          return;
        }
        await _openBookLocation(
          context,
          ref,
          originalPath,
          successMessage: '已打开原文件位置',
        );
      case _BookAction.rebuildIndex:
        await _rebuildIndex(context, ref, item.book);
      case _BookAction.refreshCover:
        await _refreshCover(context, ref, item.book);
      case _BookAction.delete:
        await _removeBook(context, ref, item.book);
      case _BookAction.deleteData:
        await _deleteBookData(context, ref, item.book);
    }
  }

  Future<void> _renameBook(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final controller = TextEditingController(text: book.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名展示标题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final nextTitle = title;
    controller.dispose();
    if (nextTitle == null || nextTitle.isEmpty || nextTitle == book.title) {
      return;
    }
    await ref
        .read(bookRepositoryProvider)
        .updateMetadata(bookId: book.id, title: nextTitle);
  }

  Future<void> _editAuthor(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final controller = TextEditingController(text: book.author ?? '');
    final author = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改作者'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '作者'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final nextAuthor = author;
    controller.dispose();
    if (nextAuthor == null || nextAuthor == book.author) {
      return;
    }
    await ref
        .read(bookRepositoryProvider)
        .updateMetadata(bookId: book.id, author: nextAuthor);
  }

  Future<void> _openBookLocation(
    BuildContext context,
    WidgetRef ref,
    String filePath, {
    required String successMessage,
  }) async {
    try {
      await ref.read(openFileLocationServiceProvider).revealFile(filePath);
      if (context.mounted) {
        _showSnackBar(context, successMessage);
      }
    } on Object catch (error) {
      if (context.mounted) {
        _showSnackBar(context, '无法打开所在位置：${_shortError(error)}');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rebuildIndex(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在重建《${book.title}》索引')));
    try {
      await ref.read(searchIndexerProvider).indexBook(book);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已重建《${book.title}》索引')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('重建索引失败：${_shortError(error)}')));
      }
    }
  }

  Future<void> _refreshCover(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    try {
      final metadata = await ref
          .read(metadataExtractorProvider)
          .extract(
            file: File(book.libraryFilePath),
            format: book.format,
            bookId: book.id,
          );
      final coverPath = metadata.coverPath;
      if (coverPath == null || coverPath.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未找到可提取的封面')));
        }
        return;
      }
      await ref
          .read(bookRepositoryProvider)
          .updateMetadata(bookId: book.id, coverPath: coverPath);
      // The previous cover was extracted into a file of its own; leaving it
      // behind orphans a copy for every refresh, and the old extraction is
      // exactly the wrong image the user asked to replace.
      final previous = book.coverPath;
      if (previous != null && previous != coverPath) {
        await _deleteIfExists(previous);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已重新提取封面')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重新提取封面失败：${_shortError(error)}')),
        );
      }
    }
  }

  Future<void> _removeBook(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final notes = await ref.read(noteRepositoryProvider).getByBook(book.id);
    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从书库移除？'),
        content: Text(
          notes.isEmpty
              ? '将移除《${book.title}》在 PageSage 中的记录，并删除关联进度、书签、标注、AI 记录和索引。不会删除原始文件路径。'
              : '将移除《${book.title}》在 PageSage 中的记录，并删除 ${notes.length} 条关联笔记、AI 记录和索引。不会删除原始文件路径。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(searchRepositoryProvider).deleteByBook(book.id);
    await ref.read(bookRepositoryProvider).deleteBook(book.id);
  }

  Future<void> _deleteBookData(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除应用副本与数据？'),
        content: Text(
          '将删除《${book.title}》在 PageSage 中的记录、阅读数据、笔记、书签、标注、AI 记录、索引、应用内副本和封面。不会删除原始文件路径。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _deleteIfExists(book.libraryFilePath);
    await _deleteIfExists(book.coverPath);
    await ref.read(searchRepositoryProvider).deleteByBook(book.id);
    await ref.read(bookRepositoryProvider).deleteBook(book.id);
  }

  Future<void> _moveCategory(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final categories = await ref
        .read(categoryRepositoryProvider)
        .getCategories();
    if (!context.mounted) {
      return;
    }
    final categoryId = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动到书架文件夹'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('__uncategorized__'),
            child: const Text('未分类'),
          ),
          ...categories.map(
            (category) => SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(category.id),
              child: Text(category.name),
            ),
          ),
        ],
      ),
    );
    if (categoryId == null) {
      return;
    }
    await ref
        .read(bookRepositoryProvider)
        .updateCategory(
          book.id,
          categoryId == '__uncategorized__' ? null : categoryId,
        );
  }

  Future<void> _editTags(BuildContext context, WidgetRef ref, Book book) async {
    final allTags = await ref.read(tagRepositoryProvider).getTags();
    final currentTags = await ref
        .read(tagRepositoryProvider)
        .getTagsForBook(book.id);
    if (!context.mounted) {
      return;
    }
    final selectedIds = currentTags.map((tag) => tag.id).toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加标签'),
          content: SizedBox(
            width: 420,
            child: allTags.isEmpty
                ? const Text('还没有标签。请先在设置中创建标签。')
                : ListView(
                    shrinkWrap: true,
                    children: allTags
                        .map(
                          (tag) => CheckboxListTile(
                            value: selectedIds.contains(tag.id),
                            title: Text(tag.name),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedIds.add(tag.id);
                                } else {
                                  selectedIds.remove(tag.id);
                                }
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedIds),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result == null) {
      return;
    }
    await ref.read(tagRepositoryProvider).setBookTags(book.id, result);
  }
}

final class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.format});

  final BookFormat format;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPdf = format == BookFormat.pdf;
    final accent = isPdf ? colorScheme.statusInfo : colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          formatBookFormat(format),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

final class _IndexingStatusChip extends StatelessWidget {
  const _IndexingStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'pending' => '待索引',
      'running' => '索引中',
      'failed' => '索引失败',
      'no_text' => '无可索引正文',
      _ => null,
    };
    if (label == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final tone = status == 'failed'
        ? colorScheme.error
        : colorScheme.statusWarning;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        switch (status) {
          'failed' => Icons.error_outline,
          'no_text' => Icons.document_scanner_outlined,
          _ => Icons.hourglass_top,
        },
        size: 16,
        color: tone,
      ),
      label: Text(label),
      backgroundColor: tone.withValues(alpha: 0.10),
      side: BorderSide(color: tone.withValues(alpha: 0.22)),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: tone,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

enum _BookAction {
  open,
  startFromBeginning,
  details,
  rename,
  editAuthor,
  moveCategory,
  tags,
  favorite,
  markFinished,
  openLibraryCopyLocation,
  openOriginalFileLocation,
  rebuildIndex,
  refreshCover,
  delete,
  deleteData,
}

ReadingLocator _startLocatorForBook(Book book) {
  return switch (book.format) {
    BookFormat.epub => ReadingLocator.epub(progress: 0),
    BookFormat.pdf => ReadingLocator.pdf(page: 1, progress: 0),
  };
}

Future<void> _openBookLocationFromDetails(
  BuildContext context,
  WidgetRef ref,
  String filePath, {
  required String successMessage,
}) async {
  try {
    await ref.read(openFileLocationServiceProvider).revealFile(filePath);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开所在位置：${_shortError(error)}')));
    }
  }
}

final class _BookDetailsPanel extends ConsumerWidget {
  const _BookDetailsPanel({required this.item});

  final LibraryBook item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = item.book;
    final progress = item.progress?.progress ?? 0;
    return FutureBuilder<List<Bookmark>>(
      future: ref.read(bookmarkRepositoryProvider).getByBook(book.id),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? const <Bookmark>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 132,
                height: 198,
                child: _BookCover(
                  format: book.format,
                  coverPath: book.coverPath,
                  semanticLabel: '《${book.title}》封面',
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              book.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _bookListSubtitle(item),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(
                  icon: Icons.description_outlined,
                  label: formatBookFormat(book.format),
                ),
                _DetailChip(
                  icon: Icons.trending_up,
                  label: _formatProgressLabel(progress),
                ),
                _DetailChip(
                  icon: Icons.bookmark_border,
                  label: '${bookmarks.length} 个书签',
                ),
                _DetailChip(
                  icon: Icons.storage_outlined,
                  label: _formatFileSize(book.fileSize),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.goNamed(
                'reader',
                pathParameters: {'bookId': book.id},
              ),
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              label: const Text('继续阅读'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.goNamed(
                'reader',
                pathParameters: {'bookId': book.id},
                extra: _startLocatorForBook(book),
              ),
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('从头开始阅读'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _BookActionsMenu.showDetails(context, ref, item),
              icon: const Icon(Icons.info_outline),
              label: const Text('更多详情'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openBookLocationFromDetails(
                context,
                ref,
                book.libraryFilePath,
                successMessage: '已打开书库副本位置',
              ),
              icon: const Icon(Icons.folder_copy_outlined),
              label: const Text('打开书库副本位置'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: book.originalFilePath == null
                  ? null
                  : () => _openBookLocationFromDetails(
                      context,
                      ref,
                      book.originalFilePath!,
                      successMessage: '已打开原文件位置',
                    ),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('打开原文件位置'),
            ),
            const SizedBox(height: 20),
            Text('最近书签', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (bookmarks.isEmpty)
              Text('这本书还没有书签', style: Theme.of(context).textTheme.bodySmall)
            else
              ...bookmarks
                  .take(4)
                  .map(
                    (bookmark) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bookmark_border),
                      title: Text(
                        bookmark.title ?? bookmark.locator.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        bookmark.note?.isNotEmpty == true
                            ? bookmark.note!
                            : bookmark.excerpt ??
                                  _formatBookmarkDate(bookmark.createdAt),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => context.goNamed(
                        'reader',
                        pathParameters: {'bookId': book.id},
                        extra: bookmark.locator,
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

final class _BookDetailsSheet extends StatelessWidget {
  const _BookDetailsSheet({required this.item, required this.bookmarks});

  final LibraryBook item;
  final List<Bookmark> bookmarks;

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final progress = item.progress?.progress ?? 0;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            book.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _bookSubtitle(item),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: Icons.description_outlined,
                label: formatBookFormat(book.format),
              ),
              _DetailChip(
                icon: Icons.trending_up,
                label: progress <= 0 ? '未开始' : '${(progress * 100).round()}%',
              ),
              _DetailChip(
                icon: Icons.bookmark_border,
                label: '${bookmarks.length} 个书签',
              ),
              _DetailChip(
                icon: Icons.storage_outlined,
                label: _formatFileSize(book.fileSize),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () =>
                context.goNamed('reader', pathParameters: {'bookId': book.id}),
            icon: const Icon(Icons.chrome_reader_mode_outlined),
            label: const Text('继续阅读'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.goNamed(
              'reader',
              pathParameters: {'bookId': book.id},
              extra: _startLocatorForBook(book),
            ),
            icon: const Icon(Icons.restart_alt_outlined),
            label: const Text('从头开始阅读'),
          ),
          const SizedBox(height: 20),
          Text('最近书签', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (bookmarks.isEmpty)
            const Text('这本书还没有书签')
          else
            ...bookmarks
                .take(5)
                .map(
                  (bookmark) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bookmark_border),
                    title: Text(
                      bookmark.title ?? bookmark.locator.displayLabel,
                    ),
                    subtitle: Text(
                      bookmark.note?.isNotEmpty == true
                          ? bookmark.note!
                          : bookmark.excerpt ??
                                _formatBookmarkDate(bookmark.createdAt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.goNamed(
                        'reader',
                        pathParameters: {'bookId': book.id},
                        extra: bookmark.locator,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

final class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

final class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.format,
    this.coverPath,
    this.size,
    this.semanticLabel,
  });

  final BookFormat format;
  final String? coverPath;
  final Size? size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final child = _buildCover(context);
    if (size == null) {
      return child;
    }
    return SizedBox(width: size!.width, height: size!.height, child: child);
  }

  Widget _buildCover(BuildContext context) {
    final path = coverPath;
    final radius = BorderRadius.circular(AppRadius.md);
    final colorScheme = Theme.of(context).colorScheme;
    Widget frame(Widget child) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.appBorder.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      );
    }

    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      // Guard against truncated/corrupt covers extracted from PDFs. Native
      // JPEG warnings are noisy and some engines are less forgiving than
      // Flutter's errorBuilder path.
      if (!_looksLikeCoverImage(path)) {
        return frame(_placeholder(context));
      }
      // Decode near display size to avoid multi-MB cover bitmaps in grid/list.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final box = size;
      final cacheWidth = box != null
          ? (box.width * dpr).round().clamp(48, 720)
          : (140 * dpr).round().clamp(48, 720);
      final cacheHeight = box != null
          ? (box.height * dpr).round().clamp(48, 960)
          : (200 * dpr).round().clamp(48, 960);
      return frame(
        Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          semanticLabel: semanticLabel,
          errorBuilder: (context, error, stackTrace) => _placeholder(context),
        ),
      );
    }
    return frame(_placeholder(context));
  }

  bool _looksLikeCoverImage(String path) {
    try {
      final file = File(path);
      final length = file.lengthSync();
      if (length < 128) {
        return false;
      }
      final raf = file.openSync();
      try {
        final header = raf.readSync(3);
        final footer = length >= 2
            ? () {
                raf.setPositionSync(length - 2);
                return raf.readSync(2);
              }()
            : const <int>[];
        // JPEG: FFD8FF … FFD9
        if (header.length >= 3 &&
            header[0] == 0xFF &&
            header[1] == 0xD8 &&
            header[2] == 0xFF) {
          return footer.length == 2 && footer[0] == 0xFF && footer[1] == 0xD9;
        }
        // PNG: 89 50 4E 47
        if (header.length >= 3 &&
            header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4E) {
          return true;
        }
        // WebP / GIF / others: let Image.file try; errorBuilder handles failure.
        return true;
      } finally {
        raf.closeSync();
      }
    } on Object {
      return false;
    }
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceSubtle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final compact = constraints.maxHeight < 72 || textScale > 1.25;
          final iconSize = compact ? 18.0 : 28.0;
          final icon = Icon(
            format == BookFormat.pdf
                ? Icons.picture_as_pdf_outlined
                : Icons.menu_book_outlined,
            size: iconSize,
            color: colorScheme.primary,
          );
          final placeholder = compact
              ? icon
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 6),
                    Text(
                      format == BookFormat.pdf ? 'PDF' : 'EPUB',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
          return Center(
            child: Semantics(
              label: semanticLabel ?? '${formatBookFormat(format)} 封面占位图',
              image: true,
              child: ExcludeSemantics(child: placeholder),
            ),
          );
        },
      ),
    );
  }
}

final class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.progress, this.compact = false});

  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 1).toDouble();
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: value,
            minHeight: compact ? 3 : 4,
            backgroundColor: colorScheme.surfaceSubtle,
            color: colorScheme.primary,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 5),
          Text(
            value == 0 ? '未开始' : '${(value * 100).round()}%',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colorScheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

final class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: message,
      message: '本地数据库暂时不可用，请重试读取。',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重试'),
      ),
    );
  }
}

typedef _CreateCategoryCallback =
    Future<BookCategory?> Function(BuildContext context);

Future<BookCategory?> _createLibraryCategory(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await _askLibraryCategoryName(context);
  if (name == null || name.isEmpty) {
    return null;
  }
  try {
    final category = await ref
        .read(categoryRepositoryProvider)
        .saveCategory(name: name);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已创建书架文件夹“${category.name}”')));
    }
    return category;
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return null;
  }
}

Future<String?> _askLibraryCategoryName(BuildContext context) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => const _CategoryNameDialog(),
  );
  return result?.trim();
}

final class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog();

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

final class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建书架文件夹'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: '文件夹名称'),
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    Navigator.of(context).pop(_controller.text.trim());
  }
}

String _bookSubtitle(LibraryBook item) {
  final author = item.book.author;
  final format = formatBookFormat(item.book.format);
  final progress = item.progress?.progress ?? 0;
  final percent = _formatProgressLabel(progress);
  if (author == null || author.isEmpty) {
    return '$format · $percent';
  }
  return '$author · $format · $percent';
}

String _bookListSubtitle(
  LibraryBook item, {
  String? categoryLabel,
  List<BookTag> tags = const [],
}) {
  final parts = <String>[
    if (item.book.author?.isNotEmpty == true) item.book.author!,
    ?categoryLabel,
    if (tags.isNotEmpty) tags.map((tag) => '#${tag.name}').join(' '),
    formatBookFormat(item.book.format),
    _formatFileSize(item.book.fileSize),
    _formatProgressLabel(item.progress?.progress ?? 0),
    if (item.book.lastOpenedAt != null)
      '最近 ${_formatBookmarkDate(item.book.lastOpenedAt!)}',
  ];
  return parts.join(' · ');
}

String? _categoryLabelForBook(
  List<BookCategory> categories,
  String? categoryId,
) {
  if (categoryId == null) {
    return '未分类';
  }
  for (final category in categories) {
    if (category.id == categoryId) {
      return category.name;
    }
  }
  return null;
}

String _categoryFilterLabel(List<BookCategory> categories, String? categoryId) {
  if (categoryId == '__uncategorized__') {
    return '未分类';
  }
  for (final category in categories) {
    if (category.id == categoryId) {
      return category.name;
    }
  }
  return '分类';
}

String _tagFilterLabel(List<BookTag> tags, String? tagId) {
  for (final tag in tags) {
    if (tag.id == tagId) {
      return tag.name;
    }
  }
  return '标签';
}

String _formatProgressLabel(double progress) {
  return progress <= 0 ? '未开始' : '${(progress * 100).round()}%';
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}

String _formatBookmarkDate(int millisecondsSinceEpoch) {
  final time = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

IconData _viewModeIcon(LibraryViewMode mode) {
  return switch (mode) {
    LibraryViewMode.grid => Icons.grid_view,
    LibraryViewMode.list => Icons.view_list,
    LibraryViewMode.compact => Icons.view_headline,
  };
}

LibraryBook? _findLibraryBook(List<LibraryBook> books, String? bookId) {
  if (bookId == null) {
    return null;
  }
  for (final item in books) {
    if (item.book.id == bookId) {
      return item;
    }
  }
  return null;
}

Future<void> _deleteIfExists(String? path) async {
  if (path == null || path.isEmpty) {
    return;
  }
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

String _shortError(Object error) {
  final text = error.toString();
  return text.length <= 120 ? text : '${text.substring(0, 120)}...';
}
