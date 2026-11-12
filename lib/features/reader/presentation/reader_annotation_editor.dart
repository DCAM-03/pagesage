import 'package:flutter/material.dart';

import '../../../domain/annotations/annotation.dart';

Future<ReaderAnnotationEditorResult?> showReaderAnnotationEditor(
  BuildContext context, {
  required String initialText,
  AnnotationColor initialColor = AnnotationColor.yellow,
  AnnotationStyle initialStyle = AnnotationStyle.highlight,
  bool textEditable = true,
}) async {
  var selectedText = initialText;
  var color = initialColor;
  var style = initialStyle;
  final result = await showDialog<ReaderAnnotationEditorResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(textEditable ? '添加标注' : '修改标注样式'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: initialText,
                onChanged: (value) => selectedText = value,
                minLines: 3,
                maxLines: 8,
                readOnly: !textEditable,
                decoration: const InputDecoration(
                  labelText: '原文',
                  helperText: 'EPUB 中能匹配到的文本会被高亮显示',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('颜色', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AnnotationColor.values
                    .map((value) {
                      return ChoiceChip(
                        selected: color == value,
                        avatar: CircleAvatar(
                          backgroundColor: readerAnnotationColor(value),
                        ),
                        label: Text(_annotationColorLabel(value)),
                        onSelected: (_) => setDialogState(() => color = value),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text('样式', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<AnnotationStyle>(
                segments: const [
                  ButtonSegment(
                    value: AnnotationStyle.highlight,
                    label: Text('高亮'),
                    icon: Icon(Icons.format_color_fill_outlined),
                  ),
                  ButtonSegment(
                    value: AnnotationStyle.underline,
                    label: Text('下划线'),
                    icon: Icon(Icons.format_underlined),
                  ),
                ],
                selected: {style},
                onSelectionChanged: (values) {
                  setDialogState(() => style = values.single);
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
            onPressed: () => Navigator.of(context).pop(
              ReaderAnnotationEditorResult(
                selectedText: selectedText,
                color: color,
                style: style,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  return result;
}

final class ReaderAnnotationEditorResult {
  const ReaderAnnotationEditorResult({
    required this.selectedText,
    required this.color,
    required this.style,
  });

  final String selectedText;
  final AnnotationColor color;
  final AnnotationStyle style;
}

Color readerAnnotationColor(AnnotationColor color) {
  return switch (color) {
    AnnotationColor.yellow => const Color(0xFFFFD85A),
    AnnotationColor.blue => const Color(0xFF7CB7FF),
    AnnotationColor.green => const Color(0xFF74D18A),
    AnnotationColor.red => const Color(0xFFFF8A8A),
    AnnotationColor.purple => const Color(0xFFB79CFF),
  };
}

String _annotationColorLabel(AnnotationColor color) {
  return switch (color) {
    AnnotationColor.yellow => '黄色',
    AnnotationColor.blue => '蓝色',
    AnnotationColor.green => '绿色',
    AnnotationColor.red => '红色',
    AnnotationColor.purple => '紫色',
  };
}
