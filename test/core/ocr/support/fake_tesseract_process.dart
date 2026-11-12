import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pagesage/core/ocr/tesseract_tsv.dart';

final class FakeTesseractProcess implements Process {
  FakeTesseractProcess({this.ignoreTerminate = false});

  final bool ignoreTerminate;
  final signals = <ProcessSignal>[];
  final _output = StreamController<List<int>>();
  final _errors = StreamController<List<int>>();
  final _exit = Completer<int>();
  final _input = IOSink(_DiscardInput());

  @override
  int get pid => 10000;

  @override
  Stream<List<int>> get stdout => _output.stream;

  @override
  Stream<List<int>> get stderr => _errors.stream;

  @override
  IOSink get stdin => _input;

  @override
  Future<int> get exitCode => _exit.future;

  void output(List<int> bytes) => _output.add(bytes);

  void diagnostic(List<int> bytes) => _errors.add(bytes);

  void outputError() =>
      _output.addError(const FormatException('private output'));

  void exitWithoutClosing() => _exit.complete(0);

  void finish({String text = '', String error = '', int code = 0}) {
    if (_exit.isCompleted) return;
    if (text.isNotEmpty) _output.add(utf8.encode(text));
    if (error.isNotEmpty) _errors.add(utf8.encode(error));
    unawaited(_output.close());
    unawaited(_errors.close());
    _exit.complete(code);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    if (signal == ProcessSignal.sigterm && ignoreTerminate) return true;
    finish(code: signal == ProcessSignal.sigkill ? -9 : -15);
    return true;
  }
}

final class _DiscardInput implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() async {}
}

Uint8List testPagePng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAAAAACPAi4CAAAAKUlEQVR4nO3MQREAAAwCIPuX1hD77SAA6VEEAoFAIBAIBAKBQCAQfA8Gpwvw4pr3blgAAAAASUVORK5CYII=',
);

String pageTsv({
  int width = 64,
  int height = 64,
  List<String> words = const [],
}) =>
    '$tesseractTsvHeader\n1\t1\t0\t0\t0\t0\t0\t0\t$width\t$height\t-1\t\n${words.join('\n')}\n';

String wordTsv(
  String text, {
  int block = 1,
  int paragraph = 1,
  int line = 1,
  int word = 1,
  int left = 1,
  int top = 2,
  int width = 10,
  int height = 12,
  String confidence = '90',
}) =>
    '5\t1\t$block\t$paragraph\t$line\t$word\t$left\t$top\t$width\t$height\t$confidence\t$text';
