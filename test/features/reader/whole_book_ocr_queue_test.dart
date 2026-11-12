import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/features/reader/application/whole_book_ocr_queue.dart';

void main() {
  test('queues every page once in bounded sequential batches', () async {
    final queue = WholeBookOcrQueue();
    final batches = <List<int>>[];
    final result = await queue.enqueue(
      totalPages: 4001,
      startBatch: (pages) async => batches.add(pages),
    );
    expect(result, 4001);
    expect(batches.map((pages) => pages.length), [2000, 2000, 1]);
    expect(batches.expand((pages) => pages), List.generate(4001, (i) => i + 1));
  });

  test('reports completed batches on failure and permits retry', () async {
    final queue = WholeBookOcrQueue();
    var calls = 0;
    await expectLater(
      queue.enqueue(
        totalPages: 2001,
        startBatch: (pages) async {
          calls++;
          if (calls == 2) throw StateError('failed');
        },
      ),
      throwsA(
        isA<WholeBookOcrQueueException>().having(
          (error) => error.queuedPages,
          'queuedPages',
          2000,
        ),
      ),
    );
    expect(await queue.enqueue(totalPages: 1, startBatch: (_) async {}), 1);
  });

  test('rejects overlapping requests while a batch is pending', () async {
    final queue = WholeBookOcrQueue();
    final gate = Completer<void>();
    final first = queue.enqueue(totalPages: 1, startBatch: (_) => gate.future);
    expect(
      await queue.enqueue(totalPages: 1, startBatch: (_) async {}),
      isNull,
    );
    gate.complete();
    expect(await first, 1);
  });
}
