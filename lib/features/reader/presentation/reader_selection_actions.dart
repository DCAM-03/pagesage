import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../renderers/common/renderer_event.dart';

enum ReaderSelectionAction {
  highlight,
  underline,
  comment,
  note,
  search,
  copy,
  ai,
}

/// Actions offered after drawing a box over an image.
final class DesktopReaderSelectionOverlay extends StatelessWidget {
  const DesktopReaderSelectionOverlay({
    required this.selection,
    required this.onAction,
    required this.onDismiss,
    super.key,
  });

  final RendererTextSelected selection;
  final ValueChanged<ReaderSelectionAction> onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = selection.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shortPreview = preview.length <= 18
        ? preview
        : '${preview.substring(0, 18).trim()}…';

    Widget action({
      required IconData icon,
      required String label,
      required ReaderSelectionAction value,
      bool accent = false,
    }) {
      final fg = accent ? colorScheme.primary : colorScheme.onSurface;
      final bg = accent
          ? colorScheme.primaryContainer.withValues(alpha: 0.85)
          : Colors.transparent;
      return Tooltip(
        message: label,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onAction(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      elevation: 14,
      color: colorScheme.surface,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.95),
          ),
          color: colorScheme.surface.withValues(alpha: 0.99),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              if (shortPreview.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Tooltip(
                    message: preview,
                    child: Text(
                      shortPreview,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colorScheme.outlineVariant,
                ),
              ],
              action(
                icon: Icons.format_color_fill_outlined,
                label: '高亮',
                value: ReaderSelectionAction.highlight,
              ),
              action(
                icon: Icons.format_underlined,
                label: '下划线',
                value: ReaderSelectionAction.underline,
              ),
              action(
                icon: Icons.add_comment_outlined,
                label: '批注',
                value: ReaderSelectionAction.comment,
              ),
              action(
                icon: Icons.note_add_outlined,
                label: '笔记',
                value: ReaderSelectionAction.note,
              ),
              action(
                icon: Icons.copy_outlined,
                label: '复制',
                value: ReaderSelectionAction.copy,
              ),
              action(
                icon: Icons.search,
                label: '搜索',
                value: ReaderSelectionAction.search,
              ),
              action(
                icon: Icons.auto_awesome_outlined,
                label: 'AI',
                value: ReaderSelectionAction.ai,
                accent: true,
              ),
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class ReaderSelectionActionSurface extends StatelessWidget {
  const ReaderSelectionActionSurface({
    required this.selection,
    required this.onAction,
    required this.onDismiss,
    this.compact = false,
    super.key,
  });

  final RendererTextSelected selection;
  final ValueChanged<ReaderSelectionAction> onAction;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = selection.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.x4 : AppSpacing.x3,
        compact ? AppSpacing.x2 : AppSpacing.x3,
        compact ? AppSpacing.x4 : AppSpacing.x3,
        compact ? AppSpacing.x4 : AppSpacing.x3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '选中文本',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭选择操作',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            Text(
              preview,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              _SelectionChipAction(
                icon: Icons.format_color_fill_outlined,
                label: '高亮',
                onTap: () => onAction(ReaderSelectionAction.highlight),
              ),
              _SelectionChipAction(
                icon: Icons.add_comment_outlined,
                label: '批注',
                onTap: () => onAction(ReaderSelectionAction.comment),
              ),
              _SelectionChipAction(
                icon: Icons.note_add_outlined,
                label: '笔记',
                onTap: () => onAction(ReaderSelectionAction.note),
              ),
              _SelectionChipAction(
                icon: Icons.copy_outlined,
                label: '复制',
                onTap: () => onAction(ReaderSelectionAction.copy),
              ),
              _SelectionChipAction(
                icon: Icons.auto_awesome_outlined,
                label: 'AI',
                accent: true,
                onTap: () => onAction(ReaderSelectionAction.ai),
              ),
              // Secondary actions last — keep the first row thumb-friendly.
              _SelectionChipAction(
                icon: Icons.format_underlined,
                label: '下划线',
                onTap: () => onAction(ReaderSelectionAction.underline),
              ),
              _SelectionChipAction(
                icon: Icons.search,
                label: '搜索',
                onTap: () => onAction(ReaderSelectionAction.search),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SelectionChipAction extends StatelessWidget {
  const _SelectionChipAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = accent ? colorScheme.primary : colorScheme.onSurface;
    final background = accent
        ? colorScheme.primaryContainer
        : colorScheme.surfaceSubtle;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: accent
                    ? colorScheme.primary.withValues(alpha: 0.28)
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
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
