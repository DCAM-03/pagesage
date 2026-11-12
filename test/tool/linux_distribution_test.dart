import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = Directory.current;

  group('Linux distribution', () {
    late Directory temporary;
    late Directory bundle;
    late Directory output;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'pagesage-distribution-',
      );
      bundle = Directory('${temporary.path}/bundle with 中文');
      output = Directory('${temporary.path}/output with 空格');
      for (final relative in [
        'lib/libapp.so',
        'lib/libflutter_linux_gtk.so',
        'lib/libsqlite3.x64.linux.so',
        'data/icudtl.dat',
        'data/flutter_assets/NOTICES.Z',
        'data/flutter_assets/assets/fonts/reader.ttf',
        'data/icons/dev.pagesage.pagesage-256.png',
      ]) {
        final file = File('${bundle.path}/$relative');
        await file.parent.create(recursive: true);
        await file.writeAsString(relative);
      }
      await _writeExecutable('${bundle.path}/pagesage', r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$LD_LIBRARY_PATH" "$@" > "$PAGESAGE_LAUNCH_CAPTURE"
''');
    });

    tearDown(() async {
      await temporary.delete(recursive: true);
    });

    Future<ProcessResult> package({
      String version = '0.2.0-beta.1+2',
      Directory? destination,
    }) {
      return Process.run(
        'bash',
        [
          '${repository.path}/tool/package_linux.sh',
          '--bundle',
          bundle.path,
          '--output-dir',
          (destination ?? output).path,
          '--version',
          version,
        ],
        environment: {'SOURCE_DATE_EPOCH': '1700000000'},
      );
    }

    Future<Directory> extract() async {
      _expectSuccess(await package());
      final extracted = Directory('${temporary.path}/extracted');
      await extracted.create();
      _expectSuccess(
        await Process.run('tar', [
          '-xzf',
          '${output.path}/pagesage-0.2.0-beta.1+2-linux-x86_64.tar.gz',
          '-C',
          extracted.path,
        ]),
      );
      return Directory(
        '${extracted.path}/pagesage-0.2.0-beta.1+2-linux-x86_64',
      );
    }

    Future<ProcessResult> install(
      Directory source,
      Directory home, {
      String? prefix,
      Map<String, String> environment = const {},
    }) {
      return Process.run(
        'bash',
        [
          '${source.path}/install.sh',
          if (prefix != null) ...['--prefix', prefix],
        ],
        environment: {
          'HOME': home.path,
          'XDG_DATA_HOME': '${home.path}/user data',
          'PAGESAGE_LAUNCH_CAPTURE': '${home.path}/unexpected-launch',
          ...environment,
        },
      );
    }

    test(
      'rejects incomplete bundles before replacing existing output',
      () async {
        await File('${bundle.path}/lib/libapp.so').delete();
        await output.create();
        final existing = File(
          '${output.path}/pagesage-0.2.0-beta.1+2-linux-x86_64.tar.gz',
        );
        await existing.writeAsString('previous archive');

        final result = await package();

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('Incomplete release bundle'));
        expect(await existing.readAsString(), 'previous archive');
      },
    );

    test('rejects bundles without the SQLite native asset', () async {
      await File('${bundle.path}/lib/libsqlite3.x64.linux.so').delete();

      final result = await package();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('SQLite native asset is missing'));
    });

    test('native asset install excludes the test runner manifest', () async {
      final cmake = await File(
        '${repository.path}/linux/CMakeLists.txt',
      ).readAsString();
      final start = cmake.indexOf('set(NATIVE_ASSETS_DIR');
      expect(start, greaterThanOrEqualTo(0));
      final end = cmake.indexOf('\n# Fully re-copy', start);
      expect(end, greaterThan(start));
      final nativeAssetInstall = cmake.substring(start, end);
      final nativeBuild = Directory('${temporary.path}/native-build');
      final nativeAssets = Directory('${nativeBuild.path}/native_assets/linux');
      await nativeAssets.create(recursive: true);
      await File(
        '${nativeAssets.path}/libsqlite3.so',
      ).writeAsString('bundled SQLite');
      await File('${nativeAssets.path}/native_assets.json').writeAsString(
        '{"native-assets":{"linux_x64":{"sqlite":["absolute","/private/build/libsqlite3.so"]}}}',
      );
      final source = Directory('${temporary.path}/cmake-source');
      final configured = Directory('${temporary.path}/cmake-build');
      final installed = Directory('${temporary.path}/cmake-installed');
      await source.create();
      await File('${source.path}/CMakeLists.txt').writeAsString(
        'cmake_minimum_required(VERSION 3.14)\n'
        'project(NativeAssetInstall NONE)\n'
        'set(PROJECT_BUILD_DIR "${nativeBuild.path}/")\n'
        'set(INSTALL_BUNDLE_LIB_DIR "${installed.path}")\n'
        '$nativeAssetInstall\n',
      );

      _expectSuccess(
        await Process.run('cmake', ['-S', source.path, '-B', configured.path]),
      );
      _expectSuccess(
        await Process.run('cmake', [
          '--install',
          configured.path,
          '--component',
          'Runtime',
        ]),
      );

      expect(
        await File('${installed.path}/libsqlite3.so').readAsString(),
        'bundled SQLite',
      );
      expect(
        await File('${installed.path}/native_assets.json').exists(),
        isFalse,
      );
    });

    test('rejects version traversal and missing option values', () async {
      final invalid = await package(version: '../../outside');
      expect(invalid.exitCode, isNot(0));
      expect(invalid.stderr, contains('Invalid version'));
      final missing = await Process.run('bash', [
        '${repository.path}/tool/package_linux.sh',
        '--version',
      ]);
      expect(missing.exitCode, isNot(0));
      expect(missing.stderr, contains('Missing value'));
      expect(await output.exists(), isFalse);
    });

    test('packages resources and a checksum without unrelated files', () async {
      await File(
        '${temporary.path}/private-database.sqlite',
      ).writeAsString('outside the application bundle');
      final source = await extract();
      final checksum = await Process.run('sha256sum', [
        '--check',
        'pagesage-0.2.0-beta.1+2-linux-x86_64.tar.gz.sha256',
      ], workingDirectory: output.path);

      _expectSuccess(checksum);
      expect(
        await File('${source.path}/data/icudtl.dat').readAsString(),
        'data/icudtl.dat',
      );
      expect(
        await File(
          '${source.path}/data/flutter_assets/assets/fonts/reader.ttf',
        ).exists(),
        isTrue,
      );
      expect(
        await File('${source.path}/BUILD_INFO.txt').readAsString(),
        contains('version=0.2.0-beta.1+2'),
      );
      for (final relative in [
        'run-pagesage',
        'install.sh',
        'README.md',
        'PRIVACY.md',
        'THIRD_PARTY_LICENSES.md',
      ]) {
        expect(
          await File('${source.path}/$relative').exists(),
          isTrue,
          reason: relative,
        );
      }
      expect(
        await File('${source.path}/private-database.sqlite').exists(),
        isFalse,
      );
    });

    test('packaging unchanged input produces identical archives', () async {
      _expectSuccess(await package());
      final other = Directory('${temporary.path}/other output');
      _expectSuccess(await package(destination: other));
      const filename = 'pagesage-0.2.0-beta.1+2-linux-x86_64.tar.gz';

      expect(
        await File('${output.path}/$filename').readAsBytes(),
        await File('${other.path}/$filename').readAsBytes(),
      );
    });

    test('rejects an output directory inside the source bundle', () async {
      final result = await package(
        destination: Directory('${bundle.path}/nested output'),
      );

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('outside the release bundle'));
    });

    test('installs standalone into a path containing spaces', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/home with 中文');

      _expectSuccess(await install(source, home));

      final target = '${home.path}/.local/opt/pagesage';
      expect(
        await File('$target/lib/libsqlite3.x64.linux.so').exists(),
        isTrue,
      );
      final desktop = File(
        '${home.path}/user data/applications/dev.pagesage.pagesage.desktop',
      );
      final entry = await desktop.readAsString();
      expect(entry, contains('Exec="$target/run-pagesage" %U'));
      expect(entry, contains('Terminal=false'));
      expect(await File('${home.path}/unexpected-launch').exists(), isFalse);
    });

    test('escapes desktop field codes and shell metacharacters', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/custom home');
      final prefix = '${home.path}/reader \$cash % "quoted"';

      _expectSuccess(await install(source, home, prefix: prefix));

      final desktop = await File(
        '${home.path}/user data/applications/dev.pagesage.pagesage.desktop',
      ).readAsString();
      expect(desktop, contains(r'\$cash %% \"quoted\"/run-pagesage" %U'));
      expect(await File('$prefix/run-pagesage').exists(), isTrue);
    });

    test('upgrades the application without touching library data', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/upgrade home');
      _expectSuccess(await install(source, home));
      final obsolete = File('${home.path}/.local/opt/pagesage/obsolete-file');
      await obsolete.writeAsString('previous version');
      final library = File('${home.path}/user data/pagesage/library.sqlite');
      await library.parent.create(recursive: true);
      await library.writeAsString('retained user database');
      await File(
        '${source.path}/BUILD_INFO.txt',
      ).writeAsString('replacement build');

      _expectSuccess(await install(source, home));

      expect(await obsolete.exists(), isFalse);
      expect(await library.readAsString(), 'retained user database');
      expect(
        await File(
          '${home.path}/.local/opt/pagesage/BUILD_INFO.txt',
        ).readAsString(),
        'replacement build',
      );
    });

    test('invalid upgrade keeps the existing installation', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/invalid upgrade home');
      _expectSuccess(await install(source, home));
      final installed = File('${home.path}/.local/opt/pagesage/BUILD_INFO.txt');
      final original = await installed.readAsString();
      await File('${source.path}/lib/libapp.so').delete();

      final result = await install(source, home);

      expect(result.exitCode, isNot(0));
      expect(await installed.readAsString(), original);
    });

    test('failed directory swap restores the previous installation', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/rollback home');
      _expectSuccess(await install(source, home));
      final installed = File('${home.path}/.local/opt/pagesage/BUILD_INFO.txt');
      final original = await installed.readAsString();
      final commands = Directory('${temporary.path}/injected commands');
      await commands.create();
      await _writeExecutable('${commands.path}/mv', r'''#!/usr/bin/env bash
set -euo pipefail
if [[ "${2:-}" == *"/.pagesage-install."* ]]; then
  exit 1
fi
exec /usr/bin/mv "$@"
''');
      await File(
        '${source.path}/BUILD_INFO.txt',
      ).writeAsString('replacement that must not persist');

      final result = await install(
        source,
        home,
        environment: {
          'PATH': '${commands.path}:${Platform.environment['PATH']}',
        },
      );

      expect(result.exitCode, isNot(0));
      expect(await installed.readAsString(), original);
      final siblings = await Directory(
        '${home.path}/.local/opt',
      ).list().toList();
      expect(
        siblings.where(
          (entry) => entry.path.split('/').last.startsWith('.pagesage-'),
        ),
        isEmpty,
      );
    });

    test('rejects installation over the user root or source bundle', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/protected home');
      await home.create();
      final marker = File('${home.path}/keep');
      await marker.writeAsString('keep');

      final overHome = await install(source, home, prefix: home.path);
      final overSource = await install(source, home, prefix: source.path);

      expect(overHome.exitCode, isNot(0));
      expect(overSource.exitCode, isNot(0));
      expect(await marker.readAsString(), 'keep');
      expect(await File('${source.path}/run-pagesage').exists(), isTrue);
    });

    test(
      'rejects a symbolic link target without replacing its contents',
      () async {
        final source = await extract();
        final home = Directory('${temporary.path}/symlink home');
        _expectSuccess(await install(source, home));
        final target = Directory('${home.path}/.local/opt/pagesage');
        final marker = File('${target.path}/BUILD_INFO.txt');
        final original = await marker.readAsString();
        final link = Link('${home.path}/linked-reader');
        await link.create(target.path);

        final result = await install(source, home, prefix: '${link.path}/');

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('symbolic link'));
        expect(await link.exists(), isTrue);
        expect(await marker.readAsString(), original);
      },
    );

    test('refuses to replace an unrelated directory', () async {
      final source = await extract();
      final home = Directory('${temporary.path}/unrelated home');
      final unrelated = Directory('${home.path}/documents');
      await unrelated.create(recursive: true);
      final marker = File('${unrelated.path}/keep.txt');
      await marker.writeAsString('unrelated document');

      final result = await install(source, home, prefix: unrelated.path);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('not a PageSage installation'));
      expect(await marker.readAsString(), 'unrelated document');
    });

    test(
      'launcher preserves paths, arguments and existing library path',
      () async {
        final source = await extract();
        final capture = File('${temporary.path}/launcher-capture');
        const arguments = ['文档 with spaces.pdf', '--flag', r'$(literal-text)'];

        final result = await Process.run(
          'bash',
          ['${source.path}/run-pagesage', ...arguments],
          workingDirectory: temporary.path,
          environment: {
            'PAGESAGE_LAUNCH_CAPTURE': capture.path,
            'LD_LIBRARY_PATH': '/existing/lib',
          },
        );

        _expectSuccess(result);
        expect(await capture.readAsLines(), [
          '${source.path}/lib:/existing/lib',
          ...arguments,
        ]);
      },
    );
  }, skip: !Platform.isLinux);
}

Future<void> _writeExecutable(String filename, String content) async {
  final file = File(filename);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
  _expectSuccess(await Process.run('chmod', ['755', filename]));
}

void _expectSuccess(ProcessResult result) {
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}
