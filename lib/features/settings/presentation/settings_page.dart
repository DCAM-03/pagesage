import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/platform/platform_providers.dart';
import '../../../core/tasks/task_cancellation.dart';
import '../../../core/tasks/task_models.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/books/reader_fonts.dart';
import '../../../domain/books/reader_settings.dart';
import '../../../domain/books/category.dart';
import '../../../domain/books/tag.dart';
import '../../export/application/export_providers.dart';
import '../../export/application/export_service.dart';
import '../../library/application/library_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../tasks/application/task_center_controller.dart';
import '../../tasks/presentation/task_center_page.dart';
import '../application/ai_settings_providers.dart';
import '../application/ai_settings_form_controller.dart';
import 'ai_profile_actions.dart';
import 'reader_font_picker.dart';
import 'reader_settings_save_status.dart';

final class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({this.initialAi = false, super.key});

  final bool initialAi;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends ConsumerState<SettingsPage> {
  late _SettingsSection _selectedSection = widget.initialAi
      ? _SettingsSection.ai
      : _SettingsSection.reader;
  bool _fileOperationBusy = false;

  Future<void> _withFileOperation(Future<void> Function() action) async {
    if (_fileOperationBusy) return;
    _fileOperationBusy = true;
    try {
      await action();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法选择文件，请重试或检查保存位置权限')));
      }
    } finally {
      _fileOperationBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readerSettings = ref.watch(readerSettingsProvider);
    final aiSettings = ref.watch(aiSettingsProvider);
    ref.watch(aiSettingsFormProvider.select((state) => state.isInitialized));

    if (context.supportsSidePanel) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // No theme control in this header: the page is where 应用外观 lives,
              // and a shortcut to the setting beside the setting is noise.
              AppPageHeader(
                title: '设置',
                subtitle: '管理阅读偏好、AI、本地数据和任务',
                leading: widget.initialAi ? const BackButton() : null,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 260,
                      child: _SettingsNavigation(
                        readerSummary: _readerSettingsSummary(readerSettings),
                        selected: _selectedSection,
                        onSelected: (section) =>
                            setState(() => _selectedSection = section),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.appBorder,
                    ),
                    Expanded(
                      child: ListView(
                        key: ValueKey(_selectedSection),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.x6,
                          AppSpacing.x2,
                          AppSpacing.x6,
                          AppSpacing.x12,
                        ),
                        children: [
                          _SettingsSectionHeader(section: _selectedSection),
                          const SizedBox(height: AppSpacing.x3),
                          _buildSection(
                            context,
                            _selectedSection,
                            readerSettings,
                            aiSettings,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.initialAi) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: [
              const AppPageHeader(title: 'AI 设置', leading: BackButton()),
              const SizedBox(height: AppSpacing.x3),
              _buildSection(
                context,
                _SettingsSection.ai,
                readerSettings,
                aiSettings,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x12,
          ),
          children: [
            const AppPageHeader(title: '设置', subtitle: '按分组管理 PageSage'),
            const SizedBox(height: AppSpacing.x2),
            for (final section in _SettingsSection.values)
              _SettingsSectionListTile(
                section: section,
                description: section == _SettingsSection.reader
                    ? _readerSettingsSummary(readerSettings)
                    : section.description,
                onTap: () => _openMobileSection(context, section),
              ),
          ],
        ),
      ),
    );
  }

  void _openMobileSection(BuildContext context, _SettingsSection section) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            final readerSettings = ref.watch(readerSettingsProvider);
            final aiSettings = ref.watch(aiSettingsProvider);
            return Scaffold(
              body: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x4,
                  AppSpacing.x12,
                ),
                children: [
                  AppPageHeader(
                    title: section.label,
                    subtitle: section.description,
                    leading: IconButton(
                      tooltip: '返回设置',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  _buildSection(context, section, readerSettings, aiSettings),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    _SettingsSection section,
    AsyncValue<ReaderSettings> readerSettings,
    AsyncValue<AiSettings> aiSettings,
  ) {
    return switch (section) {
      _SettingsSection.reader => readerSettings.when(
        data: (settings) => _ReaderDefaultsCard(settings: settings),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => const Text('无法读取阅读设置'),
      ),
      _SettingsSection.ai => aiSettings.when(
        data: (settings) => _AiSettingsCard(settings: settings),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error is AiProfileException
                  ? error.message
                  : '无法读取 AI 设置，请检查系统安全存储后重试',
            ),
            TextButton.icon(
              onPressed: () {
                ref.invalidate(aiSettingsProvider);
                ref.invalidate(aiProfilesProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新读取配置'),
            ),
          ],
        ),
      ),
      _SettingsSection.taxonomy => const _CategoryTagCard(),
      _SettingsSection.data => _PrivacyDataCard(
        onExportNotes: () =>
            _withFileOperation(() => _exportNotes(context, ref)),
        onExportNotebook: () =>
            _withFileOperation(() => _exportNotebook(context, ref)),
        onExportAnnotations: () =>
            _withFileOperation(() => _exportAnnotations(context, ref)),
        onExportBookmarks: () =>
            _withFileOperation(() => _exportBookmarks(context, ref)),
        onExportAi: () =>
            _withFileOperation(() => _exportAiConversations(context, ref)),
        onExportImages: () =>
            _withFileOperation(() => _exportImageAnnotations(context, ref)),
        onBackup: () => _withFileOperation(() => _backupDatabase(context, ref)),
        onRestore: () =>
            _withFileOperation(() => _restoreDatabase(context, ref)),
        onClearCache: () => _clearImageCache(context, ref),
        onClearAi: () => _confirmClearAiHistory(context, ref),
        onDeleteAll: () => _confirmDeleteAllLocalData(context, ref),
        onTasks: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (context) => const TaskCenterPage()),
        ),
      ),
      _SettingsSection.about => const _AboutPageSageCard(),
    };
  }

  Future<void> _confirmClearAiHistory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空 AI 历史？'),
        content: const Text('AI 对话记录会被删除，已保存为笔记的内容会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(aiConversationRepositoryProvider).clearAll();
    }
  }

  Future<void> _exportNotes(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickNotesMarkdownExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final file = await _runTrackedFileTask(
        ref,
        type: PageSageTaskType.exportNotes,
        runningMessage: '正在导出全部笔记',
        successMessage: '笔记已导出',
        plannedTargetPath: targetPath,
        action: (cancelToken) => ref
            .read(exportServiceProvider)
            .exportAllNotesMarkdown(
              targetPath: targetPath,
              cancelToken: cancelToken,
            ),
      );
      if (!context.mounted) {
        return;
      }
      _showFileResultSnackBar(context, ref, message: '已导出', file: file);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error);
    }
  }

  Future<void> _exportNotebook(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickNotebookMarkdownExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final file = await _runTrackedFileTask(
        ref,
        type: PageSageTaskType.exportNotes,
        runningMessage: '正在导出 Notebook',
        successMessage: 'Notebook 已导出',
        plannedTargetPath: targetPath,
        action: (cancelToken) => ref
            .read(exportServiceProvider)
            .exportNotebookMarkdown(
              targetPath: targetPath,
              cancelToken: cancelToken,
            ),
      );
      if (!context.mounted) {
        return;
      }
      _showFileResultSnackBar(context, ref, message: '已导出', file: file);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error);
    }
  }

  Future<void> _exportAnnotations(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickAnnotationsJsonExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final file = await _runTrackedFileTask(
        ref,
        type: PageSageTaskType.exportNotes,
        runningMessage: '正在导出标注 JSON',
        successMessage: '标注已导出',
        plannedTargetPath: targetPath,
        action: (cancelToken) => ref
            .read(exportServiceProvider)
            .exportAnnotationsJson(
              targetPath: targetPath,
              cancelToken: cancelToken,
            ),
      );
      if (!context.mounted) {
        return;
      }
      _showFileResultSnackBar(context, ref, message: '已导出', file: file);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error);
    }
  }

  Future<void> _exportBookmarks(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickBookmarksCsvExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final file = await _runTrackedFileTask(
        ref,
        type: PageSageTaskType.exportNotes,
        runningMessage: '正在导出书签 CSV',
        successMessage: '书签已导出',
        plannedTargetPath: targetPath,
        action: (cancelToken) => ref
            .read(exportServiceProvider)
            .exportBookmarksCsv(
              targetPath: targetPath,
              cancelToken: cancelToken,
            ),
      );
      if (!context.mounted) {
        return;
      }
      _showFileResultSnackBar(context, ref, message: '已导出', file: file);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error);
    }
  }

  Future<void> _exportAiConversations(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickAiMarkdownExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final file = await _runTrackedFileTask(
        ref,
        type: PageSageTaskType.exportNotes,
        runningMessage: '正在导出 AI 问答',
        successMessage: 'AI 问答已导出',
        plannedTargetPath: targetPath,
        action: (cancelToken) => ref
            .read(exportServiceProvider)
            .exportAiConversationsMarkdown(
              targetPath: targetPath,
              cancelToken: cancelToken,
            ),
      );
      if (!context.mounted) {
        return;
      }
      _showFileResultSnackBar(context, ref, message: '已导出', file: file);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error);
    }
  }

  Future<void> _exportImageAnnotations(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickImageAnnotationsExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final result = await _runTrackedTask<ImageAnnotationExportResult>(
        ref,
        type: PageSageTaskType.exportNotes,
        plannedTargetPath: targetPath,
        runningMessage: '正在导出图片批注',
        successMessage: '图片批注已导出',
        action: (cancelToken) async {
          final service = ref.read(exportServiceProvider);
          final result = await service.exportImageAnnotations(
            targetPath: targetPath,
            cancelToken: cancelToken,
          );
          if (!picker.supportsExportPathSelection) {
            final archive = await service.packageImageAnnotations(
              result,
              cancelToken: cancelToken,
            );
            cancelToken.throwIfCancelled();
            if (await picker.saveExportedFile(archive) == null) {
              throw const TaskCancelledException();
            }
          }
          return result;
        },
      );
      if (!context.mounted) {
        return;
      }
      final missing = result.missingCount;
      _showFileResultSnackBar(
        context,
        ref,
        message: missing == 0
            ? '已导出 ${result.imageCount} 张图片'
            : '已导出 ${result.imageCount} 张图片，$missing 张没有缓存',
        file: result.markdownFile,
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error);
    }
  }

  /// Drop the cached pictures.
  ///
  /// They are derived from the books and can be cut out again, so this is
  /// safe: the worst outcome is that the next export has fewer pictures to
  /// copy and says so.
  Future<void> _clearImageCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理图片缓存？'),
        content: const Text('会删除从书页裁出的图片缓存。标注本身不受影响，需要时可以重新裁出。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(imageCacheStoreProvider).clear();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('图片缓存已清理')));
  }

  Future<void> _backupDatabase(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = picker.supportsExportPathSelection
        ? await picker.pickBackupZipExportPath()
        : null;
    if ((picker.supportsExportPathSelection && targetPath == null) ||
        !context.mounted) {
      return;
    }
    try {
      final file = await _runTrackedFileTask(
        ref,
        type: PageSageTaskType.backup,
        runningMessage: '正在备份数据库',
        successMessage: '数据库已备份',
        plannedTargetPath: targetPath,
        action: (cancelToken) => ref
            .read(exportServiceProvider)
            .backupDatabaseZip(
              targetPath: targetPath,
              cancelToken: cancelToken,
            ),
      );
      if (!context.mounted) {
        return;
      }
      _showFileResultSnackBar(context, ref, message: '已备份', file: file);
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      _showFileFailure(context, error, operation: '备份');
    }
  }

  Future<void> _restoreDatabase(BuildContext context, WidgetRef ref) async {
    final tasks = await ref.read(taskRepositoryProvider).getTasks();
    final registry = ref.read(taskCancellationRegistryProvider);
    if (!context.mounted) return;
    if (tasks.any((task) => registry.isLive(task.id))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请等待当前任务结束，再恢复备份')));
      return;
    }
    final file = await ref.read(filePickerServiceProvider).pickBackupZipFile();
    if (file == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复数据库备份？'),
        content: const Text(
          '当前 PageSage 数据库会被备份 zip 覆盖。恢复前会在 exports 目录创建回滚副本，恢复完成后建议重启应用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final latestTasks = await ref.read(taskRepositoryProvider).getTasks();
      if (!context.mounted) return;
      if (latestTasks.any((task) => registry.isLive(task.id))) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请等待当前任务结束，再恢复备份')));
        return;
      }
      final restoreResult = await ref
          .read(exportServiceProvider)
          .restoreDatabaseBackup(File(file.path));
      ref.invalidate(appDatabaseProvider);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复完成'),
          content: Text(
            '数据库已从备份恢复。\n\n'
            '路径：${restoreResult.databasePath}\n'
            '回滚副本：${restoreResult.rollbackPath}\n\n'
            '请立即完全退出并重新启动应用，以确保所有页面读取新数据。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
            if (ref.read(openFileLocationServiceProvider).isSupported)
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(openFileLocationServiceProvider)
                        .revealFile(restoreResult.databasePath);
                  } on Object catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('无法打开位置：${_shortError(error)}')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('打开数据位置'),
              ),
          ],
        ),
      );
    } catch (_) {
      ref.invalidate(appDatabaseProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('恢复失败：备份文件无效或无法写入')));
    }
  }

  void _showFileResultSnackBar(
    BuildContext context,
    WidgetRef ref, {
    required String message,
    required File file,
  }) {
    final locationService = ref.read(openFileLocationServiceProvider);
    final externalSave = !ref
        .read(filePickerServiceProvider)
        .supportsExportPathSelection;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Text(
          externalSave ? '$message，已保存到所选位置' : '$message：${file.path}',
        ),
        action: !locationService.isSupported
            ? null
            : SnackBarAction(
                label: '打开位置',
                onPressed: () async {
                  try {
                    await locationService.revealFile(file.path);
                  } on Object catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('无法打开位置：${_shortError(error)}')),
                    );
                  }
                },
              ),
      ),
    );
  }

  void _showFileFailure(
    BuildContext context,
    Object error, {
    String operation = '导出',
  }) {
    final message = error is TaskCancelledException
        ? '已取消$operation'
        : error is FileSystemException
        ? '$operation失败：请检查保存位置、写入权限和剩余空间'
        : '$operation失败，请重试；详细信息可在任务中心查看';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<File> _runTrackedFileTask(
    WidgetRef ref, {
    required PageSageTaskType type,
    required String runningMessage,
    required String successMessage,
    String? plannedTargetPath,
    required Future<File> Function(TaskCancelToken cancelToken) action,
  }) {
    final picker = ref.read(filePickerServiceProvider);
    return _runTrackedTask<File>(
      ref,
      type: type,
      runningMessage: runningMessage,
      successMessage: successMessage,
      action: (cancelToken) async {
        final file = await action(cancelToken);
        if (!picker.supportsExportPathSelection) {
          cancelToken.throwIfCancelled();
          if (await picker.saveExportedFile(file) == null) {
            throw const TaskCancelledException();
          }
        }
        return file;
      },
      plannedTargetPath: plannedTargetPath,
      targetPath: (file) => file.path,
    );
  }

  Future<T> _runTrackedTask<T>(
    WidgetRef ref, {
    required PageSageTaskType type,
    required String runningMessage,
    required String successMessage,
    required Future<T> Function(TaskCancelToken cancelToken) action,
    String? sourcePath,
    String? plannedTargetPath,
    String? Function(T value)? targetPath,
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    final task = await repository.saveTask(
      type: type,
      status: PageSageTaskStatus.running,
      sourcePath: sourcePath,
      targetPath: plannedTargetPath,
      progress: 0.05,
      message: runningMessage,
    );
    final cancelRegistry = ref.read(taskCancellationRegistryProvider);
    final cancelToken = cancelRegistry.register(task.id);
    try {
      cancelToken.throwIfCancelled();
      final result = await action(cancelToken);
      await repository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.done,
        progress: 1,
        targetPath: targetPath?.call(result),
        message: successMessage,
        // A retried action leaves the previous attempt's error behind unless
        // it is cleared explicitly.
        clearError: true,
      );
      return result;
    } on TaskCancelledException {
      final tasks = await repository.getTasks();
      final latest = tasks.where((item) => item.id == task.id).firstOrNull;
      await repository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.cancelled,
        progress: latest?.progress ?? task.progress,
        message: '已取消',
      );
      rethrow;
    } on Object catch (error) {
      await repository.updateStatus(
        id: task.id,
        status: PageSageTaskStatus.failed,
        progress: 1,
        message: '$runningMessage失败',
        error: sanitizeTaskError(error),
      );
      rethrow;
    } finally {
      cancelRegistry.complete(task.id);
    }
  }

  Future<void> _confirmDeleteAllLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所有本地数据？'),
        content: _ScrollableDialogContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '此操作会删除 PageSage 中的书籍副本、进度、书签、标注、笔记、AI 记录、索引和设置，不会删除原始路径文件。请输入 DELETE 确认。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '确认文字'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim() == 'DELETE'),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) {
      return;
    }
    await ref.read(localDataServiceProvider).deleteAllLocalData();
    ref.invalidate(appDatabaseProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除所有本地数据')));
  }
}

