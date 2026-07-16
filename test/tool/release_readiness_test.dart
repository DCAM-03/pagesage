import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive_io.dart';

const _requiredPubspecAssetDirs = [
  'assets/renderer/pdf/',
  'assets/images/brand/',
  'assets/images/empty-states/',
  'assets/images/covers/',
  'assets/images/store/',
];

const _requiredPdfRendererAssets = [
  'assets/renderer/pdf/viewer.html',
  'assets/renderer/pdf/viewer.css',
  'assets/renderer/pdf/bridge.js',
  'assets/renderer/pdf/pdf.min.js',
  'assets/renderer/pdf/pdf.worker.min.js',
];

const _requiredImageAssets = [
  'assets/images/brand/app-icon-source.svg',
  'assets/images/empty-states/library-empty.svg',
  'assets/images/covers/default.svg',
];

void main() {
  test('documentation links and release assets stay valid', () async {
    final repo = Directory.current;
    final docsDir = Directory('${repo.path}/docs');
    final markdownFiles = docsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .toList(growable: false);

    final brokenLinks = <String>[];
    final linkPattern = RegExp(r'\[[^\]]+\]\(([^)]+)\)');
    for (final file in markdownFiles) {
      final text = await file.readAsString();
      for (final match in linkPattern.allMatches(text)) {
        final target = match.group(1)!;
        if (_shouldSkipMarkdownTarget(target)) {
          continue;
        }
        final cleanTarget = target.split('#').first;
        if (cleanTarget.isEmpty) {
          continue;
        }
        final normalizedTarget = cleanTarget.replaceAll(
          '/',
          Platform.pathSeparator,
        );
        final resolved = File(
          '${file.parent.path}${Platform.pathSeparator}$normalizedTarget',
        );
        final resolvedDir = Directory(resolved.path);
        if (!await resolved.exists() && !await resolvedDir.exists()) {
          brokenLinks.add('${_relative(repo, file)} -> $target');
        }
      }
    }

    expect(brokenLinks, isEmpty);

    final pubspec = await File('${repo.path}/pubspec.yaml').readAsString();
    for (final assetDir in _requiredPubspecAssetDirs) {
      expect(pubspec, contains('- $assetDir'));
      expect(
        Directory(
          '${repo.path}/${assetDir.replaceAll('/', Platform.pathSeparator)}',
        ).existsSync(),
        isTrue,
      );
    }

    _expectAssetsExist(repo, _requiredPdfRendererAssets);
    _expectAssetsExist(repo, _requiredImageAssets);

    expect(pubspec, isNot(contains('.codex-run')));
    expect(pubspec, isNot(contains('manual-samples')));
    expect(pubspec, isNot(contains('.epub')));
    expect(pubspec, isNot(contains('.pdf')));

    final gitignore = await File('${repo.path}/.gitignore').readAsString();
    expect(gitignore, contains('.codex-run/'));
    expect(
      Directory(
        '${repo.path}/assets',
      ).listSync(recursive: true).whereType<File>().where(_isBookSample),
      isEmpty,
    );
  });

  test('generated third-party license report covers locked packages', () async {
    final repo = Directory.current;
    final report = File(
      [
        repo.path,
        'docs',
        'generated',
        'third-party-licenses.md',
      ].join(Platform.pathSeparator),
    );
    expect(report.existsSync(), isTrue);

    final reportText = await report.readAsString();
    final lockedPackages = _parseNonSdkLockedPackages(
      await File('${repo.path}/pubspec.lock').readAsLines(),
    );
    for (final package in lockedPackages) {
      expect(reportText, contains('| `$package` |'), reason: package);
    }
    expect(
      RegExp(r'[A-Za-z]:\\').hasMatch(reportText),
      isFalse,
      reason: 'license report must not include local absolute paths',
    );
    expect(
      reportText,
      isNot(contains('sk-')),
      reason: 'license report must not contain API-key-like values',
    );
  });

  test(
    'controlled UI screenshot tooling covers key responsive views',
    () async {
      final repo = Directory.current;
      final captureScript = File(
        [
          repo.path,
          'tool',
          'capture_ui_screenshots.ps1',
        ].join(Platform.pathSeparator),
      );
      final contactSheetScript = File(
        [
          repo.path,
          'tool',
          'build_ui_contact_sheet.ps1',
        ].join(Platform.pathSeparator),
      );

      expect(captureScript.existsSync(), isTrue);
      expect(contactSheetScript.existsSync(), isTrue);

      final captureText = await captureScript.readAsString();
      expect(captureText, contains('reader-pdf-desktop'));
      expect(captureText, contains('mobile-360-reader-ai-large-text'));
      expect(captureText, contains('reader-theme-paper-epub'));
      expect(captureText, contains('reader-theme-green-epub'));
      expect(captureText, contains('reader-theme-ink-epub'));
      expect(captureText, contains('reader-theme-contrast-epub'));
      expect(captureText, contains('build_ui_contact_sheet.ps1'));

      final contactSheetText = await contactSheetScript.readAsString();
      expect(contactSheetText, contains('contact-sheet.png'));
      expect(contactSheetText, contains('System.Drawing'));

      final contactSheet = File(
        [
          repo.path,
          '.codex-run',
          'ui-screenshots',
          'contact-sheet.png',
        ].join(Platform.pathSeparator),
      );
      if (contactSheet.existsSync()) {
        expect(contactSheet.lengthSync(), greaterThan(0));
      }
    },
  );

  test('icon-only controls keep explicit tooltips', () async {
    final repo = Directory.current;
    final libDir = Directory('${repo.path}${Platform.pathSeparator}lib');
    final missingTooltips = <String>[];
    final constructors = [
      RegExp(r'\bIconButton(?:\.(?!styleFrom\b)[A-Za-z]+)?\s*\('),
      RegExp(r'\bPopupMenuButton(?:<[^>\n]+>)?\s*\('),
    ];

    for (final file
        in libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final text = await file.readAsString();
      for (final pattern in constructors) {
        for (final match in pattern.allMatches(text)) {
          final call = _constructorCallText(text, match.start);
          if (call == null || call.contains('tooltip:')) {
            continue;
          }
          missingTooltips.add(
            '${_relative(repo, file)}:${_lineNumber(text, match.start)}',
          );
        }
      }
    }

    expect(missingTooltips, isEmpty);
  });

  test('Windows build outputs include packaged renderer and image assets', () {
    final repo = Directory.current;
    var checkedAnyBuild = false;
    for (final mode in ['Debug', 'Release']) {
      final buildAssets = Directory(
        [
          repo.path,
          'build',
          'windows',
          'x64',
          'runner',
          mode,
          'data',
          'flutter_assets',
        ].join(Platform.pathSeparator),
      );
      if (!buildAssets.existsSync()) {
        continue;
      }
      checkedAnyBuild = true;
      _expectAssetsExist(buildAssets, [
        ..._requiredPdfRendererAssets,
        ..._requiredImageAssets,
      ]);
      final notices = File(
        '${buildAssets.path}${Platform.pathSeparator}NOTICES.Z',
      );
      expect(notices.existsSync(), isTrue, reason: notices.path);
      expect(notices.lengthSync(), greaterThan(0), reason: notices.path);
    }
    if (!checkedAnyBuild) {
      markTestSkipped('Windows build output is not present.');
    }
  });

  test('Android debug APK includes packaged renderer and image assets', () {
    final repo = Directory.current;
    final apk = File(
      [
        repo.path,
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-debug.apk',
      ].join(Platform.pathSeparator),
    );
    if (!apk.existsSync()) {
      markTestSkipped('Android debug APK output is not present.');
      return;
    }

    _expectAndroidPackageAssets(apk);
  });

  test('Android release APK includes packaged renderer and image assets', () {
    final repo = Directory.current;
    final apk = File(
      [
        repo.path,
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-release.apk',
      ].join(Platform.pathSeparator),
    );
    if (!apk.existsSync()) {
      markTestSkipped('Android release APK output is not present.');
      return;
    }

    _expectAndroidPackageAssets(apk);
  });

  test('Android release AAB includes packaged renderer and image assets', () {
    final repo = Directory.current;
    final aab = File(
      [
        repo.path,
        'build',
        'app',
        'outputs',
        'bundle',
        'release',
        'app-release.aab',
      ].join(Platform.pathSeparator),
    );
    if (!aab.existsSync()) {
      markTestSkipped('Android release AAB output is not present.');
      return;
    }

    _expectAndroidPackageAssets(aab);
  });
}

