import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import '../../../renderers/epub/epub_jump.dart';
import '../application/ai_providers.dart';
import '../application/context_builder.dart';

/// Reader AI surface used as desktop right-rail body or mobile bottom sheet.
final class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({
    required this.bookId,
    required this.locator,
    required this.initialContext,
    this.onJumpTo,
    this.onNoteSaved,
    this.embedded = false,
    super.key,
  });

  final String bookId;
  final ReadingLocator? locator;
  final String? initialContext;
  final ValueChanged<ReadingLocator>? onJumpTo;
  final VoidCallback? onNoteSaved;
  final bool embedded;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

enum _AiPanelTab { compose, history }

final class _AiPanelState extends ConsumerState<AiPanel> {
  late final TextEditingController _contextController = TextEditingController(
    text: widget.initialContext ?? '',
  );
  final _promptController = TextEditingController(text: '解释这段内容');
  AiContextRange _contextRange = AiContextRange.selectedText;
  late String _contextDescription = const ContextBuilder()
      .build(
        selectedText: widget.initialContext ?? '',
        range: _contextRange,
        locator: widget.locator,
      )
      .description;
  AiConversation? _conversation;
  AiCancelToken? _cancelToken;
  String _answer = '';
  String? _error;
  bool _loading = false;
  bool _contextExpanded = false;
  _AiPanelTab _tab = _AiPanelTab.compose;

