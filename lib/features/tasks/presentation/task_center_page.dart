import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/tasks/task_models.dart';
import '../application/task_center_controller.dart';

final class TaskCenterPage extends ConsumerStatefulWidget {
  const TaskCenterPage({super.key});

  @override
  ConsumerState<TaskCenterPage> createState() => _TaskCenterPageState();
}

final class _TaskCenterPageState extends ConsumerState<TaskCenterPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(taskCenterControllerProvider).recoverInterruptedTasks(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskListProvider);
    final completedCount = tasks.maybeWhen(
      data: (items) => items
          .where(
            (task) =>
                task.status == PageSageTaskStatus.done ||
                task.status == PageSageTaskStatus.failed ||
                task.status == PageSageTaskStatus.cancelled,
          )
          .length,
      orElse: () => 0,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: '任务中心',
              subtitle: '查看导入、文字识别、索引、导出和备份任务',
              showThemeMode: true,
              actions: [
                IconButton(
                  tooltip: completedCount > 0 ? '清除已完成' : '没有可清除的任务',
                  onPressed: completedCount == 0
                      ? null
                      : () => ref
                            .read(taskCenterControllerProvider)
                            .clearCompleted(),
                  icon: const Icon(Icons.cleaning_services_outlined),
                ),
              ],
            ),
            Expanded(
              child: tasks.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.task_alt_outlined,
                      title: '没有后台任务',
                      message: '导入、文字识别、索引、导出和备份会在这里显示。',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x4,
                      AppSpacing.x2,
                      AppSpacing.x4,
                      AppSpacing.x8,
                    ),
                    children: [
                      _TaskSummary(tasks: items),
                      const SizedBox(height: AppSpacing.x3),
                      for (final task in items) _TaskTile(task: task),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => AppEmptyState(
                  icon: Icons.error_outline,
                  title: '无法读取任务',
                  message: '请稍后重试。',
                  action: FilledButton(
                    onPressed: () => ref.invalidate(taskListProvider),
                    child: const Text('重试'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TaskSummary extends StatelessWidget {
  const _TaskSummary({required this.tasks});

  final List<PageSageTask> tasks;

  @override
  Widget build(BuildContext context) {
    final active = tasks.where((task) => _isActive(task.status)).length;
    final failed = tasks
        .where((task) => task.status == PageSageTaskStatus.failed)
        .length;
    final done = tasks
        .where((task) => task.status == PageSageTaskStatus.done)
        .length;
    final paused = tasks
        .where((task) => task.status == PageSageTaskStatus.paused)
        .length;
    final partial = tasks
        .where((task) => task.status == PageSageTaskStatus.partial)
        .length;
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        _SummaryChip(icon: Icons.sync, label: '进行中 $active'),
        _SummaryChip(icon: Icons.check_circle_outline, label: '完成 $done'),
        _SummaryChip(icon: Icons.error_outline, label: '失败 $failed'),
        if (paused > 0)
          _SummaryChip(icon: Icons.pause_circle_outline, label: '已暂停 $paused'),
        if (partial > 0)
          _SummaryChip(
            icon: Icons.warning_amber_outlined,
            label: '部分完成 $partial',
          ),
      ],
    );
  }
}

final class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

final class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final PageSageTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final failed = task.status == PageSageTaskStatus.failed;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: failed ? colorScheme.error : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _taskIcon(task),
                    color: _statusColor(context, task.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _taskTitle(task),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.message ?? _statusLabel(task.status),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TaskStatusChip(status: task.status),
                          _TaskActionsButton(task: task),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: task.progress.clamp(0, 1).toDouble(),
                color: _statusColor(context, task.status),
                semanticsLabel: '已处理进度',
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.percent,
                  label: '已处理 ${(task.progress.clamp(0, 1) * 100).round()}%',
                ),
                if (task.sourcePath?.isNotEmpty == true)
                  _MetaChip(
                    icon: Icons.input,
                    label: p.basename(task.sourcePath!),
                  ),
                if (task.targetPath?.isNotEmpty == true)
                  _MetaChip(
                    icon: Icons.folder_outlined,
                    label: p.basename(task.targetPath!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({required this.status});

  final PageSageTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final failed = status == PageSageTaskStatus.failed;
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_statusLabel(status)),
      backgroundColor: failed
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainerHighest,
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: failed
            ? colorScheme.onErrorContainer
            : status == PageSageTaskStatus.partial
            ? colorScheme.statusWarning
            : null,
      ),
    );
  }
}

