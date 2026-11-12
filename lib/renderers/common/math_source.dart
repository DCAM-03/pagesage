import 'package:flutter_math_fork/tex.dart';

/// A math expression that the local TeX renderer can parse.
final class MathSource {
  const MathSource._(this.expression);

  factory MathSource(String source) =>
      MathSource._(normalizeMathSource(source));

  final String expression;

  bool get isValid {
    try {
      SyntaxTree(greenRoot: TexParser(expression, _settings).parse());
      return true;
    } on Object {
      return false;
    }
  }

  static final TexParserSettings _settings = TexParserSettings(
    strict: Strict.ignore,
  );
}

/// Repairs the TeX shorthand common in Markdown notes before rendering.
String normalizeMathSource(String source) {
  var text = source.trim();
  text = _stripDelimiters(text);
  text = text.replaceAllMapped(
    RegExp(r'\\(frac|dfrac|tfrac|binom|sqrt)\s*([0-9a-zA-Z])\s*([0-9a-zA-Z])'),
    (match) => '\\${match.group(1)}{${match.group(2)}}{${match.group(3)}}',
  );
  text = text.replaceAllMapped(
    RegExp(r'\\(frac|dfrac|tfrac|binom)\s*([0-9a-zA-Z])\s*(?=\})'),
    (match) => '\\${match.group(1)}{${match.group(2)}}',
  );
  text = text.replaceAllMapped(
    RegExp(r'\\(frac|dfrac|tfrac|binom)\s*([0-9a-zA-Z])\s*\{'),
    (match) => '\\${match.group(1)}{${match.group(2)}}{',
  );
  text = text.replaceAllMapped(
    RegExp(r'\\(sqrt)\s*([0-9a-zA-Z])(?!\s*[{\[]})'),
    (match) => '\\sqrt{${match.group(2)}}',
  );
  return text.trim();
}

String _stripDelimiters(String source) {
  var text = source;
  for (final delimiter in const <String>[
    r'$$',
    r'\[',
    r'\]',
    r'\(',
    r'\)',
    r'$',
  ]) {
    if (text.startsWith(delimiter)) {
      text = text.substring(delimiter.length);
    }
    if (text.endsWith(delimiter)) {
      text = text.substring(0, text.length - delimiter.length);
    }
  }
  return text;
}
