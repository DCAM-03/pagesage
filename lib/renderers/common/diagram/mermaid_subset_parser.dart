import 'dart:math' as math;

import 'diagram_models.dart';

/// Bounded, offline Mermaid subset parser.
///
/// Anything outside the declared grammar returns a failure with line/column;
/// the caller keeps the complete source and never draws a partial graph.
final class MermaidSubsetParser {
  const MermaidSubsetParser();

  static const String version = 'mermaid-subset-v1';
  static const int maxSourceLength = 20000;
  static const int maxFlowNodes = 200;
  static const int maxFlowEdges = 400;
  static const int maxSequenceParticipants = 20;
  static const int maxSequenceMessages = 200;
  static const int maxLabelLength = 256;
  static final RegExp _htmlTag = RegExp(r'</?[A-Za-z][^>]*>');
  static final RegExp _allowedBreakTag = RegExp(
    r'</?br\s*/?>',
    caseSensitive: false,
  );

  static final RegExp _flowHeader = RegExp(
    r'^(?:flowchart|graph)\s+(TD|TB|LR)\s*$',
  );
  static final RegExp _flowEdge = RegExp(
    r'(-->|---|-\.->|==>)(?:\|([^|\n]*)\|)?',
  );
  static final RegExp _nodeToken = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]{0,63})(?:(\[|\(|\{)("(?:[^"\\]|\\.)*"|[^)\]}]*)(?:\]|\)|\}))?$',
  );
  static final RegExp _sequenceMessage = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]{0,63})\s*(->>|-->>)\s*([A-Za-z_][A-Za-z0-9_]{0,63})\s*:\s*(.*)$',
  );
  static final RegExp _participant = RegExp(
    r'^participant\s+([A-Za-z_][A-Za-z0-9_]{0,63})(?:\s+as\s+(.+))?$',
  );

  DiagramParseResult parse(String source) {
    if (source.length > maxSourceLength) {
      return const DiagramParseResult.failure('图表内容超出阅读上限');
    }
    if (source.contains('%%{')) {
      return const DiagramParseResult.failure(
        '当前版本不支持此 Mermaid 语法，已保留完整源码',
        line: 1,
        column: 1,
      );
    }
    final lines = source
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('%%'))
        .toList(growable: false);
    if (lines.isEmpty) {
      return const DiagramParseResult.failure('图表内容为空', line: 1, column: 1);
    }
    final first = lines.first;
    final unsupported = _unsupportedLine(lines);
    if (unsupported != null) {
      return DiagramParseResult.failure(
        '当前版本不支持此 Mermaid 语法，已保留完整源码',
        line: unsupported,
        column: 1,
      );
    }
    if (_flowHeader.hasMatch(first)) {
      return _parseFlowchart(first, lines.skip(1).toList());
    }
    if (first == 'sequenceDiagram') {
      return _parseSequence(lines.skip(1).toList());
    }
    if (first.startsWith('flowchart ') ||
        first.startsWith('graph ') ||
        first.contains('subgraph') ||
        first.contains('alt ') ||
        first.contains('style ') ||
        first.contains('classDef') ||
        first.contains('click ') ||
        first.contains('<') && first != 'sequenceDiagram') {
      return const DiagramParseResult.failure(
        '当前版本不支持此 Mermaid 语法，已保留完整源码',
        line: 1,
        column: 1,
      );
    }
    return const DiagramParseResult.failure(
      '无法识别的 Mermaid 图表类型',
      line: 1,
      column: 1,
    );
  }

  int? _unsupportedLine(List<String> lines) {
    final unsupported = RegExp(
      r'^(subgraph|style|classDef|class\s|click\s|linkStyle|'
      r'init|actor|note\s|autonumber|loop\s|alt\s|opt\s|par\s|'
      r'critical\s|break\s|create\s|destroy\s)',
      caseSensitive: false,
    );
    final participantBox = RegExp(
      r'^participant\b.*\bbox\b',
      caseSensitive: false,
    );
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (unsupported.hasMatch(line) || participantBox.hasMatch(line)) {
        return index + 1;
      }
      final withoutBreaks = line.replaceAll(_allowedBreakTag, '');
      if (_htmlTag.hasMatch(withoutBreaks)) {
        return index + 1;
      }
    }
    return null;
  }

  DiagramParseResult _parseFlowchart(String header, List<String> lines) {
    final direction = switch (_flowHeader.firstMatch(header)!.group(1)!) {
      'LR' => DiagramDirection.leftRight,
      _ => DiagramDirection.topDown,
    };
    final nodes = <String, DiagramNode>{};
    final explicitNodes = <String>{};
    final edges = <DiagramEdge>[];
    var ordinal = 0;
    DiagramNode nodeFor(String token, int lineNumber) {
      final match = _nodeToken.firstMatch(token.trim());
      if (match == null) {
        throw _DiagramSyntax(lineNumber, 1, '节点语法不受支持');
      }
      final id = match.group(1)!;
      final explicit = match.group(2) != null;
      final existing = nodes[id];
      if (existing != null && !explicit) return existing;
      final rawLabel = match.group(3)?.trim() ?? id;
      final label = _decodeLabel(rawLabel, lineNumber);
      final shape = switch (match.group(2)) {
        '(' => DiagramNodeShape.rounded,
        '{' => DiagramNodeShape.diamond,
        _ => DiagramNodeShape.rectangle,
      };
      if (existing != null && explicitNodes.contains(id)) {
        if (existing.label != label || existing.shape != shape) {
          throw _DiagramSyntax(lineNumber, 1, '节点重复定义且内容不一致');
        }
        return existing;
      }
      if (existing == null && nodes.length >= maxFlowNodes) {
        throw _DiagramSyntax(lineNumber, 1, '节点数量超出上限');
      }
      final node = DiagramNode(
        id: id,
        label: label,
        shape: shape,
        ordinal: existing?.ordinal ?? ordinal++,
      );
      nodes[id] = node;
      if (explicit) explicitNodes.add(id);
      return node;
    }

    try {
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
        final line = lines[lineIndex];
        final lineNumber = lineIndex + 2;
        for (final statement in _splitStatements(line)) {
          if (statement.isEmpty) continue;
          _parseFlowStatement(
            statement: statement,
            lineNumber: lineNumber,
            nodeFor: nodeFor,
            edges: edges,
          );
        }
      }
      return DiagramParseResult.success(
        FlowchartDiagram(
          direction: direction,
          nodes: nodes.values.toList(growable: false)
            ..sort((left, right) => left.ordinal.compareTo(right.ordinal)),
          edges: edges,
        ),
      );
    } on _DiagramSyntax catch (error) {
      return DiagramParseResult.failure(
        error.message,
        line: error.line,
        column: error.column,
      );
    }
  }

  void _parseFlowStatement({
    required String statement,
    required int lineNumber,
    required DiagramNode Function(String token, int lineNumber) nodeFor,
    required List<DiagramEdge> edges,
  }) {
    final matches = _flowEdge.allMatches(statement).toList();
    if (matches.isEmpty) {
      nodeFor(statement, lineNumber);
      return;
    }
    var cursor = 0;
    DiagramNode? left;
    for (var index = 0; index < matches.length; index += 1) {
      final match = matches[index];
      final leftToken = statement.substring(cursor, match.start).trim();
      if (left == null) {
        if (leftToken.isEmpty) {
          throw _DiagramSyntax(lineNumber, match.start + 1, '连线缺少起始节点');
        }
        left = nodeFor(leftToken, lineNumber);
      }
      final nextStart = index + 1 < matches.length
          ? matches[index + 1].start
          : statement.length;
      final rightToken = statement.substring(match.end, nextStart).trim();
      if (rightToken.isEmpty) {
        throw _DiagramSyntax(lineNumber, match.end + 1, '连线缺少目标节点');
      }
      final right = nodeFor(rightToken, lineNumber);
      if (edges.length >= maxFlowEdges) {
        throw _DiagramSyntax(lineNumber, 1, '连线数量超出上限');
      }
      final symbol = match.group(1)!;
      final label = _decodeLabel(match.group(2)?.trim() ?? '', lineNumber);
      edges.add(
        DiagramEdge(
          from: left.id,
          to: right.id,
          label: label,
          style: switch (symbol) {
            '-.->' => DiagramLineStyle.dashed,
            '==>' => DiagramLineStyle.thick,
            _ => DiagramLineStyle.solid,
          },
          arrow: symbol == '---' ? DiagramArrow.none : DiagramArrow.end,
          ordinal: edges.length,
        ),
      );
      left = right;
      cursor = match.end;
    }
  }

  List<String> _splitStatements(String line) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var quote = false;
    var bracketDepth = 0;
    for (var index = 0; index < line.length; index += 1) {
      final char = line[index];
      if (char == '"' && bracketDepth > 0) {
        quote = !quote;
      } else if (!quote) {
        if (char == '[' || char == '(' || char == '{') {
          bracketDepth += 1;
        } else if (char == ']' || char == ')' || char == '}') {
          bracketDepth = math.max(0, bracketDepth - 1);
        } else if (char == ';' && bracketDepth == 0) {
          final statement = buffer.toString().trim();
          if (statement.isNotEmpty) parts.add(statement);
          buffer.clear();
          continue;
        }
      }
      buffer.write(char);
    }
    final statement = buffer.toString().trim();
    if (statement.isNotEmpty) parts.add(statement);
    return parts;
  }

  DiagramParseResult _parseSequence(List<String> lines) {
    final participants = <String, SequenceParticipant>{};
    final messages = <SequenceMessage>[];
    var ordinal = 0;

    SequenceParticipant participantFor(String id, [String? alias]) {
      final existing = participants[id];
      if (existing != null) return existing;
      if (participants.length >= maxSequenceParticipants) {
        throw _DiagramSyntax(2, 1, '参与者数量超出上限');
      }
      final label = _decodeLabel(alias?.trim() ?? id, 2);
      final participant = SequenceParticipant(
        id: id,
        label: label,
        ordinal: ordinal++,
        center: 0,
      );
      participants[id] = participant;
      return participant;
    }

    try {
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        final lineNumber = index + 2;
        final participant = _participant.firstMatch(line);
        if (participant != null) {
          participantFor(participant.group(1)!, participant.group(2));
          continue;
        }
        final message = _sequenceMessage.firstMatch(line);
        if (message == null) {
          throw _DiagramSyntax(lineNumber, 1, '时序图语句不受支持');
        }
        if (messages.length >= maxSequenceMessages) {
          throw _DiagramSyntax(lineNumber, 1, '消息数量超出上限');
        }
        final from = participantFor(message.group(1)!);
        final to = participantFor(message.group(3)!);
        final label = _decodeLabel(message.group(4)!.trim(), lineNumber);
        messages.add(
          SequenceMessage(
            from: from.id,
            to: to.id,
            label: label,
            dashed: message.group(2) == '-->>',
            ordinal: messages.length,
            y: 0,
          ),
        );
      }
      final sorted = participants.values.toList(growable: false)
        ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
      final spaced = <SequenceParticipant>[
        for (var index = 0; index < sorted.length; index += 1)
          SequenceParticipant(
            id: sorted[index].id,
            label: sorted[index].label,
            ordinal: sorted[index].ordinal,
            center: 80 + index * 180.0,
          ),
      ];
      return DiagramParseResult.success(
        SequenceDiagram(participants: spaced, messages: messages),
      );
    } on _DiagramSyntax catch (error) {
      return DiagramParseResult.failure(
        error.message,
        line: error.line,
        column: error.column,
      );
    }
  }

  String _decodeLabel(String raw, int line) {
    var label = raw;
    if (label.startsWith('"') && label.endsWith('"') && label.length >= 2) {
      label = label.substring(1, label.length - 1);
    }
    label = label
        .replaceAll('#quot;', '"')
        .replaceAll('#amp;', '&')
        .replaceAllMapped(RegExp(r'#(\d+);'), (match) {
          final code = int.tryParse(match.group(1)!);
          return code == null ? match.group(0)! : String.fromCharCode(code);
        })
        .replaceAll(RegExp(r'</?br\s*/?>', caseSensitive: false), '\n');
    if (label.length > maxLabelLength) {
      throw _DiagramSyntax(line, 1, '标签长度超出上限');
    }
    if (label.contains('<')) {
      throw _DiagramSyntax(line, 1, '标签包含不支持的 HTML');
    }
    return label;
  }
}

final class _DiagramSyntax implements Exception {
  const _DiagramSyntax(this.line, this.column, this.message);

  final int line;
  final int column;
  final String message;
}
