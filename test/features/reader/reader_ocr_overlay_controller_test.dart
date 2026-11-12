import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/features/reader/presentation/reader_ocr_overlay_controller.dart';

void main() {
  testWidgets('a spread applies one overlay now and the next after a frame', (
    tester,
  ) async {
    final controller = ReaderOcrOverlayController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.show([
      (
        page: 3,
        blocks: [
          {'text': 'left'},
        ],
      ),
      (
        page: 4,
        blocks: [
          {'text': 'right'},
        ],
      ),
      (page: 5, blocks: const <Map<String, Object?>>[]),
    ]);

    expect(controller.state.token, 1);
    expect(controller.state.page, 3);
    expect(controller.state.blocks.single['text'], 'left');
    expect(controller.isRestored(3), isTrue);
    expect(controller.isRestored(4), isFalse);
    expect(controller.isRestored(5), isFalse);
    expect(notifications, 1);

    await tester.pump();

    expect(controller.state.token, 2);
    expect(controller.state.page, 4);
    expect(controller.state.blocks.single['text'], 'right');
    expect(controller.isRestored(4), isTrue);
    expect(notifications, 2);
  });

  testWidgets('same-frame results keep earlier pages queued for the renderer', (
    tester,
  ) async {
    final controller = ReaderOcrOverlayController();
    addTearDown(controller.dispose);
    final delivered = <int>[];
    controller.addListener(() => delivered.add(controller.state.page!));
    controller.show([
      (
        page: 1,
        blocks: [
          {'text': 'one'},
        ],
      ),
      (
        page: 2,
        blocks: [
          {'text': 'two'},
        ],
      ),
    ]);
    controller.show([
      (
        page: 3,
        blocks: [
          {'text': 'three'},
        ],
      ),
    ]);
    expect(controller.state.page, 1);
    expect(controller.isRestored(2), isFalse);
    expect(controller.isRestored(3), isFalse);
    await tester.pump();
    await tester.pump();
    expect(delivered, [1, 2, 3]);
    expect(controller.isRestored(2), isTrue);
    expect(controller.isRestored(3), isTrue);
  });

  testWidgets('a newer queued result replaces only the same page', (
    tester,
  ) async {
    final controller = ReaderOcrOverlayController();
    addTearDown(controller.dispose);
    controller.show([
      (
        page: 1,
        blocks: [
          {'text': 'one'},
        ],
      ),
      (
        page: 2,
        blocks: [
          {'text': 'old'},
        ],
      ),
    ]);
    controller.show([
      (
        page: 2,
        blocks: [
          {'text': 'new'},
        ],
      ),
    ]);
    await tester.pump();
    expect(controller.state.page, 2);
    expect(controller.state.blocks.single['text'], 'new');
    await tester.pump();
    expect(controller.state.token, 2);
  });

  test('a newer restore pass invalidates the older one', () {
    final controller = ReaderOcrOverlayController();
    addTearDown(controller.dispose);

    final first = controller.beginRestore();
    final second = controller.beginRestore();

    expect(controller.isRestoreCurrent(first), isFalse);
    expect(controller.isRestoreCurrent(second), isTrue);
  });

  testWidgets('disposing drops a queued overlay without notifying', (
    tester,
  ) async {
    final controller = ReaderOcrOverlayController();
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.show([
      (
        page: 1,
        blocks: [
          {'text': 'one'},
        ],
      ),
      (
        page: 2,
        blocks: [
          {'text': 'two'},
        ],
      ),
    ]);
    controller.dispose();
    await tester.pump();

    expect(controller.state.page, 1);
    expect(notifications, 1);
  });
}
