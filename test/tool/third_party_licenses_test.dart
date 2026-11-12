import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/generate_third_party_licenses.dart' as licenses;

void main() {
  test('license discovery includes supplemental upstream notices', () async {
    final root = await Directory.systemTemp.createTemp('pagesage-licenses-');
    addTearDown(() => root.delete(recursive: true));
    for (final filename in [
      'LICENSE',
      'LICENSE-other.md',
      'NOTICE-upstream',
      'README.md',
    ]) {
      await File('${root.path}/$filename').writeAsString('example');
    }
    expect(licenses.findLicenseFiles(root), [
      'LICENSE',
      'LICENSE-other.md',
      'NOTICE-upstream',
    ]);
  });

  test('release manifest collects project, font and archive notices', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    final paths = [
      'NOTICE',
      'assets/fonts/licenses/LXGWWenKaiLite-OFL.txt',
      'assets/fonts/licenses/AtkinsonHyperlegible-OFL.txt',
      'assets/licenses/archive-LICENSE-other.txt',
    ];
    for (final path in paths) {
      expect(manifest, contains('    - $path\n'));
      expect(
        File(path).readAsStringSync().split('\n\n').length,
        greaterThan(1),
      );
    }
    expect(
      File('LICENSE').readAsStringSync(),
      contains('Version 2.0, January 2004'),
    );
  });
}
