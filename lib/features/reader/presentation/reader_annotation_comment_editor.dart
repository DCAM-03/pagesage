import 'package:flutter/material.dart';

Future<String?> showReaderAnnotationCommentEditor(
  BuildContext context, {
  required String selectedText,
  String? initialComment,
  String title = '添加批注',
}) async {
  var comment = initialComment ?? '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedText.trim().isNotEmpty) ...[
              Text('原文', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(
                selectedText,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              initialValue: comment,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              onChanged: (value) => comment = value,
              decoration: const InputDecoration(
                labelText: '批注',
                hintText: '写下你的理解、疑问或补充',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
          onPressed: () {
            final value = comment.trim();
            if (value.isEmpty) {
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('保存批注'),
        ),
      ],
    ),
  );
}
