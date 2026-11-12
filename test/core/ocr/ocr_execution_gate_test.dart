import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/ocr_execution_gate.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';

void main() {
  test(
    'cancels a queued operation immediately without releasing its slot',
    () async {
      final gate = OcrExecutionGate();
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var secondStarted = false;
      final first = gate.run<void>(
        operation: () async {
          firstStarted.complete();
          await releaseFirst.future;
        },
      );
      await firstStarted.future;

      final token = TaskCancelToken();
      final second = gate.run<void>(
        cancelToken: token,
        operation: () async {
          secondStarted = true;
        },
      );
      token.cancel();

      await expectLater(second, throwsA(isA<TaskCancelledException>()));
      expect(secondStarted, isFalse);

      var thirdStarted = false;
      final third = gate.run<void>(
        operation: () async {
          thirdStarted = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(thirdStarted, isFalse);

      releaseFirst.complete();
      await Future.wait([first, third]);
      expect(thirdStarted, isTrue);
    },
  );
}
