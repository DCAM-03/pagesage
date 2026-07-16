import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'EPUB annotations stay in TextSpan flow to avoid layout shifts',
    () async {
      final source = await File(
        'lib/renderers/epub/epub_renderer_view.dart',
      ).readAsString();

      expect(
        source,
        isNot(contains('WidgetSpan(')),
        reason:
            'Annotation highlights must not wrap text in WidgetSpan because it '
            'changes inline metrics and shifts EPUB text after highlighting.',
      );
      expect(source, contains('TapGestureRecognizer'));
    },
  );
}
