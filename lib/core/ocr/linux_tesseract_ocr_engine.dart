import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../../domain/ocr/ocr_capability.dart';
import '../../domain/ocr/ocr_engine.dart';
import '../../domain/ocr/ocr_models.dart';
import 'tesseract_process.dart';
import 'tesseract_tsv.dart';

final class LinuxTesseractOcrEngine
    implements OcrEngine, OcrCapabilitySource, OcrCacheIdentitySource {
  LinuxTesseractOcrEngine({
    String? executable,
    TesseractProcessRunner? runner,
    Directory? temporaryDirectory,
    this.recognitionTimeout = const Duration(seconds: 45),
  }) : _configuredExecutable = executable,
       _runner = runner ?? TesseractProcessRunner(),
       _temporaryDirectory = temporaryDirectory ?? Directory.systemTemp;

  final String? _configuredExecutable;
  final TesseractProcessRunner _runner;
  final Directory _temporaryDirectory;
  final Duration recognitionTimeout;
  String? _executable;
  OcrCapability? _cachedCapability;
  DateTime? _checkedAt;
  Future<OcrCapability>? _probing;

  @override
  String get id => 'tesseract';

  @override
  bool get supportsPdfPageOcr => false;

  @override
  Future<bool> isAvailable() async => (await capability()).isAvailable;

  @override
  Future<List<String>> supportedLanguages() async =>
      (await capability()).languages;

  @override
  Future<OcrCacheIdentity> cacheIdentity({required String languageHint}) async {
    final detected = await capability();
    if (!detected.isAvailable) {
      throw OcrUnavailableException(
        detected.message,
        _capabilityCode(detected.status),
      );
    }
    return OcrCacheIdentity(
      engineId: id,
      engineVersion: detected.engineVersion,
      resolvedLanguage: _resolveLanguage(languageHint, detected.languages),
    );
  }

  @override
  Future<OcrCapability> capability({bool refresh = false}) async {
    final pending = _probing;
    if (pending != null) return pending;
    final cached = _cachedCapability;
    final checkedAt = _checkedAt;
    if (!refresh &&
        cached != null &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < const Duration(minutes: 1)) {
      return cached;
    }
    final future = _probe();
    _probing = future;
    try {
      final result = await future;
      _cachedCapability = result.isAvailable ? result : null;
      _checkedAt = result.isAvailable ? DateTime.now() : null;
      return result;
    } finally {
      _probing = null;
    }
  }

  Future<OcrCapability> _probe() async {
    _executable = await _findExecutable();
    final executable = _executable;
    if (executable == null) {
      return OcrCapability(
        status: OcrCapabilityStatus.engineMissing,
        message: '未找到本地 Tesseract 5.x，请安装后重新点击识别',
      );
    }
    String? version;
    var languages = <String>[];
    try {
      final versionOutput = utf8.decode(
        await _runner.run(
          executable,
          const ['--version'],
          timeout: const Duration(seconds: 5),
          maxStdoutBytes: 65536,
        ),
      );
      final match = RegExp(
        r'^tesseract +([0-9]+)[.]([0-9]+)[.]([0-9]+)[^ ]*',
        multiLine: true,
      ).firstMatch(versionOutput);
      if (match == null) {
        throw const OcrFailedException('引擎版本输出无效');
      }
      version = '${match.group(1)}.${match.group(2)}.${match.group(3)}';
      if (match.group(1) != '5') {
        return OcrCapability(
          status: OcrCapabilityStatus.unsupportedVersion,
          message: '当前识别引擎版本为 $version，需要 Tesseract 5.x',
          engineVersion: version,
        );
      }
      final languageOutput = utf8.decode(
        await _runner.run(
          executable,
          const ['--list-langs'],
          timeout: const Duration(seconds: 5),
          maxStdoutBytes: 65536,
        ),
      );
      final lines = const LineSplitter().convert(languageOutput.trim());
      final count = lines.isEmpty
          ? null
          : RegExp(r'[(]([0-9]+)[)]:$').firstMatch(lines.first)?.group(1);
      if (count == null) throw const OcrFailedException('语言清单输出无效');
      languages = lines.skip(1).map((line) => line.trim()).toList();
      if (languages.length != int.parse(count) ||
          languages.toSet().length != languages.length ||
          languages.any(
            (language) => !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(language),
          )) {
        throw const OcrFailedException('语言清单输出无效');
      }
      final textLanguages = languages
          .where((language) => language != 'osd')
          .toList();
      if (textLanguages.isEmpty) {
        return OcrCapability(
          status: OcrCapabilityStatus.languageMissing,
          message: '未找到可用 OCR 语言包，请安装 eng 或 chi_sim 后重试',
          engineVersion: version,
          languages: languages,
        );
      }
      final probeLanguage = textLanguages.contains('eng')
          ? 'eng'
          : textLanguages.first;
      await _recognizeImage(
        imageBytes: base64Decode(_probePng),
        language: probeLanguage,
        timeout: const Duration(seconds: 5),
      );
      return OcrCapability(
        status: OcrCapabilityStatus.available,
        message: '本地 OCR 可用',
        engineVersion: version,
        languages: languages,
      );
    } on OcrFailedException catch (error) {
      return OcrCapability(
        status: OcrCapabilityStatus.probeFailed,
        message: '本地 OCR 检测失败：${error.message}。请检查安装与 configs/tsv 输出配置后重试',
        engineVersion: version,
        languages: languages,
      );
    } on FormatException {
      return OcrCapability(
        status: OcrCapabilityStatus.probeFailed,
        message: '本地 OCR 返回了无效协议，请检查 Tesseract 安装后重试',
        engineVersion: version,
        languages: languages,
      );
    } on FileSystemException {
      return OcrCapability(
        status: OcrCapabilityStatus.probeFailed,
        message: '无法创建私有识别临时文件，请检查临时目录权限后重试',
        engineVersion: version,
        languages: languages,
      );
    }
  }

  Future<String?> _findExecutable() async {
    final configured = _configuredExecutable;
    final home = Platform.environment['HOME'];
    final candidates = configured == null
        ? [
            for (final directory in (Platform.environment['PATH'] ?? '').split(
              ':',
            ))
              if (path.isAbsolute(directory)) path.join(directory, 'tesseract'),
            if (home != null) path.join(home, '.local', 'bin', 'tesseract'),
          ]
        : [configured];
    for (final candidate in candidates.toSet()) {
      if (!path.isAbsolute(candidate)) continue;
      final stat = await File(candidate).stat();
      if (stat.type == FileSystemEntityType.file && stat.mode & 0x49 != 0) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Future<OcrPageResult> recognize({
    required Uint8List imageBytes,
    required String languageHint,
    Future<void>? cancelled,
  }) async {
    final detected = await capability();
    if (!detected.isAvailable) {
      throw OcrUnavailableException(
        detected.message,
        _capabilityCode(detected.status),
      );
    }
    final language = _resolveLanguage(languageHint, detected.languages);
    return _recognizeImage(
      imageBytes: imageBytes,
      language: language,
      timeout: recognitionTimeout,
      cancelled: cancelled,
    );
  }

  String _resolveLanguage(String hint, List<String> installed) {
    final normalized = hint.trim().replaceAll('_', '-').toLowerCase();
    final List<String> requested;
    if (normalized == 'zh' ||
        normalized == 'zh-hans' ||
        normalized == 'zh-cn' ||
        normalized == 'zh-sg') {
      requested = const ['chi_sim', 'eng'];
    } else if (normalized == 'zh-hant' ||
        normalized == 'zh-tw' ||
        normalized == 'zh-hk') {
      requested = const ['chi_tra', 'eng'];
    } else if (normalized == 'en' || normalized.startsWith('en-')) {
      requested = const ['eng'];
    } else {
      requested = hint.trim().split('+');
    }
    if (requested.isEmpty ||
        requested.any(
          (language) =>
              !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(language) ||
              language == 'osd',
        )) {
      throw const OcrUnavailableException(
        '识别语言无效，请选择已安装的语言包',
        'ocr_language_missing',
      );
    }
    final missing = requested
        .where((language) => !installed.contains(language))
        .toList();
    if (missing.isNotEmpty) {
      throw OcrUnavailableException(
        '缺少 OCR 语言包：${missing.join('、')}，请安装后重新识别',
        'ocr_language_missing',
      );
    }
    return requested.join('+');
  }

  Future<OcrPageResult> _recognizeImage({
    required Uint8List imageBytes,
    required String language,
    required Duration timeout,
    Future<void>? cancelled,
  }) async {
    final executable = _executable;
    if (executable == null) throw const OcrUnavailableException();
    final dimensions = _pngDimensions(imageBytes);
    final directory = await _temporaryDirectory.createTemp('pagesage-ocr-');
    try {
      await _makePrivate(directory);
      final image = File(path.join(directory.path, 'page.png'));
      await image.writeAsBytes(imageBytes, flush: true);
      final output = await _runner.run(
        executable,
        [
          image.path,
          'stdout',
          '-l',
          language,
          '--oem',
          '1',
          '--psm',
          '3',
          'tsv',
        ],
        timeout: timeout,
        cancelled: cancelled,
      );
      final tsv = utf8.decode(output);
      return await Isolate.run(
        () => parseTesseractTsv(
          tsv,
          imageWidth: dimensions.width,
          imageHeight: dimensions.height,
          language: language,
          engine: 'tesseract',
        ),
      );
    } on FormatException {
      throw const OcrFailedException('识别输出编码无效', code: 'ocr_output_invalid');
    } on FileSystemException {
      throw const OcrFailedException(
        '无法读写识别临时文件',
        code: 'ocr_temp_unavailable',
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }

  ({int width, int height}) _pngDimensions(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    const invalid = OcrFailedException(
      '识别需要有效的 PNG 页面图像',
      code: 'ocr_input_invalid',
    );
    if (bytes.length < 33 || bytes.length > 32 * 1024 * 1024) throw invalid;
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) throw invalid;
    }
    final header = ByteData.sublistView(bytes);
    if (header.getUint32(8) != 13 || header.getUint32(12) != 0x49484452) {
      throw invalid;
    }
    final width = header.getUint32(16);
    final height = header.getUint32(20);
    if (width == 0 ||
        height == 0 ||
        width > 3300 ||
        height > 3300 ||
        width * height > 10000000) {
      throw const OcrFailedException(
        '页面图像超过识别尺寸限制',
        code: 'ocr_input_too_large',
      );
    }
    return (width: width, height: height);
  }

  Future<void> _makePrivate(Directory directory) async {
    if (!Platform.isLinux) return;
    const unavailable = OcrFailedException(
      '无法建立仅当前用户可访问的识别临时目录',
      code: 'ocr_temp_unavailable',
    );
    if ((await directory.stat()).mode & 0x1ff != 0x1c0) {
      try {
        await TesseractProcessRunner().run(
          '/usr/bin/chmod',
          ['0700', '--', directory.path],
          timeout: const Duration(seconds: 5),
          maxStdoutBytes: 4096,
          maxStderrBytes: 4096,
        );
      } on OcrFailedException {
        throw unavailable;
      }
    }
    if ((await directory.stat()).mode & 0x1ff != 0x1c0) throw unavailable;
  }

  String _capabilityCode(OcrCapabilityStatus status) => switch (status) {
    OcrCapabilityStatus.engineMissing => 'ocr_engine_missing',
    OcrCapabilityStatus.languageMissing => 'ocr_language_missing',
    OcrCapabilityStatus.unsupportedVersion => 'ocr_unsupported_version',
    _ => 'ocr_probe_failed',
  };

  @override
  Future<OcrPageResult> recognizePdfPage({
    required String filePath,
    required int pageNumber,
    required String languageHint,
    int dpi = 200,
    int maxEdge = 2200,
  }) async {
    throw const OcrFailedException(
      '请在 PDF 页面加载后重新识别；独立 PDF 光栅化尚未接入',
      code: 'rasterize_unavailable',
    );
  }
}

const _probePng =
    'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAAAAACPAi4CAAAAKUlEQVR4nO3MQREAAAwCIPuX1hD77SAA6VEEAoFAIBAIBAKBQCAQfA8Gpwvw4pr3blgAAAAASUVORK5CYII=';
