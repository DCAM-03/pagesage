import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final repo = Directory.current;
  final lockFile = File('${repo.path}/pubspec.lock');
  final packageConfigFile = File('${repo.path}/.dart_tool/package_config.json');
  if (!lockFile.existsSync()) {
    throw StateError('pubspec.lock not found.');
  }
  if (!packageConfigFile.existsSync()) {
    throw StateError('.dart_tool/package_config.json not found. Run pub get.');
  }

  final packageRoots = readPackageRoots(packageConfigFile);
  final packages =
      parsePubspecLock(
          lockFile.readAsLinesSync(),
        ).where((package) => package.source != 'sdk').toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  final output = File('${repo.path}/docs/generated/third-party-licenses.md');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(renderLicenseReport(packages, packageRoots));
  stdout.writeln('Generated ${output.path} for ${packages.length} packages.');
}

Map<String, Directory> readPackageRoots(File packageConfigFile) {
  final json = jsonDecode(packageConfigFile.readAsStringSync());
  final packages = json['packages'] as List<dynamic>;
  return {
    for (final package in packages.cast<Map<String, dynamic>>())
      package['name'] as String: Directory.fromUri(
        Uri.parse(package['rootUri'] as String),
      ),
  };
}

List<LockedPackage> parsePubspecLock(List<String> lines) {
  final packages = <LockedPackage>[];
  String? currentName;
  String? dependency;
  String? source;
  String? version;

  void flush() {
    final name = currentName;
    if (name == null) {
      return;
    }
    packages.add(
      LockedPackage(
        name: name,
        dependency: dependency ?? '',
        source: source ?? '',
        version: version ?? '',
      ),
    );
  }

  for (final line in lines) {
    final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(line);
    if (packageMatch != null) {
      flush();
      currentName = packageMatch.group(1)!;
      dependency = null;
      source = null;
      version = null;
      continue;
    }
    if (currentName == null) {
      continue;
    }
    final dependencyMatch = RegExp(
      r'^    dependency: "?([^"]+)"?$',
    ).firstMatch(line);
    if (dependencyMatch != null) {
      dependency = dependencyMatch.group(1)!;
      continue;
    }
    final sourceMatch = RegExp(
      r'^    source: ([A-Za-z0-9_]+)$',
    ).firstMatch(line);
    if (sourceMatch != null) {
      source = sourceMatch.group(1)!;
      continue;
    }
    final versionMatch = RegExp(r'^    version: "?([^"]+)"?$').firstMatch(line);
    if (versionMatch != null) {
      version = versionMatch.group(1)!;
    }
  }
  flush();
  return packages;
}

String renderLicenseReport(
  List<LockedPackage> packages,
  Map<String, Directory> packageRoots,
) {
  final buffer = StringBuffer()
    ..writeln('# PageSage 第三方依赖许可清单')
    ..writeln()
    ..writeln('来源：`pubspec.lock`。')
    ..writeln()
    ..writeln('生成命令：`dart run tool/generate_third_party_licenses.dart`。')
    ..writeln()
    ..writeln(
      '范围：列出 `pubspec.lock` 中所有非 SDK 第三方依赖，包含运行时依赖、构建工具依赖和测试依赖；正式发布时以平台包内 Flutter `NOTICES`/`NOTICES.Z` 为许可文本来源。',
    )
    ..writeln()
    ..writeln('隐私边界：本文件不得包含 API Key、用户书籍正文、AI 请求正文、本地数据库内容或本机绝对路径。')
    ..writeln()
    ..writeln(
      '| Package | Version | Dependency | Source | Local license files |',
    )
    ..writeln('| --- | --- | --- | --- | --- |');

  for (final package in packages) {
    final licenseFiles = findLicenseFiles(packageRoots[package.name]);
    buffer.writeln(
      '| `${package.name}` | `${package.version}` | `${package.dependency}` | `${package.source}` | ${licenseFiles.isEmpty ? '未在本地包根发现 LICENSE/NOTICE，发布前需人工复核' : licenseFiles.map((file) => '`$file`').join(', ')} |',
    );
  }

  buffer
    ..writeln()
    ..writeln('发布检查：')
    ..writeln()
    ..writeln('- Android APK/AAB 与 Windows release 包必须包含 Flutter 生成的许可文本。')
    ..writeln('- 新增或升级依赖后必须重新运行生成命令，并复核本文件变化。')
    ..writeln('- `未在本地包根发现 LICENSE/NOTICE` 的条目必须在发布前通过上游仓库或包页面人工复核。');
  return buffer.toString();
}

List<String> findLicenseFiles(Directory? root) {
  if (root == null || !root.existsSync()) {
    return const [];
  }
  final names =
      root
          .listSync(followLinks: false)
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) {
            final upper = name.toUpperCase();
            return upper == 'LICENSE' ||
                upper == 'LICENSE.txt'.toUpperCase() ||
                upper.startsWith('LICENSE.') ||
                upper.startsWith('LICENSE-') ||
                upper == 'NOTICE' ||
                upper == 'NOTICE.txt'.toUpperCase() ||
                upper.startsWith('NOTICE.') ||
                upper.startsWith('NOTICE-');
          })
          .toList()
        ..sort();
  return names;
}

final class LockedPackage {
  const LockedPackage({
    required this.name,
    required this.dependency,
    required this.source,
    required this.version,
  });

  final String name;
  final String dependency;
  final String source;
  final String version;
}
