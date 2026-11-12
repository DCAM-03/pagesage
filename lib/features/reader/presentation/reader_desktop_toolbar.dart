import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../domain/books/reader_settings.dart';
import 'reader_chrome.dart';

final class ReaderDesktopToolbar extends StatelessWidget
    implements PreferredSizeWidget {
  const ReaderDesktopToolbar({
    required this.title,
    required this.tocOpen,
    required this.activeContextTab,
    required this.bookmarked,
    required this.onBack,
    required this.onToc,
    required this.onSearch,
    required this.onBookmark,
    required this.onNotebook,
    required this.onAi,
    required this.onSettings,
    required this.onMore,
    required this.moreItems,
    super.key,
  });

  final String title;
  final bool tocOpen;
  final ReaderContextTab? activeContextTab;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback? onToc;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onNotebook;
  final VoidCallback onAi;
  final VoidCallback? onSettings;
  final ValueChanged<ReaderMoreAction> onMore;
  final PopupMenuItemBuilder<ReaderMoreAction> moreItems;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tocLabel = tocOpen ? '收起目录' : '目录';
    final bookmarkLabel = bookmarked ? '取消书签' : '加书签';
    return AppBar(
      leading: IconButton(
        tooltip: '返回书库',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      titleSpacing: AppSpacing.x3,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final labelStyle = Theme.of(context).textTheme.labelLarge;
          const minimumTitleWidth = 160.0;
          var labelledWidth = 48 + 34 + minimumTitleWidth;
          for (final label in [
            tocLabel,
            '搜索',
            bookmarkLabel,
            '笔记',
            'AI',
            '设置',
          ]) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: labelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final buttonWidth = painter.width + 51;
            labelledWidth += buttonWidth < 68 ? 68 : buttonWidth;
            painter.dispose();
          }
          final showLabels = constraints.maxWidth >= labelledWidth;
          return Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ReaderToolbarButton(
                icon: Icons.toc,
                label: tocLabel,
                showLabel: showLabels,
                selected: tocOpen,
                onPressed: onToc,
              ),
              ReaderToolbarButton(
                icon: Icons.search,
                label: '搜索',
                showLabel: showLabels,
                selected: activeContextTab == ReaderContextTab.search,
                onPressed: onSearch,
              ),
              const _ToolbarDivider(),
              ReaderToolbarButton(
                icon: bookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
                label: bookmarkLabel,
                showLabel: showLabels,
                selected: bookmarked,
                onPressed: onBookmark,
              ),
              ReaderToolbarButton(
                icon: Icons.library_books_outlined,
                label: '笔记',
                showLabel: showLabels,
                selected: activeContextTab == ReaderContextTab.notebook,
                onPressed: onNotebook,
              ),
              ReaderToolbarButton(
                icon: Icons.auto_awesome_outlined,
                label: 'AI',
                showLabel: showLabels,
                selected: activeContextTab == ReaderContextTab.ai,
                onPressed: onAi,
              ),
              const _ToolbarDivider(),
              ReaderToolbarButton(
                icon: Icons.tune,
                label: '设置',
                showLabel: showLabels,
                onPressed: onSettings,
              ),
              PopupMenuButton<ReaderMoreAction>(
                tooltip: '更多阅读操作',
                onSelected: onMore,
                itemBuilder: moreItems,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 17,
      height: 24,
      child: VerticalDivider(indent: 4, endIndent: 4),
    );
  }
}
