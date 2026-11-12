import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';
import 'reader_chrome.dart';
import 'reader_location_text.dart';

final class MobileReaderTopBar extends StatelessWidget {
  const MobileReaderTopBar({
    required this.title,
    required this.progress,
    required this.locationLabel,
    required this.onBack,
    required this.onToc,
    required this.onMore,
    super.key,
  });

  final String title;
  final double? progress;
  final String locationLabel;
  final Future<void> Function() onBack;
  final VoidCallback onToc;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = ((progress ?? 0).clamp(0.0, 1.0) * 100).round();
    return ReaderFloatingChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The row is as tall as its tallest child, not a fixed 48 px: that
          // figure is the icon button's height, and at large text scales the
          // title and location lines together need more, so a hard height
          // clipped the second line by a few pixels. The buttons hold the row
          // at 48 px on their own, and the text block grows past it when it
          // must.
          Row(
            children: [
              IconButton(
                tooltip: '返回书库',
                onPressed: () => unawaited(onBack()),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$locationLabel · $percentage%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '目录',
                onPressed: onToc,
                icon: const Icon(Icons.toc),
              ),
              IconButton(
                tooltip: '更多',
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.lg),
            ),
            child: LinearProgressIndicator(
              value: (progress ?? 0).clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

final class MobileReaderBottomBar extends StatelessWidget {
  const MobileReaderBottomBar({
    required this.book,
    required this.locator,
    required this.progress,
    required this.chapterTitle,
    required this.pageNumber,
    required this.totalPages,
    required this.bookmarked,
    required this.onToc,
    required this.onSearch,
    required this.onBookmark,
    required this.onMore,
    this.onProgressTap,
    this.searchAvailable = true,
    super.key,
  });

  final Book book;
  final ReadingLocator? locator;
  final double? progress;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;
  final bool bookmarked;
  final VoidCallback onToc;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onMore;
  final VoidCallback? onProgressTap;
  final bool searchAvailable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = ((progress ?? locator?.progress ?? 0).clamp(0, 1) * 100)
        .round();
    final location = readerLocationText(
      book: book,
      locator: locator,
      chapterTitle: chapterTitle,
      pageNumber: pageNumber,
      totalPages: totalPages,
    );

    return ReaderFloatingChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProgressTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onProgressTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x1,
              0,
              AppSpacing.x1,
              AppSpacing.x1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: MobileReaderActionButton(
                    icon: Icons.toc,
                    label: '目录',
                    onPressed: onToc,
                  ),
                ),
                Expanded(
                  child: MobileReaderActionButton(
                    icon: Icons.search,
                    label: '搜索',
                    onPressed: searchAvailable ? onSearch : () {},
                    enabled: searchAvailable,
                  ),
                ),
                Expanded(
                  child: MobileReaderActionButton(
                    icon: bookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_add_outlined,
                    label: bookmarked ? '已书签' : '书签',
                    selected: bookmarked,
                    onPressed: onBookmark,
                  ),
                ),
                Expanded(
                  child: MobileReaderActionButton(
                    icon: Icons.more_horiz,
                    label: '更多',
                    onPressed: onMore,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class MobileReaderMoreSheet extends StatelessWidget {
  const MobileReaderMoreSheet({
    required this.book,
    required this.settings,
    required this.bookmarked,
    required this.searchAvailable,
    required this.textLayerAvailable,
    required this.onSearch,
    required this.onBookmark,
    required this.onNotebook,
    required this.onAi,
    required this.onSettings,
    required this.onQuickTheme,
    required this.onToggleReaderMode,
    this.capabilityReason,
    this.onPageJump,
    this.onZoomOut,
    this.onZoomIn,
    this.onFitWidth,
    this.onFitPage,
    this.onOcrPage,
    this.onOcrRange,
    this.onOcrBook,
    this.onImageBox,
    this.imageBoxMode = false,
    super.key,
  });

  final Book book;
  final ReaderSettings settings;
  final bool bookmarked;
  final bool searchAvailable;
  final bool textLayerAvailable;
  final String? capabilityReason;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onNotebook;
  final VoidCallback onAi;
  final VoidCallback onSettings;
  final VoidCallback onQuickTheme;
  final VoidCallback onToggleReaderMode;
  final VoidCallback? onPageJump;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onFitWidth;
  final VoidCallback? onFitPage;
  final VoidCallback? onOcrPage;
  final VoidCallback? onOcrRange;
  final VoidCallback? onOcrBook;
  final VoidCallback? onImageBox;
  final bool imageBoxMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPdf = book.format == BookFormat.pdf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读操作',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (isPdf && (!textLayerAvailable || !searchAvailable)) ...[
            const SizedBox(height: AppSpacing.x3),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: colorScheme.statusWarning,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        capabilityReason ??
                            (!textLayerAvailable
                                ? '无文本层 · 可用「识别可见页」；标注为近似定位'
                                : '不支持书内搜索'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onOcrPage != null) ...[
              const SizedBox(height: AppSpacing.x2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onOcrPage,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('识别可见页'),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.x3),
          if (isPdf) ...[
            Text(
              'PDF',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                if (onPageJump != null)
                  MobileMoreChip(
                    icon: Icons.pin_outlined,
                    label: '跳转页码',
                    onTap: onPageJump!,
                  ),
                if (onZoomOut != null)
                  MobileMoreChip(
                    icon: Icons.zoom_out,
                    label: '缩小',
                    onTap: onZoomOut!,
                  ),
                if (onZoomIn != null)
                  MobileMoreChip(
                    icon: Icons.zoom_in,
                    label: '放大',
                    onTap: onZoomIn!,
                  ),
                if (onFitWidth != null)
                  MobileMoreChip(
                    icon: Icons.fit_screen_outlined,
                    label: '适合宽度',
                    selected: settings.pdfZoomMode == PdfZoomMode.fitWidth,
                    onTap: onFitWidth!,
                  ),
                if (onFitPage != null)
                  MobileMoreChip(
                    icon: Icons.fullscreen_outlined,
                    label: '适合页面',
                    selected: settings.pdfZoomMode == PdfZoomMode.fitPage,
                    onTap: onFitPage!,
                  ),
                if (onOcrPage != null)
                  MobileMoreChip(
                    icon: Icons.document_scanner_outlined,
                    label: '识别可见页',
                    onTap: onOcrPage!,
                  ),
                if (onOcrRange != null)
                  MobileMoreChip(
                    icon: Icons.pin_outlined,
                    label: '识别页面范围',
                    onTap: onOcrRange!,
                  ),
                if (onOcrBook != null)
                  MobileMoreChip(
                    icon: Icons.menu_book_outlined,
                    label: '识别整本',
                    onTap: onOcrBook!,
                  ),
                if (onImageBox != null)
                  MobileMoreChip(
                    icon: Icons.crop_free,
                    label: '框选图片',
                    selected: imageBoxMode,
                    onTap: onImageBox!,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          Text(
            '常用',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.search),
            title: const Text('书内搜索'),
            enabled: searchAvailable,
            onTap: searchAvailable ? onSearch : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              bookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
            ),
            title: Text(bookmarked ? '取消书签' : '添加书签'),
            onTap: onBookmark,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('笔记与标注'),
            onTap: onNotebook,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI 助手'),
            onTap: onAi,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.brightness_4_outlined),
            title: const Text('快速主题'),
            subtitle: Text(settings.themePreset.label),
            onTap: onQuickTheme,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_day_outlined),
            title: Text(
              settings.readerMode == ReaderMode.paged ? '切换连续滚动' : '切换分页阅读',
            ),
            onTap: onToggleReaderMode,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('阅读设置'),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

final class MobileMoreChip extends StatelessWidget {
  const MobileMoreChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.secondaryContainer,
    );
  }
}

final class MobileReaderActionButton extends StatelessWidget {
  const MobileReaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? colorScheme.primary
        : colorScheme.onSurface;
    final secondary = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: secondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
