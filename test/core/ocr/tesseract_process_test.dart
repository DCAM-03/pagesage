import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/tesseract_process.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';

import 'support/fake_tesseract_process.dart';

void main() {
  test('passes arguments without a shell and sets the thread limit', () async {
    final runner = TesseractProcessRunner(
      startProcess: (executable, arguments, environment) async {
        expect(executable, '/private/bin/tesseract');
        expect(arguments, ['/private/page with spaces.png', 'stdout']);
        expect(environment, {'OMP_THREAD_LIMIT': '2'});
        return FakeTesseractProcess()..finish(text: 'output');
      },
    );
    final output = await runner.run('/private/bin/tesseract', [
      '/private/page with spaces.png',
      'stdout',
    ], timeout: const Duration(seconds: 1));
    expect(utf8.decode(output), 'output');
  });

  test(
    'nonzero exit and startup errors never expose diagnostic text',
    () async {
      final runner = TesseractProcessRunner(
        startProcess: (_, arguments, environment) async =>
            FakeTesseractProcess()
              ..finish(code: 1, text: 'private page', error: 'private path'),
      );
      await expectLater(
        runner.run('/engine', [], timeout: const Duration(seconds: 1)),
        throwsA(
          isA<OcrFailedException>()
              .having((error) => error.code, 'code', 'ocr_process_failed')
              .having(
                (error) => error.toString(),
                'message',
                isNot(contains('private')),
              ),
        ),
      );
      final broken = TesseractProcessRunner(
        startProcess: (_, arguments, environment) async {
          throw const ProcessException(
            '/private/engine',
            [],
            'private details',
          );
        },
      );
      await expectLater(
        broken.run('/engine', [], timeout: const Duration(seconds: 1)),
        throwsA(
          isA<OcrFailedException>().having(
            (error) => error.code,
            'code',
            'ocr_engine_missing',
          ),
        ),
      );
    },
  );

  for (final stderr in [false, true]) {
    test(
      'bounds ${stderr ? 'stderr' : 'stdout'} and terminates the process',
      () async {
        final process = FakeTesseractProcess();
        final started = Completer<void>();
        final runner = TesseractProcessRunner(
          startProcess: (_, arguments, environment) async {
            started.complete();
            return process;
          },
        );
        final pending = runner.run(
          '/engine',
          [],
          timeout: const Duration(seconds: 1),
          maxStdoutBytes: 4,
          maxStderrBytes: 4,
        );
        final assertion = expectLater(
          pending,
          throwsA(
            isA<OcrFailedException>().having(
              (error) => error.code,
              'code',
              'ocr_output_too_large',
            ),
          ),
        );
        await started.future;
        if (stderr) {
          process.diagnostic([1, 2, 3, 4, 5]);
        } else {
          process.output([1, 2, 3, 4, 5]);
        }
        await assertion;
        expect(process.signals, contains(ProcessSignal.sigterm));
      },
    );
  }

  test(
    'timeout escalates terminate to kill for an unresponsive child',
    () async {
      final process = FakeTesseractProcess(ignoreTerminate: true);
      final runner = TesseractProcessRunner(
        startProcess: (_, arguments, environment) async => process,
        terminateGrace: const Duration(milliseconds: 5),
      );
      await expectLater(
        runner.run('/engine', [], timeout: const Duration(milliseconds: 5)),
        throwsA(
          isA<OcrFailedException>().having(
            (error) => error.code,
            'code',
            'ocr_timeout',
          ),
        ),
      );
      expect(process.signals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
    },
  );

  test('cancelling an active request terminates it as cancellation', () async {
    final process = FakeTesseractProcess();
    final token = TaskCancelToken();
    final started = Completer<void>();
    final runner = TesseractProcessRunner(
      startProcess: (_, arguments, environment) async {
        started.complete();
        return process;
      },
    );
    final assertion = expectLater(
      runner.run(
        '/engine',
        [],
        timeout: const Duration(seconds: 1),
        cancelled: token.whenCancelled,
      ),
      throwsA(isA<TaskCancelledException>()),
    );
    await started.future;
    token.cancel();
    await assertion;
    expect(process.signals, [ProcessSignal.sigterm]);
  });

  test('already cancelled requests do not start a child', () async {
    final token = TaskCancelToken()..cancel();
    var calls = 0;
    final runner = TesseractProcessRunner(
      startProcess: (_, arguments, environment) async {
        calls += 1;
        return FakeTesseractProcess()..finish();
      },
    );
    await expectLater(
      runner.run(
        '/engine',
        [],
        timeout: const Duration(seconds: 1),
        cancelled: token.whenCancelled,
      ),
      throwsA(isA<TaskCancelledException>()),
    );
    expect(calls, 0);
  });

  test('serializes children and skips cancelled queued work', () async {
    final process = FakeTesseractProcess();
    final started = Completer<void>();
    var calls = 0;
    final runner = TesseractProcessRunner(
      startProcess: (_, arguments, environment) async {
        calls += 1;
        if (calls == 1) {
          started.complete();
          return process;
        }
        return FakeTesseractProcess()..finish(text: 'third');
      },
    );
    final first = runner.run(
      '/engine',
      [],
      timeout: const Duration(seconds: 1),
    );
    await started.future;
    final token = TaskCancelToken();
    final second = runner.run(
      '/engine',
      [],
      timeout: const Duration(seconds: 1),
      cancelled: token.whenCancelled,
    );
    final assertion = expectLater(
      second,
      throwsA(isA<TaskCancelledException>()),
    );
    final third = runner.run(
      '/engine',
      [],
      timeout: const Duration(seconds: 1),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    token.cancel();
    process.finish(text: 'first');
    expect(utf8.decode(await first), 'first');
    await assertion;
    expect(utf8.decode(await third), 'third');
    expect(calls, 2);
  });

  test(
    'cancellation during startup still escalates after the child arrives',
    () async {
      final arriving = Completer<Process>();
      final started = Completer<void>();
      final token = TaskCancelToken();
      final process = FakeTesseractProcess(ignoreTerminate: true);
      final runner = TesseractProcessRunner(
        terminateGrace: const Duration(milliseconds: 5),
        startProcess: (_, arguments, environment) {
          started.complete();
          return arriving.future;
        },
      );
      final assertion = expectLater(
        runner.run(
          '/engine',
          [],
          timeout: const Duration(seconds: 1),
          cancelled: token.whenCancelled,
        ),
        throwsA(isA<TaskCancelledException>()),
      );
      await started.future;
      token.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      arriving.complete(process);
      await assertion;
      expect(process.signals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
    },
  );

  test(
    'stream errors fail cleanly without a second completer completion',
    () async {
      final process = FakeTesseractProcess();
      final started = Completer<void>();
      final runner = TesseractProcessRunner(
        startProcess: (_, arguments, environment) async {
          started.complete();
          return process;
        },
      );
      final assertion = expectLater(
        runner.run('/engine', [], timeout: const Duration(seconds: 1)),
        throwsA(
          isA<OcrFailedException>().having(
            (error) => error.code,
            'code',
            'ocr_output_invalid',
          ),
        ),
      );
      await started.future;
      process.outputError();
      await assertion;
    },
  );

  test('cancelling during drain never signals an exited process', () async {
    final process = FakeTesseractProcess();
    final token = TaskCancelToken();
    final started = Completer<void>();
    final runner = TesseractProcessRunner(
      terminateGrace: const Duration(milliseconds: 20),
      startProcess: (_, arguments, environment) async {
        started.complete();
        return process..exitWithoutClosing();
      },
    );
    final assertion = expectLater(
      runner.run(
        '/engine',
        [],
        timeout: const Duration(seconds: 1),
        cancelled: token.whenCancelled,
      ),
      throwsA(isA<TaskCancelledException>()),
    );
    await started.future;
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    await assertion;
    expect(process.signals, isEmpty);
  });

  test('exit without closed output pipes has a bounded drain', () async {
    final process = FakeTesseractProcess();
    final runner = TesseractProcessRunner(
      terminateGrace: const Duration(milliseconds: 5),
      startProcess: (_, arguments, environment) async =>
          process..exitWithoutClosing(),
    );
    await expectLater(
      runner.run('/engine', [], timeout: const Duration(seconds: 1)),
      throwsA(
        isA<OcrFailedException>().having(
          (error) => error.code,
          'code',
          'ocr_output_invalid',
        ),
      ),
    );
    expect(process.signals, isEmpty);
  });
}
