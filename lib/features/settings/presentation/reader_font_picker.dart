import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../domain/books/reader_fonts.dart';

final class ReaderFontPicker extends StatefulWidget {
  const ReaderFontPicker({
    required this.fontFamily,
    required this.onChanged,
    super.key,
  });

  final String fontFamily;
  final ValueChanged<String> onChanged;

  @override
  State<ReaderFontPicker> createState() => _ReaderFontPickerState();
}

final class _ReaderFontPickerState extends State<ReaderFontPicker> {
  late bool _editingCustom = _isCustomFont;
  late final _controller = TextEditingController(
    text: _isCustomFont ? widget.fontFamily.trim() : '',
  );

  bool get _isCustomFont => !ReaderFonts.options.any(
    (font) => font.id == ReaderFonts.resolve(widget.fontFamily).id,
  );

  @override
  void didUpdateWidget(covariant ReaderFontPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontFamily != widget.fontFamily) {
      _editingCustom = _isCustomFont;
      _controller.text = _isCustomFont ? widget.fontFamily.trim() : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final font = ReaderFonts.resolve(widget.fontFamily);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阅读字体',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            for (final option in ReaderFonts.options)
              ChoiceChip(
                label: Text(option.label),
                selected: font.id == option.id,
                onSelected: (_) {
                  setState(() => _editingCustom = false);
                  _controller.clear();
                  if (widget.fontFamily != option.id) {
                    widget.onChanged(option.id);
                  }
                },
              ),
            ChoiceChip(
              label: const Text('自定义'),
              selected: _isCustomFont,
              onSelected: (_) => setState(() => _editingCustom = true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          '当前：${font.label} · ${font.description}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_editingCustom) ...[
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: '自定义字体名称',
              hintText: '例如 Noto Serif CJK SC',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyCustomFont(),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            '输入本机已安装的字体名称，留空恢复系统默认；应用后生效。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          TextButton(onPressed: _applyCustomFont, child: const Text('应用字体')),
        ],
        const SizedBox(height: AppSpacing.x2),
        Text(
          '用于 EPUB 和 Markdown 正文；PDF 保留文档字体。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _applyCustomFont() {
    final value = _controller.text.trim();
    if (value != widget.fontFamily) {
      widget.onChanged(value);
    }
    FocusScope.of(context).unfocus();
  }
}
