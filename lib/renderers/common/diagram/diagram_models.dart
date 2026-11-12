import 'dart:ui';

enum DiagramKind { flowchart, sequence }

enum DiagramDirection { topDown, leftRight }

enum DiagramNodeShape { rectangle, rounded, diamond }

enum DiagramLineStyle { solid, dashed, thick }

enum DiagramArrow { none, end }

final class DiagramParseResult {
  const DiagramParseResult.success(this.diagram)
    : error = null,
      line = null,
      column = null;

  const DiagramParseResult.failure(this.error, {this.line, this.column})
    : diagram = null;

  final Object? diagram;
  final String? error;
  final int? line;
  final int? column;

  bool get isSuccess => diagram != null;
}

sealed class DiagramAst {
  const DiagramAst({required this.kind});

  final DiagramKind kind;
}

final class DiagramNode {
  const DiagramNode({
    required this.id,
    required this.label,
    required this.shape,
    required this.ordinal,
    this.rect = Rect.zero,
  });

  final String id;
  final String label;
  final DiagramNodeShape shape;
  final int ordinal;
  final Rect rect;

  DiagramNode withRect(Rect value) => DiagramNode(
    id: id,
    label: label,
    shape: shape,
    ordinal: ordinal,
    rect: value,
  );
}

final class DiagramEdge {
  const DiagramEdge({
    required this.from,
    required this.to,
    required this.label,
    required this.style,
    required this.arrow,
    required this.ordinal,
    this.path = const [],
  });

  final String from;
  final String to;
  final String label;
  final DiagramLineStyle style;
  final DiagramArrow arrow;
  final int ordinal;
  final List<Offset> path;

  DiagramEdge withPath(List<Offset> value) => DiagramEdge(
    from: from,
    to: to,
    label: label,
    style: style,
    arrow: arrow,
    ordinal: ordinal,
    path: value,
  );
}

final class FlowchartDiagram extends DiagramAst {
  const FlowchartDiagram({
    required this.direction,
    required this.nodes,
    required this.edges,
  }) : super(kind: DiagramKind.flowchart);

  final DiagramDirection direction;
  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;
}

final class SequenceParticipant {
  const SequenceParticipant({
    required this.id,
    required this.label,
    required this.ordinal,
    required this.center,
  });

  final String id;
  final String label;
  final int ordinal;
  final double center;
}

final class SequenceMessage {
  const SequenceMessage({
    required this.from,
    required this.to,
    required this.label,
    required this.dashed,
    required this.ordinal,
    required this.y,
  });

  final String from;
  final String to;
  final String label;
  final bool dashed;
  final int ordinal;
  final double y;
}

final class SequenceDiagram extends DiagramAst {
  const SequenceDiagram({required this.participants, required this.messages})
    : super(kind: DiagramKind.sequence);

  final List<SequenceParticipant> participants;
  final List<SequenceMessage> messages;
}

final class DiagramScene {
  const DiagramScene({
    required this.kind,
    required this.bounds,
    required this.semanticOrder,
    this.flowchart,
    this.sequence,
  });

  final DiagramKind kind;
  final Size bounds;
  final List<String> semanticOrder;
  final FlowchartDiagram? flowchart;
  final SequenceDiagram? sequence;
}
