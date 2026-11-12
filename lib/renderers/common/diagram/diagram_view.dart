import 'package:flutter/material.dart';

import '../../../domain/books/reader_settings.dart';
import 'diagram_layout.dart';
import 'diagram_models.dart';
import 'diagram_painter.dart';
import 'mermaid_subset_parser.dart';

final class MermaidDiagramView extends StatefulWidget {
  const MermaidDiagramView({
    required this.source,
    required this.settings,
    super.key,
  });

  final String source;
  final ReaderSettings settings;

  @override
  State<MermaidDiagramView> createState() => _MermaidDiagramViewState();
}

final class _MermaidDiagramViewState extends State<MermaidDiagramView> {
  static const MermaidSubsetParser _parser = MermaidSubsetParser();
  static const DiagramLayout _layout = DiagramLayout();

  bool _sourceMode = false;
  DiagramParseResult? _parsed;
  DiagramScene? _scene;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant MermaidDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _parse();
  }

  void _parse() {
    final parsed = _parser.parse(widget.source);
    _parsed = parsed;
    _scene = parsed.isSuccess
        ? _layout.layout(parsed.diagram! as DiagramAst)
        : null;
    if (parsed.isSuccess) _sourceMode = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = widget.settings.themePreset.foreground;
    final parsed = _parsed!;
    final scene = _scene;
    final canDraw = scene != null && parsed.isSuccess;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 640.0;
        return SizedBox(
          width: availableWidth,
          child: Semantics(
            container: true,
            label: canDraw
                ? scene.semanticOrder.join('；')
                : 'Mermaid 源码：${parsed.error ?? '无法解析'}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: availableWidth,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          !canDraw || _sourceMode ? 'Mermaid 源码' : 'Mermaid 图形',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: foreground.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                      if (canDraw)
                        IconButton(
                          tooltip: _sourceMode ? '查看图形' : '查看源码',
                          onPressed: () =>
                              setState(() => _sourceMode = !_sourceMode),
                          icon: Icon(
                            _sourceMode
                                ? Icons.account_tree_outlined
                                : Icons.code,
                          ),
                        ),
                      IconButton(
                        tooltip: '展开查看',
                        onPressed: canDraw
                            ? () => _showExpanded(context, scene, foreground)
                            : null,
                        icon: const Icon(Icons.open_in_full_outlined),
                      ),
                    ],
                  ),
                ),
                if (!canDraw)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${parsed.error ?? '无法解析图表'}（第 ${parsed.line ?? 1} 行，第 ${parsed.column ?? 1} 列）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                if (_sourceMode || !canDraw)
                  SelectableText(
                    widget.source,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'monospace',
                      fontSize: widget.settings.fontSize * 0.82,
                      height: 1.4,
                    ),
                  )
                else
                  SizedBox(
                    width: availableWidth,
                    height:
                        (scene.bounds.height *
                                (availableWidth / scene.bounds.width).clamp(
                                  0.0,
                                  1.0,
                                ))
                            .clamp(0.0, 480.0),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: scene.bounds.width,
                        height: scene.bounds.height,
                        child: CustomPaint(
                          painter: DiagramPainter(
                            scene: scene,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExpanded(
    BuildContext context,
    DiagramScene scene,
    Color foreground,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          _MermaidExpandedDialog(scene: scene, foreground: foreground),
    );
  }
}

final class _MermaidExpandedDialog extends StatefulWidget {
  const _MermaidExpandedDialog({required this.scene, required this.foreground});

  final DiagramScene scene;
  final Color foreground;

  @override
  State<_MermaidExpandedDialog> createState() => _MermaidExpandedDialogState();
}

final class _MermaidExpandedDialogState extends State<_MermaidExpandedDialog> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('展开查看 Mermaid 图形')),
                IconButton(
                  tooltip: '复位缩放',
                  onPressed: () => _controller.value = Matrix4.identity(),
                  icon: const Icon(Icons.center_focus_strong_outlined),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 0.5,
                maxScale: 3,
                child: SizedBox(
                  width: scene.bounds.width,
                  height: scene.bounds.height,
                  child: CustomPaint(
                    painter: DiagramPainter(
                      scene: scene,
                      color: widget.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
