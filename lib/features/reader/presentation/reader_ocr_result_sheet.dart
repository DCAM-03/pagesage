import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../domain/ocr/ocr_models.dart';

/// Shows recognized page text without pretending the page has a text layer.
///
/// Desktop gets a compact dialog beside the AI rail; touch layouts get a
/// bottom sheet. Both offer the same two paths: copy the words, or ask AI
/// about exactly this page. The sheet never stores anything itself.
Future<void> showReaderOcrResultSheet(
  BuildContext context, {
  required int pageNumber,
  required OcrPageResult result,
  required VoidCallback onAskAi,
}) async {
  if (context.supportsSidePanel) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('本页文本（OCR · 第 $pageNumber 页）'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _OcrPrivacyNote(),
                const SizedBox(height: AppSpacing.x2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: SelectableText(result.text),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.text));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('已复制本页文本')));
                }
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onAskAi();
              },
              child: const Text('问 AI'),
            ),
          ],
        );
      },
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本页文本（OCR · 第 $pageNumber 页）',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.x1),
              const _OcrPrivacyNote(),
              const SizedBox(height: AppSpacing.x3),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(result.text),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: result.text),
                        );
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('已复制本页文本')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('复制'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onAskAi();
                      },
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('问 AI'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

final class _OcrPrivacyNote extends StatelessWidget {
  const _OcrPrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      '文本识别在本地完成，不会上传书籍页面。',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
