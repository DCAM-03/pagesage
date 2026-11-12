import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/platform/open_file_location_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pagesage_open_location_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('revealFile selects the file in Windows explorer', () async {
    final file = File(p.join(tempDir.path, 'demo book.pdf'));
    await file.writeAsString('%PDF-');
    final calls = <_ProcessCall>[];
    final service = OpenFileLocationService(
      isWindows: true,
      runner: (executable, arguments) async {
        calls.add(_ProcessCall(executable, arguments));
        return ProcessResult(1, 0, '', '');
      },
    );

    await service.revealFile(file.path);

    expect(calls.single.executable, 'explorer.exe');
    expect(calls.single.arguments, ['/select,${file.path}']);
  });

  test('openDirectory opens the directory in Windows explorer', () async {
    final calls = <_ProcessCall>[];
    final service = OpenFileLocationService(
      isWindows: true,
      runner: (executable, arguments) async {
        calls.add(_ProcessCall(executable, arguments));
        return ProcessResult(1, 0, '', '');
      },
    );

    await service.openDirectory(tempDir.path);

    expect(calls.single.executable, 'explorer.exe');
    expect(calls.single.arguments, [tempDir.path]);
  });

  test('revealFile fails when the file no longer exists', () async {
    final service = OpenFileLocationService(
      isWindows: true,
      runner: (_, _) async => ProcessResult(1, 0, '', ''),
    );

    expect(
      service.revealFile(p.join(tempDir.path, 'missing.pdf')),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('throws unsupported error on non-Windows platforms', () async {
    final service = OpenFileLocationService(
      isWindows: false,
      isLinux: false,
      runner: (_, _) async => ProcessResult(1, 0, '', ''),
    );

    expect(service.openDirectory(tempDir.path), throwsUnsupportedError);
  });

  test('Linux reveals the containing directory without a shell', () async {
    final file = File(p.join(tempDir.path, '空 格;\$(noop).md'));
    await file.writeAsString('export');
    final calls = <_ProcessCall>[];
    final service = OpenFileLocationService(
      isWindows: false,
      isLinux: true,
      runner: (executable, arguments) async {
        calls.add(_ProcessCall(executable, arguments));
        return ProcessResult(1, 0, '', '');
      },
    );
    await service.revealFile(file.path);
    expect(calls.single.executable, 'xdg-open');
    expect(calls.single.arguments, [tempDir.path]);
  });

  test('Linux reports desktop opener failure', () async {
    final service = OpenFileLocationService(
      isWindows: false,
      isLinux: true,
      runner: (_, _) async => ProcessResult(1, 1, '', 'no handler'),
    );
    await expectLater(
      service.openDirectory(tempDir.path),
      throwsA(isA<ProcessException>()),
    );
  });
}

final class _ProcessCall {
  const _ProcessCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}
