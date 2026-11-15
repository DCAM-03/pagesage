import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

final class LibraryFileDropTarget extends StatelessWidget {
  const LibraryFileDropTarget({
    required this.dragging,
    required this.isImporting,
    required this.child,
    super.key,
  });

  final ValueListenable<bool> dragging;
  final bool isImporting;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: dragging,
      child: child,
      builder: (context, active, content) => Stack(
        fit: StackFit.expand,
        children: [
          content!,
          if (active)
            Positioned.fill(
              child: IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.all(AppSpacing.x3),
                    padding: const EdgeInsets.all(AppSpacing.x6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      border: Border.all(color: colorScheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isImporting
                                ? Icons.hourglass_top
                                : Icons.file_download_outlined,
                            size: 40,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          Text(
                            isImporting ? '正在导入，请稍后再拖入' : '松开即可导入阅读',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.x2),
                          Text(
                            '支持 PDF、EPUB、Markdown；多个文件将批量加入书库',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
