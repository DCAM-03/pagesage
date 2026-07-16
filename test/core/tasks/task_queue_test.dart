import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/tasks/task_queue.dart';

void main() {
  test('runs queued tasks serially by default', () async {
    final queue = TaskQueue();
    final events = <String>[];

    final first = queue.enqueue(() async {
      events.add('first:start');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      events.add('first:end');
      return 1;
    });
    final second = queue.enqueue(() async {
      events.add('second:start');
      events.add('second:end');
      return 2;
    });

    expect(await Future.wait([first, second]), [1, 2]);
    expect(events, ['first:start', 'first:end', 'second:start', 'second:end']);
    expect(queue.isIdle, isTrue);
  });

  test('allows limited concurrency', () async {
    final queue = TaskQueue(maxConcurrent: 2);
    var active = 0;
    var maxActive = 0;

    await Future.wait(
      List.generate(4, (index) {
        return queue.enqueue(() async {
          active += 1;
          if (active > maxActive) {
            maxActive = active;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          active -= 1;
          return index;
        });
      }),
    );

    expect(maxActive, 2);
    expect(queue.isIdle, isTrue);
  });
}
