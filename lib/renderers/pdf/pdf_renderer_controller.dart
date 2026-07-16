import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../common/renderer_command.dart';
import '../common/web_renderer_helpers.dart';

final class PdfRendererController implements BookRendererController {
  PdfRendererController(this._webViewController);

  final InAppWebViewController _webViewController;

  @override
  Future<void> dispatch(RendererCommand command) async {
    final script = switch (command) {
      RendererOpenCommand() => rendererOpenScript(
        filePath: command.filePath,
        settings: command.settings,
        locator: command.initialLocator,
      ),
      RendererGoToCommand() => rendererGoToScript(command.locator),
      RendererApplyThemeCommand() => rendererApplySettingsScript(
        command.settings,
      ),
      RendererSetTextOptionsCommand() => rendererSetTextOptionsScript(
        fontSize: command.fontSize,
        lineHeight: command.lineHeight,
        paragraphSpacing: command.paragraphSpacing,
        pageMargin: command.pageMargin,
        fontFamily: command.fontFamily,
      ),
      RendererSearchCommand() => rendererSearchScript(command.query),
      RendererClearSearchHighlightsCommand() =>
        rendererClearSearchHighlightsScript(),
      RendererApplyAnnotationsCommand() => rendererApplyAnnotationsScript(
        command.annotations,
      ),
    };
    await _webViewController.evaluateJavascript(source: script);
  }
}
