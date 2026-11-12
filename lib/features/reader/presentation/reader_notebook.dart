import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/books/bookmark.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import '../../../domain/books/locator_excerpt.dart';
import '../application/reader_notebook_providers.dart';
import 'reader_annotation_actions.dart';
import 'reader_annotation_editor.dart';
import 'reader_bookmark_actions.dart';
import 'reader_context_empty_state.dart';

final class ReaderNotebookSheet extends ConsumerWidget {
  const ReaderNotebookSheet({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notebook',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭 Notebook',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReaderNotebookPane(
                bookId: bookId,
                onSelected: (locator) => Navigator.of(context).pop(locator),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class ReaderNotebookPane extends ConsumerWidget {
  const ReaderNotebookPane({
    required this.bookId,
    required this.onSelected,
    super.key,
  });

  final String bookId;
  final ValueChanged<ReadingLocator> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksByBookProvider(bookId));
    final annotations = ref.watch(annotationsByBookProvider(bookId));
    final notes = ref.watch(notesByBookProvider(bookId));
    if (bookmarks.isLoading || annotations.isLoading || notes.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bookmarks.hasError || annotations.hasError || notes.hasError) {
      return const Center(child: Text('无法读取 Notebook'));
    }
    return StreamBuilder<List<AiConversation>>(
      stream: ref.watch(aiConversationRepositoryProvider).watchConversations(),
      builder: (context, snapshot) {
        final entries = _buildNotebookEntries(
          bookmarks.value ?? const [],
          annotations.value ?? const [],
          notes.value ?? const [],
          (snapshot.data ?? const <AiConversation>[])
              .where((conversation) => conversation.bookId == bookId)
              .toList(growable: false),
        );
        if (entries.isEmpty) {
          return const ReaderContextEmptyState(
            icon: Icons.library_books_outlined,
            message: '这本书还没有 Notebook 条目',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x6,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) =>
              _NotebookEntryTile(entry: entries[index], onSelected: onSelected),
        );
      },
    );
  }
}

final class _NotebookEntryTile extends ConsumerWidget {
  const _NotebookEntryTile({required this.entry, required this.onSelected});

  final _NotebookEntry entry;
  final ValueChanged<ReadingLocator> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = entry.color ?? _notebookTypeColor(context, entry.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: entry.locator == null
              ? null
              : () => onSelected(entry.locator!),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: accent.withValues(alpha: 0.30)),
                  ),
                  child: Icon(entry.icon, size: 19, color: accent),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _NotebookMetaChip(label: entry.label, color: accent),
                          const SizedBox(width: AppSpacing.x2),
                          Expanded(
                            child: Text(
                              _formatNotebookTime(entry.timestamp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colorScheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (entry.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          entry.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.textSecondary),
                        ),
                      ],
                      if (entry.locator != null) ...[
                        const SizedBox(height: AppSpacing.x2),
                        _NotebookMetaChip(
                          label: entry.locator!.displayLabel,
                          color: colorScheme.primary,
                          subtle: true,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_NotebookAction>(
                  tooltip: 'Notebook 条目操作',
                  itemBuilder: (context) => _notebookMenuItems(entry),
                  onSelected: (action) => _handleNotebookAction(
                    context,
                    ref,
                    entry,
                    action,
                    onSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _NotebookMetaChip extends StatelessWidget {
  const _NotebookMetaChip({
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _NotebookEntryType { bookmark, annotation, image, note, ai }

enum _NotebookAction {
  jump,
  edit,
  note,
  deleteComment,
  copy,
  delete,
  openNotes,
}

final class _NotebookEntry {
  const _NotebookEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.source,
    this.locator,
    this.color,
    this.hasComment = false,
  });

  final _NotebookEntryType type;
  final String title;
  final String subtitle;
  final int timestamp;
  final Object source;
  final ReadingLocator? locator;
  final Color? color;
  final bool hasComment;

  String get label {
    return switch (type) {
      _NotebookEntryType.bookmark => '书签',
      _NotebookEntryType.annotation => hasComment ? '标注 · 批注' : '标注',
      // Image annotations are annotations in storage; they are listed apart
      // because a frame with no words is hard to find in a wall of text.
      _NotebookEntryType.image => hasComment ? '图片 · 批注' : '图片',
      _NotebookEntryType.note => '笔记',
      _NotebookEntryType.ai => 'AI',
    };
  }

  IconData get icon {
    return switch (type) {
      _NotebookEntryType.bookmark => Icons.bookmark_border,
      _NotebookEntryType.annotation => Icons.border_color_outlined,
      _NotebookEntryType.image => Icons.image_outlined,
      _NotebookEntryType.note => Icons.sticky_note_2_outlined,
      _NotebookEntryType.ai => Icons.auto_awesome_outlined,
    };
  }
}

List<_NotebookEntry> _buildNotebookEntries(
  List<Bookmark> bookmarks,
  List<Annotation> annotations,
  List<Note> notes,
  List<AiConversation> conversations,
) {
  final annotationIds = annotations.map((item) => item.id).toSet();
  final commentsByAnnotation = <String, Note>{
    for (final note in notes)
      if (note.noteType == NoteType.comment && note.annotationId != null)
        note.annotationId!: note,
  };
  final entries = <_NotebookEntry>[
    for (final bookmark in bookmarks)
      _NotebookEntry(
        type: _NotebookEntryType.bookmark,
        title: bookmark.title ?? bookmark.locator.displayLabel,
        subtitle: bookmark.note?.isNotEmpty == true
            ? bookmark.note!
            : bookmark.excerpt ?? bookmark.locator.displayLabel,
        timestamp: bookmark.updatedAt,
        locator: bookmark.locator,
        source: bookmark,
      ),
    for (final annotation in annotations)
      _annotationEntry(annotation, commentsByAnnotation),
    for (final note in notes)
      if (!(note.noteType == NoteType.comment &&
          note.annotationId != null &&
          annotationIds.contains(note.annotationId)))
        _NotebookEntry(
          type: _NotebookEntryType.note,
          title: note.title?.isNotEmpty == true ? note.title! : '无标题笔记',
          subtitle: note.sourceText?.isNotEmpty == true
              ? note.sourceText!
              : note.content,
          timestamp: note.updatedAt,
          locator: note.locator,
          source: note,
        ),
    for (final conversation in conversations)
      _NotebookEntry(
        type: _NotebookEntryType.ai,
        title: conversation.prompt,
        subtitle: conversation.answer,
        timestamp: conversation.createdAt,
        locator: conversation.locator,
        source: conversation,
      ),
  ];
  entries.sort((a, b) {
    final aKey = _notebookLocatorSortKey(a.locator);
    final bKey = _notebookLocatorSortKey(b.locator);
    if (aKey != null && bKey != null && aKey != bKey) {
      return aKey.compareTo(bKey);
    }
    if (aKey != null && bKey == null) {
      return -1;
    }
    if (aKey == null && bKey != null) {
      return 1;
    }
    return b.timestamp.compareTo(a.timestamp);
  });
  return entries;
}

_NotebookEntry _annotationEntry(
  Annotation annotation,
  Map<String, Note> commentsByAnnotation,
) {
  final comment = commentsByAnnotation[annotation.id];
  final hasComment = comment != null && comment.content.trim().isNotEmpty;
  return _NotebookEntry(
    type: annotation.target == AnnotationTarget.image
        ? _NotebookEntryType.image
        : _NotebookEntryType.annotation,
    // An image annotation often has no caption, and an entry titled '' is
    // a blank row: name it by position instead, which is what the reader
    // would say out loud anyway.
    title: annotation.selectedText.isNotEmpty
        ? annotation.selectedText
        : annotation.target == AnnotationTarget.image
        ? '图片 · ${annotation.locator.displayLabel}'
        : annotation.selectedText,
    subtitle: hasComment
        ? comment.content
        : annotation.target == AnnotationTarget.image
        ? (annotation.selectedText.isNotEmpty
              ? annotation.locator.displayLabel
              : '没有图注')
        : annotation.locator.displayLabel,
    timestamp: hasComment ? comment.updatedAt : annotation.updatedAt,
    locator: annotation.locator,
    source: annotation,
    color: readerAnnotationColor(annotation.color),
    hasComment: hasComment,
  );
}

double? _notebookLocatorSortKey(ReadingLocator? locator) {
  if (locator == null) {
    return null;
  }
  return switch (locator.type) {
    ReadingLocatorType.pdf => (locator.page ?? 1).toDouble(),
    ReadingLocatorType.epub || ReadingLocatorType.markdown =>
      ((locator.chapterIndex ?? 0) * 1000000000 + (locator.chapterOffset ?? 0))
          .toDouble(),
  };
}

Color _notebookTypeColor(BuildContext context, _NotebookEntryType type) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (type) {
    _NotebookEntryType.bookmark => colorScheme.statusWarning,
    _NotebookEntryType.annotation => colorScheme.primary,
    _NotebookEntryType.image => colorScheme.statusInfo,
    _NotebookEntryType.note => colorScheme.statusInfo,
    _NotebookEntryType.ai => colorScheme.aiAccent,
  };
}

List<PopupMenuEntry<_NotebookAction>> _notebookMenuItems(_NotebookEntry entry) {
  return [
    PopupMenuItem(
      value: _NotebookAction.jump,
      enabled: entry.locator != null,
      child: const ListTile(
        dense: true,
        leading: Icon(Icons.near_me_outlined),
        title: Text('跳回原文'),
      ),
    ),
    if (entry.type == _NotebookEntryType.bookmark)
      const PopupMenuItem(
        value: _NotebookAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_note_outlined),
          title: Text('编辑备注'),
        ),
      ),
    if (entry.type == _NotebookEntryType.annotation ||
        entry.type == _NotebookEntryType.image)
      const PopupMenuItem(
        value: _NotebookAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.palette_outlined),
          title: Text('修改样式'),
        ),
      ),
    if (entry.type == _NotebookEntryType.annotation ||
        entry.type == _NotebookEntryType.image ||
        entry.type == _NotebookEntryType.ai)
      PopupMenuItem(
        value: _NotebookAction.note,
        child: ListTile(
          dense: true,
          leading: Icon(
            entry.type == _NotebookEntryType.ai
                ? Icons.note_add_outlined
                : Icons.add_comment_outlined,
          ),
          title: Text(
            entry.type == _NotebookEntryType.ai ? '保存为笔记' : '添加/编辑批注',
          ),
        ),
      ),
    if ((entry.type == _NotebookEntryType.annotation ||
            entry.type == _NotebookEntryType.image) &&
        entry.hasComment)
      const PopupMenuItem(
        value: _NotebookAction.deleteComment,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_sweep_outlined),
          title: Text('删除批注'),
        ),
      ),
    if (entry.type == _NotebookEntryType.note)
      const PopupMenuItem(
        value: _NotebookAction.openNotes,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.open_in_new),
          title: Text('打开笔记页'),
        ),
      ),
    const PopupMenuItem(
      value: _NotebookAction.copy,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.copy_outlined),
        title: Text('复制内容'),
      ),
    ),
    if (entry.type != _NotebookEntryType.ai)
      const PopupMenuItem(
        value: _NotebookAction.delete,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline),
          title: Text('删除'),
        ),
      ),
  ];
}

