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

  bool get hasText => text.trim().isNotEmpty;

  bool get hasGeometry => blocks.any((block) => block.hasGeometry);
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
  const OcrUnavailableException([this.message = '当前平台暂不支持本地识别']);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when rasterization or recognition fails for a recoverable reason.
final class OcrFailedException implements Exception {
  const OcrFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
