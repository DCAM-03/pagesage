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
import '../application/ai_context_range.dart';
import '../application/ai_context_reference.dart';
import '../application/ai_context_source.dart';
import '../application/ai_providers.dart';
import '../application/context_builder.dart';
import '../application/retrieval_context_source.dart';

/// Reader AI surface used as desktop right-rail body or mobile bottom sheet.
final class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({
    required this.bookId,
    required this.locator,
    required this.initialContext,
    this.bookPath,
    this.isEpub = false,
    this.onJumpTo,
    this.onNoteSaved,
    this.embedded = false,
    super.key,
  });

  final String bookId;
  final ReadingLocator? locator;
  final String? initialContext;

  /// Where to read page or chapter text from when the range asks for it.
  ///
  /// Null when the panel was opened without a book on disk (search results
  /// from a deleted file, a preview), in which case the wider ranges fall back
  /// to the selection rather than pretending to have read the chapter.
  final String? bookPath;

  final bool isEpub;
  final ValueChanged<ReadingLocator>? onJumpTo;
  final VoidCallback? onNoteSaved;
  final bool embedded;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

enum _AiPanelTab { compose, history }

final class _AiPanelState extends ConsumerState<AiPanel> {
  final _promptController = TextEditingController(text: '解释这段内容');
  AiContextRange _contextRange = AiContextRange.selectedText;

  /// What the next request will carry, in the order it will be sent.
  ///
  /// A list rather than one text box: `AGENTS.md` requires the context range to
  /// be explicit, and once a range can return several blocks from several
  /// books, a single box hides which ones are in play. Each row can be opened,
  /// edited, jumped back to, or dropped.
  final List<AiContextReference> _references = [];
  int _nextReferenceId = 0;

  AiConversation? _conversation;
  AiCancelToken? _cancelToken;

  /// The thread the next question continues, if any.
  ///
  /// Set from the first answer in a context. A new selection or a different
  /// reference list starts a new one: carrying turns across a changed context
  /// would ask the model to reason about a passage it was never shown.
  String? _threadId;

  /// Earlier turns in this thread, oldest first.
  final List<AiThreadTurn> _history = [];

  List<AiThreadTurn> get _threadHistory =>
      List<AiThreadTurn>.unmodifiable(_history);
  String _answer = '';
  String? _error;
  bool _loading = false;
  bool _contextExpanded = false;

  /// True while a page or chapter is being read for a wider context range.
  bool _loadingContext = false;

  /// True when the loaded block was longer than one request can carry.
  bool _contextTruncated = false;

  /// Why a wider range could not be loaded, shown next to the context card.
  ///
  /// Kept apart from [_error]: that banner offers "设置" and "复制" because it
  /// speaks about the AI provider, and neither helps when the book file is
  /// simply unreadable.
  String? _contextNotice;

  /// What the reader has typed into the question box.
  ///
  /// Null until they type: the prefilled default is a suggestion for the
  /// model, and using it as a search query would look for the words in the
  /// suggestion instead of the words in the passage.
  String? _editedPrompt;

  /// True while retrieval is picking passages from the indexed book text.
  ///
  /// Separate from [_loadingContext] only in what the card says: a read names
  /// one page or chapter, retrieval has to say how many books it went
  /// through before the passages appear.
  String? _retrievalStatus;

  /// Discards a read whose page the reader has already left.
  int _loadToken = 0;

  /// Bumped on every range attempt so the selector redraws from the panel.
  ///
  /// A `FormField` keeps the value it was given by `didChange` until its
  /// `initialValue` changes. When a wider range fails and the panel falls back
  /// to the selection, `_contextRange` returns to the value it already had, so
  /// nothing would tell the selector to drop the label it was just handed.
  int _rangeVersion = 0;

  _AiPanelTab _tab = _AiPanelTab.compose;

  @override
  void initState() {
    super.initState();
    _references.add(_selectionReference());
  }