String _readerSettingsSummary(AsyncValue<ReaderSettings> settings) {
  return settings.when(
    data: (value) =>
        '${value.fontSize.round()} px · ${value.readerMode.label} · ${value.themePreset.label}\n'
        '${ReaderFonts.resolve(value.fontFamily).label}',
    loading: () => '正在读取阅读配置…',
    error: (error, stackTrace) => '无法读取阅读配置',
  );
}

enum _SettingsSection {
  reader('阅读', '所有书籍共用的阅读模式、字体、排版和主题', Icons.menu_book_outlined),
  ai('AI', 'Provider、模型、密钥和请求确认', Icons.auto_awesome_outlined),
  taxonomy('分类与标签', '维护书库分类和标签', Icons.category_outlined),
  data('隐私与数据', '本地导出、备份、任务和危险操作', Icons.storage_outlined),
  about('关于', '版本、隐私说明和开源许可', Icons.info_outline);

  const _SettingsSection(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

final class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({
    required this.readerSummary,
    required this.selected,
    required this.onSelected,
  });

  final String readerSummary;
  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x3,
          AppSpacing.x6,
        ),
        children: [
          for (final section in _SettingsSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: _SettingsNavigationTile(
                section: section,
                description: section == _SettingsSection.reader
                    ? readerSummary
                    : section.description,
                selected: selected == section,
                onTap: () => onSelected(section),
              ),
            ),
        ],
      ),
    );
  }
}

