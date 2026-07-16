import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/annotations/annotation.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import 'renderer_event.dart';

String rendererOpenScript({
  required String filePath,
  required ReaderSettings settings,
  ReadingLocator? locator,
}) {
  return rendererOpenUrlScript(
    fileUrl: Uri.file(filePath).toString(),
    settings: settings,
    locator: locator,
  );
}

String rendererOpenUrlScript({
  required String fileUrl,
  required ReaderSettings settings,
  ReadingLocator? locator,
}) {
  final payload = {
    'fileUrl': fileUrl,
    'settings': rendererSettingsPayload(settings),
    if (locator != null) 'locator': locator.toJson(),
  };
  return 'window.PageSageRenderer.open(${jsonEncode(payload)});';
}

String rendererApplySettingsScript(ReaderSettings settings) {
  return 'window.PageSageRenderer.applySettings(${jsonEncode(rendererSettingsPayload(settings))});';
}

String rendererGoToScript(ReadingLocator locator) {
  return 'window.PageSageRenderer.goTo(${jsonEncode(locator.toJson())});';
}

String rendererSearchScript(String query) {
  return 'window.PageSageRenderer.search(${jsonEncode(query)});';
}

String rendererClearSearchHighlightsScript() {
  return 'window.PageSageRenderer.clearSearchHighlights();';
}

String rendererApplyAnnotationsScript(List<Annotation> annotations) {
  final payload = annotations
      .map(
        (annotation) => {
          'id': annotation.id,
          'selectedText': annotation.selectedText,
          'color': annotation.color.value,
          'style': annotation.style.value,
          'locator': annotation.locator.toJson(),
          'rects': annotation.locator.selectionRects
              .map((rect) => rect.toJson())
              .toList(growable: false),
        },
      )
      .toList(growable: false);
  return 'window.PageSageRenderer.applyAnnotations(${jsonEncode(payload)});';
}

String rendererSetTextOptionsScript({
  required double fontSize,
  required double lineHeight,
  required double paragraphSpacing,
  required double pageMargin,
  String? fontFamily,
}) {
  final payload = <String, Object?>{
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'paragraphSpacing': paragraphSpacing,
    'pageMargin': pageMargin,
  };
  if (fontFamily != null) {
    payload['fontFamily'] = fontFamily;
  }
  return 'window.PageSageRenderer.applySettings(${jsonEncode(payload)});';
}

Map<String, Object?> rendererSettingsPayload(ReaderSettings settings) {
  final preset = settings.themePreset;
  return {
    'fontSize': settings.fontSize,
    'fontFamily': settings.fontFamily,
    'lineHeight': settings.lineHeight,
    'paragraphSpacing': settings.paragraphSpacing,
    'pageMargin': settings.pageMargin,
    'readerMode': settings.readerMode.value,
    'pdfScale': settings.pdfScale,
    'pdfZoomMode': settings.pdfZoomMode.value,
    'themePreset': preset.value,
    'background': _cssColor(preset.background),
    'foreground': _cssColor(preset.foreground),
    'link': _cssColor(preset.link),
    'reduceMotion': settings.reduceMotion,
  };
}

