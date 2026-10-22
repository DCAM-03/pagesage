import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'theme_mode_button.dart';

final class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.dense = false,
    this.showThemeMode = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Offer the app's light/dark switch in this header.
  ///
  /// This is the narrow-window half of the pair: above the expanded breakpoint
  /// [AppCommandBar] carries the control, and [ThemeModeMenuButton.compactOnly]
  /// hides the header copy so the two are never on screen together. Off by
  /// default and turned on by the main tabs because the control reads the
  /// settings store, and a header that pulls a provider cannot be pumped by a
  /// widget test that has no database behind it.
  final bool showThemeMode;

  /// Tighter vertical padding under a desktop command bar.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 420 || textScale > 1.2;
    final useDense = dense || width >= 900;
    final titleBlock = Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.x3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: narrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.x1),
                Text(
                  subtitle!,
                  maxLines: narrow ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Trailing in the title row rather than in [actions]: actions stack on
        // a second row below 420 px or at large text, and one 48 px button is
        // not worth pushing every page's content down by a row.
        if (showThemeMode)
          const ThemeModeMenuButton(compactOnly: true, dense: true),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x6,
        useDense ? AppSpacing.x3 : AppSpacing.x5,
        AppSpacing.x6,
        AppSpacing.x3,
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x2,
                      children: actions,
                    ),
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(child: titleBlock),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.x4),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.x2,
                        runSpacing: AppSpacing.x2,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

final class AppCommandBar extends StatelessWidget {
  const AppCommandBar({
    required this.onSearch,
    required this.onImport,
    required this.onTasks,
    this.title,
    this.taskCount = 0,
    this.showSearch = true,
    super.key,
  });

  /// Optional page title. Prefer page-level [AppPageHeader] for the real title
  /// to avoid "double title" chrome on desktop.
  final String? title;
  final VoidCallback onSearch;
  final VoidCallback onImport;
  final VoidCallback onTasks;
  final int taskCount;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasTitle = title != null && title!.trim().isNotEmpty;
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.appBorder.withValues(alpha: 0.95),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x2,
          ),
          child: Row(
            children: [
              if (hasTitle)
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'PageSage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              // With the other tools rather than at the bottom of the sidebar:
              // it is a thing you toggle in passing, not a preference to find.
              // Below the expanded breakpoint this bar does not exist, so the
              // page headers carry the same control (see [AppPageHeader]).
              const ThemeModeMenuButton(),
              const SizedBox(width: AppSpacing.x2),
              if (showSearch) ...[
                _CommandButton(
                  tooltip: '全局搜索',
                  icon: Icons.search,
                  label: '搜索',
                  onPressed: onSearch,
                ),
                const SizedBox(width: AppSpacing.x2),
              ],
              _CommandButton(
                tooltip: '导入 EPUB/PDF',
                icon: Icons.upload_file_outlined,
                label: '导入',
                filled: true,
                onPressed: onImport,
              ),
              const SizedBox(width: AppSpacing.x1),
              Tooltip(
                message: taskCount > 0 ? '任务中心：$taskCount 个任务' : '任务中心',
                child: Badge.count(
                  count: taskCount,
                  isLabelVisible: taskCount > 0,
                  child: IconButton(
                    tooltip: '任务中心',
                    onPressed: onTasks,
                    icon: const Icon(Icons.task_alt_outlined),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.secondaryAction,
    this.semanticLabel,
    this.illustrationAsset,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Widget? secondaryAction;
  final String? semanticLabel;

  /// Optional brand illustration under `assets/images/empty-states/`.
  final String? illustrationAsset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: semanticLabel ?? _emptyStateSemanticLabel(title, message),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: illustrationAsset != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Image.asset(
                            illustrationAsset!,
                            width: 220,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _EmptyIconBadge(icon: icon),
                          ),
                        )
                      : _EmptyIconBadge(icon: icon),
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.x5),
                  action!,
                ],
                if (secondaryAction != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  secondaryAction!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _EmptyIconBadge extends StatelessWidget {
  const _EmptyIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.accentSubtle,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Icon(icon, size: 28, color: colorScheme.primary),
      ),
    );
  }
}

String _emptyStateSemanticLabel(String title, String? message) {
  if (message == null || message.isEmpty) {
    return '空状态：$title';
  }
  return '空状态：$title。$message';
}

final class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    required this.icon,
    required this.message,
    this.action,
    this.tone = AppStatusTone.neutral,
    super.key,
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final toneColor = switch (tone) {
      AppStatusTone.neutral => colorScheme.primary,
      AppStatusTone.warning => colorScheme.statusWarning,
      AppStatusTone.danger => colorScheme.error,
      AppStatusTone.ai => colorScheme.aiAccent,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: toneColor.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Row(
          children: [
            Icon(icon, color: toneColor),
            const SizedBox(width: AppSpacing.x3),
            Expanded(child: Text(message)),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.x3),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

enum AppStatusTone { neutral, warning, danger, ai }

enum AppSidePanelBorder { left, right }

final class AppSidePanel extends StatelessWidget {
  const AppSidePanel({
    required this.title,
    required this.child,
    this.border = AppSidePanelBorder.left,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final AppSidePanelBorder border;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: switch (border) {
            AppSidePanelBorder.left => Border(
              left: BorderSide(
                color: colorScheme.appBorder.withValues(alpha: 0.95),
              ),
            ),
            AppSidePanelBorder.right => Border(
              right: BorderSide(
                color: colorScheme.appBorder.withValues(alpha: 0.95),
              ),
            ),
          },
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x2,
                AppSpacing.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.appBorder.withValues(alpha: 0.9),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

final class AppFilterBar extends StatelessWidget {
  const AppFilterBar({required this.children, this.padding, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.appBorder)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
          child: Row(children: children),
        ),
      ),
    );
  }
}

final class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = filled
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              backgroundColor: colorScheme.accentSubtle,
              foregroundColor: colorScheme.primary,
            ),
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          );
    return Tooltip(message: tooltip, child: child);
  }
}