final class _TaskActionsButton extends ConsumerWidget {
  const _TaskActionsButton({required this.task});

  final PageSageTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = task.status == PageSageTaskStatus.failed;
    final isOcr = task.type == PageSageTaskType.ocrPages;
    final canRetryFailedPages =
        isOcr &&
        (task.status == PageSageTaskStatus.failed ||
            task.status == PageSageTaskStatus.partial);
    final canClearOcr = isOcr && !_isActive(task.status);
    return PopupMenuButton<_TaskAction>(
      tooltip: '任务操作',
      onSelected: (action) => _handleTaskAction(context, ref, task, action),
      itemBuilder: (context) => [
        if (failed && !isOcr)
          const PopupMenuItem(
            value: _TaskAction.retry,
            child: ListTile(leading: Icon(Icons.refresh), title: Text('重试')),
          ),
        if (canRetryFailedPages)
          const PopupMenuItem(
            value: _TaskAction.retryFailedPages,
            child: ListTile(leading: Icon(Icons.refresh), title: Text('重试失败页')),
          ),
        if (_isCancellable(task))
          const PopupMenuItem(
            value: _TaskAction.cancel,
            child: ListTile(leading: Icon(Icons.close), title: Text('取消')),
          ),
        if (task.type == PageSageTaskType.ocrPages && _isActive(task.status))
          const PopupMenuItem(
            value: _TaskAction.pause,
            child: ListTile(leading: Icon(Icons.pause), title: Text('暂停识别')),
          ),
        if (task.type == PageSageTaskType.ocrPages &&
            task.status == PageSageTaskStatus.paused)
          const PopupMenuItem(
            value: _TaskAction.resume,
            child: ListTile(
              leading: Icon(Icons.play_arrow),
              title: Text('继续识别'),
            ),
          ),
        if (canClearOcr)
          const PopupMenuItem(
            value: _TaskAction.clearOcr,
            child: ListTile(
              leading: Icon(Icons.delete_sweep_outlined),
              title: Text('清除 OCR 结果'),
            ),
          ),
        const PopupMenuItem(
          value: _TaskAction.details,
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('查看详情'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTaskAction(
    BuildContext context,
    WidgetRef ref,
    PageSageTask task,
    _TaskAction action,
  ) async {
    final controller = ref.read(taskCenterControllerProvider);
    switch (action) {
      case _TaskAction.retry:
        await controller.retryTask(task);
      case _TaskAction.cancel:
        await controller.cancelTask(task);
      case _TaskAction.pause:
        await controller.pauseTask(task);
      case _TaskAction.resume:
        await controller.resumeTask(task);
      case _TaskAction.retryFailedPages:
        try {
          final retried = await controller.retryFailedOcrPages(task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  retried == 0 ? '没有失败页可重试' : '已重新排队 $retried 个失败页',
                ),
              ),
            );
          }
        } on Object {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('重试失败页失败')));
          }
        }
      case _TaskAction.clearOcr:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除 OCR 结果？'),
            content: const Text('将删除这次任务保存的文字、页面记录和搜索索引；原 PDF、原生文字、笔记与批注不会删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('清除'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        try {
          await controller.clearOcrResults(task);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('OCR 结果已清除')));
          }
        } on Object {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('清除 OCR 结果失败')));
          }
        }
      case _TaskAction.details:
        if (context.mounted) {
          await _showTaskDetails(context, task);
        }
    }
  }
}

final class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
    );
  }
}

