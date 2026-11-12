import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/annotations/annotation.dart';
import '../../../domain/notes/note.dart';
import '../application/reader_annotation_comment_service.dart';
import 'reader_annotation_comment_editor.dart';
import 'reader_annotation_editor.dart';

Future<void> showReaderAnnotationActions(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: FutureBuilder<Note?>(
        future: ref
            .read(readerAnnotationCommentServiceProvider)
            .commentFor(annotation),
        builder: (sheetContext, snapshot) {
          final note = snapshot.data;
          final hasComment = note != null && note.content.trim().isNotEmpty;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(
                hasComment ? '批注' : '标注',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                annotation.selectedText,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasComment) ...[
                const SizedBox(height: 16),
                Text(
                  '批注内容',
                  style: Theme.of(sheetContext).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Text(note.content),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      editReaderAnnotation(context, ref, annotation);
                    },
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('修改样式'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      editReaderAnnotationComment(context, ref, annotation);
                    },
                    icon: Icon(
                      hasComment
                          ? Icons.edit_note_outlined
                          : Icons.add_comment_outlined,
                    ),
                    label: Text(hasComment ? '编辑批注' : '添加批注'),
                  ),
                  if (hasComment)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        deleteReaderAnnotationComment(context, ref, annotation);
                      },
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('删除批注'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      deleteReaderAnnotation(context, ref, annotation);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除标注'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> editReaderAnnotationComment(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  final service = ref.read(readerAnnotationCommentServiceProvider);
  final note = await service.commentFor(annotation);
  if (!context.mounted) {
    return;
  }
  final comment = await showReaderAnnotationCommentEditor(
    context,
    selectedText: annotation.selectedText,
    initialComment: note?.content,
    title: note == null ? '添加批注' : '编辑批注',
  );
  if (comment == null || !context.mounted) {
    return;
  }
  try {
    await service.saveForAnnotation(annotation: annotation, comment: comment);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存批注失败')));
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('已保存批注'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}

Future<void> deleteReaderAnnotationComment(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  final service = ref.read(readerAnnotationCommentServiceProvider);
  final note = await service.commentFor(annotation);
  if (note == null || !context.mounted) {
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除批注？'),
      content: const Text('只删除批注，保留这条划线。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除批注'),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  try {
    await service.deleteComment(annotation);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除批注失败')));
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('已删除批注'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}

Future<void> editReaderAnnotation(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  final result = await showReaderAnnotationEditor(
    context,
    initialText: annotation.selectedText,
    initialColor: annotation.color,
    initialStyle: annotation.style,
    textEditable: false,
  );
  if (result == null) {
    return;
  }
  await ref
      .read(annotationRepositoryProvider)
      .saveAnnotation(
        id: annotation.id,
        bookId: annotation.bookId,
        locator: annotation.locator,
        selectedText: annotation.selectedText,
        color: result.color,
        style: result.style,
        imageAnchor: annotation.imageAnchor,
      );
}

Future<void> deleteReaderAnnotation(
  BuildContext context,
  WidgetRef ref,
  Annotation annotation,
) async {
  final service = ref.read(readerAnnotationCommentServiceProvider);
  final note = await service.linkedNoteFor(annotation);
  if (!context.mounted) {
    return;
  }
  final deletesComment = note?.noteType == NoteType.comment;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除标注？'),
      content: Text(
        deletesComment
            ? '删除标注会同时删除这条批注。'
            : note == null
            ? '删除后不会影响书籍原文。'
            : '只删除这条标注，关联笔记会保留。',
      ),
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
  await service.deleteAnnotation(annotation);
  final anchor = annotation.imageAnchor;
  if (anchor != null) {
    await ref
        .read(imageCacheStoreProvider)
        .delete(bookId: annotation.bookId, anchor: anchor);
  }
}
