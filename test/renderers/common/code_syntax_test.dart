import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/renderers/common/code_syntax.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';

void main() {
  group('CodeSyntax', () {
    test('runs stay sorted, disjoint and in chapter coordinates', () {
      const code = '// 说明\nfinal answer = 42;\nprint("完成");\n';
      final runs = const CodeSyntax().tokenize(
        code,
        language: 'dart',
        chapterOffset: 37,
      );

      var previousEnd = 37;
      for (final run in runs) {
        expect(run.start, greaterThanOrEqualTo(previousEnd));
        expect(run.end, greaterThan(run.start));
        expect(run.end, lessThanOrEqualTo(37 + code.length));
        previousEnd = run.end;
      }
      EpubCodeTokenType? typeAt(int offset) => runs
          .where((run) => run.start <= offset && offset < run.end)
          .map((run) => run.type)
          .singleOrNull;
      expect(typeAt(37), EpubCodeTokenType.comment);
      expect(typeAt(code.indexOf('final') + 37), EpubCodeTokenType.keyword);
      expect(typeAt(code.indexOf('42') + 37), EpubCodeTokenType.number);
      expect(typeAt(code.indexOf('"完成"') + 37), EpubCodeTokenType.string);
    });

    test('a string shields comment and keyword markers', () {
      const code = 'const text = "// final 99 /* nope */";\n// real\n';
      final runs = const CodeSyntax().tokenize(
        code,
        language: 'javascript',
        chapterOffset: 0,
      );

      final insideString = runs.where(
        (run) =>
            run.start <= code.indexOf('// final') &&
            run.end > code.indexOf('// final'),
      );
      expect(insideString.single.type, EpubCodeTokenType.string);
      expect(
        runs.where((run) => run.type == EpubCodeTokenType.comment),
        hasLength(1),
      );
      expect(
        runs.where((run) => run.type == EpubCodeTokenType.number),
        isEmpty,
      );
    });

    test('SQL words are matched without case sensitivity', () {
      const code = 'select count(*) from books where id = 7;';
      final runs = const CodeSyntax().tokenize(
        code,
        language: 'SQL',
        chapterOffset: 0,
      );

      expect(
        runs.where((run) => run.type == EpubCodeTokenType.keyword),
        hasLength(3),
      );
    });

    test('supported aliases and unknown languages degrade quietly', () {
      const code = 'def f(x): return x + 1\nunknown: 12 and "text"';
      final python = const CodeSyntax().tokenize(
        code,
        language: 'py',
        chapterOffset: 0,
      );
      final unknown = const CodeSyntax().tokenize(
        code,
        language: 'brainfuck',
        chapterOffset: 0,
      );

      expect(
        python.where((run) => run.type == EpubCodeTokenType.keyword),
        isNotEmpty,
      );
      expect(
        unknown.where((run) => run.type == EpubCodeTokenType.keyword),
        isEmpty,
      );
      expect(
        unknown.where((run) => run.type == EpubCodeTokenType.number),
        isNotEmpty,
      );
      expect(
        unknown.where((run) => run.type == EpubCodeTokenType.string),
        isNotEmpty,
      );
    });

    test('an unlabelled fence still gets numbers and strings', () {
      const code = 'answer = 42;\nprint("完成");';
      final runs = const CodeSyntax().tokenize(code, chapterOffset: 0);

      expect(
        runs.where((run) => run.type == EpubCodeTokenType.number),
        isNotEmpty,
      );
      expect(
        runs.where((run) => run.type == EpubCodeTokenType.string),
        isNotEmpty,
      );
      expect(
        runs.where((run) => run.type == EpubCodeTokenType.keyword),
        isEmpty,
      );
    });
  });

  group('codeSyntaxColor', () {
    for (final preset in ReaderThemePreset.values) {
      test('${preset.label} syntax colours meet WCAG AA on the code panel', () {
        final alpha = preset == ReaderThemePreset.night ? 0.10 : 0.055;
        final panel = Color.lerp(preset.background, preset.foreground, alpha)!;
        for (final type in EpubCodeTokenType.values) {
          final ratio = _contrastRatio(codeSyntaxColor(preset, type), panel);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${preset.label} ${type.name} contrast is '
                '${ratio.toStringAsFixed(2)}',
          );
        }
      });
    }
  });
}

double _contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = math.max(aLuminance, bLuminance);
  final darker = math.min(aLuminance, bLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}
