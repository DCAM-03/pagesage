import '../../domain/books/reading_position.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/annotations/annotation.dart';

abstract interface class BookRendererController {
  Future<void> dispatch(RendererCommand command);
}

sealed class RendererCommand {
  const RendererCommand();
}

final class RendererOpenCommand extends RendererCommand {
  const RendererOpenCommand({
    required this.filePath,
    required this.settings,
    this.initialLocator,
  });

  final String filePath;
  final ReaderSettings settings;
  final ReadingLocator? initialLocator;
}

typedef RendererOpenRequest = RendererOpenCommand;

final class RendererGoToCommand extends RendererCommand {
  const RendererGoToCommand(this.locator);

  final ReadingLocator locator;
}

final class RendererApplyThemeCommand extends RendererCommand {
  const RendererApplyThemeCommand(this.settings);

  final ReaderSettings settings;
}

final class RendererSetTextOptionsCommand extends RendererCommand {
  const RendererSetTextOptionsCommand({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.pageMargin,
    this.fontFamily,
  });

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double pageMargin;
  final String? fontFamily;
}

final class RendererSearchCommand extends RendererCommand {
  const RendererSearchCommand(this.query);

  final String query;
}

final class RendererClearSearchHighlightsCommand extends RendererCommand {
  const RendererClearSearchHighlightsCommand();
}

final class RendererApplyAnnotationsCommand extends RendererCommand {
  const RendererApplyAnnotationsCommand(this.annotations);

  final List<Annotation> annotations;
}

/// Overlay OCR text with normalized geometry onto a PDF page (scan PDFs).
final class RendererApplyOcrLayerCommand extends RendererCommand {
  const RendererApplyOcrLayerCommand({
    required this.pageNumber,
    required this.blocks,
    this.replace = true,
  });

  /// 1-based PDF page number.
  final int pageNumber;

  /// Blocks with optional normalized 0..1 geometry.
  final List<Map<String, Object?>> blocks;

  /// When true, replace any previous OCR layer for this page.
  final bool replace;
}

/// Export a rendered page canvas as JPEG bytes for OCR (display-space aligned).
final class RendererExportPageImageCommand extends RendererCommand {
  const RendererExportPageImageCommand({
    required this.pageNumber,
    this.quality = 0.86,
  });

  final int pageNumber;
  final double quality;
}
