import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'math_source.dart';

/// A locally typeset TeX equation, with a readable source fallback.
final class MathView extends StatelessWidget {
  const MathView({
    required this.source,
    required this.fallback,
    required this.style,
    this.mathStyle = MathStyle.display,
    super.key,
  });

  final String source;
  final String fallback;
  final TextStyle style;
  final MathStyle mathStyle;

  @override
  Widget build(BuildContext context) {
    final mathSource = MathSource(source);
    if (!mathSource.isValid) {
      return Text(fallback, style: style);
    }
    return Math.tex(
      mathSource.expression,
      mathStyle: mathStyle,
      textStyle: style.copyWith(
        fontSize: style.fontSize,
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.normal,
      ),
      settings: TexParserSettings(strict: Strict.ignore),
      onErrorFallback: (_) => Text(fallback, style: style),
    );
  }
}

/// An inline equation that sits on the surrounding text baseline.
final class InlineMathSpan extends WidgetSpan {
  InlineMathSpan({
    required String source,
    required String fallback,
    required TextStyle style,
  }) : super(
         alignment: PlaceholderAlignment.baseline,
         baseline: TextBaseline.alphabetic,
         child: SelectionContainer.disabled(
           child: MathView(
             source: source,
             fallback: fallback,
             style: style,
             mathStyle: MathStyle.text,
           ),
         ),
       );
}

/// A centered display equation that can scroll horizontally when too wide.
final class DisplayMathView extends StatelessWidget {
  const DisplayMathView({
    required this.source,
    required this.fallback,
    required this.style,
    super.key,
  });

  final String source;
  final String fallback;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: MathView(
          source: source,
          fallback: fallback,
          style: style,
          mathStyle: MathStyle.display,
        ),
      ),
    );
  }
}