  @override
  void dispose() {
    _cancelToken?.cancel();
    _contextController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextContext = widget.initialContext?.trim() ?? '';
    final oldContext = oldWidget.initialContext?.trim() ?? '';
    final nextLocator = widget.locator?.toJsonText();
    final oldLocator = oldWidget.locator?.toJsonText();
    if (nextContext == oldContext && nextLocator == oldLocator) {
      return;
    }
    if (_loading) {
      return;
    }
    final current = _contextController.text;
    final canReplace =
        current.trim().isEmpty ||
        current == (oldWidget.initialContext ?? '') ||
        current == oldContext;
    if (!canReplace) {
      setState(() {
        _contextDescription = const ContextBuilder()
            .build(
              selectedText: current,
              range: _contextRange,
              locator: widget.locator,
            )
            .description;
      });
      return;
    }
    _contextController.text = widget.initialContext ?? '';
    setState(() {
      _contextDescription = const ContextBuilder()
          .build(
            selectedText: widget.initialContext ?? '',
            range: _contextRange,
            locator: widget.locator,
          )
          .description;
      if (nextContext != oldContext) {
        _answer = '';
        _error = null;
        _conversation = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    final gap = embedded ? AppSpacing.x2 : AppSpacing.x3;
    return SafeArea(
      top: !embedded,
      child: Padding(
        padding: EdgeInsets.only(
          left: embedded ? AppSpacing.x2 : 20,
          right: embedded ? AppSpacing.x2 : 20,
          top: embedded ? AppSpacing.x1 : 0,
          bottom: MediaQuery.viewInsetsOf(context).bottom + (embedded ? 6 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!embedded) ...[
              Text(
                'AI',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: gap),
            ],
            _AiPanelTabBar(
              tab: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            SizedBox(height: gap),
            Expanded(
              child: switch (_tab) {
                _AiPanelTab.compose => _buildCompose(context),
                _AiPanelTab.history => _AiHistoryView(
                  bookId: widget.bookId,
                  onUseConversation: _useConversation,
                  onCopyAnswer: _copyConversationAnswer,
                  onSaveAsNote: _saveConversationAsNote,
                  onJumpTo: (locator) {
                    widget.onJumpTo?.call(locator);
                    if (!widget.embedded && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompose(BuildContext context) {
    final embedded = widget.embedded;
    final sectionGap = embedded ? AppSpacing.x2 : AppSpacing.x3;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              _AiContextCard(
                description: _contextDescription,
                text: _contextController.text,
                range: _contextRange,
                locationLabel: const ContextBuilder().locationLabel(
                  widget.locator,
                ),
                expanded: _contextExpanded,
                compact: embedded,
                onToggleExpand: () =>
                    setState(() => _contextExpanded = !_contextExpanded),
                contextController: _contextController,
                onContextChanged: _refreshContextDescription,
                onRangeChanged: _applyContextRange,
              ),
              SizedBox(height: sectionGap),
              Text(
                '快捷动作',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final action in _kPromptActions)
                    _AiPromptChip(
                      label: action.label,
                      prompt: action.prompt,
                      compact: embedded,
                      onPressed: () {
                        _promptController.text = action.prompt;
                        _promptController.selection = TextSelection.collapsed(
                          offset: action.prompt.length,
                        );
                        setState(() {});
                      },
                    ),
                ],
              ),
              SizedBox(height: sectionGap),
              TextField(
                controller: _promptController,
                minLines: 1,
                maxLines: embedded ? 2 : 3,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!_loading) {
                    unawaited(_ask());
                  }
                },
                decoration: InputDecoration(
                  labelText: '问题',
                  hintText: '解释、翻译或自定义提问…',
                  isDense: embedded,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                '仅发送上方文本，不会上传整本书。',
                style: textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_loading) ...[
                SizedBox(height: sectionGap),
                const _AiStatusBanner(
                  icon: Icons.auto_awesome_outlined,
                  message: '正在生成回答，可随时取消。',
                  tone: AppStatusTone.ai,
                ),
              ],
              if (_error != null) ...[
                SizedBox(height: sectionGap),
                _AiStatusBanner(
                  icon: Icons.error_outline,
                  message: _error!,
                  tone: AppStatusTone.danger,
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () {
                        if (!widget.embedded &&
                            Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        context.go('/settings');
                      },
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('设置'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyError,
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('复制'),
                    ),
                  ],
                ),
              ],
              if (_answer.isNotEmpty) ...[
                SizedBox(height: sectionGap),
                Text(
                  '回答',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                _AiAnswerBlock(answer: _answer, compact: embedded),
                const SizedBox(height: AppSpacing.x2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _copyAnswer,
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('复制'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _ask,
                        icon: const Icon(Icons.refresh_outlined, size: 16),
                        label: const Text('重试'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saveAsNote,
                        icon: const Icon(Icons.note_add_outlined, size: 16),
                        label: const Text('笔记'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: sectionGap),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildActionBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sendButton = FilledButton.icon(
          onPressed: _loading ? null : _ask,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_loading ? '生成中' : '发送'),
        );
        if (!_loading) {
          return SizedBox(width: double.infinity, child: sendButton);
        }
        final cancelButton = OutlinedButton.icon(
          onPressed: _cancel,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('取消'),
        );
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cancelButton,
              const SizedBox(height: AppSpacing.x2),
              sendButton,
            ],
          );
        }
        return Row(
          children: [
            cancelButton,
            const SizedBox(width: AppSpacing.x3),
            Expanded(child: sendButton),
          ],
        );
      },
    );
  }

  Future<void> _ask() async {
    final contextText = _contextController.text.trim();
    final prompt = _promptController.text.trim();
    if (contextText.isEmpty || prompt.isEmpty) {
      setState(() => _error = '请输入上下文和问题');
      return;
    }
    final settings = await ref.read(aiSettingsRepositoryProvider).getSettings();
    if (!settings.enabled) {
      setState(() => _error = 'AI 功能未启用，请先在设置中打开并配置 Provider');
      return;
    }
    if (!settings.hasApiKey ||
        settings.baseUrl.trim().isEmpty ||
        settings.model.trim().isEmpty) {
      setState(() => _error = '请先在设置中配置 AI Provider、模型与 API Key');
      return;
    }
    if (contextText.length > 12000) {
      setState(() => _error = '上下文过长，请缩短选区或改用更短范围后再发送');
      return;
    }
    final contextDescription = const ContextBuilder()
        .build(
          selectedText: contextText,
          range: _contextRange,
          locator: widget.locator,
        )
        .description;
    if (settings.confirmBeforeRequest && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发送 AI 请求？'),
          content: Text(contextDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('发送'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    final cancelToken = AiCancelToken();
    setState(() {
      _loading = true;
      _error = null;
      _answer = '';
      _conversation = null;
      _cancelToken = cancelToken;
      _tab = _AiPanelTab.compose;
    });
    try {
      final conversation = await ref
          .read(aiChatServiceProvider)
          .ask(
            bookId: widget.bookId,
            locator: widget.locator,
            contextText: contextText,
            prompt: prompt,
            sourceText: contextText,
            cancelToken: cancelToken,
            onChunk: (chunk) {
              if (!mounted) {
                return;
              }
              setState(() => _answer += chunk);
            },
          );
      setState(() {
        _conversation = conversation;
        _answer = conversation.answer;
      });
    } on AiChatCancelledException catch (error) {
      setState(() {
        _answer = error.partialAnswer.isEmpty ? _answer : error.partialAnswer;
        _error = '请求已取消，可保存已生成内容或重新发送';
      });
    } on AiChatException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'AI 请求失败');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _cancelToken = null;
        });
      }
    }
  }

  void _cancel() {
    _cancelToken?.cancel();
  }

  Future<void> _copyError() async {
    final error = _error?.trim();
    if (error == null || error.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: error));
  }

  void _useConversation(AiConversation conversation) {
    setState(() {
      _tab = _AiPanelTab.compose;
      _conversation = conversation;
      _promptController.text = conversation.prompt;
      _contextController.text =
          conversation.contextText ?? conversation.sourceText ?? '';
      _answer = conversation.answer;
      _error = null;
      _contextDescription = const ContextBuilder()
          .build(
            selectedText: _contextController.text,
            range: _contextRange,
            locator: conversation.locator ?? widget.locator,
          )
          .description;
    });
  }

  Future<void> _copyConversationAnswer(AiConversation conversation) async {
    await Clipboard.setData(ClipboardData(text: conversation.answer));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制回答')));
  }

  Future<void> _saveConversationAsNote(AiConversation conversation) async {
    await ref
        .read(noteRepositoryProvider)
        .saveNote(
          bookId: widget.bookId,
          title: conversation.prompt,
          content: conversation.answer,
          sourceText: conversation.sourceText ?? conversation.contextText,
          locator: conversation.locator ?? widget.locator,
          noteType: NoteType.ai,
        )
        .then((note) async {
          await ref
              .read(aiConversationRepositoryProvider)
              .linkNote(conversationId: conversation.id, noteId: note.id);
        });
    widget.onNoteSaved?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存为笔记')));
  }

  void _applyContextRange(AiContextRange range) {
    final built = const ContextBuilder().build(
      selectedText: widget.initialContext ?? _contextController.text,
      range: range,
      locator: widget.locator,
    );
    setState(() {
      _contextRange = range;
      _contextController.text = built.text;
      _contextDescription = built.description;
    });
  }

  void _refreshContextDescription(String value) {
    final built = const ContextBuilder().build(
      selectedText: value,
      range: _contextRange,
      locator: widget.locator,
    );
    setState(() => _contextDescription = built.description);
  }

  Future<void> _copyAnswer() async {
    final answer = _answer.trim();
    if (answer.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: answer));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制回答')));
  }

  Future<void> _saveAsNote() async {
    final answer = _answer.trim();
    if (answer.isEmpty) {
      return;
    }
    final conversation = _conversation;
    final note = await ref
        .read(noteRepositoryProvider)
        .saveNote(
          bookId: widget.bookId,
          title: conversation?.prompt ?? _promptController.text.trim(),
          content: answer,
          sourceText:
              conversation?.sourceText ?? _contextController.text.trim(),
          locator: widget.locator,
          noteType: NoteType.ai,
        );
    if (conversation != null) {
      await ref
          .read(aiConversationRepositoryProvider)
          .linkNote(conversationId: conversation.id, noteId: note.id);
    }
    widget.onNoteSaved?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存为笔记')));
  }
}

final class _PromptAction {
  const _PromptAction(this.label, this.prompt);

  final String label;
  final String prompt;
}

const _kPromptActions = <_PromptAction>[
  _PromptAction('解释', '解释这段内容'),
  _PromptAction('总结', '总结这段内容'),
  _PromptAction('提炼要点', '提炼这段内容的要点'),
  _PromptAction('翻译', '把这段内容翻译成中文'),
  _PromptAction('简单说明', '用更简单的话说明这段内容'),
  _PromptAction('生成问题', '基于这段内容生成 3 个值得继续思考的问题'),
];

final class _AiPanelTabBar extends StatelessWidget {
  const _AiPanelTabBar({required this.tab, required this.onChanged});

  final _AiPanelTab tab;
  final ValueChanged<_AiPanelTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _AiPanelTabChip(
                label: '提问',
                icon: Icons.edit_note_outlined,
                selected: tab == _AiPanelTab.compose,
                onTap: () => onChanged(_AiPanelTab.compose),
              ),
            ),
            Expanded(
              child: _AiPanelTabChip(
                label: '历史',
                icon: Icons.history,
                selected: tab == _AiPanelTab.history,
                onTap: () => onChanged(_AiPanelTab.history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AiPanelTabChip extends StatelessWidget {
  const _AiPanelTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AiContextCard extends StatelessWidget {
  const _AiContextCard({
    required this.description,
    required this.text,
    required this.range,
    required this.expanded,
    required this.onToggleExpand,
    required this.contextController,
    required this.onContextChanged,
    required this.onRangeChanged,
    this.locationLabel,
    this.compact = false,
  });

  final String description;
  final String text;
  final AiContextRange range;
  final String? locationLabel;
  final bool expanded;
  final bool compact;
  final VoidCallback onToggleExpand;
  final TextEditingController contextController;
  final ValueChanged<String> onContextChanged;
  final ValueChanged<AiContextRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final aiAccent = colorScheme.aiAccent;
    final preview = text.trim().isEmpty ? '还没有可发送的文本' : text.trim();
    final pad = compact ? AppSpacing.x2 : AppSpacing.x3;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: aiAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: aiAccent.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: aiAccent,
                  size: compact ? 16 : 18,
                ),
                SizedBox(width: compact ? 6 : AppSpacing.x2),
                Expanded(
                  child: Text(
                    '将发送的文本',
                    style:
                        (compact ? textTheme.labelLarge : textTheme.titleSmall)
                            ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _MetaChip(label: range.label, color: aiAccent),
              ],
            ),
            SizedBox(height: compact ? AppSpacing.x1 : AppSpacing.x2),
            DropdownButtonFormField<AiContextRange>(
              initialValue: range,
              isDense: true,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: '上下文范围',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: AiContextRange.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onRangeChanged(value);
                }
              },
            ),
            SizedBox(height: compact ? AppSpacing.x1 : AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x1,
              runSpacing: AppSpacing.x1,
              children: [
                _MetaChip(
                  label: description,
                  color: colorScheme.onSurfaceVariant,
                  subtle: true,
                ),
                if (locationLabel != null && locationLabel!.trim().isNotEmpty)
                  _MetaChip(
                    label: '回跳：$locationLabel',
                    color: colorScheme.onSurfaceVariant,
                    subtle: true,
                  ),
              ],
            ),
            SizedBox(height: compact ? AppSpacing.x1 : AppSpacing.x2),
            Text(
              preview,
              maxLines: expanded ? null : (compact ? 2 : 3),
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
                fontSize: compact ? 13 : 14,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onToggleExpand,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.edit_outlined,
                  size: 16,
                ),
                label: Text(
                  expanded ? '收起' : '编辑',
                  style: textTheme.labelMedium,
                ),
              ),
            ),
            if (expanded) ...[
              TextField(
                controller: contextController,
                minLines: compact ? 2 : 3,
                maxLines: compact ? 6 : 8,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
                onChanged: onContextChanged,
                decoration: InputDecoration(
                  helperText: compact ? null : '默认只发送这里显示的文本，不会发送整本书',
                  isDense: compact,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _AiPromptChip extends StatelessWidget {
  const _AiPromptChip({
    required this.label,
    required this.prompt,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final String prompt;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Action chips only fill the prompt — no sticky selected/check state.
    return ActionChip(
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 0),
      labelPadding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
      avatar: Icon(Icons.auto_awesome_outlined, size: compact ? 14 : 16),
      label: Text(label, style: Theme.of(context).textTheme.labelMedium),
      onPressed: onPressed,
    );
  }
}

final class _AiAnswerBlock extends StatelessWidget {
  const _AiAnswerBlock({required this.answer, this.compact = false});

  final String answer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Side-rail answers read as dense docs, not page body text.
    final bodySize = compact ? 13.0 : 14.0;
    final bodyHeight = compact ? 1.45 : 1.5;
    final bodyStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface,
      fontSize: bodySize,
      height: bodyHeight,
    );
    final secondaryStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: compact ? 12 : 13,
      height: 1.4,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: compact ? 0.22 : 0.3,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.x2 : AppSpacing.x3),
        child: MarkdownBody(
          data: answer,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: bodyStyle,
            pPadding: EdgeInsets.only(bottom: compact ? 6 : 8),
            h1: bodyStyle?.copyWith(
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            h2: bodyStyle?.copyWith(
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            h3: bodyStyle?.copyWith(
              fontSize: compact ? 13.5 : 14.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            h1Padding: EdgeInsets.only(top: compact ? 4 : 6, bottom: 4),
            h2Padding: EdgeInsets.only(top: compact ? 4 : 6, bottom: 4),
            h3Padding: EdgeInsets.only(top: compact ? 2 : 4, bottom: 2),
            listBullet: bodyStyle,
            listIndent: compact ? 16 : 20,
            blockquote: secondaryStyle,
            blockquotePadding: EdgeInsets.only(
              left: compact ? 8 : 10,
              top: 2,
              bottom: 2,
            ),
            code: textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: compact ? 12 : 12.5,
              color: colorScheme.onSurface,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
            ),
            codeblockPadding: EdgeInsets.all(compact ? 8 : 10),
            codeblockDecoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _AiStatusBanner extends StatelessWidget {
  const _AiStatusBanner({
    required this.icon,
    required this.message,
    required this.tone,
    this.actions = const [],
  });

  final IconData icon;
  final String message;
  final AppStatusTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppStatusBanner(
      icon: icon,
      message: message,
      tone: tone,
      action: actions.isEmpty
          ? null
          : Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: actions,
            ),
    );
  }
}

final class _AiHistoryView extends ConsumerWidget {
  const _AiHistoryView({
    required this.bookId,
    required this.onUseConversation,
    required this.onCopyAnswer,
    required this.onSaveAsNote,
    required this.onJumpTo,
  });

  final String bookId;
  final ValueChanged<AiConversation> onUseConversation;
  final Future<void> Function(AiConversation) onCopyAnswer;
  final Future<void> Function(AiConversation) onSaveAsNote;
  final ValueChanged<ReadingLocator> onJumpTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<AiConversation>>(
      stream: ref.watch(aiConversationRepositoryProvider).watchConversations(),
      builder: (context, snapshot) {
        final conversations = (snapshot.data ?? const <AiConversation>[])
            .where((conversation) => conversation.bookId == bookId)
            .toList(growable: false);
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (conversations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    '还没有当前书籍的 AI 历史',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    '选中正文后提问，或在「提问」页直接发送。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.x2),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _AiHistoryCard(
              conversation: conversation,
              onOpen: () => onUseConversation(conversation),
              onCopy: () => unawaited(onCopyAnswer(conversation)),
              onSaveNote: () => unawaited(onSaveAsNote(conversation)),
              onJump: conversation.locator == null
                  ? null
                  : () => onJumpTo(
                      enrichLocatorForJump(
                        conversation.locator!,
                        fallbackExcerpt:
                            conversation.sourceText ?? conversation.contextText,
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

final class _AiHistoryCard extends StatelessWidget {
  const _AiHistoryCard({
    required this.conversation,
    required this.onOpen,
    required this.onCopy,
    required this.onSaveNote,
    this.onJump,
  });

  final AiConversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onSaveNote;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final time = DateTime.fromMillisecondsSinceEpoch(conversation.createdAt);
    final timeLabel =
        '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: colorScheme.aiAccent,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      conversation.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                conversation.answer,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Row(
                children: [
                  TextButton(onPressed: onOpen, child: const Text('载入提问')),
                  IconButton(
                    tooltip: '复制回答',
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: '保存为笔记',
                    onPressed: onSaveNote,
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: '跳回原文',
                    onPressed: onJump,
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    this.subtle = false,
  });

  final String label;
  final Color color;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: subtle ? 0.07 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
