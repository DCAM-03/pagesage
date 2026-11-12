import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/ocr/ocr_models.dart';
import '../tasks/task_cancellation.dart';

typedef TesseractProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
    );

final class TesseractProcessRunner {
  TesseractProcessRunner({
    TesseractProcessStarter? startProcess,
    this.terminateGrace = const Duration(seconds: 1),
  }) : _startProcess = startProcess ?? _start;

  final TesseractProcessStarter _startProcess;
  final Duration terminateGrace;
  Future<void> _pending = Future<void>.value();

  static Future<Process> _start(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  ) => Process.start(
    executable,
    arguments,
    environment: environment,
    runInShell: false,
  );

  Future<Uint8List> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
    Future<void>? cancelled,
    int maxStdoutBytes = 8 * 1024 * 1024,
    int maxStderrBytes = 64 * 1024,
  }) async {
    final previous = _pending;
    final released = Completer<void>();
    _pending = released.future;
    try {
      await previous;
      return await _run(
        executable,
        arguments,
        timeout: timeout,
        cancelled: cancelled,
        maxStdoutBytes: maxStdoutBytes,
        maxStderrBytes: maxStderrBytes,
      );
    } finally {
      released.complete();
    }
  }

  Future<Uint8List> _run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
    required Future<void>? cancelled,
    required int maxStdoutBytes,
    required int maxStderrBytes,
  }) async {
    Object? failure;
    Process? activeProcess;
    Timer? killTimer;
    var finished = false;
    var exited = false;
    void terminate() {
      activeProcess?.kill(ProcessSignal.sigterm);
      killTimer ??= Timer(terminateGrace, () {
        activeProcess?.kill(ProcessSignal.sigkill);
      });
    }

    void stop(Object error) {
      if (finished || failure != null) return;
      failure = error;
      if (activeProcess != null) terminate();
    }

    cancelled?.then<void>(
      (_) => stop(const TaskCancelledException()),
      onError: (Object _) => stop(const TaskCancelledException()),
    );
    await Future<void>.value();
    if (failure case final error?) {
      finished = true;
      killTimer?.cancel();
      throw error;
    }
    final stdout = BytesBuilder(copy: false);
    var stderrBytes = 0;
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    StreamSubscription<List<int>>? stdoutSubscription;
    StreamSubscription<List<int>>? stderrSubscription;
    Timer? timer;
    try {
      final process = await _startProcess(executable, arguments, const {
        'OMP_THREAD_LIMIT': '2',
      });
      activeProcess = process;
      if (failure != null) {
        terminate();
      }
      stdoutSubscription = process.stdout.listen(
        (chunk) {
          if (failure != null) return;
          if (stdout.length + chunk.length > maxStdoutBytes) {
            stop(
              const OcrFailedException(
                '识别输出超出单页限制',
                code: 'ocr_output_too_large',
              ),
            );
          } else {
            stdout.add(chunk);
          }
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (Object _) {
          stop(
            const OcrFailedException('无法读取识别输出', code: 'ocr_output_invalid'),
          );
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );
      stderrSubscription = process.stderr.listen(
        (chunk) {
          stderrBytes += chunk.length;
          if (stderrBytes > maxStderrBytes) {
            stop(
              const OcrFailedException(
                '识别诊断输出超出限制',
                code: 'ocr_output_too_large',
              ),
            );
          }
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (Object _) {
          stop(
            const OcrFailedException('无法读取识别进程状态', code: 'ocr_output_invalid'),
          );
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );
      unawaited(process.stdin.close().catchError((Object _) {}));
      timer = Timer(
        timeout,
        () => stop(
          const OcrFailedException('本页识别超时，请重试或降低页面分辨率', code: 'ocr_timeout'),
        ),
      );
      final exitCode = await process.exitCode;
      exited = true;
      activeProcess = null;
      killTimer?.cancel();
      await Future.wait([stdoutDone.future, stderrDone.future]).timeout(
        terminateGrace,
        onTimeout: () {
          throw failure ??
              const OcrFailedException(
                '识别进程输出未正常结束',
                code: 'ocr_output_invalid',
              );
        },
      );
      if (failure case final error?) throw error;
      if (exitCode != 0) {
        throw const OcrFailedException(
          '本地识别进程失败，请检查语言包或页面图像',
          code: 'ocr_process_failed',
        );
      }
      return stdout.takeBytes();
    } on ProcessException {
      throw const OcrFailedException(
        '无法启动本地识别引擎，请检查安装与执行权限',
        code: 'ocr_engine_missing',
      );
    } finally {
      finished = true;
      timer?.cancel();
      killTimer?.cancel();
      if (!exited) activeProcess?.kill(ProcessSignal.sigkill);
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
      activeProcess = null;
    }
  }
}
