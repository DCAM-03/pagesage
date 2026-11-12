import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../domain/books/reader_settings.dart';

enum ReaderMoreAction {
  pageJump,
  pdfFitWidth,
  pdfFitPage,
  pdfZoomOut,
  pdfZoomIn,
  pdfImageBox,
  ocrRange,
  readerMode,
  quickTheme,
  notebook,
  ai,
  addAnnotation,
  createNote,
  refreshFolder,
}

/// A compact, transient SnackBar with an action.
///
/// Flutter defaults [SnackBar.persist] to true whenever an action is present.
/// Reader feedback must still time out, and on desktop a full-width bar is
/// needlessly heavy, so this keeps it to a centered card.
SnackBar readerActionSnackBar({
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  required bool compact,
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    persist: false,
    duration: duration,
    width: compact ? null : 420,
    margin: compact
        ? const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            0,
            AppSpacing.x3,
            AppSpacing.x3,
          )
        : null,
    action: SnackBarAction(label: actionLabel, onPressed: onAction),
  );
}

/// A toolbar button that keeps its label only when the window is wide enough.
final class ReaderToolbarButton extends StatelessWidget {
  const ReaderToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.showLabel,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showLabel;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = selected ? colors.secondaryContainer : null;
    final foreground = selected ? colors.onSecondaryContainer : null;
    return Semantics(
      selected: selected,
      child: showLabel
          ? Tooltip(
              message: label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, size: 19),
                  label: Text(label, maxLines: 1),
                  style: TextButton.styleFrom(
                    backgroundColor: background,
                    foregroundColor: foreground,
                    textStyle: Theme.of(context).textTheme.labelLarge,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            )
          : IconButton(
              tooltip: label,
              onPressed: onPressed,
              icon: Icon(icon),
              style: IconButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
              ),
            ),
    );
  }
}

/// The small pill a reader taps to bring the toolbar back.
final class ReaderChromeRevealButton extends StatelessWidget {
  const ReaderChromeRevealButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.96),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(
                '菜单',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating toolbar surface shared by the desktop and mobile readers.
final class ReaderFloatingChrome extends StatelessWidget {
  const ReaderFloatingChrome({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colorScheme.appBorder),
        ),
        child: child,
      ),
    );
  }
}

/// Gives a bottom sheet a stable height instead of letting content decide it.
final class ReaderBottomSheetFrame extends StatelessWidget {
  const ReaderBottomSheetFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: child,
    );
  }
}

/// One theme in the reader's quick appearance row.
final class QuickThemeChip extends StatelessWidget {
  const QuickThemeChip({
    required this.preset,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ReaderThemePreset preset;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(preset.label),
      selected: selected,
      avatar: CircleAvatar(
        backgroundColor: preset.background,
        foregroundColor: preset.foreground,
        child: selected
            ? Icon(Icons.check, size: 14, color: preset.foreground)
            : null,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

/// The vertical drag target between the reader and its side panel.
final class PanelResizeHandle extends StatefulWidget {
  const PanelResizeHandle({
    required this.semanticLabel,
    required this.onDrag,
    super.key,
  });

  final String semanticLabel;
  final ValueChanged<DragUpdateDetails> onDrag;

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

final class _PanelResizeHandleState extends State<PanelResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: widget.onDrag,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _hovered ? 3 : 1,
              color: _hovered
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}
