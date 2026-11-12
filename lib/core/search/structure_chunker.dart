/// One structural run in a chapter or PDF page.
final class StructuralBlock {
  const StructuralBlock({
    required this.startOffset,
    required this.endOffset,
    required this.kind,
    this.headingLevel,
  });

  final int startOffset;
  final int endOffset;
  final StructuralBlockKind kind;
  final int? headingLevel;
}

enum StructuralBlockKind { heading, paragraph, list, code, table, quote }

/// A half-open range in the source text.
final class ChunkSpan {
  const ChunkSpan({required this.startOffset, required this.endOffset});

  final int startOffset;
  final int endOffset;

  int get length => endOffset - startOffset;
}

final class ChildChunkDraft {
  const ChildChunkDraft({
    required this.ordinal,
    required this.span,
    required this.text,
  });

  final int ordinal;
  final ChunkSpan span;
  final String text;
}

final class ParentChunkDraft {
  const ParentChunkDraft({
    required this.ordinal,
    required this.span,
    required this.text,
    required this.titlePath,
    required this.children,
  });

  final int ordinal;
  final ChunkSpan span;
  final String text;
  final String titlePath;
  final List<ChildChunkDraft> children;
}

final class StructuredChunkSet {
  const StructuredChunkSet({required this.parents});

  final List<ParentChunkDraft> parents;
}

/// Builds parent and child chunks from one chapter or physical page.
///
/// Parent boundaries follow headings first and size limits second. Children
/// never leave their parent, and every emitted span points into [text].
final class StructureAwareChunker {
  const StructureAwareChunker({
    this.parentTargetLength = 2400,
    this.parentMaxLength = 3200,
    this.childTargetLength = 900,
    this.childMaxLength = 1200,
  }) : assert(parentTargetLength > 0),
       assert(parentMaxLength >= parentTargetLength),
       assert(childTargetLength > 0),
       assert(childMaxLength >= childTargetLength),
       assert(childMaxLength <= parentMaxLength);

  final int parentTargetLength;
  final int parentMaxLength;
  final int childTargetLength;
  final int childMaxLength;

  StructuredChunkSet chunk({
    required String text,
    required String chapterTitle,
    List<StructuralBlock> blocks = const [],
  }) {
    if (text.trim().isEmpty) {
      return const StructuredChunkSet(parents: []);
    }

    final units = _unitsFor(text: text, blocks: blocks);
    if (units.isEmpty) {
      return const StructuredChunkSet(parents: []);
    }

    final baseTitle = chapterTitle.trim().isEmpty ? '正文' : chapterTitle.trim();
    var titlePath = <String>[baseTitle];
    final headingStack = <_Heading>[];
    var section = <_Unit>[];
    var parentOrdinal = 0;
    final parents = <ParentChunkDraft>[];

    void flushSection() {
      if (section.isEmpty) {
        return;
      }
      if (!section.any((unit) => unit.kind != StructuralBlockKind.heading)) {
        section = <_Unit>[];
        return;
      }
      final packed = _packSpans(
        text: text,
        units: section,
        targetLength: parentTargetLength,
        maxLength: parentMaxLength,
      );
      for (final parentUnits in packed) {
        final start = parentUnits.first.startOffset;
        final end = parentUnits.last.endOffset;
        final children = _childrenFor(text: text, units: parentUnits);
        parents.add(
          ParentChunkDraft(
            ordinal: parentOrdinal,
            span: ChunkSpan(startOffset: start, endOffset: end),
            text: text.substring(start, end),
            titlePath: titlePath.join(' › '),
            children: children,
          ),
        );
        parentOrdinal += 1;
      }
      section = <_Unit>[];
    }

    for (final original in units) {
      final unit = _trimmedUnit(text: text, unit: original);
      if (unit == null) {
        continue;
      }
      if (unit.kind == StructuralBlockKind.heading) {
        flushSection();
        final level = unit.headingLevel ?? 2;
        if (level > 1) {
          while (headingStack.isNotEmpty && headingStack.last.level >= level) {
            headingStack.removeLast();
          }
          headingStack.add(
            _Heading(
              level: level,
              title: text.substring(unit.startOffset, unit.endOffset).trim(),
            ),
          );
          titlePath = <String>[
            baseTitle,
            for (final heading in headingStack) heading.title,
          ];
        }
      }
      section.addAll(
        _splitOversizeUnit(text: text, unit: unit, maxLength: parentMaxLength),
      );
    }
    flushSection();

    return StructuredChunkSet(
      parents: List<ParentChunkDraft>.unmodifiable(parents),
    );
  }

  List<ChildChunkDraft> _childrenFor({
    required String text,
    required List<_Unit> units,
  }) {
    final packed = _packSpans(
      text: text,
      units: units,
      targetLength: childTargetLength,
      maxLength: childMaxLength,
    );
    final children = <ChildChunkDraft>[];
    for (var index = 0; index < packed.length; index += 1) {
      final group = packed[index];
      final start = group.first.startOffset;
      final end = group.last.endOffset;
      children.add(
        ChildChunkDraft(
          ordinal: index,
          span: ChunkSpan(startOffset: start, endOffset: end),
          text: text.substring(start, end),
        ),
      );
    }
    return List<ChildChunkDraft>.unmodifiable(children);
  }