  /// The reader's own selection, as the first reference by default.
  AiContextReference _selectionReference() {
    return AiContextReference(
      id: 'ref-${_nextReferenceId++}',
      title: '选中文本',
      text: widget.initialContext?.trim() ?? '',
      locator: widget.locator,
      isSelection: true,
    );
  }

  /// A thread id for the turn about to be sent.
  ///
  /// The panel names the thread rather than the service: the id has to be on
  /// the row this request writes, and the service only learns about threads
  /// through what it is handed.
  static String _newThreadId() =>
      'thread-${DateTime.now().microsecondsSinceEpoch}';

  /// Drops the thread so the next question starts fresh.
  ///
  /// Called whenever the context changes shape — a new selection, a different
  /// range, a removed reference. The old turns discussed text the next
  /// question will not carry, and keeping them would invite the model to
  /// answer from a passage it was not given this time.
  void _startNewThread() {
    _threadId = null;
    _history.clear();
    _conversation = null;
  }

  /// The selection currently in the list, if the reader has not dropped it.
  AiContextReference? get _selection =>
      _references.where((reference) => reference.isSelection).firstOrNull;

  /// The references that actually carry text, in list order.
  List<AiContextReference> get _visibleReferences => _references
      .where((reference) => reference.text.trim().isNotEmpty)
      .toList(growable: false);

  /// Everything the request will carry, in list order.
  String get _payloadText => joinContextReferences(_references);

  int get _payloadChars => _payloadText.length;

  String get _contextDescription {
    final visible = _visibleReferences;
    final what = switch (visible.length) {
      0 => '没有可发送的文本',
      1 => visible.first.label,
      final count => '$count 段引用',
    };
    return '$what · 约 $_payloadChars 字 · 仅发送下方列表';
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
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
    if (_loadingContext) {
      // The read in flight was for the page the reader has just left. Let it
      // finish into nothing rather than labelling the new selection with the
      // old chapter. A build follows this call, so no setState is needed.
      _loadToken++;
      _loadingContext = false;
    }
    setState(() {
      // A new selection replaces the list rather than adding to it: text read
      // for the previous page is not context for this one, and leaving it in
      // would send a chapter the reader has since left.
      _references
        ..clear()
        ..add(
          AiContextReference(
            id: 'ref-${_nextReferenceId++}',
            title: '选中文本',
            text: nextContext,
            locator: widget.locator,
            isSelection: true,
          ),
        );
      _contextRange = AiContextRange.selectedText;
      _contextTruncated = false;
      _contextNotice = null;
      _startNewThread();
      if (nextContext != oldContext) {
        _answer = '';
        _error = null;
      }
    });
  }

