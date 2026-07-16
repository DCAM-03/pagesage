import 'dart:io';

import 'package:path/path.dart' as p;

typedef PlatformProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final class OpenFileLocationService {
  factory OpenFileLocationService({
    PlatformProcessRunner runner = Process.run,
    bool? isWindows,
  }) {
    return OpenFileLocationService._(runner, isWindows);
  }

  const OpenFileLocationService._(this._runner, this._isWindowsOverride);

  final PlatformProcessRunner _runner;
  final bool? _isWindowsOverride;

  bool get isSupported => _isWindowsOverride ?? Platform.isWindows;

  Future<void> revealFile(String filePath) async {
    _ensureSupported();
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }
    await _runExplorer(['/select,${file.path}']);
  }

  Future<void> openDirectory(String directoryPath) async {
    _ensureSupported();
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw FileSystemException('目录不存在', directoryPath);
    }
    await _runExplorer([directory.path]);
  }

  Future<void> openContainingDirectory(String filePath) async {
    await openDirectory(p.dirname(filePath));
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw UnsupportedError('当前平台不支持打开文件所在位置');
    }
  }

  Future<void> _runExplorer(List<String> arguments) async {
    final result = await _runner('explorer.exe', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'explorer.exe',
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }
}
