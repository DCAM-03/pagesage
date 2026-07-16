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