Future<void> _showTaskDetails(BuildContext context, PageSageTask task) async {
  final error = sanitizeTaskError(task.error);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text('任务详情', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _DetailRow(label: '类型', value: _typeLabel(task.type)),
          _DetailRow(label: '状态', value: _statusLabel(task.status)),
          _DetailRow(label: '进度', value: '${(task.progress * 100).round()}%'),
          if (task.message?.isNotEmpty == true)
            _DetailRow(label: '消息', value: task.message!),
          if (task.sourcePath?.isNotEmpty == true)
            _DetailRow(label: '来源', value: p.basename(task.sourcePath!)),
          if (task.targetPath?.isNotEmpty == true)
            _DetailRow(label: '目标', value: p.basename(task.targetPath!)),
          _DetailRow(label: '创建时间', value: _formatTime(task.createdAt)),
          _DetailRow(label: '更新时间', value: _formatTime(task.updatedAt)),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('错误详情', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SelectableText(error),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: error));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制脱敏错误详情')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制错误详情'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stacked = MediaQuery.sizeOf(context).width < 420 || textScale > 1.25;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 4),
            SelectableText(value),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: labelStyle)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

enum _TaskAction {
  retry,
  retryFailedPages,
  cancel,
  pause,
  resume,
  clearOcr,
  details,
}

String _taskTitle(PageSageTask task) {
  final path = task.sourcePath ?? task.targetPath;
  if (path != null && path.isNotEmpty) {
    return '${_typeLabel(task.type)} · ${p.basename(path)}';
  }
  return _typeLabel(task.type);
}

String _typeLabel(PageSageTaskType type) {
  return switch (type) {
    PageSageTaskType.importBook => '导入书籍',
    PageSageTaskType.metadata => '提取元数据',
    PageSageTaskType.indexBook => '建立索引',
    PageSageTaskType.rebuildIndex => '重建索引',
    PageSageTaskType.ocrPages => '识别页面文字',
    PageSageTaskType.exportNotes => '导出笔记',
    PageSageTaskType.backup => '备份',
    PageSageTaskType.restore => '恢复',
    PageSageTaskType.unknown => '不支持的任务',
  };
}

String _statusLabel(PageSageTaskStatus status) {
  return switch (status) {
    PageSageTaskStatus.queued => '等待中',
    PageSageTaskStatus.running => '进行中',
    PageSageTaskStatus.indexing => '索引中',
    PageSageTaskStatus.paused => '已暂停',
    PageSageTaskStatus.partial => '部分完成',
    PageSageTaskStatus.done => '完成',
    PageSageTaskStatus.failed => '失败',
    PageSageTaskStatus.cancelled => '已取消',
  };
}

IconData _taskIcon(PageSageTask task) {
  return switch (task.type) {
    PageSageTaskType.importBook => Icons.upload_file,
    PageSageTaskType.metadata => Icons.description_outlined,
    PageSageTaskType.indexBook ||
    PageSageTaskType.rebuildIndex => Icons.manage_search,
    PageSageTaskType.ocrPages => Icons.text_snippet_outlined,
    PageSageTaskType.exportNotes => Icons.download_outlined,
    PageSageTaskType.backup => Icons.backup_outlined,
    PageSageTaskType.restore => Icons.restore_outlined,
    PageSageTaskType.unknown => Icons.help_outline,
  };
}

Color _statusColor(BuildContext context, PageSageTaskStatus status) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status) {
    PageSageTaskStatus.failed => colorScheme.error,
    PageSageTaskStatus.partial => colorScheme.statusWarning,
    PageSageTaskStatus.done => colorScheme.primary,
    PageSageTaskStatus.cancelled => colorScheme.outline,
    _ => colorScheme.secondary,
  };
}

bool _isActive(PageSageTaskStatus status) {
  return switch (status) {
    PageSageTaskStatus.queued ||
    PageSageTaskStatus.running ||
    PageSageTaskStatus.indexing => true,
    PageSageTaskStatus.paused || PageSageTaskStatus.partial => false,
    PageSageTaskStatus.done ||
    PageSageTaskStatus.failed ||
    PageSageTaskStatus.cancelled => false,
  };
}

bool _isCancellable(PageSageTask task) {
  if (!_isActive(task.status)) {
    return false;
  }
  return switch (task.type) {
    PageSageTaskType.importBook ||
    PageSageTaskType.indexBook ||
    PageSageTaskType.rebuildIndex ||
    PageSageTaskType.ocrPages ||
    PageSageTaskType.exportNotes ||
    PageSageTaskType.backup => true,
    PageSageTaskType.metadata ||
    PageSageTaskType.restore ||
    PageSageTaskType.unknown => false,
  };
}

String _formatTime(int millisecondsSinceEpoch) {
  final time = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