  /// Puts a canned question into the prompt box.
  ///
  /// The edited prompt is what gets sent, so a quick action has to replace
  /// the field, not just appear in it.
  void _fillPrompt(String prompt) {
    setState(() {
      _editedPrompt = prompt;
      _promptController.text = prompt;
      _promptController.selection = TextSelection.collapsed(
        offset: prompt.length,
      );
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
                references: _references,
                range: _contextRange,
                rangeVersion: _rangeVersion,
                truncated: _contextTruncated,
                loadingSource: _loadingContext,
                retrievalStatus: _retrievalStatus,
                canLoadSource: widget.bookPath != null,
                locationLabel: const ContextBuilder().locationLabel(
                  widget.locator,
                ),
                expanded: _contextExpanded,
                compact: embedded,
                onToggleExpand: () =>
                    setState(() => _contextExpanded = !_contextExpanded),
                onReferenceChanged: _editReference,
                onRemoveReference: _removeReference,
                onOpenReference: (reference) =>
                    _openReference(context, reference),
                onRangeChanged: _applyContextRange,
              ),
              if (_contextNotice != null) ...[
                const SizedBox(height: AppSpacing.x1),
                Text(
                  _contextNotice!,
                  style: textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              SizedBox(height: sectionGap),
              // Six outlined chips were six more boxes for six phrases that
              // only fill the prompt. Text buttons in a wrap say the same and
              // leave the box count for things that hold a value.
              Wrap(
                // Tight enough that the six stay on one line in a rail this
                // narrow; a lone word wrapping onto a second line reads as a
                // layout bug, not as a set of choices.
                spacing: AppSpacing.x1,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final action in _kPromptActions)
                    _AiPromptChip(
                      label: action.label,
                      compact: embedded,
                      onPressed: () => _fillPrompt(action.prompt),
                    ),
                  _AiPromptMoreMenu(
                    actions: _kMorePromptActions,
                    onSelected: _fillPrompt,
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
                onChanged: (value) =>
                    _editedPrompt = value.trim().isEmpty ? null : value.trim(),
                onSubmitted: (_) {
                  if (!_loading) {
                    unawaited(_ask());
                  }
                },
                decoration: InputDecoration(
                  hintText: '解释、翻译或自定义提问…',
                  isDense: embedded,
                  // The box stays: this is the one thing in the rail that
                  // really is an input. It is just not another card.
                  border: const OutlineInputBorder(),
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
        final busy = _loading || _loadingContext;
        final sendButton = FilledButton.icon(
          onPressed: busy ? null : _ask,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            _loading
                ? '生成中'
                : _loadingContext
                ? '读取中'
                : '发送',
          ),
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
    if (_loading || _loadingContext) {
      return;
    }
    final contextText = _payloadText;
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
    if (contextText.length > ContextBuilder.maxSourceChars) {
      setState(() => _error = '上下文过长，请缩短选区或改用更短范围后再发送');
      return;
    }
    // The confirmation names what is going out, not just how much: the whole
    // point of the reference list is that the reader can check it here.
    final contextDescription = [
      _contextDescription,
      for (final reference in _references)
        if (reference.text.trim().isNotEmpty) '· ${reference.label}',
    ].join('\n');
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
    // A thread is named by its first turn; every later turn in the same
    // context reuses it so the history can be regrouped.
    final threadId = _threadId ?? _newThreadId();
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
            threadId: threadId,
            history: _threadHistory,
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
        // The service mints the thread on the first turn and reuses it after,
        // so this is the one place that learns the id.
        _threadId = conversation.threadId ?? threadId;
        _history.add(AiThreadTurn(prompt: prompt, answer: conversation.answer));
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
      // The stored conversation carries one block of context; show it as a
      // single reference so the rows stay the one source of truth.
      _references
        ..clear()
        ..add(
          AiContextReference(
            id: 'ref-${_nextReferenceId++}',
            title: '上次的上下文',
            text: conversation.contextText ?? conversation.sourceText ?? '',
            locator: conversation.locator ?? widget.locator,
            isSelection: true,
          ),
        );
      _answer = conversation.answer;
      _error = null;
      _contextRange = AiContextRange.selectedText;
      _contextTruncated = false;
      _contextNotice = null;
      // Continuing a stored thread keeps its name, so the follow-up is
      // regrouped with the turns it belongs to. A conversation saved before
      // threads existed has no id; the next question starts one.
      _threadId = conversation.threadId;
      _history
        ..clear()
        ..add(
          AiThreadTurn(
            prompt: conversation.prompt,
            answer: conversation.answer,
          ),
        );
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

  /// Switches the context range and loads the text that range needs.
  ///
  /// The loaded block becomes one more reference rather than replacing the
  /// box: the reader can see exactly what is going out, drop it, or open it.
  /// Switching back to "仅选中文本" removes it and leaves the selection, which
  /// the list kept the whole time.
  Future<void> _applyContextRange(AiContextRange range) async {
    // A failed read falls back to the range the panel was already on, which
    // leaves `initialValue` unchanged — and a `FormField` would keep showing
    // the range the reader just picked. A fresh key each attempt rebuilds it
    // from `_contextRange`.
    setState(() => _rangeVersion++);
    if (_contextRange != range) {
      setState(_startNewThread);
    }
    if (!range.needsBookText) {
      setState(() {
        _contextRange = range;
        _contextTruncated = false;
        _contextNotice = null;
        // Back to the selection alone: whatever the previous range read is no
        // longer what will be sent, and leaving it in would keep sending the
        // chapter under a label that says otherwise.
        _references.removeWhere((reference) => !reference.isSelection);
      });
      return;
    }

    if (range.usesRetrieval) {
      await _loadRetrieval(range);
      return;
    }

    final path = widget.bookPath;
    if (path == null) {
      // The dropdown disables these ranges when there is no file, so this is
      // only reachable from a caller that bypassed it. Say so rather than
      // quietly sending the selection under a wider label.
      setState(() => _contextNotice = '无法读取书籍文件，已退回仅发送选中文本');
      return;
    }

    setState(() {
      _loadingContext = true;
      _contextNotice = null;
    });
    final token = ++_loadToken;
    final ContextSource? loaded;
    try {
      loaded = await _loadSource(range, path);
    } on BookUnreadableException {
      if (!mounted || token != _loadToken) return;
      await _fallBackToSelection('无法读取书籍文件，已退回仅发送选中文本');
      return;
    }
    if (!mounted || token != _loadToken) return;
    if (loaded == null) {
      // The file opened but this page or chapter has no text (a scanned page,
      // a cover image). Staying on the wide range would send the bare
      // selection under a label promising the page.
      final what = range == AiContextRange.currentPage ? '页' : '章';
      await _fallBackToSelection('这一$what没有可读文字，已退回仅发送选中文本');
      return;
    }
    final source = loaded;
    final original = source.text.trim();
    final text = const ContextBuilder().boundText(
      text: original,
      selected: _selection?.text ?? '',
    );
    setState(() {
      _loadingContext = false;
      _contextRange = range;
      _contextTruncated = text.length < original.length;
      // Replaces whatever the previous range contributed, but keeps the
      // reader's selection: the selection is the question's subject, and
      // dropping it would send the chapter alone.
      _references.removeWhere((reference) => !reference.isSelection);
      _references.add(
        AiContextReference(
          id: 'ref-${_nextReferenceId++}',
          title: source.title,
          text: text,
          locator: source.locator,
          bookTitle: source.bookTitle,
        ),
      );
    });
  }

  /// Retrieval branch of [_applyContextRange].
  ///
  /// The passages are added to the list rather than replacing it, but the
  /// selection stays first: the reader selected a passage and asked what in
  /// the book relates to it, so an answer built only from retrieved passages
  /// would be answering a different question.
  Future<void> _loadRetrieval(AiContextRange range) async {
    final query = _retrievalQuery();
    if (query.isEmpty) {
      await _fallBackToSelection('请先选中文本或输入问题，再使用${range.label}');
      return;
    }
    setState(() {
      _loadingContext = true;
      _contextNotice = null;
      _retrievalStatus = range == AiContextRange.folder
          ? '正在检索同文件夹的书籍…'
          : '正在检索全书…';
    });
    final token = ++_loadToken;

    // The reader can type a question while retrieval runs; the first pass
    // goes out immediately with what is known, and a second pass replaces the
    // references if the question then narrows or widens what is relevant.
    final outcome = await _runRetrieval(range, query);
    if (!mounted || token != _loadToken) return;
    if (outcome == null) {
      await _fallBackToSelection('无法检索书籍内容，已退回仅发送选中文本');
      return;
    }
    if (outcome.isEmpty) {
      await _fallBackToSelection(
        outcome.booksSearched == 0 ? '没有已建立索引的书籍可供检索' : '书中没有与这个问题相关的内容',
      );
      return;
    }
    _applyRetrievedReferences(range, outcome);
    // Only a question the reader actually wrote refines the search; the
    // prefilled default is an instruction for the model, not a topic.
    final prompt = _editedPrompt ?? '';
    if (prompt.isEmpty || prompt == query) {
      return;
    }
    if (mounted && token == _loadToken) {
      setState(() => _retrievalStatus = '正在按问题重新检索…');
    }
    final refined = await _runRetrieval(range, prompt);
    if (!mounted || token != _loadToken) return;
    // An empty second pass keeps the first: the question was already answered
    // by the selection query, and dropping everything because a follow-up
    // refinement found nothing would be a worse outcome than a slightly wider
    // set of passages.
    if (refined != null && !refined.isEmpty) {
      _applyRetrievedReferences(range, refined);
    }
  }

  /// Runs retrieval, reporting a failure rather than throwing into the UI.
  Future<RetrievalOutcome?> _runRetrieval(
    AiContextRange range,
    String query,
  ) async {
    try {
      return await ref
          .read(retrievalContextSourceProvider)
          .load(range: range, bookId: widget.bookId, query: query);
    } on Object {
      return null;
    }
  }

  void _applyRetrievedReferences(
    AiContextRange range,
    RetrievalOutcome outcome,
  ) {
    setState(() {
      _loadingContext = false;
      _retrievalStatus = null;
      _contextRange = range;
      _contextTruncated = false;
      // Only the passages from the previous retrieval go; the selection and
      // anything the reader added by hand stay.
      _references.removeWhere((reference) => !reference.isSelection);
      _references.addAll(outcome.references);
    });
  }

  /// The text retrieval searches with.
  ///
  /// The question when the reader has written one — they are asking something
  /// specific — and the selection otherwise, since "what in this book relates
  /// to this passage" is the workflow the panel exists for.
  ///
  /// Only what the reader typed counts, not the prefilled default. That
  /// default («解释这段内容») is an action for the model, not a description of
  /// what to look up; searching with it would return passages about explaining
  /// rather than about the passage.
  String _retrievalQuery() {
    final prompt = _editedPrompt ?? '';
    if (prompt.isNotEmpty) return prompt;
    return _selection?.text.trim() ?? '';
  }

  /// Puts the list back to just the selection, and says why.
  Future<void> _fallBackToSelection(String notice) async {
    setState(() {
      _loadingContext = false;
      _retrievalStatus = null;
      _contextRange = AiContextRange.selectedText;
      _contextTruncated = false;
      _references.removeWhere((reference) => !reference.isSelection);
    });
    if (!mounted) return;
    setState(() => _contextNotice = notice);
  }

  /// Reads the range's text, letting [BookUnreadableException] through.
  ///
  /// Swallowing it here would turn a corrupt or missing book into "this page
  /// has no text", which sends the reader looking in the wrong place.
  Future<ContextSource?> _loadSource(AiContextRange range, String path) {
    return ref
        .read(aiContextSourceProvider)
        .load(
          range: range,
          bookPath: path,
          locator: widget.locator,
          isEpub: widget.isEpub,
        );
  }

  /// Opens the passage a reference came from.
  ///
  /// Jumps inside this book are a scroll. A passage retrieved from a sibling
  /// book is a different document: the reader route takes the target locator
  /// as `extra` and opens at the same place, which is why the reference has to
  /// carry its book.
  void _openReference(BuildContext context, AiContextReference reference) {
    final locator = reference.locator;
    if (locator == null) return;
    final bookId = reference.bookId;
    if (bookId != null && bookId != widget.bookId) {
      if (!widget.embedded && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      context.go('/book/$bookId/reader', extra: locator);
      return;
    }
    widget.onJumpTo?.call(locator);
    if (!widget.embedded && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Applies an edit to the text of one reference.
  void _editReference(String id, String text) {
    setState(() {
      final index = _references.indexWhere((reference) => reference.id == id);
      if (index < 0) return;
      _references[index] = _references[index].copyWith(text: text);
    });
  }

  void _removeReference(String id) {
    setState(() {
      _startNewThread();
      _references.removeWhere((reference) => reference.id == id);
      // A range whose block the reader just dropped is no longer what is
      // being sent, so the selector must stop claiming it.
      _contextRange = AiContextRange.selectedText;
      _contextTruncated = false;
      _contextNotice = null;
    });
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
          sourceText: conversation?.sourceText ?? _payloadText,
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

/// The four that stay on one line.
///
/// A narrow rail at large text cannot hold six labels: the last two used to
/// wrap onto a second row alone, which reads as a layout fault rather than a
/// choice. These are the ones a reader reaches for most.
const _kPromptActions = <_PromptAction>[
  _PromptAction('解释', '解释这段内容'),
  _PromptAction('总结', '总结这段内容'),
  _PromptAction('提炼要点', '提炼这段内容的要点'),
  _PromptAction('翻译', '把这段内容翻译成中文'),
];

/// The rest, behind 「更多」.
///
/// `docs/02-feature-spec.md` §10.3 lists these as quick actions, so they
/// stay reachable — just not as a second row of the rail.
const _kMorePromptActions = <_PromptAction>[
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
    // A segmented pill inside a pill-shaped tab bar was two rounded boxes
    // doing one job. Flat labels over a hairline read the same and stop the
    // rail from looking like a stack of containers.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            // Selected state is a rule under the label, not a filled pill:
            // the border already under the bar is where it lands.
            bottom: BorderSide(
              color: selected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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

/// The context-range selector, sized to sit in a heading line.
///
/// A full-width outlined dropdown took a third of the card's height to show
/// one short word, and its box plus the card's box plus the chips' boxes is
/// what made the rail read as a stack of frames. This is the same control
/// (and the same `DropdownButton` semantics, reachable from a keyboard) with
/// the box reduced to the rule under the text.
final class _AiRangeDropdown extends StatelessWidget {
  const _AiRangeDropdown({
    required this.value,
    required this.enabled,
    required this.canLoadSource,
    required this.onChanged,
    super.key,
  });

  final AiContextRange value;
  final bool enabled;

  /// False when no book file is behind the panel, so ranges that read the
  /// book cannot do what their labels promise.
  final bool canLoadSource;
  final ValueChanged<AiContextRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<AiContextRange>(
      enabled: enabled,
      tooltip: '上下文范围',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final range in AiContextRange.values)
          PopupMenuItem<AiContextRange>(
            value: range,
            // Retrieval ranges read the index rather than the file, so they
            // stay available without a path; they report an empty index
            // themselves when nothing is indexed.
            enabled:
                enabled &&
                (range.usesRetrieval || canLoadSource || !range.needsBookText),
            child: Row(
              children: [
                Icon(range == value ? Icons.check : null, size: 16),
                if (range == value) const SizedBox(width: 6),
                Text(range.label),
              ],
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.9),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list of text the request will carry.
///
/// Every block is a row the reader can open, edit, or drop, and each says
/// where it came from with a way back to that place. A single editable box
/// could not show which of several blocks — eventually from several books —
/// was in play, and `AGENTS.md` requires the context to be explicit.
final class _AiContextCard extends StatelessWidget {
  const _AiContextCard({
    required this.description,
    required this.references,
    required this.range,
    required this.expanded,
    required this.onToggleExpand,
    required this.onReferenceChanged,
    required this.onRemoveReference,
    required this.onOpenReference,
    required this.onRangeChanged,
    this.locationLabel,
    this.truncated = false,
    this.rangeVersion = 0,
    this.loadingSource = false,
    this.retrievalStatus,
    this.canLoadSource = true,
    this.compact = false,
  });

  final String description;
  final List<AiContextReference> references;
  final AiContextRange range;
  final String? locationLabel;

  /// True when a block was cut to fit one request.
  final bool truncated;

  /// Changes whenever the panel tries a range, to rebuild the selector.
  final int rangeVersion;

  /// True while the page or chapter is being read off disk.
  final bool loadingSource;

  /// What retrieval is doing right now, or null when it is not running.
  final String? retrievalStatus;

  /// False when the panel has no file to read, so wide ranges cannot work.
  final bool canLoadSource;

  final bool expanded;
  final bool compact;
  final VoidCallback onToggleExpand;

  /// Applies an edit to one reference, keyed by id.
  final void Function(String id, String text) onReferenceChanged;
  final ValueChanged<String> onRemoveReference;

  /// Opens one reference. Given the whole reference, not its locator: a
  /// passage from another book has to navigate to that book first.
  final ValueChanged<AiContextReference> onOpenReference;
  final ValueChanged<AiContextRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final aiAccent = colorScheme.aiAccent;
    final visible = references
        .where((reference) => reference.text.trim().isNotEmpty)
        .toList(growable: false);
    // No card around the block. The rail is one narrow column, and a tinted,
    // bordered box holding a bordered dropdown holding bordered chips is the
    // "cards inside cards" the design system rules out. What stays is the
    // only part that has to look like a control — the range selector — and
    // the text itself; hierarchy comes from spacing and weight.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.x1 : 0,
        vertical: compact ? AppSpacing.x1 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: aiAccent,
                size: compact ? 15 : 16,
              ),
              SizedBox(width: 6),
              Text(
                // The range name used to sit in its own chip beside the title
                // and then again in the dropdown. Once, in the control that
                // changes it, is enough.
                '将发送的文本',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // Edit acts on the blocks this heading introduces, and a lone
              // button on its own row was the last thing keeping the rail a
              // stack of rows.
              _AiEditToggle(expanded: expanded, onPressed: onToggleExpand),
              const SizedBox(width: AppSpacing.x2),
              _AiRangeDropdown(
                // A FormField keeps the value from its own `didChange`, so a
                // failed read that falls back would leave the selector
                // claiming the range the panel just declined to send. The
                // version makes it rebuild from the panel's own state on
                // every attempt.
                key: ValueKey(rangeVersion),
                value: range,
                enabled: !loadingSource,
                canLoadSource: canLoadSource,
                onChanged: onRangeChanged,
              ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.x1 : AppSpacing.x2),
          // One line of plain text instead of two bordered chips: the word
          // count and the jump target are facts to read, not controls.
          Text(
            [
              description,
              if (locationLabel != null && locationLabel!.trim().isNotEmpty)
                '回跳：$locationLabel',
            ].join(' · '),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (loadingSource || retrievalStatus != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Row(
              children: [
                // A static icon rather than a spinner: the read is short,
                // and an indeterminate animation would keep any tree that
                // contains the panel from ever settling.
                Icon(Icons.hourglass_empty, size: 12, color: aiAccent),
                const SizedBox(width: AppSpacing.x1),
                Expanded(
                  child: Text(
                    retrievalStatus ?? '正在读取…',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.x1),
          if (visible.isEmpty && !loadingSource)
            Text(
              '还没有可发送的文本',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          for (final reference in visible)
            _AiReferenceRow(
              key: ValueKey(reference.id),
              reference: reference,
              expanded: expanded,
              compact: compact,
              canRemove: visible.length > 1 || !reference.isSelection,
              onChanged: (value) => onReferenceChanged(reference.id, value),
              onRemove: () => onRemoveReference(reference.id),
              onOpen: reference.locator == null
                  ? null
                  : () => onOpenReference(reference),
            ),
          if (truncated) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              '原文较长，已截取选区附近 '
              '${ContextBuilder.maxSourceChars} 字以内发送',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Turns the reference list into editable fields, from the heading line.
final class _AiEditToggle extends StatelessWidget {
  const _AiEditToggle({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: expanded ? '收起编辑' : '编辑文本',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      icon: Icon(
        expanded ? Icons.expand_less : Icons.edit_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Editable text for one reference.
///
/// Stateful so the controller outlives a rebuild: a controller built inside
/// `build` would be recreated on every keystroke and take the cursor with it.
final class _AiReferenceEditor extends StatefulWidget {
  const _AiReferenceEditor({
    required this.text,
    required this.compact,
    required this.onChanged,
    super.key,
  });

  final String text;
  final bool compact;
  final ValueChanged<String> onChanged;

  @override
  State<_AiReferenceEditor> createState() => _AiReferenceEditorState();
}

final class _AiReferenceEditorState extends State<_AiReferenceEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(covariant _AiReferenceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Take an outside change (a new range loaded) without fighting the reader
    // mid-edit: only when the text really differs.
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      minLines: widget.compact ? 2 : 3,
      maxLines: widget.compact ? 6 : 8,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurface,
        height: 1.4,
      ),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        isDense: widget.compact,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// One reference: what it is, where it came from, and its text.
final class _AiReferenceRow extends StatelessWidget {
  const _AiReferenceRow({
    required this.reference,
    required this.expanded,
    required this.compact,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    required this.onOpen,
    super.key,
  });

  final AiContextReference reference;
  final bool expanded;
  final bool compact;
  final bool canRemove;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  /// Null when the block cannot be located in the book.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = reference.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? AppSpacing.x1 : AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reference.isSelection
                    ? Icons.format_quote_outlined
                    : Icons.article_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reference.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${reference.charCount} 字',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (onOpen != null)
                IconButton(
                  tooltip: '回到这段原文',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                ),
              if (canRemove)
                IconButton(
                  tooltip: '移除这段引用',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (expanded)
            _AiReferenceEditor(
              key: ValueKey('edit-${reference.id}'),
              text: reference.text,
              compact: compact,
              onChanged: onChanged,
            )
          else
            _AiReferenceText(text: text, compact: compact),
        ],
      ),
    );
  }
}

/// The reference text, clipped to a few lines, with a way to read all of it.
///
/// A long selection was simply cut off with an ellipsis: the reader could
/// see that there was more but not what it said, and the whole point of the
/// list is that the reader checks what is about to be sent.
final class _AiReferenceText extends StatefulWidget {
  const _AiReferenceText({required this.text, required this.compact});

  final String text;
  final bool compact;

  @override
  State<_AiReferenceText> createState() => _AiReferenceTextState();
}

final class _AiReferenceTextState extends State<_AiReferenceText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface,
      height: 1.4,
      fontSize: widget.compact ? 13 : 14,
    );
    final maxLines = widget.compact ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final clipped = _isClipped(style, constraints.maxWidth, maxLines);
        if (_expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.text, style: style),
              const SizedBox(height: AppSpacing.x1),
              Align(
                alignment: Alignment.centerLeft,
                child: _AiExpandToggle(
                  label: '收起',
                  onPressed: () => setState(() => _expanded = false),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
            // Only offered when something was actually cut: a button that
            // expands nothing is noise.
            if (clipped) ...[
              const SizedBox(height: AppSpacing.x1),
              Align(
                alignment: Alignment.centerLeft,
                child: _AiExpandToggle(
                  label: '显示全文',
                  onPressed: () => setState(() => _expanded = true),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Whether the text is longer than the lines the row shows.
  bool _isClipped(TextStyle? style, double maxWidth, int maxLines) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    final clipped = painter.didExceedMaxLines;
    painter.dispose();
    return clipped;
  }
}

/// A plain text link that expands or collapses something.
final class _AiExpandToggle extends StatelessWidget {
  const _AiExpandToggle({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 28),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// The quick actions that did not fit on the rail's one line.
final class _AiPromptMoreMenu extends StatelessWidget {
  const _AiPromptMoreMenu({required this.actions, required this.onSelected});

  final List<_PromptAction> actions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: '更多快捷动作',
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<String>(
            value: action.prompt,
            child: Text(action.label),
          ),
      ],
      // An icon, not a word: 「更多」 plus the arrow took the room the four
      // main labels needed, and the row wrapped at large text.
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 8, bottom: 8),
        child: Icon(Icons.more_horiz, size: 18, color: colorScheme.primary),
      ),
    );
  }
}

final class _AiPromptChip extends StatelessWidget {
  const _AiPromptChip({
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Plain text: these fill the prompt and hold no state, so they do not
    // need to look like containers.
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 32),
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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
    // No frame around the answer: the design system asks for reading
    // typography here, and a tinted box turns a reply into another panel of
    // the rail. The 「回答」 label above already says what the text is.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? AppSpacing.x1 : 0),
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
              const SizedBox(height: AppSpacing.x1),
              // The whole card already opens the question, so a separate
              // 「载入提问」 button only repeated the tap. What is left is the
              // three things a tap cannot do.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '复制回答',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: '保存为笔记',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSaveNote,
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: '跳回原文',
                    visualDensity: VisualDensity.compact,
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
