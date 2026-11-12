import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../domain/ai/ai_models.dart';
import '../application/ai_settings_providers.dart';

enum _ProfileAction { copy, copySecret, rename, delete }

final class AiProfileSelector extends ConsumerStatefulWidget {
  const AiProfileSelector({required this.settings, super.key});

  final AiSettings settings;

  @override
  ConsumerState<AiProfileSelector> createState() => _AiProfileSelectorState();
}

final class _AiProfileSelectorState extends ConsumerState<AiProfileSelector> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(aiProfilesProvider);
    final entries = profiles.asData?.value;
    final selected = widget.settings.activeProfileId;
    final activeProfile = entries
        ?.where((profile) => profile.id == selected)
        .firstOrNull;
    final activeLabel = activeProfile?.name ?? widget.settings.profileName;
    final canSelect = !_busy && entries != null && !profiles.hasError;
    final canManage = !_busy && entries != null && !profiles.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: '当前配置',
            suffixIcon: profiles.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.x3),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              key: ValueKey(
                'ai-profile-$selected-${entries?.length ?? 'loading'}',
              ),
              value: selected,
              isExpanded: true,
              items: [
                if (selected == null)
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('首次保存将创建默认配置'),
                  ),
                if (selected != null)
                  DropdownMenuItem<String?>(
                    value: selected,
                    child: Text(
                      activeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                for (final profile in entries ?? const <AiProfile>[])
                  if (profile.id != selected)
                    DropdownMenuItem<String?>(
                      value: profile.id,
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: canSelect
                  ? (value) {
                      if (value == selected) return;
                      _select(value);
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Row(
          children: [
            if (context.appBreakpoint.isCompact)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canManage ? _create : null,
                  icon: const Icon(Icons.add_outlined),
                  label: const Text('新建配置'),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: canManage ? _create : null,
                icon: const Icon(Icons.add_outlined),
                label: const Text('新建配置'),
              ),
            const SizedBox(width: AppSpacing.x2),
            PopupMenuButton<_ProfileAction>(
              enabled: canManage && selected != null,
              tooltip: '配置操作',
              onSelected: _handleAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ProfileAction.copy,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.copy_outlined),
                    title: Text('复制配置'),
                  ),
                ),
                PopupMenuItem(
                  value: _ProfileAction.copySecret,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.key_outlined),
                    title: Text('复制配置和密钥'),
                  ),
                ),
                PopupMenuItem(
                  value: _ProfileAction.rename,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('重命名配置'),
                  ),
                ),
                PopupMenuItem(
                  value: _ProfileAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('删除配置'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          profiles.isLoading && entries == null
              ? '正在读取 AI 配置…'
              : profiles.hasError
              ? '配置列表暂时不可用；已有内容仍保留，可重试刷新。'
              : entries?.isEmpty == true
              ? '可直接填写下方连接信息并保存，也可先新建命名配置。'
              : '切换配置会加载该组已保存的接口、模型和密钥；未保存草稿按组保留。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: profiles.hasError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.textSecondary,
          ),
        ),
        if (profiles.hasError) ...[
          const SizedBox(height: AppSpacing.x2),
          Semantics(
            liveRegion: true,
            child: AppStatusBanner(
              icon: Icons.error_outline,
              message: '无法读取 AI 配置',
              tone: AppStatusTone.danger,
              action: TextButton(
                onPressed: () {
                  setState(() => _error = null);
                  ref.invalidate(aiProfilesProvider);
                },
                child: const Text('重试'),
              ),
            ),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: AppSpacing.x2),
          const LinearProgressIndicator(
            minHeight: 2,
            semanticsLabel: '正在更新 AI 配置',
          ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: AppSpacing.x2),
          Semantics(
            liveRegion: true,
            child: AppStatusBanner(
              icon: Icons.error_outline,
              message: error,
              tone: AppStatusTone.danger,
              action: TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('关闭'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _select(String? value) {
    return _run(
      failure: '无法切换配置，请重试',
      action: () => ref.read(aiSettingsControllerProvider).selectProfile(value),
    );
  }

  Future<void> _create() async {
    final name = await _prompt(title: '新建配置', initial: '新配置');
    if (!mounted || name == null || name.trim().isEmpty) return;
    await _run(
      failure: '无法新建配置，请重试',
      action: () async {
        final created = await ref
            .read(aiSettingsControllerProvider)
            .createProfile(name: name.trim());
        if (created != null) {
          await ref
              .read(aiSettingsControllerProvider)
              .selectProfile(created.id);
        }
      },
    );
  }

  Future<void> _copy({required bool copyCredential}) async {
    final source = widget.settings.activeProfileId;
    if (source == null) return;
    final name = await _prompt(
      title: copyCredential ? '复制配置和密钥' : '复制配置',
      initial: '${widget.settings.profileName} 副本',
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    await _run(
      failure: copyCredential ? '无法复制配置和密钥，请重试' : '无法复制配置，请重试',
      action: () async {
        final created = await ref
            .read(aiSettingsControllerProvider)
            .createProfile(
              name: name.trim(),
              sourceProfileId: source,
              copyCredential: copyCredential,
            );
        if (created != null) {
          await ref
              .read(aiSettingsControllerProvider)
              .selectProfile(created.id);
        }
      },
    );
  }

  Future<void> _rename() async {
    final selected = widget.settings.activeProfileId;
    if (selected == null) return;
    final name = await _prompt(
      title: '重命名配置',
      initial:
          widget.settings.profileNames[selected] ?? widget.settings.profileName,
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    await _run(
      failure: '无法重命名配置，请重试',
      action: () => ref
          .read(aiSettingsControllerProvider)
          .renameActiveProfile(name.trim()),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除当前配置？'),
        content: const Text('该组的密钥会一并清除；历史回答保留当时的配置身份。'),
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
    if (!mounted || confirmed != true) return;
    await _run(
      failure: '无法删除配置，请重试',
      action: () =>
          ref.read(aiSettingsControllerProvider).deleteActiveProfile(),
    );
  }

  Future<void> _handleAction(_ProfileAction action) {
    return switch (action) {
      _ProfileAction.copy => _copy(copyCredential: false),
      _ProfileAction.copySecret => _copy(copyCredential: true),
      _ProfileAction.rename => _rename(),
      _ProfileAction.delete => _delete(),
    };
  }

  Future<void> _run({
    required String failure,
    required Future<void> Function() action,
  }) async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(aiSettingsProvider);
      ref.invalidate(aiProfilesProvider);
    } catch (_) {
      if (mounted) setState(() => _error = '$failure。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _prompt({required String title, required String initial}) {
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          decoration: const InputDecoration(labelText: '配置名称'),
          onChanged: (next) => value = next,
          onFieldSubmitted: (next) => Navigator.of(context).pop(next),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(value),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