Future<void> _handleNotebookAction(
  BuildContext context,
  WidgetRef ref,
  _NotebookEntry entry,
  _NotebookAction action,
  ValueChanged<ReadingLocator> onSelected,
) async {
  switch (action) {
    case _NotebookAction.jump:
      final locator = entry.locator;
      if (locator != null) {
        final fallback = switch (entry.source) {
          final Note note => note.sourceText,
          final Annotation annotation => annotation.selectedText,
          final Bookmark bookmark => bookmark.excerpt ?? bookmark.note,
          final AiConversation conversation =>
            conversation.sourceText ?? conversation.contextText,
          _ => entry.subtitle,
        };
        onSelected(enrichLocatorForJump(locator, fallbackExcerpt: fallback));
      }
    case _NotebookAction.edit:
      switch (entry.source) {
        case final Bookmark bookmark:
          await editReaderBookmarkNote(context, ref, bookmark);
        case final Annotation annotation:
          await editReaderAnnotation(context, ref, annotation);
      }
    case _NotebookAction.note:
      switch (entry.source) {
        case final Annotation annotation:
          await editReaderAnnotationComment(context, ref, annotation);
        case final AiConversation conversation:
          await _saveNotebookAiAsNote(context, ref, conversation);
      }
    case _NotebookAction.deleteComment:
      final annotation = entry.source;
      if (annotation is Annotation) {
        await deleteReaderAnnotationComment(context, ref, annotation);
      }
    case _NotebookAction.copy:
      await Clipboard.setData(ClipboardData(text: entry.subtitle));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制内容')));
      }
    case _NotebookAction.delete:
      switch (entry.source) {
        case final Bookmark bookmark:
          await deleteReaderBookmarkWithUndo(context, ref, bookmark);
        case final Annotation annotation:
          await deleteReaderAnnotation(context, ref, annotation);
        case final Note note:
          await _deleteNotebookNote(context, ref, note);
      }
    case _NotebookAction.openNotes:
      context.go('/notes');
  }
}

Future<void> _saveNotebookAiAsNote(
  BuildContext context,
  WidgetRef ref,
  AiConversation conversation,
) async {
  final note = await ref
      .read(noteRepositoryProvider)
      .saveNote(
        bookId: conversation.bookId,
        title: conversation.prompt,
        content: conversation.answer,
        sourceText: conversation.sourceText ?? conversation.contextText,
        locator: conversation.locator,
        noteType: NoteType.ai,
      );
  await ref
      .read(aiConversationRepositoryProvider)
      .linkNote(conversationId: conversation.id, noteId: note.id);
  if (conversation.bookId != null) {
    ref.invalidate(notesByBookProvider(conversation.bookId!));
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存为笔记'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

Future<void> _deleteNotebookNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除笔记？'),
      content: const Text('删除后不会影响书籍原文和已有标注。'),
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
  if (confirmed != true) {
    return;
  }
  await ref.read(noteRepositoryProvider).deleteNote(note.id);
  if (note.bookId != null) {
    ref.invalidate(notesByBookProvider(note.bookId!));
  }
}

String _formatNotebookTime(int millis) {
  final value = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
