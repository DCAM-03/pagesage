import 'package:flutter/material.dart';

import '../../../domain/books/book.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/reading_position.dart';
import 'reader_location_text.dart';

final class ReaderMessage extends StatelessWidget {
  const ReaderMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

final class ReaderErrorPanel extends StatelessWidget {
  const ReaderErrorPanel({
    required this.message,
    required this.onRetry,
    required this.onShowDetails,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 42, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  '无法渲染书籍',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('重试'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onShowDetails,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('查看详情'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class ReaderStatusBar extends StatelessWidget {
  const ReaderStatusBar({
    required this.book,
    required this.locator,
    required this.progress,
    required this.chapterTitle,
    required this.pageNumber,
    required this.totalPages,
    required this.settings,
    required this.tocOpen,
    required this.contextOpen,
    required this.tocWidth,
    required this.contextWidth,
    super.key,
  });

  final Book book;
  final ReadingLocator? locator;
  final double? progress;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;
  final ReaderSettings settings;
  final bool tocOpen;
  final bool contextOpen;
  final double tocWidth;
  final double contextWidth;

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
    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(width: tocOpen ? tocWidth - 8 : 0),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBarPill(label: '$percentage%'),
              const SizedBox(width: 8),
              _StatusBarPill(label: readerScaleText(book, settings)),
              const SizedBox(width: 8),
              _StatusBarPill(label: settings.readerMode.label),
              const SizedBox(width: 8),
              _StatusBarPill(label: readerFormatLabel(book.format)),
              SizedBox(width: contextOpen ? contextWidth - 4 : 0),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StatusBarPill extends StatelessWidget {
  const _StatusBarPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Says that dragging now means "draw a box around a picture", and offers the
/// way out.
///
/// A transient toast was not enough: the mode lasts until the reader leaves it,
/// and someone who turned it on, drew badly and gave up needs to see the state
/// they are in, not remember a message from ten seconds ago.
final class ImageBoxModeBanner extends StatelessWidget {
  const ImageBoxModeBanner({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.crop_free,
                size: 18,
                color: colorScheme.onInverseSurface,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '框选图片：拖出图片范围',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onInverseSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: onExit,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onInverseSurface,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('退出'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class ReaderStatusBanner extends StatelessWidget {
  const ReaderStatusBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            message,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onInverseSurface,
            ),
          ),
        ),
      ),
    );
  }
}
