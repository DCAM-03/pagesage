import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';
import '../../ai/presentation/ai_panel.dart';
import 'reader_notebook.dart';
import 'reader_search_pane.dart';

extension ReaderContextTabPresentation on ReaderContextTab {
  String get label => switch (this) {
    ReaderContextTab.search => '搜索',
    ReaderContextTab.notebook => '笔记',
    ReaderContextTab.ai => 'AI',
  };

  IconData get icon => switch (this) {
    ReaderContextTab.search => Icons.search,
    ReaderContextTab.notebook => Icons.library_books_outlined,
    ReaderContextTab.ai => Icons.auto_awesome_outlined,
  };
}

final class _ContextTabChip extends StatelessWidget {
  const _ContextTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ReaderContextTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The selected tab is the one that paints the rule under itself;
          // the others keep the space so the row does not jump.
          border: Border(
            bottom: BorderSide(
              color: selected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 16,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                tab.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class ReaderContextPane extends StatelessWidget {
  const ReaderContextPane({
    required this.bookId,
    required this.activeTab,
    required this.searchQuery,
    required this.currentLocator,
    required this.selectedText,
    required this.selectedLocator,
    required this.onQueryChanged,
    required this.onPreviewResult,
    required this.onClear,
    required this.onClose,
    required this.onTabChanged,
    required this.onAction,
    this.bookPath,
    required this.format,
    this.onNoteSaved,
    super.key,
  });

  final String bookId;

  /// The book on disk, so the AI panel can read a page or chapter.
  final String? bookPath;

  final BookFormat format;
  final ReaderContextTab activeTab;
  final String? searchQuery;
  final ReadingLocator? currentLocator;
  final String? selectedText;
  final ReadingLocator? selectedLocator;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ReadingLocator> onPreviewResult;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final ValueChanged<ReaderContextTab> onTabChanged;
  final ValueChanged<InBookSearchAction> onAction;
  final VoidCallback? onNoteSaved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.appBorder.withValues(alpha: 0.95),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x2,
                AppSpacing.x2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          switch (activeTab) {
                            ReaderContextTab.search => '在本书内查找并跳转',
                            ReaderContextTab.notebook => '书签、标注与笔记',
                            ReaderContextTab.ai => '对选中文本提问',
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '收起侧栏',
                    onPressed: onClose,
                    icon: const Icon(Icons.keyboard_tab),
                  ),
                ],
              ),
            ),
            // Flat tabs over one hairline, same as the AI panel's own
            // 提问 / 历史 strip. As a bordered pill this stacked a pill
            // inside a pill directly above another pill bar, which is what
            // made the rail read as a column of frames.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.appBorder.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    for (final tab in ReaderContextTab.values)
                      Expanded(
                        child: _ContextTabChip(
                          tab: tab,
                          selected: activeTab == tab,
                          onTap: () => onTabChanged(tab),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildTab(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context) {
    return switch (activeTab) {
      ReaderContextTab.search => ReaderSearchPane(
        bookId: bookId,
        initialQuery: searchQuery,
        currentLocator: currentLocator,
        onQueryChanged: onQueryChanged,
        onPreviewResult: onPreviewResult,
        onClear: onClear,
        onClose: onClose,
        onAction: onAction,
        embedded: true,
      ),
      ReaderContextTab.notebook => ReaderNotebookPane(
        bookId: bookId,
        onSelected: onPreviewResult,
      ),
      ReaderContextTab.ai => AiPanel(
        bookId: bookId,
        bookPath: bookPath,
        format: format,
        locator: selectedLocator ?? currentLocator,
        initialContext: selectedText ?? currentLocator?.excerpt,
        onJumpTo: onPreviewResult,
        onNoteSaved: onNoteSaved,
        embedded: true,
      ),
    };
  }
}