RendererEvent parseRendererEvent(Object? raw) {
  if (raw is! Map) {
    return const RendererFailed('Renderer event payload is invalid');
  }

  final event = raw.cast<String, Object?>();
  final type = event['type'] as String?;
  final payload = event['payload'];

  if (type == 'ready') {
    return const RendererReady();
  }

  if (type == 'renderError') {
    final message = payload is Map ? payload['message']?.toString() : null;
    return RendererFailed(message ?? '阅读器渲染失败');
  }

  if (type == 'locationChanged' && payload is Map) {
    final map = payload.cast<String, Object?>();
    final locatorMap = (map['locator'] as Map?)?.cast<String, Object?>();
    if (locatorMap == null) {
      return const RendererFailed('阅读位置数据无效');
    }
    final locator = ReadingLocator.fromJson(locatorMap);
    return RendererLocationChanged(
      locator: locator,
      progress: _asDouble(map['progress']) ?? locator.progress,
      chapterTitle: map['chapterTitle'] as String?,
      pageNumber: _asInt(map['pageNumber']),
      totalPages: _asInt(map['totalPages']),
    );
  }

  if (type == 'textSelected' && payload is Map) {
    final map = payload.cast<String, Object?>();
    final locatorMap = (map['locator'] as Map?)?.cast<String, Object?>();
    final text = map['text']?.toString().trim();
    if (locatorMap == null || text == null || text.isEmpty) {
      return const RendererFailed('选区数据无效');
    }
    return RendererTextSelected(
      text: text,
      locator: ReadingLocator.fromJson(locatorMap),
      sourceRect: _parseRect(map['sourceRect']),
      selectionRects: _parseRects(map['selectionRects']),
    );
  }

  if (type == 'capabilityChanged' && payload is Map) {
    final map = payload.cast<String, Object?>();
    return RendererCapabilityChanged(
      textSelection: map['textSelection'] == true,
      search: map['search'] == true,
      reason: map['reason'] as String?,
    );
  }

  if (type == 'renderNotice' && payload is Map) {
    final message = payload['message']?.toString();
    return RendererNotice(
      message == null || message.isEmpty ? '阅读器提示' : message,
    );
  }

  if (type == 'searchResults' && payload is Map) {
    final items = payload['results'];
    if (items is! List) {
      return const RendererFailed('搜索结果数据无效');
    }
    return RendererSearchResults(
      items
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .map(_parseSearchResult)
          .whereType<RendererSearchResult>()
          .toList(growable: false),
    );
  }

  if (type == 'outlineChanged' && payload is Map) {
    final items = payload['items'];
    if (items is! List) {
      return const RendererOutlineChanged([]);
    }
    return RendererOutlineChanged(
      items
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .map(_parseOutlineItem)
          .whereType<RendererOutlineItem>()
          .toList(growable: false),
    );
  }

  if (type == 'bookmarkRequested' && payload is Map) {
    final locatorMap = (payload['locator'] as Map?)?.cast<String, Object?>();
    if (locatorMap == null) {
      return const RendererFailed('书签位置数据无效');
    }
    return RendererBookmarkRequested(ReadingLocator.fromJson(locatorMap));
  }

  if (type == 'annotationSelected' && payload is Map) {
    final annotationId = payload['annotationId']?.toString();
    if (annotationId == null || annotationId.isEmpty) {
      return const RendererFailed('标注数据无效');
    }
    return RendererAnnotationSelected(
      annotationId,
      sourceRect: _parseRect(payload['sourceRect']),
    );
  }

  return RendererFailed('未知阅读器事件：$type');
}

RendererSearchResult? _parseSearchResult(Map<String, Object?> item) {
  final locatorMap = (item['locator'] as Map?)?.cast<String, Object?>();
  if (locatorMap == null) {
    return null;
  }
  return RendererSearchResult(
    title: item['title']?.toString() ?? '',
    snippet: item['snippet']?.toString() ?? '',
    locator: ReadingLocator.fromJson(locatorMap),
  );
}

RendererOutlineItem? _parseOutlineItem(Map<String, Object?> item) {
  final title = item['title']?.toString().trim();
  final page = _asInt(item['page']);
  if (title == null || title.isEmpty || page == null || page <= 0) {
    return null;
  }
  return RendererOutlineItem(
    title: title,
    page: page,
    level: (_asInt(item['level']) ?? 0).clamp(0, 6),
  );
}

String _cssColor(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

ReaderRect? _parseRect(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    return ReaderRect.fromJson(value.cast<String, Object?>());
  } on Object {
    return null;
  }
}

List<ReaderRect> _parseRects(Object? value) {
  if (value is! List) {
    return const [];
  }
  final rects = <ReaderRect>[];
  for (final item in value.whereType<Map>()) {
    final rect = _parseRect(item);
    if (rect != null) {
      rects.add(rect);
    }
  }
  return rects;
}
