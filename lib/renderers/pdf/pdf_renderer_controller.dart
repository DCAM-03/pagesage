import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../common/renderer_command.dart';
import '../common/web_renderer_helpers.dart';

final class PdfPageExport {
  const PdfPageExport({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.bytes,
    this.imageWidth,
    this.imageHeight,
  });

  final int pageNumber;
  final double width;
  final double height;
  final Uint8List bytes;
  final int? imageWidth;
  final int? imageHeight;
}

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
      RendererApplyOcrLayerCommand() => rendererApplyOcrLayerScript(
        pageNumber: command.pageNumber,
        blocks: command.blocks,
        replace: command.replace,
      ),
      RendererExportPageImageCommand() => rendererExportPageImageScript(
        pageNumber: command.pageNumber,
        quality: command.quality,
      ),
    };
    await _webViewController.evaluateJavascript(source: script);
  }

  /// Capture the currently rendered page canvas (display-space) for OCR.
  Future<PdfPageExport?> exportPageImage({
    required int pageNumber,
    double quality = 0.86,
  }) async {
    final raw = await _webViewController.evaluateJavascript(
      source: rendererExportPageImageScript(
        pageNumber: pageNumber,
        quality: quality,
      ),
    );
    final map = _coerceMap(raw);
    if (map == null) {
      return null;
    }
    final dataUrl = map['dataUrl']?.toString() ?? '';
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || comma >= dataUrl.length - 1) {
      return null;
    }
    final b64 = dataUrl.substring(comma + 1);
    try {
      final bytes = base64Decode(b64);
      return PdfPageExport(
        pageNumber: (map['page'] as num?)?.toInt() ?? pageNumber,
        width: (map['width'] as num?)?.toDouble() ?? 0,
        height: (map['height'] as num?)?.toDouble() ?? 0,
        imageWidth: (map['imageWidth'] as num?)?.toInt(),
        imageHeight: (map['imageHeight'] as num?)?.toInt(),
        bytes: Uint8List.fromList(bytes),
      );
    } on FormatException {
      return null;
    }
  }

  /// Pages currently visible in the viewer (1-based).
  ///
  /// Double-page mode returns both pages of the spread when applicable.
  Future<List<int>> getVisiblePages({int? fallbackPage}) async {
    final raw = await _webViewController.evaluateJavascript(
      source: rendererGetVisiblePagesScript(),
    );
    final pages = <int>[];
    if (raw is List) {
      for (final item in raw) {
        final page = item is num
            ? item.toInt()
            : int.tryParse(item?.toString() ?? '');
        if (page != null && page > 0) {
          pages.add(page);
        }
      }
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty && trimmed != 'null') {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (final item in decoded) {
              final page = item is num
                  ? item.toInt()
                  : int.tryParse(item?.toString() ?? '');
              if (page != null && page > 0) {
                pages.add(page);
              }
            }
          }
        } on Object {
          // fall through to fallback
        }
      }
    }
    if (pages.isEmpty && fallbackPage != null && fallbackPage > 0) {
      return [fallbackPage];
    }
    return pages;
  }

  Map<String, Object?>? _coerceMap(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == 'null') {
        return null;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } on Object {
        return null;
      }
    }
    return null;
  }
}
