import 'dart:convert';

import 'package:flutter/material.dart';

enum ReaderThemePreset {
  day('day', '白昼', Color(0xFFFAFAF7), Color(0xFF24251F), Color(0xFF1F6F64)),
  paper('paper', '纸张', Color(0xFFF3EAD8), Color(0xFF2D261C), Color(0xFF70612A)),
  warm('warm', '暖色', Color(0xFFF7E3C3), Color(0xFF2D2418), Color(0xFF7A5421)),
  amber('amber', '琥珀', Color(0xFFF0D49A), Color(0xFF2E2512), Color(0xFF765100)),
  night('night', '夜间', Color(0xFF161716), Color(0xFFE8E6DA), Color(0xFF7AC7B7)),
  green('green', '护眼', Color(0xFFE8EFE4), Color(0xFF243026), Color(0xFF1E6B5D)),
  sage('sage', '柔和护眼', Color(0xFFDDE8D6), Color(0xFF223026), Color(0xFF256B55)),
  ink(
    'ink',
    '墨水屏',
    Color(0xFFEDECE6),
    Color(0xFF1E1F1B),
    Color(0xFF3C5F58),
    epubInk: true,
  ),
  inkWarm(
    'ink-warm',
    '暖墨',
    Color(0xFFECE4D3),
    Color(0xFF211D16),
    Color(0xFF5C5541),
    epubInk: true,
  ),
  contrast(
    'contrast',
    '高对比',
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFF0047B3),
  );

  const ReaderThemePreset(
    this.value,
    this.label,
    this.background,
    this.foreground,
    this.link, {
    this.epubInk = false,
  });

  final String value;
  final String label;
  final Color background;
  final Color foreground;
  final Color link;
  final bool epubInk;

  static ReaderThemePreset fromValue(String value) {
    return values.firstWhere(
      (preset) => preset.value == value,
      orElse: () => ReaderThemePreset.day,
    );
  }
}

enum ReaderMode {
  continuous('continuous', '连续滚动'),
  paged('paged', '分页');

  const ReaderMode(this.value, this.label);

  final String value;
  final String label;

  static ReaderMode fromValue(String value) {
    return values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => ReaderMode.continuous,
    );
  }
}

enum PdfZoomMode {
  custom('custom', '自定义'),
  actual('actual', '实际大小'),
  fitWidth('fit-width', '适合宽度'),
  fitPage('fit-page', '适合页面');

  const PdfZoomMode(this.value, this.label);

  final String value;
  final String label;

  static PdfZoomMode fromValue(String value) {
    return values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => PdfZoomMode.custom,
    );
  }
}

final class ReaderSettings {
  const ReaderSettings({
    this.appThemeMode = ThemeMode.system,
    this.fontFamily = '',
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.paragraphSpacing = 12,
    this.pageMargin = 24,
    this.readerMode = ReaderMode.continuous,
    this.pdfScale = 1.2,
    this.pdfZoomMode = PdfZoomMode.custom,
    this.themePreset = ReaderThemePreset.day,
    this.reduceMotion = false,
    this.desktopTocOpen = true,
    this.desktopContextOpen = false,
    this.desktopTocWidth = 300,
    this.desktopContextWidth = 420,
  });

  final ThemeMode appThemeMode;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double pageMargin;
  final ReaderMode readerMode;
  final double pdfScale;
  final PdfZoomMode pdfZoomMode;
  final ReaderThemePreset themePreset;
  final bool reduceMotion;
  final bool desktopTocOpen;
  final bool desktopContextOpen;
  final double desktopTocWidth;
  final double desktopContextWidth;

