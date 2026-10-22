import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import '../../../domain/search/search_models.dart';
import '../../../renderers/epub/epub_jump.dart';
import '../../ai/application/ai_providers.dart';
import '../../library/application/library_providers.dart';

final class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  Future<_SearchPageResult>? _future;
  int _searchGeneration = 0;
  bool _rebuildingIndex = false;
  Set<SearchResultType> _typeFilters = const {};
  BookFormat? _formatFilter;
  String? _categoryFilterId;
  String? _tagFilterId;
  String? _bookFilterId;
  SearchResult? _previewResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryBooks = ref.watch(libraryBooksProvider);
    final horizontalPadding = context.appBreakpoint.isCompact
        ? AppSpacing.x4
        : AppSpacing.x6;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: '搜索',
              subtitle: '搜索本地书库、正文、Notebook 和 AI 历史',
              showThemeMode: true,
              actions: [
                IconButton(
                  tooltip: '清空搜索',
                  onPressed: _controller.text.isEmpty ? null : _clearSearch,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: SearchBar(
                controller: _controller,
                focusNode: _searchFocusNode,
                hintText: '搜索书名、作者、笔记、书签和 AI 回答',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      tooltip: '清空',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    ),
                ],
                onSubmitted: (_) => _search(),
                onChanged: (_) {
                  setState(() {});
                  _debouncedSearch();
                },
              ),
            ),
            _SearchFilters(
              typeFilters: _typeFilters,
              format: _formatFilter,
              categoryId: _categoryFilterId,
              tagId: _tagFilterId,
              bookId: _bookFilterId,
              onTypeChanged: (value) => _updateFilters(
                typeFilters: value,
                format: _formatFilter,
                categoryId: _categoryFilterId,
                tagId: _tagFilterId,
                bookId: _bookFilterId,
              ),
              onFormatChanged: (value) => _updateFilters(
                typeFilters: _typeFilters,
                format: value,
                categoryId: _categoryFilterId,
                tagId: _tagFilterId,
                bookId: _bookFilterId,
              ),
              onCategoryChanged: (value) => _updateFilters(
                typeFilters: _typeFilters,
                format: _formatFilter,
                categoryId: value,
                tagId: _tagFilterId,
                bookId: _bookFilterId,
              ),
              onTagChanged: (value) => _updateFilters(
                typeFilters: _typeFilters,
                format: _formatFilter,
                categoryId: _categoryFilterId,
                tagId: value,
                bookId: _bookFilterId,
              ),
              onBookChanged: (value) => _updateFilters(
                typeFilters: _typeFilters,
                format: _formatFilter,
                categoryId: _categoryFilterId,
                tagId: _tagFilterId,
                bookId: value,
              ),
              onClear: _clearFilters,
            ),
            libraryBooks.when(
              data: (books) => Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _IndexingStatusBanner(
                  books: books,
                  rebuilding: _rebuildingIndex,
                  onRebuildPending: () => _rebuildIndexes(books),
                  onRebuildAll: () => _rebuildIndexes(books, includeDone: true),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.x3),
            Expanded(
              child: FutureBuilder<_SearchPageResult>(
                future: _future,
                builder: _buildResultArea,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea(
    BuildContext context,
    AsyncSnapshot<_SearchPageResult> snapshot,
  ) {
    final horizontalPadding = context.appBreakpoint.isCompact
        ? AppSpacing.x4
        : AppSpacing.x6;
    final bottomPadding = context.appBreakpoint.isCompact ? 144.0 : 96.0;
    if (_future == null) {
      return const _SearchEmptyState();
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.x6),
        child: LinearProgressIndicator(),
      );
    }
    if (snapshot.hasError) {
      return _SearchError(onRetry: _search);
    }
    final result = snapshot.data!;
    if (result.books.isEmpty && result.results.isEmpty) {
      final books =
          ref.read(libraryBooksProvider).value ?? const <LibraryBook>[];
      final indexing = books.any(
        (item) =>
            item.book.indexingStatus == 'pending' ||
            item.book.indexingStatus == 'running',
      );
      final failed = books.any((item) => item.book.indexingStatus == 'failed');
      return _NoSearchResult(
        indexing: indexing || _rebuildingIndex,
        failed: failed,
        onRebuild: () => _rebuildIndexes(books),
      );
    }
    final supportsPreview = context.supportsSidePanel;
    final list = _SearchResultsList(
      result: result,
      selected: supportsPreview ? _previewResult : null,
      onPreview: supportsPreview
          ? (item) => setState(() => _previewResult = item)
          : null,
    );
    if (!supportsPreview) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          bottomPadding,
        ),
        children: [list],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              AppSpacing.x4,
              bottomPadding,
            ),
            children: [list],
          ),
        ),
        SizedBox(
          width: 360,
          child: _SearchPreviewPanel(result: _previewResult),
        ),
      ],
    );
  }

  void _debouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      _search();
    });
  }

  void _search() {
    _debounceTimer?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _future = null;
        _previewResult = null;
      });
      return;
    }
    final generation = ++_searchGeneration;
    setState(() {
      _future = _loadResults(query, generation);
      _previewResult = null;
    });
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    _searchGeneration += 1;
    setState(() {
      _future = null;
      _previewResult = null;
    });
    _searchFocusNode.requestFocus();
  }

  void _updateFilters({
    required Set<SearchResultType> typeFilters,
    required BookFormat? format,
    required String? categoryId,
    required String? tagId,
    required String? bookId,
  }) {
    setState(() {
      _typeFilters = typeFilters;
      _formatFilter = format;
      _categoryFilterId = categoryId;
      _tagFilterId = tagId;
      _bookFilterId = bookId;
    });
    _search();
  }

  void _clearFilters() {
    setState(() {
      _typeFilters = const {};
      _formatFilter = null;
      _categoryFilterId = null;
      _tagFilterId = null;
      _bookFilterId = null;
    });
    _search();
  }

  Future<_SearchPageResult> _loadResults(String query, int generation) async {
    final books = await ref.read(bookRepositoryProvider).getLibrary();
    if (!mounted || generation != _searchGeneration) {
      return const _SearchPageResult(books: [], results: []);
    }
    final lowerQuery = query.toLowerCase();
    final matchedBooks = <LibraryBook>[];
    for (final item in books) {
      if (!_bookMatchesText(item, lowerQuery) || !_bookMatchesFilters(item)) {
        continue;
      }
      if (_tagFilterId != null) {
        final tags = await ref
            .read(tagRepositoryProvider)
            .getTagsForBook(item.book.id);
        if (!tags.any((tag) => tag.id == _tagFilterId)) {
          continue;
        }
      }
      matchedBooks.add(item);
    }
    if (!mounted || generation != _searchGeneration) {
      return const _SearchPageResult(books: [], results: []);
    }
    final results = await ref
        .read(searchRepositoryProvider)
        .search(
          SearchQuery(
            query: query,
            typeFilters: _typeFilters,
            bookId: _bookFilterId,
            categoryId: _categoryFilterId,
            tagIds: _tagFilterId == null ? const {} : {_tagFilterId!},
            format: _formatFilter,
          ),
        );
    if (!mounted || generation != _searchGeneration) {
      return const _SearchPageResult(books: [], results: []);
    }
    return _SearchPageResult(books: matchedBooks, results: results);
  }

  bool _bookMatchesText(LibraryBook item, String lowerQuery) {
    return item.book.title.toLowerCase().contains(lowerQuery) ||
        (item.book.author ?? '').toLowerCase().contains(lowerQuery);
  }

  bool _bookMatchesFilters(LibraryBook item) {
    final book = item.book;
    if (_bookFilterId != null && book.id != _bookFilterId) {
      return false;
    }
    if (_formatFilter != null && book.format != _formatFilter) {
      return false;
    }
    if (_categoryFilterId == '__uncategorized__' && book.categoryId != null) {
      return false;
    }
    if (_categoryFilterId != null &&
        _categoryFilterId != '__uncategorized__' &&
        book.categoryId != _categoryFilterId) {
      return false;
    }
    return true;
  }

  Future<void> _rebuildIndexes(
    List<LibraryBook> books, {
    bool includeDone = false,
  }) async {
    if (_rebuildingIndex) {
      return;
    }
    final targets = includeDone
        ? books
        : books
              .where(
                (item) =>
                    item.book.indexingStatus == 'pending' ||
                    item.book.indexingStatus == 'failed',
              )
              .toList(growable: false);
    if (targets.isEmpty) {
      return;
    }
    setState(() => _rebuildingIndex = true);
    var failed = 0;
    try {
      for (final item in targets) {
        try {
          await ref.read(searchIndexerProvider).indexBook(item.book);
        } catch (_) {
          failed += 1;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _rebuildingIndex = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failed == 0
                  ? includeDone
                        ? '已重建全部索引'
                        : '索引重建完成'
                  : '索引重建完成，失败 $failed 本',
            ),
          ),
        );
      }
    }
  }
}

