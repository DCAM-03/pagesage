import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../core/database/database_providers.dart';
import '../../../domain/books/bookmark.dart';
import 'reader_chrome.dart';

Future<void> editReaderBookmarkNote(
  BuildContext context,
  WidgetRef ref,
  Bookmark bookmark,
) async {
  final repository = ref.read(bookmarkRepositoryProvider);
  var editedNote = bookmark.note ?? '';
  final note = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('编辑书签备注'),
      content: TextFormField(
        initialValue: bookmark.note ?? '',
        onChanged: (value) => editedNote = value,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '备注',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(editedNote),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (note == null) {
    return;
  }
  await repository.saveBookmark(
    id: bookmark.id,
    bookId: bookmark.bookId,
    locator: bookmark.locator,
    title: bookmark.title,
    note: note.trim().isEmpty ? null : note.trim(),
    excerpt: bookmark.excerpt,
  );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('书签备注已保存')));
}

Future<void> deleteReaderBookmarkWithUndo(
  BuildContext context,
  WidgetRef ref,
  Bookmark bookmark,
) async {
  final repository = ref.read(bookmarkRepositoryProvider);
  await repository.deleteBookmark(bookmark.id);
  if (!context.mounted) {
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      readerActionSnackBar(
        message: '已删除书签',
        actionLabel: '撤销',
        compact: context.appBreakpoint.isCompact,
        duration: const Duration(seconds: 5),
        onAction: () => unawaited(
          repository.saveBookmark(
            id: bookmark.id,
            bookId: bookmark.bookId,
            locator: bookmark.locator,
            title: bookmark.title,
            note: bookmark.note,
            excerpt: bookmark.excerpt,
          ),
        ),
      ),
    );
}
