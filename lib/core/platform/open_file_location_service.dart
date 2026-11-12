import 'dart:io';

typedef PlatformProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final class OpenFileLocationService {
  factory OpenFileLocationService({
    PlatformProcessRunner runner = Process.run,
    bool? isWindows,
    bool? isLinux,
  }) {
    return OpenFileLocationService._(runner, isWindows, isLinux);
  }

  const OpenFileLocationService._(
    this._runner,
    this._isWindowsOverride,
    this._isLinuxOverride,
  );

  final PlatformProcessRunner _runner;
  final bool? _isWindowsOverride;
  final bool? _isLinuxOverride;

  bool get _isWindows => _isWindowsOverride ?? Platform.isWindows;
  bool get _isLinux => _isLinuxOverride ?? Platform.isLinux;
  bool get isSupported => _isWindows || _isLinux;

  Future<void> revealFile(String filePath) async {
    _ensureSupported();
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }
    if (_isWindows) {
      await _run('explorer.exe', ['/select,${file.path}']);
    } else {
      await _run('xdg-open', [file.absolute.parent.path]);
    }
  }

  Future<void> openDirectory(String directoryPath) async {
    _ensureSupported();
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw FileSystemException('目录不存在', directoryPath);
    }
    await _run(_isWindows ? 'explorer.exe' : 'xdg-open', [
      directory.absolute.path,
    ]);
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw UnsupportedError('当前平台不支持打开文件所在位置');
    }
  }

  Future<void> _run(String executable, List<String> arguments) async {
    final result = await _runner(executable, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }
}
