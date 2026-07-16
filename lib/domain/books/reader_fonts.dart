/// Built-in EPUB reading fonts shipped with the app.
///
/// Keep identifiers stable — they are stored in [ReaderSettings.fontFamily].
final class ReaderFontOption {
  const ReaderFontOption({
    required this.id,
    required this.label,
    required this.description,
    this.familyName,
    this.assetPath,
  });

  /// Stored value in settings. Empty means system default.
  final String id;

  final String label;
  final String description;

  /// Flutter font family registered in pubspec, when bundled.
  final String? familyName;

  /// Asset path for documentation / diagnostics.
  final String? assetPath;

  bool get isSystem => id.isEmpty;

  /// CSS/Flutter family string used by renderers. Empty for system default.
  String get renderFamily => familyName ?? '';
}

abstract final class ReaderFonts {
  static const system = ReaderFontOption(
    id: '',
    label: '系统默认',
    description: '跟随系统字体',
  );

  static const wenKai = ReaderFontOption(
    id: 'LXGW WenKai Lite',
    label: '霞鹜文楷',
    description: '开源楷体，适合中文长读',
    familyName: 'LXGW WenKai Lite',
    assetPath: 'assets/fonts/LXGWWenKaiLite-Regular.ttf',
  );

  static const atkinson = ReaderFontOption(
    id: 'Atkinson Hyperlegible',
    label: 'Atkinson',
    description: '高可读拉丁字体',
    familyName: 'Atkinson Hyperlegible',
    assetPath: 'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
  );

  /// Quick picks shown in the reader toolbar and settings sheet.
  static const List<ReaderFontOption> options = [system, wenKai, atkinson];

  static ReaderFontOption resolve(String? fontFamily) {
    final value = fontFamily?.trim() ?? '';
    if (value.isEmpty) {
      return system;
    }
    for (final option in options) {
      if (option.id == value || option.familyName == value) {
        return option;
      }
    }
    // Legacy free-text font families still work, but without a chip.
    return ReaderFontOption(
      id: value,
      label: value,
      description: '自定义字体',
      familyName: value,
    );
  }

  static String renderFamilyFor(String? fontFamily) {
    return resolve(fontFamily).renderFamily;
  }
}
