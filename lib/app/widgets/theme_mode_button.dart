import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../responsive/app_breakpoints.dart';
import '../theme/app_tokens.dart';

/// The app's light/dark switch, reachable from the shell instead of only from
/// settings.
///
/// Two theme settings exist and they are not the same thing: the **app** theme
/// paints the shell, and the **reader** preset paints the page. Choosing 夜间
/// in the reader used to darken the book and leave the whole shell white, which
/// reads as a bug — so the shell now has its own switch.
///
/// One icon, one tap, no menu: it walks 跟随系统 → 亮色 → 暗色 → 跟随系统. A
/// menu would be three taps to reach the two states people actually alternate
/// between, and the icon already shows which one is active, so there is nothing
/// to choose from. It lives in [AppCommandBar]'s tool group on desktop and in
/// the page header below the expanded breakpoint, where there is no command
/// bar.
final class ThemeModeMenuButton extends ConsumerWidget {
  const ThemeModeMenuButton({
    this.compactOnly = false,
    this.dense = false,
    super.key,
  });

  /// Hide above the expanded breakpoint, where the command bar has it.
  final bool compactOnly;

  /// Size the tap target for a dense title row rather than a toolbar.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compactOnly && context.appBreakpoint.isExpanded) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(readerSettingsProvider).value;
    final mode = settings?.appThemeMode ?? ThemeMode.system;

    void cycle() {
      final current = settings;
      if (current == null) {
        return;
      }
      // Written through rather than debounced: this is one tap, and the whole
      // window repaints on it — a delayed save would leave chrome and setting
      // disagreeing for a third of a second.
      ref
          .read(readerSettingsControllerProvider)
          .saveNow(current.copyWith(appThemeMode: _next(mode)));
    }

    return IconButton(
      onPressed: settings == null ? null : cycle,
      tooltip: '外观：${_labelFor(mode)}',
      icon: Icon(_iconFor(mode), size: dense ? 20 : 24),
      visualDensity: dense ? VisualDensity.compact : null,
      padding: dense ? EdgeInsets.zero : null,
      constraints: dense
          ? const BoxConstraints.tightFor(width: 40, height: 40)
          : null,
    );
  }

  static ThemeMode _next(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }

  static IconData _iconFor(ThemeMode mode) {
    return switch (mode) {
      // `brightness_auto` reads as a gear at 20 px; a half-filled circle is
      // the plainer word for "let the system decide".
      ThemeMode.system => Icons.contrast,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
  }

  static String _labelFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '亮色',
      ThemeMode.dark => '暗色',
    };
  }
}

/// The three choices as a segmented control, for the reader's quick theme sheet
/// where the reader is already looking at a list of options and there is room
/// to show all of them at once.
final class AppThemeModeSelector extends ConsumerWidget {
  const AppThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider).value;
    if (settings == null) {
      return const SizedBox.shrink();
    }
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('系统')),
        ButtonSegment(value: ThemeMode.light, label: Text('亮色')),
        ButtonSegment(value: ThemeMode.dark, label: Text('暗色')),
      ],
      selected: {settings.appThemeMode},
      onSelectionChanged: (values) {
        ref
            .read(readerSettingsControllerProvider)
            .saveNow(settings.copyWith(appThemeMode: values.single));
      },
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        textStyle: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// Small caption for the quick theme sheet, explaining why the page colour and
/// the interface colour are two settings.
final class AppThemeHint extends StatelessWidget {
  const AppThemeHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '上面的主题只改书页纸色；界面颜色用下面这一行单独设置。',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
