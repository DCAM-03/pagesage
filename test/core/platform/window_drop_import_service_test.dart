import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/platform/window_drop_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pagesage/test_window_drop_service');
  late WindowDropImportService service;
  late List<MethodCall> nativeCalls;

  setUp(() {
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          return null;
        });
    service = WindowDropImportService(channel: channel);
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> emit(String method, [Object? arguments]) async {
    final completed = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) => completed.complete(),
        );
    await completed.future;
  }

  test('enables on start and disables on stop', () async {
    service.start((_) {});
    await Future<void>.delayed(Duration.zero);
    service.stop();
    await Future<void>.delayed(Duration.zero);
    expect(nativeCalls.map((call) => call.method), [
      'setEnabled',
      'setEnabled',
    ]);
    expect(nativeCalls.map((call) => call.arguments), [true, false]);
  });

  test(
    'tracks drag enter, leave and drop without duplicate notifications',
    () async {
      var changes = 0;
      service.dragging.addListener(() => changes++);
      service.start((_) {});
      await emit('dragEntered');
      await emit('dragEntered');
      expect(service.dragging.value, isTrue);
      expect(changes, 1);
      await emit('dragExited');
      expect(service.dragging.value, isFalse);
      await emit('dragEntered');
      await emit('filesDropped', ['/tmp/book.pdf']);
      expect(service.dragging.value, isFalse);
      expect(changes, 4);
    },
  );

  test('filters invalid payload entries and deduplicates file paths', () async {
    final received = <List<String>>[];
    service.start(received.add);
    await emit('filesDropped', [
      '/tmp/线性代数 7.pdf',
      '/tmp/线性代数 7.pdf',
      null,
      42,
      ' ',
      '/tmp/notes.md',
    ]);
    expect(received, [
      ['/tmp/线性代数 7.pdf', '/tmp/notes.md'],
    ]);
    await emit('filesDropped', 'not a list');
    await emit('filesDropped', [null, '', 3]);
    await emit('unknown');
    expect(received, hasLength(1));
  });

  test('stopping clears hover and ignores subsequent native drops', () async {
    var received = 0;
    service.start((_) => received++);
    await emit('dragEntered');
    service.stop();
    expect(service.dragging.value, isFalse);
    await emit('filesDropped', ['/tmp/book.pdf']);
    expect(received, 0);
  });

  test(
    'remount replaces the handler rather than replaying an earlier drop',
    () async {
      final first = <List<String>>[];
      final second = <List<String>>[];
      service.start(first.add);
      await emit('filesDropped', ['/tmp/first.pdf']);
      service.stop();
      service.start(second.add);
      await emit('filesDropped', ['/tmp/second.pdf']);
      expect(first.single, ['/tmp/first.pdf']);
      expect(second.single, ['/tmp/second.pdf']);
    },
  );
}
