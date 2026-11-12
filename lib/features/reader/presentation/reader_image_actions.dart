import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

enum ReaderImageAction { annotate, save, copyCaption }

final class ReaderImageActionOverlay extends StatelessWidget {
  const ReaderImageActionOverlay({
    required this.hasCaption,
    required this.onAction,
    required this.onDismiss,
    super.key,
  });

  final bool hasCaption;
  final ValueChanged<ReaderImageAction> onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget action({
      required IconData icon,
      required String label,
      required ReaderImageAction value,
      bool enabled = true,
    }) {
      final foreground = enabled
          ? colorScheme.onSurface
          : colorScheme.onSurfaceVariant;
      return Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? () => onAction(value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              action(
                icon: Icons.edit_outlined,
                label: '注释此图',
                value: ReaderImageAction.annotate,
              ),
              action(
                icon: Icons.download_outlined,
                label: '保存图片',
                value: ReaderImageAction.save,
              ),
              action(
                icon: Icons.copy_all_outlined,
                label: '复制图注',
                value: ReaderImageAction.copyCaption,
                enabled: hasCaption,
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

Future<ReaderImageAction?> showReaderImageActionSheet(
  BuildContext context, {
  required String caption,
}) {
  return showModalBottomSheet<ReaderImageAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x4,
          AppSpacing.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '图片',
              style: Theme.of(
                sheetContext,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.x2),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('注释此图'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ReaderImageAction.annotate),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('保存图片'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ReaderImageAction.save),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制图注'),
              subtitle: Text(caption.isEmpty ? '这张图没有图注' : caption),
              enabled: caption.isNotEmpty,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ReaderImageAction.copyCaption),
            ),
          ],
        ),
      ),
    ),
  );
}