final class _SearchResultGroup {
  const _SearchResultGroup({required this.label, required this.results});

  final String label;
  final List<SearchResult> results;
}

List<_SearchResultGroup> _groupSearchResults(List<SearchResult> results) {
  final books = <SearchResult>[];
  final content = <SearchResult>[];
  final notebook = <SearchResult>[];
  final ai = <SearchResult>[];
  for (final result in results) {
    switch (result.type) {
      case SearchResultType.book:
        books.add(result);
      case SearchResultType.content:
        content.add(result);
      case SearchResultType.note || SearchResultType.bookmark:
        notebook.add(result);
      case SearchResultType.ai:
        ai.add(result);
    }
  }
  return [
    if (books.isNotEmpty) _SearchResultGroup(label: '书籍', results: books),
    if (content.isNotEmpty) _SearchResultGroup(label: '正文', results: content),
    if (notebook.isNotEmpty)
      _SearchResultGroup(label: 'Notebook', results: notebook),
    if (ai.isNotEmpty) _SearchResultGroup(label: 'AI', results: ai),
  ];
}

final class _SearchPageResult {
  const _SearchPageResult({required this.books, required this.results});

  final List<LibraryBook> books;
  final List<SearchResult> results;
}

final class _SearchFilters extends ConsumerWidget {
  const _SearchFilters({
    required this.typeFilters,
    required this.format,
    required this.categoryId,
    required this.tagId,
    required this.bookId,
    required this.onTypeChanged,
    required this.onFormatChanged,
    required this.onCategoryChanged,
    required this.onTagChanged,
    required this.onBookChanged,
    required this.onClear,
  });