bool _shouldSkipMarkdownTarget(String target) {
  final lower = target.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('#') ||
      lower.startsWith('file:');
}

bool _isBookSample(File file) {
  final lower = file.path.toLowerCase();
  return lower.endsWith('.epub') || lower.endsWith('.pdf');
}

void _expectAssetsExist(Directory root, Iterable<String> assets) {
  for (final asset in assets) {
    final file = File(
      '${root.path}${Platform.pathSeparator}${asset.replaceAll('/', Platform.pathSeparator)}',
    );
    expect(file.existsSync(), isTrue, reason: asset);
    expect(file.lengthSync(), greaterThan(0), reason: asset);
  }
}

void _expectAndroidPackageAssets(File packageFile) {
  final archive = ZipDecoder().decodeBytes(packageFile.readAsBytesSync());
  final entries = {for (final file in archive.files) file.name: file};
  for (final asset in [
    ..._requiredPdfRendererAssets,
    ..._requiredImageAssets,
  ]) {
    final packagePath = 'base/assets/flutter_assets/$asset';
    final entry =
        entries['assets/flutter_assets/$asset'] ?? entries[packagePath];
    expect(entry, isNotNull, reason: '${packageFile.path}: $asset');
    expect(entry!.size, greaterThan(0), reason: '${packageFile.path}: $asset');
    expect(entry.content, isA<Uint8List>(), reason: packagePath);
  }
  final notices =
      entries['assets/flutter_assets/NOTICES.Z'] ??
      entries['base/assets/flutter_assets/NOTICES.Z'];
  expect(notices, isNotNull, reason: '${packageFile.path}: NOTICES.Z');
  final noticesEntry = notices;
  if (noticesEntry == null) {
    return;
  }
  expect(
    noticesEntry.size,
    greaterThan(0),
    reason: '${packageFile.path}: NOTICES.Z',
  );
  expect(
    archive.files.where(
      (entry) =>
          entry.name.toLowerCase().endsWith('.epub') ||
          entry.name.toLowerCase().endsWith('.pdf'),
    ),
    isEmpty,
    reason: packageFile.path,
  );
}

