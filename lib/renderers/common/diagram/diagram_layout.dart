import 'dart:math' as math;
import 'dart:ui';

import 'diagram_models.dart';

final class DiagramLayout {
  const DiagramLayout();

  static const String version = 'diagram-layout-v1';

  DiagramScene layout(DiagramAst diagram) => switch (diagram) {
    FlowchartDiagram() => _layoutFlowchart(diagram),
    SequenceDiagram() => _layoutSequence(diagram),
  };

  DiagramScene _layoutFlowchart(FlowchartDiagram diagram) {
    final nodeOrdinals = <String, int>{
      for (final node in diagram.nodes) node.id: node.ordinal,
    };
    final components = _stronglyConnectedComponents(diagram);
    final componentOf = <String, int>{};
    for (var index = 0; index < components.length; index += 1) {
      for (final id in components[index]) {
        componentOf[id] = index;
      }
    }
    final componentLevels = _componentLevels(
      diagram,
      components,
      componentOf,
      nodeOrdinals,
    );
    final nodeLevels = <String, int>{
      for (final node in diagram.nodes)
        node.id: componentLevels[componentOf[node.id]] ?? 0,
    };
    final grouped = <int, List<DiagramNode>>{};
    for (final node in diagram.nodes) {
      grouped.putIfAbsent(nodeLevels[node.id] ?? 0, () => []).add(node);
    }
    final horizontal = diagram.direction == DiagramDirection.leftRight;
    const nodeWidth = 150.0;
    const nodeHeight = 54.0;
    const gapX = 56.0;
    const gapY = 74.0;
    final placed = <String, DiagramNode>{};
    final levelKeys = grouped.keys.toList(growable: false)..sort();
    for (final level in levelKeys) {
      final row = grouped[level]!
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      for (var index = 0; index < row.length; index += 1) {
        final major =
            34 + level * (horizontal ? nodeWidth + gapX : nodeHeight + gapY);
        final minor =
            24 + index * (horizontal ? nodeHeight + gapY : nodeWidth + gapX);
        final rect = horizontal
            ? Rect.fromLTWH(major, minor, nodeWidth, nodeHeight)
            : Rect.fromLTWH(minor, major, nodeWidth, nodeHeight);
        placed[row[index].id] = row[index].withRect(rect);
      }
    }
    final edges = <DiagramEdge>[
      for (final edge in diagram.edges)
        edge.withPath(
          _edgePath(
            placed[edge.from]?.rect,
            placed[edge.to]?.rect,
            horizontal: horizontal,
            ordinal: edge.ordinal,
            selfLoop: edge.from == edge.to,
            backward:
                (nodeLevels[edge.to] ?? 0) <= (nodeLevels[edge.from] ?? 0),
          ),
        ),
    ];
    final rowCount = grouped.values.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final width = horizontal
        ? (levelKeys.length * (nodeWidth + gapX) + 48)
        : (rowCount * (nodeWidth + gapX) + 48);
    final height = horizontal
        ? (rowCount * (nodeHeight + gapY) + 48)
        : (levelKeys.length * (nodeHeight + gapY) + 48);
    return DiagramScene(
      kind: DiagramKind.flowchart,
      bounds: Size(width, height),
      semanticOrder: [
        '流程图，${diagram.nodes.length} 个节点，${diagram.edges.length} 条连线',
        for (final node in placed.values) '节点：${node.label}',
        for (final edge in edges)
          '连线：${placed[edge.from]?.label ?? edge.from} 到 ${placed[edge.to]?.label ?? edge.to}${edge.label.isEmpty ? '' : '，${edge.label}'}',
      ],
      flowchart: FlowchartDiagram(
        direction: diagram.direction,
        nodes: placed.values.toList(growable: false)
          ..sort((a, b) => a.ordinal.compareTo(b.ordinal)),
        edges: edges,
      ),
    );
  }

  List<Offset> _edgePath(
    Rect? from,
    Rect? to, {
    required bool horizontal,
    required int ordinal,
    required bool selfLoop,
    required bool backward,
  }) {
    if (from == null || to == null) return const [];
    if (selfLoop) {
      final channel = 28.0 + (ordinal % 3) * 12;
      if (horizontal) {
        return [
          Offset(from.center.dx - 8, from.bottom),
          Offset(from.center.dx - 8, from.bottom + channel),
          Offset(from.center.dx + 18, from.bottom + channel),
          Offset(from.center.dx + 18, from.bottom),
        ];
      }
      return [
        Offset(from.right, from.center.dy - 8),
        Offset(from.right + channel, from.center.dy - 8),
        Offset(from.right + channel, from.center.dy + 18),
        Offset(from.right, from.center.dy + 18),
      ];
    }
    if (backward) {
      final channel = 26.0 + (ordinal % 4) * 10;
      if (horizontal) {
        final y = math.max(from.bottom, to.bottom) + channel;
        return [
          Offset(from.center.dx, from.bottom),
          Offset(from.center.dx, y),
          Offset(to.center.dx, y),
          Offset(to.center.dx, to.bottom),
        ];
      }
      final x = math.max(from.right, to.right) + channel;
      return [
        Offset(from.right, from.center.dy),
        Offset(x, from.center.dy),
        Offset(x, to.center.dy),
        Offset(to.right, to.center.dy),
      ];
    }
    if (horizontal) {
      return [
        Offset(from.right, from.center.dy),
        Offset(to.left, to.center.dy),
      ];
    }
    return [Offset(from.center.dx, from.bottom), Offset(to.center.dx, to.top)];
  }