  List<List<_Unit>> _packSpans({
    required String text,
    required List<_Unit> units,
    required int targetLength,
    required int maxLength,
  }) {
    final groups = <List<_Unit>>[];
    var current = <_Unit>[];

    void flush() {
      if (current.isNotEmpty) {
        groups.add(List<_Unit>.unmodifiable(current));
        current = <_Unit>[];
      }
    }

    for (final unit in units) {
      for (final part in _splitOversizeUnit(
        text: text,
        unit: unit,
        maxLength: maxLength,
      )) {
        final span = _Unit(
          startOffset: part.startOffset,
          endOffset: part.endOffset,
          kind: part.kind,
          headingLevel: part.headingLevel,
        );
        if (current.isNotEmpty) {
          final currentLength =
              current.last.endOffset - current.first.startOffset;
          final prospectiveLength = span.endOffset - current.first.startOffset;
          if (currentLength >= targetLength || prospectiveLength > maxLength) {
            flush();
          }
        }
        current.add(span);
      }
    }
    flush();

    if (groups.length >= 2) {
      final lastLength =
          groups.last.last.endOffset - groups.last.first.startOffset;
      final previous = groups[groups.length - 2];
      final mergedLength =
          groups.last.last.endOffset - previous.first.startOffset;
      if (lastLength < targetLength ~/ 3 && mergedLength <= maxLength) {
        final merged = <_Unit>[...previous, ...groups.removeLast()];
        groups[groups.length - 1] = List<_Unit>.unmodifiable(merged);
      }
    }
    return groups;
  }

  List<_Unit> _splitOversizeUnit({
    required String text,
    required _Unit unit,
    required int maxLength,
  }) {
    if (unit.length <= maxLength) {
      return <_Unit>[unit];
    }
    final parts = <_Unit>[];
    var start = unit.startOffset;
    while (start < unit.endOffset) {
      if (unit.endOffset - start <= maxLength) {
        parts.add(
          _Unit(
            startOffset: start,
            endOffset: unit.endOffset,
            kind: unit.kind,
            headingLevel: unit.headingLevel,
          ),
        );
        break;
      }
      var split = _preferredSplit(
        text: text,
        start: start,
        hardEnd: start + maxLength,
        kind: unit.kind,
      );
      if (split <= start) {
        split = _safeCodeUnitEnd(text, start, start + maxLength);
      }
      parts.add(
        _Unit(
          startOffset: start,
          endOffset: split,
          kind: unit.kind,
          headingLevel: unit.headingLevel,
        ),
      );
      start = split;
    }
    return parts;
  }

  int _preferredSplit({
    required String text,
    required int start,
    required int hardEnd,
    required StructuralBlockKind kind,
  }) {
    final minimum = start + ((hardEnd - start) ~/ 2);
    if (kind == StructuralBlockKind.code ||
        kind == StructuralBlockKind.table ||
        kind == StructuralBlockKind.list) {
      final newline = text.lastIndexOf('\n', hardEnd - 1);
      if (newline >= minimum) {
        return newline + 1;
      }
    }
    const sentenceEnds = {'。', '！', '？', '.', '!', '?', '；', ';'};
    for (var index = hardEnd - 1; index >= minimum; index -= 1) {
      if (sentenceEnds.contains(text[index])) {
        return index + 1;
      }
    }
    for (var index = hardEnd - 1; index >= minimum; index -= 1) {
      if (_isWhitespace(text.codeUnitAt(index))) {
        return index;
      }
    }
    return _safeCodeUnitEnd(text, start, hardEnd);
  }

  int _safeCodeUnitEnd(String text, int start, int end) {
    if (end <= start) {
      return end;
    }
    var safe = end;
    final unit = text.codeUnitAt(safe - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF && safe < text.length) {
      safe -= 1;
    }
    return safe > start ? safe : mathMin(start + 1, text.length);
  }

  List<_Unit> _unitsFor({
    required String text,
    required List<StructuralBlock> blocks,
  }) {
    if (blocks.isEmpty) {
      final units = <_Unit>[];
      for (final match in RegExp(
        r'\S[\s\S]*?(?=\n\s*\n+|$)',
      ).allMatches(text)) {
        final start = match.start;
        final end = match.end;
        final trimmed = _trimmedUnit(
          text: text,
          unit: _Unit(
            startOffset: start,
            endOffset: end,
            kind: StructuralBlockKind.paragraph,
          ),
        );
        if (trimmed != null) {
          units.add(trimmed);
        }
      }
      return units;
    }

    final units = <_Unit>[];
    for (final block in blocks) {
      if (block.startOffset < 0 ||
          block.endOffset > text.length ||
          block.endOffset <= block.startOffset) {
        continue;
      }
      final unit = _trimmedUnit(
        text: text,
        unit: _Unit(
          startOffset: block.startOffset,
          endOffset: block.endOffset,
          kind: block.kind,
          headingLevel: block.headingLevel,
        ),
      );
      if (unit != null) {
        units.add(unit);
      }
    }
    return units;
  }

  _Unit? _trimmedUnit({required String text, required _Unit unit}) {
    var start = unit.startOffset.clamp(0, text.length);
    var end = unit.endOffset.clamp(start, text.length);
    while (start < end && _isWhitespace(text.codeUnitAt(start))) {
      start += 1;
    }
    while (end > start && _isWhitespace(text.codeUnitAt(end - 1))) {
      end -= 1;
    }
    if (end <= start) {
      return null;
    }
    return _Unit(
      startOffset: start,
      endOffset: end,
      kind: unit.kind,
      headingLevel: unit.headingLevel,
    );
  }

  bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D ||
        codeUnit == 0x0B ||
        codeUnit == 0x0C;
  }
}

int mathMin(int first, int second) => first < second ? first : second;

final class _Unit {
  const _Unit({
    required this.startOffset,
    required this.endOffset,
    required this.kind,
    this.headingLevel,
  });

  final int startOffset;
  final int endOffset;
  final StructuralBlockKind kind;
  final int? headingLevel;

  int get length => endOffset - startOffset;
}

final class _Heading {
  const _Heading({required this.level, required this.title});

  final int level;
  final String title;
}