final class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.section,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Row(
            children: [
              Icon(
                section.icon,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Tooltip(
                      message: description,
                      child: Text(
                        description,
                        maxLines: section == _SettingsSection.reader ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SettingsSectionListTile extends StatelessWidget {
  const _SettingsSectionListTile({
    required this.section,
    required this.description,
    required this.onTap,
  });

  final _SettingsSection section;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: ListTile(
          leading: Icon(section.icon),
          title: Text(section.label),
          subtitle: Text(description),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

final class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.section});

  final _SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.accentSubtle,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Icon(section.icon, color: colorScheme.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.label,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                section.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _PrivacyDataCard extends StatelessWidget {
  const _PrivacyDataCard({
    required this.onExportNotes,
    required this.onExportNotebook,
    required this.onExportAnnotations,
    required this.onExportBookmarks,
    required this.onExportAi,
    required this.onExportImages,
    required this.onBackup,
    required this.onRestore,
    required this.onClearCache,
    required this.onClearAi,
    required this.onDeleteAll,
    required this.onTasks,
  });

  final VoidCallback onExportNotes;
  final VoidCallback onExportNotebook;
  final VoidCallback onExportAnnotations;
  final VoidCallback onExportBookmarks;
  final VoidCallback onExportAi;
  final VoidCallback onExportImages;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onClearCache;
  final VoidCallback onClearAi;
  final VoidCallback onDeleteAll;
  final VoidCallback onTasks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SettingsPanel(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsGroup(
            icon: Icons.ios_share_outlined,
            title: '导出',
            subtitle: '导出笔记、标注、书签与 AI 记录到本地文件。',
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.download_outlined,
                  title: '导出全部笔记',
                  subtitle: '选择保存位置，导出 Markdown 文件',
                  onTap: onExportNotes,
                ),
                _SettingsActionTile(
                  icon: Icons.library_books_outlined,
                  title: '导出 Notebook',
                  subtitle: '导出书签、标注、笔记和 AI 历史 Markdown',
                  onTap: onExportNotebook,
                ),
                _SettingsActionTile(
                  icon: Icons.data_object_outlined,
                  title: '导出标注 JSON',
                  subtitle: '包含 locator JSON，便于迁移和备份',
                  onTap: onExportAnnotations,
                ),
                _SettingsActionTile(
                  icon: Icons.bookmarks_outlined,
                  title: '导出书签 CSV',
                  subtitle: '选择保存位置，导出书签 CSV 文件',
                  onTap: onExportBookmarks,
                ),
                _SettingsActionTile(
                  icon: Icons.auto_awesome_outlined,
                  title: '导出 AI 问答',
                  subtitle: '导出 Markdown，不包含 API Key',
                  onTap: onExportAi,
                ),
                _SettingsActionTile(
                  icon: Icons.image_outlined,
                  title: '导出图片批注',
                  subtitle: '导出 Markdown 与图片目录，图片相对路径引用',
                  onTap: onExportImages,
                ),
              ],
            ),
          ),
          const _SettingsFieldGap(size: AppSpacing.x5),
          _SettingsGroup(
            icon: Icons.backup_outlined,
            title: '备份与恢复',
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.backup_outlined,
                  title: '备份数据库',
                  subtitle: '导出 SQLite 数据库 zip 备份',
                  onTap: onBackup,
                ),
                _SettingsActionTile(
                  icon: Icons.restore_outlined,
                  title: '恢复数据库备份',
                  subtitle: '从 PageSage 备份 zip 恢复，恢复前会创建回滚副本',
                  onTap: onRestore,
                ),
                _SettingsActionTile(
                  icon: Icons.task_alt_outlined,
                  title: '任务中心',
                  subtitle: '查看导入、索引、导出和备份任务',
                  onTap: onTasks,
                ),
                _SettingsActionTile(
                  icon: Icons.cleaning_services_outlined,
                  title: '清理图片缓存',
                  subtitle: '删除从书页裁出的图片缓存，标注不受影响',
                  onTap: onClearCache,
                ),
              ],
            ),
          ),
          const _SettingsFieldGap(size: AppSpacing.x5),
          _SettingsGroup(
            icon: Icons.warning_amber_outlined,
            title: '危险操作',
            subtitle: '这些操作不可轻易撤销，请先备份。',
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.delete_outline,
                  title: '清空 AI 历史',
                  subtitle: '不会删除已经保存为普通笔记的内容',
                  onTap: onClearAi,
                ),
                _SettingsActionTile(
                  icon: Icons.delete_forever_outlined,
                  iconColor: colorScheme.error,
                  title: '删除所有本地数据',
                  subtitle: '删除书库、进度、笔记、书签、标注、AI 和索引',
                  onTap: onDeleteAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _AboutPageSageCard extends StatelessWidget {
  const _AboutPageSageCard();

  static const _version = '0.0.1+2';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('PageSage'),
            subtitle: Text('版本 $_version，本地优先 EPUB/PDF/Markdown 阅读器'),
          ),
          _SettingsActionTile(
            icon: Icons.privacy_tip_outlined,
            title: '隐私说明',
            subtitle: '查看本地数据、AI 请求、日志与备份规则',
            onTap: () => _showPrivacyNotice(context),
          ),
          _SettingsActionTile(
            icon: Icons.article_outlined,
            title: '开源许可说明',
            subtitle: 'Apache-2.0 与第三方组件许可',
            onTap: () => _showLicenseNotice(context),
          ),
          _SettingsActionTile(
            icon: Icons.list_alt_outlined,
            title: 'Flutter 许可证',
            subtitle: '查看 Flutter 运行时收集到的完整许可证列表',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'PageSage',
              applicationVersion: _version,
              applicationLegalese:
                  'Copyright 2026 PageSage contributors\nApache License 2.0',
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PageSage 隐私说明'),
        content: const SingleChildScrollView(
          child: Text(
            'PageSage 默认把书籍副本、阅读进度、书签、标注、笔记、全文索引、AI 对话记录和应用设置保存在本机。\n\n'
            '普通 EPUB/PDF/Markdown 文件导入时复制到应用书库目录；Markdown 文件夹按原路径只读访问，不复制也不写入源目录。移除书籍不会删除原文件或原目录。\n\n'
            'AI 请求会明确展示将发送的选中文本或上下文范围，默认不会自动上传整本书。API Key 存在系统安全存储中，不写入 SQLite，也不进入普通日志。\n\n'
            '默认日志不记录 API key、AI 请求正文、选中文本、完整上下文或大段书籍正文。备份和恢复仅处理本地文件，恢复前会创建回滚副本。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showLicenseNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PageSage 开源许可说明'),
        content: const SingleChildScrollView(
          child: Text(
            'PageSage 自有代码与文档采用 Apache License 2.0；第三方组件和字体保留各自许可，用户导入的书籍不在项目授权范围内。\n\n'
            '主要依赖许可：Flutter SDK、go_router、flutter_secure_storage、url_launcher 使用 BSD-3-Clause；Riverpod、Drift、file_picker、archive 与 sqlite3 Dart 包使用 MIT；dart_pdf_editor、pdf_document、pdf_graphics、pdf_cos 使用 Apache-2.0。\n\n'
            '内置 LXGW WenKai Lite 和 Atkinson Hyperlegible 字体使用 SIL Open Font License 1.1。Android Google ML Kit OCR SDK 另受其上游条款约束。\n\n'
            '完整许可文本可在“Flutter 许可证”中查看；再分发时请保留项目及第三方的授权与声明。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

final class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

final class _ReaderDefaultsCard extends ConsumerStatefulWidget {
  const _ReaderDefaultsCard({required this.settings});

  final ReaderSettings settings;

  @override
  ConsumerState<_ReaderDefaultsCard> createState() =>
      _ReaderDefaultsCardState();
}

final class _ReaderDefaultsCardState
    extends ConsumerState<_ReaderDefaultsCard> {
  late ReaderSettings _settings = widget.settings;
  late final ReaderSettingsController _saveController;

  @override
  void initState() {
    super.initState();
    _saveController = ref.read(readerSettingsControllerProvider);
    _settings = _saveController.unsavedSettings ?? widget.settings;
  }

  @override
  void dispose() {
    unawaited(_saveController.flush());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReaderDefaultsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings =
          ref.read(readerSettingsControllerProvider).unsavedSettings ??
          widget.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ReaderSettingsSaveStatus(),
          _SettingsGroup(
            icon: Icons.text_fields_outlined,
            title: '阅读排版',
            subtitle: '与阅读器内设置共用，对当前及后续打开的书籍生效。文字排版用于 EPUB 和 Markdown。',
            child: Column(
              children: [
                _SettingsSlider(
                  label: '字号',
                  value: _settings.fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  displayValue: _settings.fontSize.round().toString(),
                  onChanged: (value) =>
                      _save(_settings.copyWith(fontSize: value)),
                ),
                _SettingsSlider(
                  label: '行高',
                  value: _settings.lineHeight,
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  displayValue: _settings.lineHeight.toStringAsFixed(1),
                  onChanged: (value) =>
                      _save(_settings.copyWith(lineHeight: value)),
                ),
                _SettingsSlider(
                  label: '段距',
                  value: _settings.paragraphSpacing,
                  min: 0,
                  max: 32,
                  divisions: 16,
                  displayValue: _settings.paragraphSpacing.round().toString(),
                  onChanged: (value) =>
                      _save(_settings.copyWith(paragraphSpacing: value)),
                ),
                _SettingsSlider(
                  label: '页边距',
                  value: _settings.pageMargin,
                  min: 12,
                  max: 72,
                  divisions: 20,
                  displayValue: _settings.pageMargin.round().toString(),
                  onChanged: (value) =>
                      _save(_settings.copyWith(pageMargin: value)),
                ),
                _SettingsSlider(
                  label: 'PDF 默认缩放',
                  value: _settings.pdfScale,
                  min: ReaderSettings.pdfScaleMin,
                  max: ReaderSettings.pdfScaleMax,
                  divisions: 25,
                  displayValue: '${(_settings.pdfScale * 100).round()}%',
                  onChanged: (value) =>
                      _save(_settings.copyWith(pdfScale: value)),
                ),
                const _SettingsFieldGap(),
                ReaderFontPicker(
                  fontFamily: _settings.fontFamily,
                  onChanged: (value) =>
                      _save(_settings.copyWith(fontFamily: value)),
                ),
              ],
            ),
          ),
          const _SettingsFieldGap(size: AppSpacing.x5),
          _SettingsGroup(
            icon: Icons.palette_outlined,
            title: '主题与模式',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '阅读主题',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: ReaderThemePreset.values
                      .map((preset) {
                        return ChoiceChip(
                          label: Text(preset.label),
                          selected: _settings.themePreset == preset,
                          avatar: CircleAvatar(
                            backgroundColor: preset.background,
                          ),
                          onSelected: (_) =>
                              _save(_settings.copyWith(themePreset: preset)),
                        );
                      })
                      .toList(growable: false),
                ),
                const _SettingsFieldGap(),
                Text(
                  '阅读模式',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.x2),
                SegmentedButton<ReaderMode>(
                  segments: ReaderMode.values
                      .map(
                        (mode) =>
                            ButtonSegment(value: mode, label: Text(mode.label)),
                      )
                      .toList(growable: false),
                  selected: {_settings.readerMode},
                  onSelectionChanged: (values) =>
                      _save(_settings.copyWith(readerMode: values.single)),
                ),
                const _SettingsFieldGap(),
                Text(
                  '应用外观',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.x2),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('系统')),
                    ButtonSegment(value: ThemeMode.light, label: Text('亮色')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('暗色')),
                  ],
                  selected: {_settings.appThemeMode},
                  onSelectionChanged: (values) =>
                      _save(_settings.copyWith(appThemeMode: values.single)),
                ),
                const Divider(height: AppSpacing.x8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('减少动画'),
                  subtitle: Text(
                    '阅读器和界面尽量减少过渡动画',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.textSecondary,
                    ),
                  ),
                  value: _settings.reduceMotion,
                  onChanged: (value) =>
                      _save(_settings.copyWith(reduceMotion: value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _save(ReaderSettings settings) {
    setState(() => _settings = settings);
    ref.read(readerSettingsControllerProvider).save(settings);
  }
}

final class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(displayValue, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

final class _CategoryTagCard extends ConsumerWidget {
  const _CategoryTagCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(tagsProvider);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('新建分类'),
            onTap: () => _createCategory(context, ref),
          ),
          categories.when(
            data: (items) => _CategoryList(items: items),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('无法读取分类'),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.new_label_outlined),
            title: const Text('新建标签'),
            onTap: () => _createTag(context, ref),
          ),
          tags.when(
            data: (items) => _TagList(items: items),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('无法读取标签'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, title: '新建分类', label: '分类名称');
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await ref.read(categoryRepositoryProvider).saveCategory(name: name);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final draft = await _askTag(context, title: '新建标签');
    if (draft == null || draft.name.isEmpty) {
      return;
    }
    try {
      await ref
          .read(tagRepositoryProvider)
          .saveTag(name: draft.name, color: draft.color);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String label,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<_TagDraft?> _askTag(
  BuildContext context, {
  required String title,
  BookTag? tag,
}) async {
  final controller = TextEditingController(text: tag?.name ?? '');
  var selectedColor = tag?.color ?? _tagColorPresets.first;
  final result = await showDialog<_TagDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: _ScrollableDialogContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: '标签名称'),
              ),
              const SizedBox(height: 16),
              Text('颜色', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagColorPresets
                    .map((color) {
                      final selected = selectedColor == color;
                      return ChoiceChip(
                        label: Text(color),
                        selected: selected,
                        avatar: CircleAvatar(
                          backgroundColor: _parseColor(color),
                        ),
                        onSelected: (_) =>
                            setDialogState(() => selectedColor = color),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _TagDraft(name: controller.text.trim(), color: selectedColor),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

final class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.items});

  final List<BookCategory> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text('暂无分类')),
        ),
      );
    }
    return Column(
      children: items.indexed
          .map((entry) {
            final index = entry.$1;
            final category = entry.$2;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined),
              title: Text(category.name),
              subtitle: category.parentId == null ? null : const Text('子分类'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: '上移分类',
                    onPressed: index == 0
                        ? null
                        : () => _moveCategory(context, ref, index, -1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: '下移分类',
                    onPressed: index == items.length - 1
                        ? null
                        : () => _moveCategory(context, ref, index, 1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    tooltip: '重命名分类',
                    onPressed: () => _renameCategory(context, ref, category),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '删除分类',
                    onPressed: () => _deleteCategory(context, ref, category),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _moveCategory(
    BuildContext context,
    WidgetRef ref,
    int index,
    int direction,
  ) async {
    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= items.length) {
      return;
    }
    final reordered = [...items];
    final category = reordered.removeAt(index);
    reordered.insert(targetIndex, category);
    final repository = ref.read(categoryRepositoryProvider);
    for (var i = 0; i < reordered.length; i += 1) {
      final item = reordered[i];
      final nextSortOrder = (i + 1) * 1024;
      if (item.sortOrder == nextSortOrder) {
        continue;
      }
      await repository.saveCategory(
        id: item.id,
        parentId: item.parentId,
        name: item.name,
        sortOrder: nextSortOrder,
        icon: item.icon,
      );
    }
  }

  Future<void> _renameCategory(
    BuildContext context,
    WidgetRef ref,
    BookCategory category,
  ) async {
    final name = await _askName(
      context,
      title: '重命名分类',
      label: '分类名称',
      initialValue: category.name,
    );
    if (name == null || name.isEmpty || name == category.name) {
      return;
    }
    try {
      await ref
          .read(categoryRepositoryProvider)
          .saveCategory(
            id: category.id,
            parentId: category.parentId,
            name: name,
            sortOrder: category.sortOrder,
            icon: category.icon,
          );
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    BookCategory category,
  ) async {
    final target = await showDialog<String>(
      context: context,
      builder: (context) {
        var selectedTarget = _uncategorizedCategoryTarget;
        final moveTargets = items
            .where((item) => item.id != category.id)
            .toList(growable: false);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('删除分类？'),
            content: _ScrollableDialogContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('删除“${category.name}”不会删除书籍。请选择分类中书籍的迁移目标。'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTarget,
                    decoration: const InputDecoration(labelText: '迁移到'),
                    items: [
                      const DropdownMenuItem(
                        value: _uncategorizedCategoryTarget,
                        child: Text('未分类'),
                      ),
                      ...moveTargets.map(
                        (target) => DropdownMenuItem(
                          value: target.id,
                          child: Text(target.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => selectedTarget = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selectedTarget),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
    );
    if (target != null) {
      await ref
          .read(categoryRepositoryProvider)
          .deleteCategory(
            category.id,
            moveBooksToCategoryId: target == _uncategorizedCategoryTarget
                ? null
                : target,
          );
    }
  }
}

final class _TagList extends ConsumerWidget {
  const _TagList({required this.items});

  final List<BookTag> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text('暂无标签')),
        ),
      );
    }
    return Column(
      children: items
          .map(
            (tag) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: _parseColor(tag.color),
                radius: 10,
              ),
              title: Text(tag.name),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: '编辑标签',
                    onPressed: () => _editTag(context, ref, tag),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '删除标签',
                    onPressed: () => _deleteTag(context, ref, tag),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _editTag(
    BuildContext context,
    WidgetRef ref,
    BookTag tag,
  ) async {
    final draft = await _askTag(context, title: '编辑标签', tag: tag);
    if (draft == null || draft.name.isEmpty) {
      return;
    }
    try {
      await ref
          .read(tagRepositoryProvider)
          .saveTag(id: tag.id, name: draft.name, color: draft.color);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    BookTag tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签？'),
        content: Text('删除“${tag.name}”只会解除书籍和笔记上的标签，不会删除书籍或笔记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tagRepositoryProvider).deleteTag(tag.id);
    }
  }
}

final class _TagDraft {
  const _TagDraft({required this.name, required this.color});

  final String name;
  final String color;
}

final class _ScrollableDialogContent extends StatelessWidget {
  const _ScrollableDialogContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: height * 0.52),
      child: SingleChildScrollView(child: child),
    );
  }
}

const _tagColorPresets = [
  '#1F6F64',
  '#0047B3',
  '#70612A',
  '#8A4FBA',
  '#B84A4A',
  '#5F6B2A',
];

const _uncategorizedCategoryTarget = '__uncategorized__';

Color _parseColor(String? value) {
  final normalized = value?.replaceFirst('#', '') ?? '';
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? const Color(0xFF1F6F64) : Color(0xFF000000 | parsed);
}

String _shortError(Object error) {
  final text = error.toString();
  return text.length <= 120 ? text : '${text.substring(0, 120)}...';
}

final class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x5),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

final class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceSubtle.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.appBorder.withValues(alpha: 0.9)),
      ),
      // The tint above is painted by a DecoratedBox, which sits between a
      // ListTile's row (SwitchListTile included) and the page's Material. A
      // ListTile paints its background and ink on the nearest Material, so
      // that tint would hide them — and Flutter asserts on exactly that. This
      // transparent Material is the nearest ancestor the tile needs; it paints
      // nothing itself, so the group's tint shows through.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.x2),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.x1),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

final class _SettingsFieldGap extends StatelessWidget {
  const _SettingsFieldGap({this.size = AppSpacing.x4});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}

final class _SettingsLabeledField extends StatelessWidget {
  const _SettingsLabeledField({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        child,
        if (helper != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            helper!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

final class _AiSettingsCard extends ConsumerStatefulWidget {
  const _AiSettingsCard({required this.settings});

  final AiSettings settings;

  @override
  ConsumerState<_AiSettingsCard> createState() => _AiSettingsCardState();
}

final class _AiSettingsCardState extends ConsumerState<_AiSettingsCard> {
  AiSettingsFormState get _form => ref.read(aiSettingsFormProvider);
  AiSettingsFormController get _formController =>
      ref.read(aiSettingsFormProvider.notifier);
  AiSettings get _settings => (_form.saved ?? widget.settings).copyWith(
    streaming: _form.streaming,
    confirmBeforeRequest: _form.confirmBeforeRequest,
  );
  late final _baseUrlController = TextEditingController(
    text: _form.value(AiSettingsField.baseUrl),
  );
  late final _modelController = TextEditingController(
    text: _form.value(AiSettingsField.model),
  );
  late final _temperatureController = TextEditingController(
    text: _form.value(AiSettingsField.temperature),
  );
  late final _maxTokensController = TextEditingController(
    text: _form.value(AiSettingsField.maxTokens),
  );
  late final _systemPromptController = TextEditingController(
    text: _form.value(AiSettingsField.systemPrompt),
  );
  late final _apiKeyController = TextEditingController(
    text: _form.value(AiSettingsField.apiKey),
  );
  final _advancedController = ExpansibleController();
  bool _showApiKey = false;
  bool _confirmingClear = false;

  void _synchronizeControllers(AiSettingsFormState form) {
    final controllers = {
      AiSettingsField.baseUrl: _baseUrlController,
      AiSettingsField.model: _modelController,
      AiSettingsField.apiKey: _apiKeyController,
      AiSettingsField.temperature: _temperatureController,
      AiSettingsField.maxTokens: _maxTokensController,
      AiSettingsField.systemPrompt: _systemPromptController,
    };
    for (final entry in controllers.entries) {
      final value = form.value(entry.key);
      if (entry.value.text != value) {
        entry.value.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
    if (form.hasAdvancedErrors) _advancedController.expand();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    _systemPromptController.dispose();
    _apiKeyController.dispose();
    _advancedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final form = ref.watch(aiSettingsFormProvider);
    ref.listen(aiSettingsFormProvider, (previous, next) {
      _synchronizeControllers(next);
    });
    final enabled = !form.isBusy;
    return _SettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AiSettingsGroup(
            icon: Icons.power_settings_new_outlined,
            title: '启用状态',
            subtitle: 'AI 会使用选定上下文并展示发送范围，不会自动上传整本书。',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用联网 AI'),
              subtitle: Text(
                _settings.enabled
                    ? '已开启，可在阅读器中对选中文本提问'
                    : '可先编辑并保存配置，开启后才能联网提问和测试',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.textSecondary,
                ),
              ),
              value: _settings.enabled,
              onChanged: form.isBusy ? null : _formController.setEnabled,
            ),
          ),
          const _SettingsFieldGap(size: AppSpacing.x5),
          _AiSettingsGroup(
            icon: Icons.tune_outlined,
            title: 'AI 配置组',
            subtitle: '每组独立保存接口、模型和密钥；切换不会把草稿写入另一组。',
            child: AiProfileSelector(settings: _settings),
          ),
          const _SettingsFieldGap(size: AppSpacing.x5),
          _AiSettingsGroup(
            icon: Icons.dns_outlined,
            title: 'Provider 连接',
            subtitle: '填写 OpenAI 兼容接口的地址、模型和密钥。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_settings.credentialState == 'interrupted' ||
                    _settings.credentialState == 'unavailable') ...[
                  Text(
                    _settings.credentialState == 'interrupted'
                        ? '上次密钥保存中断，已清除无法确认的密钥。请重新输入并保存，其他配置已保留。'
                        : '系统安全存储暂不可用，请解锁系统凭据服务后重新读取配置。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                  const _SettingsFieldGap(),
                ],
                _SettingsLabeledField(
                  label: 'Base URL',
                  helper: '填写完整接口地址，例如 https://api.example.com/v1',
                  child: TextField(
                    key: const ValueKey('ai-base-url'),
                    controller: _baseUrlController,
                    enabled: enabled,
                    onChanged: (value) =>
                        _formController.edit(AiSettingsField.baseUrl, value),
                    decoration: InputDecoration(
                      hintText: 'https://api.example.com/v1',
                      errorText: form.errors[AiSettingsField.baseUrl],
                    ),
                  ),
                ),
                const _SettingsFieldGap(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >=
                        640 * MediaQuery.textScalerOf(context).scale(1);
                    final modelField = _SettingsLabeledField(
                      label: '模型',
                      child: TextField(
                        key: const ValueKey('ai-model'),
                        controller: _modelController,
                        enabled: enabled,
                        onChanged: (value) =>
                            _formController.edit(AiSettingsField.model, value),
                        decoration: InputDecoration(
                          hintText: '服务商提供的模型名称',
                          errorText: form.errors[AiSettingsField.model],
                        ),
                      ),
                    );
                    final keyField = _SettingsLabeledField(
                      label: _settings.hasApiKey ? 'API Key（已保存）' : 'API Key',
                      helper: _settings.hasApiKey
                          ? '留空继续使用已保存密钥；输入新密钥会覆盖。'
                          : '密钥只保存在系统安全存储中，不会写入数据库。',
                      child: TextField(
                        key: const ValueKey('ai-api-key'),
                        controller: _apiKeyController,
                        onChanged: (value) =>
                            _formController.edit(AiSettingsField.apiKey, value),
                        enabled: enabled,
                        obscureText: !_showApiKey,
                        decoration: InputDecoration(
                          hintText: 'sk-...',
                          suffixIcon: IconButton(
                            tooltip: _showApiKey ? '隐藏 API Key' : '显示 API Key',
                            onPressed: enabled
                                ? () =>
                                      setState(() => _showApiKey = !_showApiKey)
                                : null,
                            icon: Icon(
                              _showApiKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                    );
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          modelField,
                          const _SettingsFieldGap(),
                          keyField,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: modelField),
                        const SizedBox(width: AppSpacing.x4),
                        Expanded(child: keyField),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const _SettingsFieldGap(size: AppSpacing.x5),
          _buildActions(form),
          const Divider(height: AppSpacing.x8),
          ExpansionTile(
            controller: _advancedController,
            initiallyExpanded: form.hasAdvancedErrors,
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: AppSpacing.x4),
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('高级设置'),
            subtitle: const Text('生成参数、请求行为和系统提示词'),
            children: [
              _AiSettingsGroup(
                icon: Icons.tune_outlined,
                title: '生成参数',
                subtitle: '控制回答风格和长度。',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >=
                        640 * MediaQuery.textScalerOf(context).scale(1);
                    final temperature = _SettingsLabeledField(
                      label: 'Temperature',
                      helper: '建议 0 到 1，越高越发散',
                      child: TextField(
                        key: const ValueKey('ai-temperature'),
                        controller: _temperatureController,
                        enabled: enabled,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (value) => _formController.edit(
                          AiSettingsField.temperature,
                          value,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.2',
                          errorText: form.errors[AiSettingsField.temperature],
                        ),
                      ),
                    );
                    final maxTokens = _SettingsLabeledField(
                      label: 'Max tokens',
                      helper: '限制单次回答长度',
                      child: TextField(
                        key: const ValueKey('ai-max-tokens'),
                        controller: _maxTokensController,
                        enabled: enabled,
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _formController.edit(
                          AiSettingsField.maxTokens,
                          value,
                        ),
                        decoration: InputDecoration(
                          hintText: '1200',
                          errorText: form.errors[AiSettingsField.maxTokens],
                        ),
                      ),
                    );
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          temperature,
                          const _SettingsFieldGap(),
                          maxTokens,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: temperature),
                        const SizedBox(width: AppSpacing.x4),
                        Expanded(child: maxTokens),
                      ],
                    );
                  },
                ),
              ),
              const _SettingsFieldGap(size: AppSpacing.x5),
              _AiSettingsGroup(
                icon: Icons.shield_outlined,
                title: '请求行为',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('流式显示回答'),
                      subtitle: Text(
                        '边生成边显示，可随时取消',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.textSecondary,
                        ),
                      ),
                      value: _settings.streaming,
                      onChanged: enabled ? _formController.setStreaming : null,
                    ),
                    const Divider(height: AppSpacing.x6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('每次请求前确认上下文'),
                      subtitle: Text(
                        '默认关闭；开启后每次发送前弹出确认框',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.textSecondary,
                        ),
                      ),
                      value: _settings.confirmBeforeRequest,
                      onChanged: enabled
                          ? _formController.setConfirmBeforeRequest
                          : null,
                    ),
                    const _SettingsFieldGap(),
                    _SettingsLabeledField(
                      label: '默认系统提示词',
                      helper: '可留空；不会自动加入书籍正文',
                      child: TextField(
                        key: const ValueKey('ai-system-prompt'),
                        controller: _systemPromptController,
                        onChanged: (value) => _formController.edit(
                          AiSettingsField.systemPrompt,
                          value,
                        ),
                        enabled: enabled,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '你是一个克制、准确的阅读助手…',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AiSettingsFormState form) {
    final feedback = form.feedback;
    final status = switch (form.operation) {
      AiSettingsOperation.saving => '正在保存配置…',
      AiSettingsOperation.savingForTest => '正在保存配置，随后测试…',
      AiSettingsOperation.testing => '配置已保存，正在测试连接…',
      AiSettingsOperation.toggling => '正在更新 AI 开关…',
      AiSettingsOperation.clearing => '正在清除密钥…',
      AiSettingsOperation.idle when form.isDirty => '有未保存的更改',
      AiSettingsOperation.idle when form.saved?.baseUrl.isEmpty ?? true =>
        '填写连接信息后保存',
      AiSettingsOperation.idle => '当前配置已保存',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.x3,
          runSpacing: AppSpacing.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(status, style: Theme.of(context).textTheme.bodyMedium),
            if (form.isDirty)
              TextButton(
                onPressed: form.isBusy ? null : _formController.discardChanges,
                child: const Text('放弃更改'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            FilledButton(
              onPressed: !form.isBusy && form.isDirty
                  ? () => _formController.save()
                  : null,
              child: Text(
                form.operation == AiSettingsOperation.saving
                    ? '保存中…'
                    : '保存 AI 设置',
              ),
            ),
            OutlinedButton(
              onPressed: form.enabled && !form.isBusy
                  ? () => _formController.save(testConnection: true)
                  : null,
              child: Text(switch (form.operation) {
                AiSettingsOperation.savingForTest => '正在保存配置…',
                AiSettingsOperation.testing => '正在测试连接…',
                _ => '保存并测试',
              }),
            ),
            TextButton(
              onPressed: _settings.hasApiKey && !form.isBusy
                  ? _confirmClearApiKey
                  : null,
              child: const Text('清除密钥'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          '连接测试会先保存当前配置，不会发送书籍正文。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.textSecondary,
          ),
        ),
        if (form.isBusy) ...[
          const SizedBox(height: AppSpacing.x3),
          LinearProgressIndicator(semanticsLabel: status),
        ],
        if (feedback != null) ...[
          const SizedBox(height: AppSpacing.x3),
          Semantics(
            liveRegion: true,
            child: AppStatusBanner(
              icon: switch (feedback.kind) {
                AiSettingsFeedbackKind.success => Icons.check_circle_outline,
                AiSettingsFeedbackKind.error => Icons.error_outline,
                AiSettingsFeedbackKind.info => Icons.info_outline,
              },
              message: feedback.message,
              tone: feedback.kind == AiSettingsFeedbackKind.error
                  ? AppStatusTone.danger
                  : AppStatusTone.neutral,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmClearApiKey() async {
    if (_confirmingClear || _form.isBusy) return;
    _confirmingClear = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除 API Key？'),
        content: const Text('清除后，联网 AI 请求会在重新保存密钥前不可用。'),
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
    _confirmingClear = false;
    if (confirmed != true || !mounted) {
      return;
    }
    await _formController.clearApiKey();
  }
}

final class _AiSettingsGroup extends StatelessWidget {
  const _AiSettingsGroup({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.x2),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),
        child,
      ],
    );
  }
}