  final Set<SearchResultType> typeFilters;
  final BookFormat? format;
  final String? categoryId;
  final String? tagId;
  final String? bookId;
  final ValueChanged<Set<SearchResultType>> onTypeChanged;
  final ValueChanged<BookFormat?> onFormatChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onBookChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(tagsProvider);
    final books = ref.watch(libraryBooksProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          ...SearchResultType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_typeLabel(type)),
                selected: typeFilters.contains(type),
                onSelected: (_) {
                  final next = {...typeFilters};
                  if (!next.add(type)) {
                    next.remove(type);
                  }
                  onTypeChanged(next);
                },
              ),
            ),
          ),
          _SearchMenuButton<BookFormat?>(
            icon: Icons.description_outlined,
            label: format == null ? '格式' : _formatLabel(format!),
            onClear: format == null ? null : () => onFormatChanged(null),
            entries: [
              const PopupMenuItem(value: null, child: Text('全部格式')),
              ...BookFormat.values.map(
                (value) => PopupMenuItem(
                  value: value,
                  child: Text(_formatLabel(value)),
                ),
              ),
            ],
            onSelected: onFormatChanged,
          ),
          categories.when(
            data: (items) => _SearchMenuButton<String?>(
              icon: Icons.folder_outlined,
              label: categoryId == null
                  ? '分类'
                  : _categoryLabel(items, categoryId!),
              onClear: categoryId == null
                  ? null
                  : () => onCategoryChanged(null),
              entries: [
                const PopupMenuItem(value: null, child: Text('全部分类')),
                const PopupMenuItem(
                  value: '__uncategorized__',
                  child: Text('未分类'),
                ),
                ...items.map(
                  (category) => PopupMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onSelected: onCategoryChanged,
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          tags.when(
            data: (items) => _SearchMenuButton<String?>(
              icon: Icons.label_outline,
              label: tagId == null ? '标签' : _tagLabel(items, tagId!),
              onClear: tagId == null ? null : () => onTagChanged(null),
              entries: [
                const PopupMenuItem(value: null, child: Text('全部标签')),
                ...items.map(
                  (tag) => PopupMenuItem(value: tag.id, child: Text(tag.name)),
                ),
              ],
              onSelected: onTagChanged,
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          books.when(
            data: (items) => _SearchMenuButton<String?>(
              icon: Icons.menu_book_outlined,
              label: bookId == null ? '书籍范围' : _bookLabel(items, bookId!),
              onClear: bookId == null ? null : () => onBookChanged(null),
              entries: [
                const PopupMenuItem(value: null, child: Text('全部书籍')),
                ...items.map(
                  (item) => PopupMenuItem(
                    value: item.book.id,
                    child: Text(item.book.title),
                  ),
                ),
              ],
              onSelected: onBookChanged,
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(SearchResultType type) {
    return switch (type) {
      SearchResultType.book => '书籍',
      SearchResultType.content => '正文',
      SearchResultType.note => '笔记',
      SearchResultType.bookmark => '书签',
      SearchResultType.ai => 'AI',
    };
  }

  String _formatLabel(BookFormat format) {
    return switch (format) {
      BookFormat.epub => 'EPUB',
      BookFormat.pdf => 'PDF',
    };
  }

  String _categoryLabel(List<dynamic> categories, String id) {
    if (id == '__uncategorized__') {
      return '未分类';
    }
    for (final category in categories) {
      if (category.id == id) {
        return category.name;
      }
    }
    return '分类';
  }

  String _tagLabel(List<dynamic> tags, String id) {
    for (final tag in tags) {
      if (tag.id == id) {
        return tag.name;
      }
    }
    return '标签';
  }

  String _bookLabel(List<LibraryBook> books, String id) {
    for (final item in books) {
      if (item.book.id == id) {
        return item.book.title;
      }
    }
    return '书籍范围';
  }
}

final class _SearchMenuButton<T> extends StatelessWidget {
  const _SearchMenuButton({
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
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
      ),
    );
  }
}

final class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.result,
    required this.selected,
    required this.onPreview,
  });

  final _SearchPageResult result;
  final SearchResult? selected;
  final ValueChanged<SearchResult>? onPreview;

  @override
  Widget build(BuildContext context) {
    final groups = _groupSearchResults(result.results);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            FocusScope.of(context).nextFocus(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            FocusScope.of(context).previousFocus(),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.books.isNotEmpty) ...[
            _SearchGroupHeader(label: '书籍', count: result.books.length),
            const SizedBox(height: AppSpacing.x2),
            ...result.books.map((item) => _BookSearchTile(item: item)),
            const SizedBox(height: AppSpacing.x4),
          ],
          for (final group in groups) ...[
            _SearchGroupHeader(label: group.label, count: group.results.length),
            const SizedBox(height: AppSpacing.x2),
            ...group.results.map(
              (item) => _SearchResultTile(
                result: item,
                selected: selected?.id == item.id,
                onPreview: onPreview == null ? null : () => onPreview!(item),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
        ],
      ),
    );
  }
}

final class _SearchGroupHeader extends StatelessWidget {
  const _SearchGroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        _SearchMetaChip(label: '$count'),
      ],
    );
  }
}

