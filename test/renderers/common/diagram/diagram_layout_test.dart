import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/common/diagram/diagram_layout.dart';
import 'package:pagesage/renderers/common/diagram/diagram_models.dart';
import 'package:pagesage/renderers/common/diagram/mermaid_subset_parser.dart';

void main() {
  const parser = MermaidSubsetParser();
  const layout = DiagramLayout();

  DiagramScene sceneFor(String source) {
    final result = parser.parse(source);
    expect(result.isSuccess, isTrue, reason: result.error);
    return layout.layout(result.diagram! as DiagramAst);
  }

  test('a cycle stays on one level instead of growing unbounded', () {
    final scene = sceneFor('flowchart TD\nA --> B\nB --> C\nC --> A\nC --> D');
    final nodes = scene.flowchart!.nodes;
    final byId = {for (final node in nodes) node.id: node.rect};

    expect(byId.keys, containsAll(['A', 'B', 'C', 'D']));
    expect(byId['A']!.top, closeTo(byId['B']!.top, 0.1));
    expect(byId['B']!.top, closeTo(byId['C']!.top, 0.1));
    expect(byId['D']!.top, greaterThan(byId['A']!.top));
    expect(scene.bounds.height, lessThan(1000));
  });

  test('self loops and back edges use side channels', () {
    final scene = sceneFor('flowchart TD\nA --> A\nA --> B\nB --> A');
    final self = scene.flowchart!.edges.firstWhere(
      (edge) => edge.from == 'A' && edge.to == 'A',
    );
    final back = scene.flowchart!.edges.firstWhere(
      (edge) => edge.from == 'B' && edge.to == 'A',
    );

    expect(self.path, hasLength(4));
    expect(back.path, hasLength(4));
    expect(self.path.last, isNot(self.path.first));
  });

  test('LR direction swaps the layout axis', () {
    final scene = sceneFor('flowchart LR\nA --> B\nB --> C');
    final nodes = scene.flowchart!.nodes;
    final byId = {for (final node in nodes) node.id: node.rect};

    expect(byId['A']!.left, lessThan(byId['B']!.left));
    expect(byId['B']!.left, lessThan(byId['C']!.left));
    expect(byId['A']!.top, closeTo(byId['B']!.top, 0.1));
  });

  test('sequence participants do not overlap and self messages get height', () {
    final normal = sceneFor(
      'sequenceDiagram\nparticipant A as 短\nparticipant B as 短\n'
      'A->>B: 一\nB-->>A: 二',
    );
    final self = sceneFor('sequenceDiagram\nparticipant A as 短\nA->>A: 重试');
    final centers = normal.sequence!.participants
        .map((participant) => participant.center)
        .toList();

    expect(centers[1] - centers[0], greaterThanOrEqualTo(180));
    expect(self.sequence!.messages.single.y, normal.sequence!.messages.first.y);
    expect(self.bounds.height, greaterThan(120));
    expect(
      self.bounds.height - (self.sequence!.messages.single.y + 18),
      greaterThan(50),
    );
  });

  test('Semantics order names nodes and edges', () {
    final scene = sceneFor('flowchart LR\nA[读取] -->|通过| B[完成]');

    expect(scene.semanticOrder.first, contains('流程图'));
    expect(scene.semanticOrder, contains('节点：读取'));
    expect(scene.semanticOrder, contains('节点：完成'));
    expect(scene.semanticOrder.last, contains('通过'));
  });
}
