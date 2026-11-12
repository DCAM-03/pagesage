import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_providers.dart';

final class ReaderSettingsSaveStatus extends ConsumerWidget {
  const ReaderSettingsSaveStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(readerSettingsSavePhaseProvider).asData?.value;
    if (phase == null || phase == ReaderSettingsSavePhase.idle) {
      return const SizedBox.shrink();
    }
    final failed = phase == ReaderSettingsSavePhase.failed;
    return Semantics(
      liveRegion: failed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              failed ? Icons.error_outline : Icons.save_outlined,
              size: 18,
              color: failed ? Theme.of(context).colorScheme.error : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(switch (phase) {
                ReaderSettingsSavePhase.waiting => '等待保存…',
                ReaderSettingsSavePhase.saving => '正在保存…',
                ReaderSettingsSavePhase.failed => '阅读设置未保存，修改已保留',
                _ => '阅读设置已保存',
              }, style: Theme.of(context).textTheme.bodySmall),
            ),
            if (failed)
              TextButton(
                onPressed: ref.read(readerSettingsControllerProvider).retry,
                child: const Text('重试保存'),
              ),
          ],
        ),
      ),
    );
  }
}