final class _BookSearchTile extends StatelessWidget {
  const _BookSearchTile({required this.item});

  final LibraryBook item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(
            item.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(item.book.author ?? '未知作者'),
          trailing: _SearchMetaChip(label: item.book.format.name.toUpperCase()),
          onTap: () => context.goNamed(
            'reader',
            pathParameters: {'bookId': item.book.id},
          ),
        ),
      ),
    );
  }
}

final class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({
    required this.result,
    required this.selected,
    required this.onPreview,
  });

  final SearchResult result;
  final bool selected;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final plainSnippet = _plainSearchSnippet(result.snippet);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onPreview ?? () => _openResult(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconForType(result.type), color: colorScheme.primary),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _SearchMetaChip(label: _searchTypeLabel(result.type)),
                          if (result.locator != null) ...[
                            const SizedBox(width: AppSpacing.x2),
                            Flexible(
                              child: _SearchMetaChip(
                                label: result.locator!.displayLabel,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      RichText(
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        text: _snippetSpan(context, result.snippet),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '保存搜索片段为笔记',
                      onPressed: plainSnippet.isEmpty
                          ? null
                          : () => unawaited(
                              _saveSnippetAsNote(context, ref, plainSnippet),
                            ),
                      icon: const Icon(Icons.note_add_outlined),
                    ),
                    IconButton(
                      tooltip: '对搜索片段提问',
                      onPressed: plainSnippet.isEmpty
                          ? null
                          : () => unawaited(
                              _askAiAboutSnippet(context, ref, plainSnippet),
                            ),
                      icon: const Icon(Icons.auto_awesome_outlined),
                    ),
                    PopupMenuButton<_SearchResultAction>(
                      tooltip: '更多搜索结果操作',
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _SearchResultAction.open,
                          child: Text(
                            result.type == SearchResultType.note ||
                                    result.type == SearchResultType.ai
                                ? (result.locator != null ||
                                          result.bookId != null
                                      ? '跳转原文'
                                      : '查看详情')
                                : '打开来源',
                          ),
                        ),
                        const PopupMenuItem(
                          value: _SearchResultAction.copySnippet,
                          child: Text('复制片段'),
                        ),
                        if (result.bookId != null) const PopupMenuDivider(),
                        if (result.bookId != null)
                          const PopupMenuItem(
                            value: _SearchResultAction.rebuildBookIndex,
                            child: Text('重建本书索引'),
                          ),
                      ],
                      onSelected: (action) {
                        switch (action) {
                          case _SearchResultAction.open:
                            _openResult(context, ref);
                          case _SearchResultAction.copySnippet:
                            unawaited(_copySnippet(context, plainSnippet));
                          case _SearchResultAction.rebuildBookIndex:
                            unawaited(_rebuildBookIndex(context, ref));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copySnippet(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制片段')));
  }

  Future<void> _saveSnippetAsNote(
    BuildContext context,
    WidgetRef ref,
    String text,
  ) async {
    if (text.trim().isEmpty) {
      return;
    }
    await ref
        .read(noteRepositoryProvider)
        .saveNote(
          bookId: result.bookId,
          title: result.title,
          content: text,
          sourceText: text,
          locator: result.locator,
          noteType: NoteType.excerpt,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存为笔记')));
  }

  Future<void> _askAiAboutSnippet(
    BuildContext context,
    WidgetRef ref,
    String text,
  ) async {
    if (text.trim().isEmpty) {
      return;
    }
    final promptController = TextEditingController(text: '解释这段内容的重点');
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('对片段提问'),
        content: _SearchDialogContent(
          maxWidth: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '上下文范围：当前搜索结果片段',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.x3),
              TextField(
                controller: promptController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '问题',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(promptController.text.trim()),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    promptController.dispose();
    if (prompt == null || prompt.isEmpty) {
      return;
    }
    try {
      await ref
          .read(aiChatServiceProvider)
          .ask(
            bookId: result.bookId,
            locator: result.locator,
            contextText: text,
            prompt: prompt,
            sourceText: text,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI 回答已保存')));
    } on AiChatException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _rebuildBookIndex(BuildContext context, WidgetRef ref) async {
    final bookId = result.bookId;
    if (bookId == null) {
      return;
    }
    final book = await ref.read(bookRepositoryProvider).getBook(bookId);
    if (!context.mounted) {
      return;
    }
    if (book == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到这本书')));
      return;
    }
    try {
      await ref.read(searchIndexerProvider).indexBook(book);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已重建本书索引')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重建本书索引失败')));
      }
    }
  }

  void _openResult(BuildContext context, WidgetRef ref) {
    switch (result.type) {
      case SearchResultType.note:
        unawaited(_openNoteResult(context, ref));
        return;
      case SearchResultType.ai:
        unawaited(_openAiResult(context, ref));
        return;
      case SearchResultType.book ||
          SearchResultType.content ||
          SearchResultType.bookmark:
        break;
    }
    final bookId = result.bookId;
    if (bookId == null) {
      return;
    }
    final locator = result.locator;
    context.goNamed(
      'reader',
      pathParameters: {'bookId': bookId},
      extra: locator == null
          ? null
          : enrichLocatorForJump(
              locator,
              fallbackExcerpt: _plainSearchSnippet(result.snippet),
            ),
    );
  }

  Future<void> _openNoteResult(BuildContext context, WidgetRef ref) async {
    final noteId = result.sourceId;
    if (noteId == null) {
      context.go('/notes');
      return;
    }
    final note = await ref.read(noteRepositoryProvider).getNote(noteId);
    if (!context.mounted) {
      return;
    }
    if (note == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到这条笔记')));
      return;
    }

    // One-tap jump when we can open the source book at a known locator.
    final bookId = note.bookId ?? result.bookId;
    final locator = note.locator ?? result.locator;
    if (bookId != null && locator != null) {
      context.goNamed(
        'reader',
        pathParameters: {'bookId': bookId},
        extra: enrichLocatorForJump(
          locator,
          fallbackExcerpt:
              note.sourceText ?? _plainSearchSnippet(result.snippet),
        ),
      );
      return;
    }

    await _showNoteDialog(context, note);
  }

  Future<void> _showNoteDialog(BuildContext context, Note note) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note.title?.isNotEmpty == true ? note.title! : '笔记详情'),
        content: _SearchDialogContent(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note.sourceText?.isNotEmpty == true) ...[
                Text('原文', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                SelectableText(note.sourceText!),
                const SizedBox(height: 16),
              ],
              Text('内容', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SelectableText(note.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          if (note.bookId != null && note.locator == null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.goNamed(
                  'reader',
                  pathParameters: {'bookId': note.bookId!},
                );
              },
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('打开书籍'),
            ),
          if (note.bookId != null && note.locator != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.goNamed(
                  'reader',
                  pathParameters: {'bookId': note.bookId!},
                  extra: enrichLocatorForJump(
                    note.locator!,
                    fallbackExcerpt: note.sourceText,
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('跳转原文'),
            ),
        ],
      ),
    );
  }

  Future<void> _openAiResult(BuildContext context, WidgetRef ref) async {
    final conversationId = result.sourceId;
    if (conversationId == null) {
      return;
    }
    final conversations = await ref
        .read(aiConversationRepositoryProvider)
        .getConversations();
    AiConversation? conversation;
    for (final item in conversations) {
      if (item.id == conversationId) {
        conversation = item;
        break;
      }
    }
    if (!context.mounted) {
      return;
    }
    if (conversation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到这条 AI 记录')));
      return;
    }

    final bookId = conversation.bookId ?? result.bookId;
    final locator = conversation.locator ?? result.locator;
    if (bookId != null && locator != null) {
      context.goNamed(
        'reader',
        pathParameters: {'bookId': bookId},
        extra: enrichLocatorForJump(
          locator,
          fallbackExcerpt:
              conversation.sourceText ??
              conversation.contextText ??
              _plainSearchSnippet(result.snippet),
        ),
      );
      return;
    }

    await _showAiDialog(context, conversation);
  }

  Future<void> _showAiDialog(
    BuildContext context,
    AiConversation conversation,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 记录'),
        content: _SearchDialogContent(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('问题', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SelectableText(conversation.prompt),
              if (conversation.contextText?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text('上下文', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                SelectableText(conversation.contextText!),
              ],
              const SizedBox(height: 16),
              Text('回答', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SelectableText(conversation.answer),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: conversation.answer)),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制回答'),
          ),
          if (conversation.bookId != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                final locator = conversation.locator;
                context.goNamed(
                  'reader',
                  pathParameters: {'bookId': conversation.bookId!},
                  extra: locator == null
                      ? null
                      : enrichLocatorForJump(
                          locator,
                          fallbackExcerpt:
                              conversation.contextText ??
                              conversation.sourceText,
                        ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('回跳原文'),
            ),
        ],
      ),
    );
  }

  IconData _iconForType(SearchResultType type) {
    return switch (type) {
      SearchResultType.book => Icons.menu_book_outlined,
      SearchResultType.content => Icons.article_outlined,
      SearchResultType.note => Icons.edit_note_outlined,
      SearchResultType.bookmark => Icons.bookmark_border,
      SearchResultType.ai => Icons.auto_awesome_outlined,
    };
  }
}

enum _SearchResultAction { open, copySnippet, rebuildBookIndex }

final class _SearchMetaChip extends StatelessWidget {
  const _SearchMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _SearchDialogContent extends StatelessWidget {
  const _SearchDialogContent({required this.child, required this.maxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height * 0.54),
      child: SingleChildScrollView(child: child),
    );
  }
}

final class _SearchPreviewPanel extends StatelessWidget {
  const _SearchPreviewPanel({required this.result});

  final SearchResult? result;

  @override
  Widget build(BuildContext context) {
    final selected = result;
    if (selected == null) {
      return const AppSidePanel(
        title: '预览',
        child: AppEmptyState(
          icon: Icons.preview_outlined,
          title: '选择一个结果',
          message: '桌面端会在这里显示来源、位置和命中片段。',
          action: SizedBox.shrink(),
        ),
      );
    }
    return AppSidePanel(
      title: '预览',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          Row(
            children: [
              _SearchMetaChip(label: _searchTypeLabel(selected.type)),
              if (selected.locator != null) ...[
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: _SearchMetaChip(label: selected.locator!.displayLabel),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            selected.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x3),
          SelectableText.rich(_snippetSpan(context, selected.snippet)),
          const SizedBox(height: AppSpacing.x4),
          if (selected.bookId != null)
            FilledButton.icon(
              onPressed: () => context.goNamed(
                'reader',
                pathParameters: {'bookId': selected.bookId!},
                extra: selected.locator == null
                    ? null
                    : enrichLocatorForJump(
                        selected.locator!,
                        fallbackExcerpt: _plainSearchSnippet(selected.snippet),
                      ),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(
                selected.type == SearchResultType.note ||
                        selected.type == SearchResultType.ai
                    ? '跳转原文'
                    : '打开来源',
              ),
            ),
        ],
      ),
    );
  }
}

String _plainSearchSnippet(String snippet) {
  return snippet
      .replaceAll(RegExp(r'</?mark>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

TextSpan _snippetSpan(BuildContext context, String snippet) {
  final colorScheme = Theme.of(context).colorScheme;
  final highContrast =
      MediaQuery.highContrastOf(context) ||
      (colorScheme.outline == Colors.black &&
          colorScheme.onSurface == Colors.black);
  final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: colorScheme.onSurfaceVariant,
    height: 1.45,
  );
  final highlightStyle = baseStyle?.copyWith(
    color: colorScheme.onSurface,
    backgroundColor: highContrast
        ? const Color(0xFFFFFF00)
        : AppColors.warning.withValues(alpha: 0.22),
    fontWeight: FontWeight.w700,
  );
  final spans = <TextSpan>[];
  final regex = RegExp(r'<mark>(.*?)</mark>', caseSensitive: false);
  var offset = 0;
  for (final match in regex.allMatches(snippet)) {
    if (match.start > offset) {
      spans.add(
        TextSpan(
          text: _plainSearchSnippet(snippet.substring(offset, match.start)),
        ),
      );
    }
    spans.add(TextSpan(text: match.group(1) ?? '', style: highlightStyle));
    offset = match.end;
  }
  if (offset < snippet.length) {
    spans.add(TextSpan(text: _plainSearchSnippet(snippet.substring(offset))));
  }
  return TextSpan(
    style: baseStyle,
    children: spans.isEmpty
        ? [TextSpan(text: _plainSearchSnippet(snippet))]
        : spans,
  );
}

String _searchTypeLabel(SearchResultType type) {
  return switch (type) {
    SearchResultType.book => '书籍',
    SearchResultType.content => '正文',
    SearchResultType.note => '笔记',
    SearchResultType.bookmark => '书签',
    SearchResultType.ai => 'AI',
  };
}

final class _IndexingStatusBanner extends StatelessWidget {
  const _IndexingStatusBanner({
    required this.books,
    required this.rebuilding,
    required this.onRebuildPending,
    required this.onRebuildAll,
  });

  final List<LibraryBook> books;
  final bool rebuilding;
  final VoidCallback onRebuildPending;
  final VoidCallback onRebuildAll;

  @override
  Widget build(BuildContext context) {
    final pending = _countStatus('pending');
    final running = _countStatus('running');
    final failed = _countStatus('failed');
    if (pending == 0 && running == 0 && failed == 0 && !rebuilding) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 520;
    final statusText = rebuilding
        ? '正在重建索引...'
        : '索引状态：待处理 $pending，进行中 $running，失败 $failed';
    final actions = [
      (compact ? TextButton.icon : OutlinedButton.icon)(
        onPressed: rebuilding || pending + failed == 0
            ? null
            : onRebuildPending,
        icon: rebuilding
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_outlined),
        label: const Text('重建待处理'),
      ),
      (compact ? TextButton.icon : OutlinedButton.icon)(
        onPressed: rebuilding || books.isEmpty ? null : onRebuildAll,
        icon: const Icon(Icons.restart_alt_outlined),
        label: const Text('重建全部'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.manage_search_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(statusText)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.manage_search_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(statusText)),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ),
        ),
      ),
    );
  }

  int _countStatus(String status) {
    return books.where((item) => item.book.indexingStatus == status).length;
  }
}

final class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.manage_search_outlined,
      illustrationAsset: 'assets/images/empty-states/empty-search.png',
      title: '输入关键词后搜索',
      message: '搜索本地书库、正文、Notebook 和 AI 历史。',
    );
  }
}

final class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult({
    this.indexing = false,
    this.failed = false,
    this.onRebuild,
  });

  final bool indexing;
  final bool failed;
  final VoidCallback? onRebuild;

  @override
  Widget build(BuildContext context) {
    if (indexing) {
      return AppEmptyState(
        icon: Icons.hourglass_top_outlined,
        title: '索引仍在进行',
        message: '正文索引完成后结果会更完整。可先搜索书名，或稍后再试。',
        action: onRebuild == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRebuild,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('重建待处理索引'),
              ),
      );
    }
    if (failed) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '没有匹配内容',
        message: '部分书籍索引失败，重建索引后再搜索正文会更准确。',
        action: onRebuild == null
            ? null
            : FilledButton.icon(
                onPressed: onRebuild,
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('重建失败索引'),
              ),
      );
    }
    return const AppEmptyState(
      icon: Icons.search_off_outlined,
      title: '没有找到匹配内容',
      message: '换一个关键词，或清除筛选后再试。也可在上方重建索引。',
    );
  }
}

final class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: '搜索失败',
      message: '请检查本地数据库后重试。若刚导入书籍，可先重建索引。',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重试搜索'),
      ),
    );
  }
}
