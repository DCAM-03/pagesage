import 'dart:convert';

enum OcrJobStatus {
  queued('queued'),
  running('running'),
  paused('paused'),
  partial('partial'),
  done('done'),
  failed('failed'),
  cancelled('cancelled');

  const OcrJobStatus(this.value);

  final String value;

  static OcrJobStatus fromValue(String value) {
    return values.firstWhere(
      (status) => status.value == value,
      orElse: () => OcrJobStatus.failed,
    );
  }
}

enum OcrPageJobStatus {
  pending('pending'),
  rendering('rendering'),
  recognizing('recognizing'),
  recognized('recognized'),
  indexing('indexing'),
  done('done'),
  empty('empty'),
  skippedNative('skippedNative'),
  failed('failed'),
  cancelled('cancelled');

  const OcrPageJobStatus(this.value);

  final String value;

  static OcrPageJobStatus fromValue(String value) {
    return values.firstWhere(
      (status) => status.value == value,
      orElse: () => OcrPageJobStatus.failed,
    );
  }

  bool get isTerminal => switch (this) {
    OcrPageJobStatus.done ||
    OcrPageJobStatus.empty ||
    OcrPageJobStatus.skippedNative ||
    OcrPageJobStatus.failed ||
    OcrPageJobStatus.cancelled => true,
    OcrPageJobStatus.pending ||
    OcrPageJobStatus.rendering ||
    OcrPageJobStatus.recognizing ||
    OcrPageJobStatus.recognized ||
    OcrPageJobStatus.indexing => false,
  };
}

final class OcrJobConfig {
  const OcrJobConfig({this.languageHint, this.dpi = 200, this.maxEdge = 2200});

  final String? languageHint;
  final int dpi;
  final int maxEdge;

  Map<String, Object?> toJson() => {
    'version': 1,
    if (languageHint != null) 'languageHint': languageHint,
    'dpi': dpi,
    'maxEdge': maxEdge,
  };

  String encode() => jsonEncode(toJson());

  static OcrJobConfig decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const OcrJobConfig();
      }
      final hint = decoded['languageHint']?.toString().trim();
      return OcrJobConfig(
        languageHint: hint == null || hint.isEmpty ? null : hint,
        dpi: _positiveInt(decoded['dpi'], 200),
        maxEdge: _positiveInt(decoded['maxEdge'], 2200),
      );
    } on Object {
      return const OcrJobConfig();
    }
  }

  static int _positiveInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed == null || parsed <= 0 ? fallback : parsed;
  }
}

final class OcrJob {
  const OcrJob({
    required this.id,
    required this.taskId,
    required this.bookId,
    required this.sourceRevision,
    required this.config,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reason,
  });

  final String id;
  final String taskId;
  final String bookId;
  final String sourceRevision;
  final OcrJobConfig config;
  final OcrJobStatus status;
  final String? reason;
  final int createdAt;
  final int updatedAt;
}

final class OcrJobPage {
  const OcrJobPage({
    required this.id,
    required this.jobId,
    required this.pageNumber,
    required this.status,
    required this.attempt,
    required this.expectedCacheSignature,
    required this.updatedAt,
    this.ocrPageId,
    this.errorCode,
  });

  final String id;
  final String jobId;
  final int pageNumber;
  final OcrPageJobStatus status;
  final int attempt;
  final String? ocrPageId;
  final String expectedCacheSignature;
  final String? errorCode;
  final int updatedAt;
}

abstract interface class OcrJobRepository {
  Future<OcrJob> createJob({
    required String taskId,
    required String bookId,
    required String sourceRevision,
    required OcrJobConfig config,
    required List<int> pageNumbers,
    required String expectedCacheSignature,
  });

  Future<OcrJob?> getJob(String id);

  Future<OcrJob?> getJobByTaskId(String taskId);

  Future<OcrJob?> getLatestResumable(String bookId);

  Future<List<OcrJobPage>> getPages(String jobId);

  Future<void> updateJob({
    required String id,
    required OcrJobStatus status,
    String? reason,
    bool clearReason = false,
  });

  Future<void> updatePage({
    required String id,
    required OcrPageJobStatus status,
    int? attempt,
    String? ocrPageId,
    String? errorCode,
    bool clearError = false,
  });

  Future<void> deleteJob(String id);

  Future<void> recoverInterrupted({required Set<String> liveTaskIds});

  Future<void> deleteByBook(String bookId);
}

/// Parses `1-3, 8, 10–12` into a sorted, duplicate-free page list.
final class OcrPageRange {
  const OcrPageRange._();

  static const int maxPagesPerJob = 2000;
  static const int maxPageNumber = 1000000;

  static List<int> parse(
    String input, {
    required int pageCount,
    int maxPages = maxPagesPerJob,
  }) {
    if (pageCount < 1) {
      throw const FormatException('PDF 页数无效');
    }
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('请输入页码范围');
    }
    final pages = <int>{};
    for (final rawPart in trimmed.split(RegExp(r'[,，;；]'))) {
      final part = rawPart.trim();
      if (part.isEmpty) {
        throw const FormatException('页码范围中有空白项');
      }
      final match = RegExp(r'^(\d+)(?:\s*[-–—~～]\s*(\d+))?$').firstMatch(part);
      if (match == null) {
        throw FormatException('无法识别页码：$part');
      }
      final start = int.tryParse(match.group(1)!);
      final endText = match.group(2);
      final end = endText == null ? start : int.tryParse(endText);
      if (start == null || end == null) {
        throw FormatException('无法识别页码：$part');
      }
      if (start < 1 ||
          end < 1 ||
          start > maxPageNumber ||
          end > maxPageNumber) {
        throw const FormatException('页码必须大于 0');
      }
      final low = start <= end ? start : end;
      final high = start <= end ? end : start;
      if (high > pageCount) {
        throw FormatException('页码 $high 超过全书 $pageCount 页');
      }
      for (var page = low; page <= high; page += 1) {
        pages.add(page);
        if (pages.length > maxPages) {
          throw FormatException('单次最多识别 $maxPages 页，请分批处理');
        }
      }
    }
    final sorted = pages.toList(growable: false)..sort();
    return sorted;
  }
}