String? _constructorCallText(String text, int start) {
  final open = text.indexOf('(', start);
  if (open < 0) {
    return null;
  }
  var depth = 0;
  for (var index = open; index < text.length; index += 1) {
    final char = text.codeUnitAt(index);
    if (char == 40) {
      depth += 1;
    } else if (char == 41) {
      depth -= 1;
      if (depth == 0) {
        return text.substring(start, index + 1);
      }
    }
  }
  return null;
}

int _lineNumber(String text, int offset) {
  var line = 1;
  for (var index = 0; index < offset && index < text.length; index += 1) {
    if (text.codeUnitAt(index) == 10) {
      line += 1;
    }
  }
  return line;
}

Set<String> _parseNonSdkLockedPackages(List<String> lines) {
  final packages = <String>{};
  String? currentName;
  String? source;

  void flush() {
    final name = currentName;
    if (name != null && source != 'sdk') {
      packages.add(name);
    }
  }

  for (final line in lines) {
    final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(line);
    if (packageMatch != null) {
      flush();
      currentName = packageMatch.group(1)!;
      source = null;
      continue;
    }
    if (currentName == null) {
      continue;
    }
    final sourceMatch = RegExp(
      r'^    source: ([A-Za-z0-9_]+)$',
    ).firstMatch(line);
    if (sourceMatch != null) {
      source = sourceMatch.group(1)!;
    }
  }
  flush();
  return packages;
}

String _relative(Directory repo, File file) {
  final root = repo.path.endsWith(Platform.pathSeparator)
      ? repo.path
      : '${repo.path}${Platform.pathSeparator}';
  return file.path.startsWith(root)
      ? file.path.substring(root.length)
      : file.path;
}
