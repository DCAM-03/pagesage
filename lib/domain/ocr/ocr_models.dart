/// One OCR block with geometry for page overlay.
///
/// Coordinates are normalized to the OCR source image: 0..1 relative to
/// image width/height (origin top-left). Bridge maps them onto the CSS page box.
final class OcrTextBlock {
  const OcrTextBlock({
    required this.text,
    this.left,
    this.top,
    this.width,
    this.height,
  });

  final String text;

  /// Normalized left (0..1 of image width).
  final double? left;

  /// Normalized top (0..1 of image height).
  final double? top;

  /// Normalized width (0..1 of image width).
  final double? width;

  /// Normalized height (0..1 of image height).
  final double? height;

  bool get hasGeometry =>
      left != null && top != null && width != null && height != null;

  Map<String, Object?> toJson() => {
    'text': text,
    if (left != null) 'left': left,
    if (top != null) 'top': top,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };
}

/// Result of recognizing a single PDF page image.
final class OcrPageResult {
  const OcrPageResult({
    required this.text,
    required this.language,
    required this.engine,
    this.confidence,
    this.blocks = const [],
    this.imageWidth,
    this.imageHeight,
    this.sourceRevision,
    this.cacheSignature,
    this.textRevision,
    this.engineVersion,
    this.pipelineVersion,
    this.resultState = 'recognized',
    this.indexState = 'pending',
  });

  final String text;
  final String language;
  final String engine;
  final double? confidence;

  /// Positioned text units for overlay (lines or words).
  final List<OcrTextBlock> blocks;

  /// Source bitmap size used for OCR (pixels). Useful for debugging/mapping.
  final int? imageWidth;
  final int? imageHeight;

  /// The source file identity this result was recognized from.
  final String? sourceRevision;

  /// Hash of the source, engine, language and render settings.
  final String? cacheSignature;

  /// Revision of the text conversion rules and recognized body.
  final String? textRevision;

  final String? engineVersion;
  final String? pipelineVersion;

  /// `recognized`, `empty`, or `legacy` for rows written before signatures.
  final String resultState;

  /// `pending`, `indexed`, `failed`, or `notApplicable`.
  final String indexState;

  bool get hasText => text.trim().isNotEmpty;

  bool get hasGeometry => blocks.any((block) => block.hasGeometry);

  bool get isLegacyOrUnverified =>
      resultState == 'legacy' || cacheSignature == null;

  OcrPageResult copyWith({
    String? sourceRevision,
    String? cacheSignature,
    String? textRevision,
    String? engineVersion,
    String? pipelineVersion,
    String? resultState,
    String? indexState,
  }) {
    return OcrPageResult(
      text: text,
      language: language,
      engine: engine,
      confidence: confidence,
      blocks: blocks,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      cacheSignature: cacheSignature ?? this.cacheSignature,
      textRevision: textRevision ?? this.textRevision,
      engineVersion: engineVersion ?? this.engineVersion,
      pipelineVersion: pipelineVersion ?? this.pipelineVersion,
      resultState: resultState ?? this.resultState,
      indexState: indexState ?? this.indexState,
    );
  }
}

/// Stable identity inputs used to decide whether a stored OCR page is current.
final class OcrCacheIdentity {
  const OcrCacheIdentity({
    required this.engineId,
    required this.resolvedLanguage,
    this.engineVersion,
  });

  final String engineId;
  final String resolvedLanguage;
  final String? engineVersion;
}

/// Engines can expose the exact language they will run and their version so
/// cache keys do not have to guess from a user-facing language tag.
abstract interface class OcrCacheIdentitySource {
  Future<OcrCacheIdentity> cacheIdentity({required String languageHint});
}

/// One recognized page made available to search indexing.
final class OcrIndexPage {
  const OcrIndexPage({
    required this.pageNumber,
    required this.text,
    this.cacheSignature,
    this.textRevision,
  });

  final int pageNumber;
  final String text;
  final String? cacheSignature;
  final String? textRevision;
}

/// A stored page together with its 1-based page number.
final class OcrStoredPage {
  const OcrStoredPage({required this.pageNumber, required this.result});

  final int pageNumber;
  final OcrPageResult result;
}

/// Decouples the core search indexer from the OCR feature's storage layer.
abstract interface class OcrSearchSource {
  Future<List<OcrIndexPage>> pagesForBook(
    String bookId, {
    String? sourceRevision,
  });
}

/// Thrown when OCR completes but yields no usable text.
final class OcrEmptyResultException implements Exception {
  const OcrEmptyResultException([this.message = '未能识别到文字，请尝试更清晰的扫描页']);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the platform OCR engine is missing or unavailable.
final class OcrUnavailableException implements Exception {
  const OcrUnavailableException([
    this.message = '当前平台暂不支持本地识别',
    this.code = 'ocr_engine_missing',
  ]);

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Thrown when rasterization or recognition fails for a recoverable reason.
final class OcrFailedException implements Exception {
  const OcrFailedException(this.message, {this.code = 'ocr_failed'});

  final String message;
  final String code;

  @override
  String toString() => message;
}