  ReaderSettings copyWith({
    ThemeMode? appThemeMode,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? pageMargin,
    ReaderMode? readerMode,
    double? pdfScale,
    PdfZoomMode? pdfZoomMode,
    ReaderThemePreset? themePreset,
    bool? reduceMotion,
    bool? desktopTocOpen,
    bool? desktopContextOpen,
    double? desktopTocWidth,
    double? desktopContextWidth,
  }) {
    return ReaderSettings(
      appThemeMode: appThemeMode ?? this.appThemeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      pageMargin: pageMargin ?? this.pageMargin,
      readerMode: readerMode ?? this.readerMode,
      pdfScale: pdfScale ?? this.pdfScale,
      pdfZoomMode: pdfZoomMode ?? this.pdfZoomMode,
      themePreset: themePreset ?? this.themePreset,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      desktopTocOpen: desktopTocOpen ?? this.desktopTocOpen,
      desktopContextOpen: desktopContextOpen ?? this.desktopContextOpen,
      desktopTocWidth: desktopTocWidth ?? this.desktopTocWidth,
      desktopContextWidth: desktopContextWidth ?? this.desktopContextWidth,
    );
  }

  ReaderSettings mergeOverride(ReaderSettingsOverride override) {
    return copyWith(
      appThemeMode: override.appThemeMode,
      fontFamily: override.fontFamily,
      fontSize: override.fontSize,
      lineHeight: override.lineHeight,
      paragraphSpacing: override.paragraphSpacing,
      pageMargin: override.pageMargin,
      readerMode: override.readerMode,
      pdfScale: override.pdfScale,
      pdfZoomMode: override.pdfZoomMode,
      themePreset: override.themePreset,
      reduceMotion: override.reduceMotion,
    );
  }

  String toJsonText() {
    return jsonEncode({
      'themeMode': appThemeMode.name,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'paragraphSpacing': paragraphSpacing,
      'pageMargin': pageMargin,
      'readerMode': readerMode.value,
      'pdfScale': pdfScale,
      'pdfZoomMode': pdfZoomMode.value,
      'themePreset': themePreset.value,
      'reduceMotion': reduceMotion,
      'desktopTocOpen': desktopTocOpen,
      'desktopContextOpen': desktopContextOpen,
      'desktopTocWidth': desktopTocWidth,
      'desktopContextWidth': desktopContextWidth,
    });
  }

  static ReaderSettings fromJsonText(String? value) {
    if (value == null || value.isEmpty) {
      return const ReaderSettings();
    }

    final json = jsonDecode(value) as Map<String, Object?>;
    return ReaderSettings(
      appThemeMode: _themeModeFromName(json['themeMode'] as String?),
      fontFamily: json['fontFamily'] as String? ?? '',
      fontSize: _asDouble(json['fontSize']) ?? 18,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.7,
      paragraphSpacing: _asDouble(json['paragraphSpacing']) ?? 12,
      pageMargin: _asDouble(json['pageMargin']) ?? 24,
      readerMode: ReaderMode.fromValue(
        json['readerMode'] as String? ?? ReaderMode.continuous.value,
      ),
      pdfScale: _asDouble(json['pdfScale']) ?? 1.2,
      pdfZoomMode: PdfZoomMode.fromValue(
        json['pdfZoomMode'] as String? ?? PdfZoomMode.custom.value,
      ),
      themePreset: ReaderThemePreset.fromValue(
        json['themePreset'] as String? ?? ReaderThemePreset.day.value,
      ),
      reduceMotion: json['reduceMotion'] == true,
      desktopTocOpen: json['desktopTocOpen'] != false,
      desktopContextOpen: json['desktopContextOpen'] == true,
      desktopTocWidth: _asDouble(json['desktopTocWidth']) ?? 300,
      desktopContextWidth: _asDouble(json['desktopContextWidth']) ?? 360,
    );
  }

  static ThemeMode _themeModeFromName(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}

final class ReaderSettingsOverride {
  const ReaderSettingsOverride({
    this.appThemeMode,
    this.fontFamily,
    this.fontSize,
    this.lineHeight,
    this.paragraphSpacing,
    this.pageMargin,
    this.readerMode,
    this.pdfScale,
    this.pdfZoomMode,
    this.themePreset,
    this.reduceMotion,
  });

  final ThemeMode? appThemeMode;
  final String? fontFamily;
  final double? fontSize;
  final double? lineHeight;
  final double? paragraphSpacing;
  final double? pageMargin;
  final ReaderMode? readerMode;
  final double? pdfScale;
  final PdfZoomMode? pdfZoomMode;
  final ReaderThemePreset? themePreset;
  final bool? reduceMotion;
}
