import 'package:flutter/material.dart';

Future<ReaderExcerptDraft?> showReaderExcerptEditor(
  BuildContext context, {
  required String initialTitle,
  String? sourceText,
}) {
  var title = initialTitle;
  var content = '';
  return showDialog<ReaderExcerptDraft>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('创建摘录笔记'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sourceText?.isNotEmpty == true) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '原文摘录',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
              Text(sourceText!, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
            ],
            TextFormField(
              initialValue: initialTitle,
              onChanged: (value) => title = value,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              onChanged: (value) => content = value,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '笔记',
                helperText: '纯文本显示；可使用 **加粗**、*斜体*、`代码` 简单标记',
                border: OutlineInputBorder(),
              ),
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
            ReaderExcerptDraft(title: title.trim(), content: content.trim()),
          ),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

final class ReaderExcerptDraft {
  const ReaderExcerptDraft({required this.title, required this.content});

  final String title;
  final String content;
}
