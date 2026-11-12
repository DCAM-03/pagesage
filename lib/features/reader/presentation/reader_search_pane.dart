import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/search/search_models.dart';
import '../application/in_book_search_controller.dart';
import '../application/reader_excerpt_note_service.dart';

final class ReaderSearchPane extends ConsumerStatefulWidget {
  const ReaderSearchPane({
    required this.bookId,
    required this.onQueryChanged,
    required this.onPreviewResult,
    required this.onClear,
    this.initialQuery,
    this.currentLocator,
    this.onClose,
    this.onAction,
    this.embedded = false,
    super.key,
  });

  final String bookId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ReadingLocator> onPreviewResult;
  final VoidCallback onClear;
  final String? initialQuery;
  final ReadingLocator? currentLocator;
  final VoidCallback? onClose;
  final ValueChanged<InBookSearchAction>? onAction;
  final bool embedded;

  @override
  ConsumerState<ReaderSearchPane> createState() => _ReaderSearchPaneState();
}

final class _ReaderSearchPaneState extends ConsumerState<ReaderSearchPane> {
  final _queryController = TextEditingController();
  late InBookSearchController _searchController;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  void _initializeSearch() {
    _searchController = InBookSearchController(
      bookId: widget.bookId,
      repository: ref.read(searchRepositoryProvider),
      currentLocator: widget.currentLocator,
    )..addListener(_handleSearchStateChanged);
    final initialQuery = widget.initialQuery?.trim() ?? '';
    _queryController.text = initialQuery;
    if (initialQuery.isNotEmpty) {
      unawaited(_searchController.searchNow(initialQuery));
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchStateChanged)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderSearchPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId) {
      _searchController
        ..removeListener(_handleSearchStateChanged)
        ..dispose();
      _initializeSearch();
      return;
    }
    final nextQuery = widget.initialQuery?.trim() ?? '';
    final oldQuery = oldWidget.initialQuery?.trim() ?? '';
    if (nextQuery != oldQuery && nextQuery != _queryController.text.trim()) {
      _queryController.text = nextQuery;
      if (nextQuery.isEmpty) {
        _searchController.clear();
      } else {
        unawaited(_searchController.searchNow(nextQuery));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _searchController.state;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _selectNextAndPreview,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            _selectPreviousAndPreview,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: Padding(
            padding: widget.embedded
                ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                : EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                  ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '本书搜索',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭搜索',
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SearchBar(
                  controller: _queryController,
                  hintText: '搜索当前书籍',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_queryController.text.isNotEmpty)
                      IconButton(
                        tooltip: '清空搜索',
                        onPressed: _clear,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  onChanged: _updateQuery,
                  onSubmitted: (_) => _selectNextAndPreview(),
                ),
                const SizedBox(height: 12),
                if (state.results.isNotEmpty)
                  _SearchNavigationBar(
                    state: state,
                    onPrevious: _selectPreviousAndPreview,
                    onNext: _selectNextAndPreview,
                    onJump: () => _previewSearchResult(state.selectedResult),
                  ),
                const SizedBox(height: 8),
                _buildSearchBody(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectNextAndPreview() {
    final state = _searchController.state;
    if (state.results.isEmpty) {
      unawaited(_searchController.searchNow(_queryController.text));
      return;
    }
    _searchController.selectNext();
    _previewSearchResult(_searchController.state.selectedResult);
  }

  void _selectPreviousAndPreview() {
    final state = _searchController.state;
    if (state.results.isEmpty) {
      unawaited(_searchController.searchNow(_queryController.text));
      return;
    }
    _searchController.selectPrevious();
    _previewSearchResult(_searchController.state.selectedResult);
  }

  void _close() {
    widget.onClear();
    widget.onClose?.call();
    if (!widget.embedded) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildSearchBody(BuildContext context, InBookSearchState state) {
    if (state.query.isEmpty) {
      return const Center(child: Text('输入关键词搜索当前书籍'));
    }
    if (state.isSearching) {
      return const LinearProgressIndicator();
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _searchController.retry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (state.results.isEmpty) {
      return const Center(child: Text('没有找到匹配内容'));
    }
    return Column(
      children: [
        for (var index = 0; index < state.results.length; index++)
          _SearchResultTile(
            result: state.results[index],
            selected: index == state.selectedIndex,
            onSelected: () {
              _searchController.select(index);
              _previewSearchResult(state.results[index]);
            },
            onSaveNote: () => _saveSearchResultAsNote(state.results[index]),
            onAskAi: () => _popSearchAction(
              state.results[index],
              intent: InBookSearchIntent.askAi,
            ),
          ),
      ],
    );
  }

  void _handleSearchStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    _queryController.clear();
    _searchController.clear();
    widget.onClear();
  }

  void _updateQuery(String value) {
    _searchController.updateQuery(value);
    widget.onQueryChanged(value);
  }

  void _popSearchAction(
    SearchResult? result, {
    InBookSearchIntent intent = InBookSearchIntent.jump,
  }) {
    final locator = result?.locator;
    if (result == null || locator == null) {
      return;
    }
    final action = InBookSearchAction(
      locator: locator,
      sourceText: plainSearchSnippet(result.snippet),
      intent: intent,
    );
    if (widget.onAction != null) {
      widget.onAction!(action);
      return;
    }
    Navigator.of(context).pop(action);
  }

  void _previewSearchResult(SearchResult? result) {
    final locator = result?.locator;
    if (locator == null) {
      return;
    }
    widget.onPreviewResult(locator);
  }

  Future<void> _saveSearchResultAsNote(SearchResult result) async {
    final bookId = widget.bookId;
    final note = await ref
        .read(readerExcerptNoteServiceProvider)
        .saveResult(bookId: bookId, result: result);
    if (note == null || !mounted || widget.bookId != bookId) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存为笔记'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

final class _SearchNavigationBar extends StatelessWidget {
  const _SearchNavigationBar({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
  });

  final InBookSearchState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('${state.selectedIndex + 1}/${state.results.length}'),
        const Spacer(),
        IconButton(
          tooltip: '上一条',
          onPressed: onPrevious,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: '下一条',
          onPressed: onNext,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        FilledButton.icon(
          onPressed: state.selectedResult?.locator == null ? null : onJump,
          icon: const Icon(Icons.near_me_outlined),
          label: const Text('跳转'),
        ),
      ],
    );
  }
}

final class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.selected,
    required this.onSelected,
    required this.onSaveNote,
    required this.onAskAi,
  });

  final SearchResult result;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onSaveNote;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    final snippet = plainSearchSnippet(result.snippet);
    return ListTile(
      selected: selected,
      leading: Icon(
        selected ? Icons.arrow_right_outlined : Icons.article_outlined,
      ),
      title: Text(result.isOcrText ? '${result.title} · 识别文本' : result.title),
      subtitle: Text(snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '保存搜索结果为笔记',
            onPressed: result.locator == null ? null : onSaveNote,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: '对搜索结果片段提问',
            onPressed: result.locator == null ? null : onAskAi,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      onTap: result.locator == null ? null : onSelected,
    );
  }
}

enum InBookSearchIntent { jump, askAi }

final class InBookSearchAction {
  const InBookSearchAction({
    required this.locator,
    required this.sourceText,
    required this.intent,
  });

  final ReadingLocator locator;
  final String sourceText;
  final InBookSearchIntent intent;
}