  DiagramScene _layoutSequence(SequenceDiagram diagram) {
    const participantHeight = 46.0;
    const messageGap = 52.0;
    const selfMessageGap = 86.0;
    final centers = <String, double>{};
    var center = 80.0;
    double? lastRight;
    for (final participant in diagram.participants) {
      final half = _estimatedParticipantWidth(participant.label) / 2;
      if (lastRight != null) {
        center = math.max(center, lastRight + 56 + half);
      }
      centers[participant.id] = center;
      lastRight = center + half;
      center += 180;
    }
    var y = participantHeight + 38;
    final messages = <SequenceMessage>[];
    for (final message in diagram.messages) {
      messages.add(
        SequenceMessage(
          from: message.from,
          to: message.to,
          label: message.label,
          dashed: message.dashed,
          ordinal: message.ordinal,
          y: y,
        ),
      );
      y += message.from == message.to ? selfMessageGap : messageGap;
    }
    final width = centers.isEmpty
        ? 320.0
        : centers.values.reduce((a, b) => math.max(a, b)) + 110;
    final height = y + 18;
    return DiagramScene(
      kind: DiagramKind.sequence,
      bounds: Size(width, height),
      semanticOrder: [
        '时序图，${diagram.participants.length} 个参与者，${messages.length} 条消息',
        for (final participant in diagram.participants)
          '参与者：${participant.label}',
        for (final message in messages)
          '消息：${message.from} 到 ${message.to}，${message.label}',
      ],
      sequence: SequenceDiagram(
        participants: [
          for (final participant in diagram.participants)
            SequenceParticipant(
              id: participant.id,
              label: participant.label,
              ordinal: participant.ordinal,
              center: centers[participant.id] ?? 80,
            ),
        ],
        messages: messages,
      ),
    );
  }

  double _estimatedParticipantWidth(String label) {
    var width = 32.0;
    for (final rune in label.runes) {
      width += rune > 0x2E80 ? 13 : 7;
    }
    return width.clamp(110.0, 260.0);
  }

  List<List<String>> _stronglyConnectedComponents(FlowchartDiagram diagram) {
    final ids = [for (final node in diagram.nodes) node.id];
    final adjacency = <String, List<String>>{
      for (final id in ids) id: <String>[],
    };
    for (final edge in diagram.edges) {
      if (edge.from != edge.to) adjacency[edge.from]?.add(edge.to);
    }
    var index = 0;
    final indices = <String, int>{};
    final lowLinks = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final result = <List<String>>[];

    void connect(String id) {
      indices[id] = index;
      lowLinks[id] = index;
      index += 1;
      stack.add(id);
      onStack.add(id);
      for (final next in adjacency[id] ?? const <String>[]) {
        if (!indices.containsKey(next)) {
          connect(next);
          lowLinks[id] = math.min(lowLinks[id]!, lowLinks[next]!);
        } else if (onStack.contains(next)) {
          lowLinks[id] = math.min(lowLinks[id]!, indices[next]!);
        }
      }
      if (lowLinks[id] == indices[id]) {
        final component = <String>[];
        while (stack.isNotEmpty) {
          final popped = stack.removeLast();
          onStack.remove(popped);
          component.add(popped);
          if (popped == id) break;
        }
        result.add(component);
      }
    }

    for (final id in ids) {
      if (!indices.containsKey(id)) connect(id);
    }
    return result;
  }

  Map<int, int> _componentLevels(
    FlowchartDiagram diagram,
    List<List<String>> components,
    Map<String, int> componentOf,
    Map<String, int> nodeOrdinals,
  ) {
    final outgoing = <int, Set<int>>{
      for (var index = 0; index < components.length; index += 1) index: {},
    };
    final indegree = <int, int>{
      for (var index = 0; index < components.length; index += 1) index: 0,
    };
    for (final edge in diagram.edges) {
      final from = componentOf[edge.from];
      final to = componentOf[edge.to];
      if (from == null || to == null || from == to) continue;
      if (outgoing[from]!.add(to)) indegree[to] = indegree[to]! + 1;
    }
    final level = <int, int>{
      for (var index = 0; index < components.length; index += 1) index: 0,
    };
    int ordinalOf(int component) => components[component]
        .map((id) => nodeOrdinals[id] ?? 0)
        .reduce(math.min);
    final queue = [
      for (var index = 0; index < components.length; index += 1)
        if (indegree[index] == 0) index,
    ]..sort((left, right) => ordinalOf(left).compareTo(ordinalOf(right)));
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final next in outgoing[current]!) {
        level[next] = math.max(level[next]!, level[current]! + 1);
        indegree[next] = indegree[next]! - 1;
        if (indegree[next] == 0) {
          queue.add(next);
          queue.sort(
            (left, right) => ordinalOf(left).compareTo(ordinalOf(right)),
          );
        }
      }
    }
    return level;
  }
}
