import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/linux_tesseract_ocr_engine.dart';
import 'package:pagesage/core/ocr/tesseract_process.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/domain/ocr/ocr_capability.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/features/ocr/application/ocr_providers.dart';

import 'support/fake_tesseract_process.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pagesage_engine_test_');
  });
  tearDown(() async {
    expect(await directory.list().toList(), isEmpty);
    await directory.delete(recursive: true);
  });

  test('Linux provider installs a real image engine', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(ocrEngineProvider), isA<LinuxTesseractOcrEngine>());
    expect(container.read(ocrEngineProvider).supportsPdfPageOcr, isFalse);
  }, skip: !Platform.isLinux);

  test(
    'capability probes version languages and a real private TSV image',
    () async {
      final harness = _Harness();
      final engine = harness.engine(directory);
      final capabilities = await Future.wait([
        engine.capability(),
        engine.capability(),
        engine.capability(),
      ]);
      expect(
        capabilities.every((capability) => capability.isAvailable),
        isTrue,
        reason: capabilities.first.message,
      );
      expect(capabilities.first.engineVersion, '5.5.4');
      expect(capabilities.first.languages, ['eng', 'chi_sim']);
      expect(harness.calls.length, 3);
      expect(await engine.isAvailable(), isTrue);
      expect(await engine.supportedLanguages(), ['eng', 'chi_sim']);
      expect(harness.calls.length, 3);
      // Windows FileStat.mode does not describe POSIX group/other permissions.
      if (!Platform.isWindows) {
        expect(harness.privateModes.single & 0x3f, 0);
      }
      expect(await directory.list().toList(), isEmpty);
      await engine.capability(refresh: true);
      expect(harness.calls.length, 6);
    },
  );

  test(
    'a missing executable is distinct from an unsupported version',
    () async {
      final missing = LinuxTesseractOcrEngine(
        executable: '${directory.path}/missing',
        temporaryDirectory: directory,
      );
      expect(
        (await missing.capability()).status,
        OcrCapabilityStatus.engineMissing,
      );
      final harness = _Harness(version: '4.1.1');
      final capability = await harness.engine(directory).capability();
      expect(capability.status, OcrCapabilityStatus.unsupportedVersion);
      expect(harness.calls.length, 1);
    },
  );

  test(
    'empty or orientation-only model lists cannot claim text recognition',
    () async {
      for (final languages in [
        <String>[],
        ['osd'],
      ]) {
        final harness = _Harness(languages: languages);
        final capability = await harness.engine(directory).capability();
        expect(capability.status, OcrCapabilityStatus.languageMissing);
        expect(harness.imageCalls, 0);
      }
    },
  );

  test(
    'exit zero with plain text fails TSV probe and can be rechecked',
    () async {
      final harness = _Harness(invalidOutput: true);
      final engine = harness.engine(directory);
      final failed = await engine.capability();
      expect(failed.status, OcrCapabilityStatus.probeFailed);
      expect(failed.message, contains('configs/tsv'));
      expect(failed.message, isNot(contains('private source')));
      harness.invalidOutput = false;
      expect((await engine.capability()).isAvailable, isTrue);
      expect(harness.calls.length, 6);
    },
  );

  test(
    'recognizes images with ordered language mapping and normalized line boxes',
    () async {
      final harness = _Harness();
      final engine = harness.engine(directory);
      final result = await engine.recognize(
        imageBytes: testPagePng(),
        languageHint: 'zh-Hans',
      );
      expect(result.text, 'Hello OCR');
      expect(result.language, 'chi_sim+eng');
      expect(result.engine, 'tesseract');
      expect(result.imageWidth, 64);
      expect(result.blocks.single.width, 20 / 64);
      expect(harness.calls.last.sublist(1), [
        'stdout',
        '-l',
        'chi_sim+eng',
        '--oem',
        '1',
        '--psm',
        '3',
        'tsv',
      ]);
      final reordered = await engine.recognize(
        imageBytes: testPagePng(),
        languageHint: 'eng+chi_sim',
      );
      expect(reordered.language, 'eng+chi_sim');
      expect(harness.calls.last[3], 'eng+chi_sim');
    },
  );

  test('missing Chinese never falls back silently to English', () async {
    final harness = _Harness(languages: ['eng']);
    final engine = harness.engine(directory);
    await expectLater(
      engine.recognize(imageBytes: testPagePng(), languageHint: 'zh-CN'),
      throwsA(
        isA<OcrUnavailableException>()
            .having((error) => error.code, 'code', 'ocr_language_missing')
            .having((error) => error.message, 'message', contains('chi_sim')),
      ),
    );
    expect(harness.imageCalls, 1);
    final english = await engine.recognize(
      imageBytes: testPagePng(),
      languageHint: 'en-US',
    );
    expect(english.language, 'eng');
  });

  test(
    'rejects injection and uninstalled models before the image command',
    () async {
      final harness = _Harness();
      final engine = harness.engine(directory);
      for (final hint in ['eng; touch /tmp/file', 'eng+-l', 'fra', '', 'osd']) {
        await expectLater(
          engine.recognize(imageBytes: testPagePng(), languageHint: hint),
          throwsA(isA<OcrUnavailableException>()),
        );
      }
      expect(harness.imageCalls, 1);
    },
  );

  test('invalid PNG and extreme dimensions never launch recognition', () async {
    final harness = _Harness();
    final engine = harness.engine(directory);
    final huge = testPagePng();
    ByteData.sublistView(huge).setUint32(16, 999999);
    for (final image in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      huge,
    ]) {
      await expectLater(
        engine.recognize(imageBytes: image, languageHint: 'eng'),
        throwsA(isA<OcrFailedException>()),
      );
    }
    expect(harness.imageCalls, 1);
  });

  test(
    'cleans private images when recognition times out or is cancelled',
    () async {
      for (final cancel in [false, true]) {
        final harness = _Harness();
        final engine = harness.engine(
          directory,
          timeout: const Duration(milliseconds: 30),
        );
        expect(await engine.isAvailable(), isTrue);
        final started = Completer<void>();
        final process = FakeTesseractProcess(ignoreTerminate: true);
        harness.pendingProcess = process;
        harness.recognitionStarted = started;
        final token = TaskCancelToken();
        final future = engine.recognize(
          imageBytes: testPagePng(),
          languageHint: 'eng',
          cancelled: token.whenCancelled,
        );
        final assertion = expectLater(
          future,
          cancel
              ? throwsA(isA<TaskCancelledException>())
              : throwsA(
                  isA<OcrFailedException>().having(
                    (error) => error.code,
                    'code',
                    'ocr_timeout',
                  ),
                ),
        );
        await started.future;
        if (cancel) token.cancel();
        await assertion;
        expect(process.signals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
        expect(await directory.list().toList(), isEmpty);
      }
    },
  );

  test(
    'keeps a blank valid TSV result distinct from protocol failure',
    () async {
      final harness = _Harness();
      final engine = harness.engine(directory);
      await engine.capability();
      harness.blank = true;
      final result = await engine.recognize(
        imageBytes: testPagePng(),
        languageHint: 'eng',
      );
      expect(result.text, isEmpty);
      expect(result.confidence, isNull);
      expect(result.blocks, isEmpty);
    },
  );
}

