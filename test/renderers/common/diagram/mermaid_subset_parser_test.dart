import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/common/diagram/diagram_models.dart';
import 'package:pagesage/renderers/common/diagram/mermaid_subset_parser.dart';

void main() {
  const parser = MermaidSubsetParser();

  group('supported flowchart fixtures', () {
    final fixtures = <String, String>{
      'TD edge': 'flowchart TD\nA --> B',
      'TB graph alias': 'graph TB\nA --> B',
      'LR branch': 'flowchart LR\nA --> B\nA --> C',
      'rectangle label': 'flowchart TD\nA[开始] --> B[结束]',
      'rounded label': 'flowchart TD\nA(开始) --> B(结束)',
      'diamond label': 'flowchart TD\nA{判断} --> B[完成]',
      'quoted unicode': 'flowchart LR\nA["读取 文件"] --> B["继续"]',
      'entities': 'flowchart LR\nA["a#quot;b#amp;c#65;"] --> B',
      'edge label': 'flowchart LR\nA -->|通过| B',
      'chain': 'flowchart TD\nA --> B --> C',
      'semicolons': 'flowchart TD\nA --> B; B --> C',
      'comments': 'flowchart TD\n%% comment\nA --> B',
      'isolated node': 'flowchart TD\nA[孤立]\nB --> C',
      'self loop': 'flowchart TD\nA --> A',
      'cycle': 'flowchart TD\nA --> B\nB --> A',
      'repeated edge': 'flowchart TD\nA --> B\nA --> B',
      'break tag': 'flowchart TD\nA["第一行<br/>第二行"] --> B',
      'merge': 'flowchart TD\nA --> B\nA --> C\nB --> D\nC --> D',
      'dashed edge': 'flowchart LR\nA -.-> B',
      'thick edge': 'flowchart LR\nA ==> B',
      'plain edge': 'flowchart LR\nA --- B',
    };

    for (final entry in fixtures.entries) {
      test(entry.key, () {
        final result = parser.parse(entry.value);

        expect(result.isSuccess, isTrue, reason: result.error);
        expect(result.diagram, isA<FlowchartDiagram>());
      });
    }
  });

  test('labelled nodes can be referenced by id in later edges', () {
    final result = parser.parse(
      'flowchart TD\nA[导入文件] --> B[阅读正文]\nB --> C[保存笔记]',
    );
    expect(result.isSuccess, isTrue, reason: result.error);
    final diagram = result.diagram! as FlowchartDiagram;
    expect(diagram.nodes.map((node) => node.label), ['导入文件', '阅读正文', '保存笔记']);
    expect(diagram.edges.map((edge) => (edge.from, edge.to)), [
      ('A', 'B'),
      ('B', 'C'),
    ]);
  });

  test('a forward node reference accepts its later explicit definition', () {
    final result = parser.parse('flowchart TD\nA --> B\nB{判断} --> C');
    expect(result.isSuccess, isTrue, reason: result.error);
    final diagram = result.diagram! as FlowchartDiagram;
    final node = diagram.nodes.singleWhere((node) => node.id == 'B');
    expect(node.label, '判断');
    expect(node.shape, DiagramNodeShape.diamond);
    expect(node.ordinal, 1);
    expect(diagram.nodes, hasLength(3));
  });

  test(
    'conflicting explicit node definitions still reject the whole diagram',
    () {
      final result = parser.parse('flowchart TD\nA[甲] --> B\nA[乙] --> C');
      expect(result.isSuccess, isFalse);
      expect(result.diagram, isNull);
      expect(result.error, contains('节点重复定义'));
    },
  );

  group('supported sequence fixtures', () {
    final fixtures = <String, String>{
      'explicit participants':
          'sequenceDiagram\nparticipant U as 读者\nparticipant R as 阅读器\n'
          'U->>R: 打开\nR-->>U: 恢复',
      'implicit participants': 'sequenceDiagram\nA->>B: 请求\nB-->>A: 返回',
      'self message': 'sequenceDiagram\nparticipant A\nA->>A: 重试',
      'unicode': 'sequenceDiagram\nA->>B: 中文消息\nB-->>A: 完成',
      'multiple participants': 'sequenceDiagram\nA->>B: 一\nB->>C: 二\nC-->>A: 三',
    };

    for (final entry in fixtures.entries) {
      test(entry.key, () {
        final result = parser.parse(entry.value);

        expect(result.isSuccess, isTrue, reason: result.error);
        expect(result.diagram, isA<SequenceDiagram>());
      });
    }
  });

  test('edge ordinals stay unique across chained statements', () {
    final result = parser.parse('flowchart TD\nA --> B --> C\nD --> E');
    final diagram = result.diagram! as FlowchartDiagram;

    expect(diagram.edges.map((edge) => edge.ordinal).toSet(), hasLength(3));
  });

  test('a semicolon inside a quoted label is not a statement break', () {
    final result = parser.parse('flowchart LR\nA["a;b"] --> B');

    expect(result.isSuccess, isTrue);
    final diagram = result.diagram! as FlowchartDiagram;
    expect(diagram.nodes.first.label, 'a;b');
  });

  group('unsupported and malicious fixtures', () {
    final fixtures = <String, String>{
      'subgraph': 'flowchart TD\nsubgraph one\nA --> B\nend',
      'style': 'flowchart TD\nA --> B\nstyle A fill:#f00',
      'classDef': 'flowchart TD\nclassDef big fill:#f00',
      'click': 'flowchart TD\nclick A "https://example.com"',
      'init': 'flowchart TD\n%%{init: {"theme":"dark"}}%%\nA --> B',
      'RL direction': 'flowchart RL\nA --> B',
      'HTML label': 'flowchart TD\nA["<script>alert(1)</script>"] --> B',
      'actor': 'sequenceDiagram\nactor A',
      'note': 'sequenceDiagram\nA->>B: x\nNote right of A: y',
      'autonumber': 'sequenceDiagram\nautonumber\nA->>B: x',
      'loop block': 'sequenceDiagram\nloop retry\nA->>B: x\nend',
      'broken bracket': 'flowchart TD\nA[未闭合 --> B',
      'conflicting node': 'flowchart TD\nA[甲] --> B\nA[乙] --> C',
      'unknown arrow': 'flowchart TD\nA ~~~ B',
    };

    for (final entry in fixtures.entries) {
      test(entry.key, () {
        final result = parser.parse(entry.value);

        expect(result.isSuccess, isFalse);
        expect(result.error, isNotEmpty);
      });
    }
  });

  test('node and edge limits fail without a partial diagram', () {
    final tooManyNodes = StringBuffer('flowchart TD\n');
    for (var index = 0; index <= MermaidSubsetParser.maxFlowNodes; index += 1) {
      tooManyNodes.writeln('N$index');
    }
    final nodesResult = parser.parse(tooManyNodes.toString());
    expect(nodesResult.isSuccess, isFalse);
    expect(nodesResult.diagram, isNull);
  });

  test('label longer than the budget fails', () {
    final label = List.filled(
      MermaidSubsetParser.maxLabelLength + 1,
      '长',
    ).join();
    final result = parser.parse('flowchart TD\nA["$label"] --> B');

    expect(result.isSuccess, isFalse);
    expect(result.error, contains('标签长度'));
  });
}
