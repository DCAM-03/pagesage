import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/tasks/task_models.dart';
import '../../import/application/import_intent.dart';
import '../../tasks/application/task_center_controller.dart';

final class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);
    final tasks = ref.watch(taskListProvider).value ?? const <PageSageTask>[];
    final activeTaskCount = tasks
        .where((task) => _isActive(task.status))
        .length;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactNavHeight = textScale > 1.4
        ? 112.0
        : textScale > 1.25
        ? 96.0
        : 88.0;

    final shell = context.appBreakpoint.isExpanded
        ? Scaffold(
            body: Row(
              children: [
                _DesktopNavigation(
                  selectedIndex: selectedIndex,
                  activeTaskCount: activeTaskCount,
                  onSelected: (index) => _go(context, index),
                ),
                Expanded(
                  child: Column(
                    children: [
                      AppCommandBar(
                        taskCount: activeTaskCount,
                        showSearch: !path.startsWith('/search'),
                        onSearch: () => context.go('/search'),
                        onImport: () => _requestImport(context, ref),
                        onTasks: () => context.go('/tasks'),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              height: compactNavHeight,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _go(context, index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.local_library_outlined),
                  selectedIcon: Icon(Icons.local_library),
                  label: '书库',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: '搜索',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: '笔记',
                ),
                NavigationDestination(
                  icon: Badge.count(
                    count: activeTaskCount,
                    isLabelVisible: activeTaskCount > 0,
                    child: const Icon(Icons.task_alt_outlined),
                  ),
                  selectedIcon: Badge.count(
                    count: activeTaskCount,
                    isLabelVisible: activeTaskCount > 0,
                    child: const Icon(Icons.task_alt),
                  ),
                  label: '任务',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            _requestImport(context, ref),
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          control: true,
          shift: true,
        ): () =>
            context.go('/search'),
      },
      // Avoid autofocus so page-level fields (search bar, forms) keep focus.
      child: Focus(child: shell),
    );
  }

  void _requestImport(BuildContext context, WidgetRef ref) {
    if (GoRouterState.of(context).uri.path != '/library') {
      context.go('/library');
    }
    requestBookImport(ref);
  }

  int _selectedIndex(String path) {
    if (path.startsWith('/search')) {
      return 1;
    }
    if (path.startsWith('/notes')) {
      return 2;
    }
    if (path.startsWith('/tasks')) {
      return 3;
    }
    if (path.startsWith('/settings')) {
      return 4;
    }
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/library');
      case 1:
        context.go('/search');
      case 2:
        context.go('/notes');
      case 3:
        context.go('/tasks');
      case 4:
        context.go('/settings');
    }
  }

  bool _isActive(PageSageTaskStatus status) {
    return switch (status) {
      PageSageTaskStatus.queued ||
      PageSageTaskStatus.running ||
      PageSageTaskStatus.indexing => true,
      PageSageTaskStatus.done ||
      PageSageTaskStatus.failed ||
      PageSageTaskStatus.cancelled => false,
    };
  }
}

final class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.activeTaskCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int activeTaskCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.appBorder.withValues(alpha: 0.95)),
        ),
      ),
      child: SizedBox(
        width: 236,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x3,
              AppSpacing.x4,
              AppSpacing.x3,
              AppSpacing.x3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandHeader(),
                const SizedBox(height: AppSpacing.x6),
                _NavItem(
                  selected: selectedIndex == 0,
                  icon: Icons.local_library_outlined,
                  selectedIcon: Icons.local_library,
                  label: '书库',
                  onTap: () => onSelected(0),
                ),
                _NavItem(
                  selected: selectedIndex == 1,
                  icon: Icons.search_outlined,
                  selectedIcon: Icons.search,
                  label: '搜索',
                  onTap: () => onSelected(1),
                ),
                _NavItem(
                  selected: selectedIndex == 2,
                  icon: Icons.edit_note_outlined,
                  selectedIcon: Icons.edit_note,
                  label: '笔记',
                  onTap: () => onSelected(2),
                ),
                _NavItem(
                  selected: selectedIndex == 3,
                  icon: Icons.task_alt_outlined,
                  selectedIcon: Icons.task_alt,
                  label: '任务',
                  badgeCount: activeTaskCount,
                  onTap: () => onSelected(3),
                ),
                const Spacer(),
                Divider(
                  height: 24,
                  color: colorScheme.appBorder.withValues(alpha: 0.85),
                ),
                _NavItem(
                  selected: selectedIndex == 4,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: '设置',
                  onTap: () => onSelected(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.asset(
              'assets/images/brand/app-logo-mark.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.accentSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x2 + 2),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PageSage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '本地阅读工作台',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.textSecondary,
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

final class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x1),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppDurations.hover,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.accentSubtle
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: selected
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.16),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AppDurations.hover,
                      width: 3,
                      height: 18,
                      margin: const EdgeInsets.only(right: AppSpacing.x2),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    Icon(
                      selected ? selectedIcon : icon,
                      size: 20,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Badge.count(
                        count: badgeCount,
                        backgroundColor: colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