final class _Harness {
  _Harness({
    this.version = '5.5.4',
    this.languages = const ['eng', 'chi_sim'],
    this.invalidOutput = false,
  });

  final String version;
  final List<String> languages;
  bool invalidOutput;
  bool blank = false;
  int imageCalls = 0;
  final calls = <List<String>>[];
  final privateModes = <int>[];
  FakeTesseractProcess? pendingProcess;
  Completer<void>? recognitionStarted;

  LinuxTesseractOcrEngine engine(
    Directory temporaryDirectory, {
    Duration timeout = const Duration(seconds: 1),
  }) => LinuxTesseractOcrEngine(
    executable: Platform.resolvedExecutable,
    temporaryDirectory: temporaryDirectory,
    recognitionTimeout: timeout,
    runner: TesseractProcessRunner(
      startProcess: start,
      terminateGrace: const Duration(milliseconds: 5),
    ),
  );

  Future<Process> start(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  ) async {
    calls.add(List.of(arguments));
    if (arguments.singleOrNull == '--version') {
      return FakeTesseractProcess()
        ..finish(text: 'tesseract $version\nleptonica-1.87.0\n');
    }
    if (arguments.singleOrNull == '--list-langs') {
      return FakeTesseractProcess()..finish(
        text:
            'List of available languages in private directory (${languages.length}):\n${languages.join('\n')}\n',
      );
    }
    imageCalls += 1;
    final image = File(arguments.first);
    privateModes.add((await image.parent.stat()).mode);
    final bytes = await image.readAsBytes();
    final header = ByteData.sublistView(bytes);
    final pending = pendingProcess;
    if (pending != null) {
      recognitionStarted?.complete();
      return pending;
    }
    return FakeTesseractProcess()..finish(
      text: invalidOutput
          ? 'private source'
          : pageTsv(
              width: header.getUint32(16),
              height: header.getUint32(20),
              words: blank ? const [] : [wordTsv('Hello OCR', width: 20)],
            ),
    );
  }
}
