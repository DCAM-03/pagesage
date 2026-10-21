import 'dart:math' as math;
import 'dart:ui';

import '../../domain/books/reader_settings.dart';

/// How a page's colours should be adjusted for the reader's theme.
///
/// A PDF paints its own colours; a theme cannot restyle it the way it restyles
/// EPUB text. The bridge solved this with a CSS filter over the page canvas
/// (`viewer.css`), and this is the same treatment expressed as a
/// [ColorFilter], so the canvas renderer produces the same picture the WebView
/// did and the two are interchangeable until S7.
///
/// [invert] describes a soft night mode that keeps the page's own contrast
/// while darkening the paper; [tint] is the warm/eye-care cast applied to
/// otherwise white pages.
final class PdfPageTint {
  const PdfPageTint._({
    this.inverted = false,
    this.sepia = 0,
    this.saturation = 1,
    this.brightness = 1,
    this.contrast = 1,
    required this.paper,
  });

  /// No adjustment: the page paints as authored.
  const PdfPageTint.plain(Color paper) : this._(paper: paper);

  /// Matrix producing at most a small colour shift; null when the page needs
  /// none, so the painter can skip a save layer.
  ColorFilter? get filter =>
      needsFilter ? ColorFilter.matrix(colourMatrix) : null;

  /// Whether [filter] is non-null.
  bool get needsFilter =>
      inverted ||
      sepia != 0 ||
      saturation != 1 ||
      brightness != 1 ||
      contrast != 1;

  /// The 4x5 colour matrix, exposed for tests.
  ///
  /// `ColorFilter` does not expose its own matrix, so the values a theme
  /// produces can only be checked — white must come out dark under night, text
  /// must stay separated from paper — if they are readable here.
  List<double> get colourMatrix => _matrix();

  /// Whether the page is rendered dark.
  final bool inverted;

  /// Colour matrix terms, matching the CSS filter pipeline the bridge used.
  final double sepia;
  final double saturation;
  final double brightness;
  final double contrast;

  /// Page background behind the picture, for margins and for pages whose own
  /// paint does not reach the edge.
  final Color paper;

  @override
  bool operator ==(Object other) =>
      other is PdfPageTint &&
      other.inverted == inverted &&
      other.sepia == sepia &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.paper == paper;

  @override
  int get hashCode =>
      Object.hash(inverted, sepia, saturation, brightness, contrast, paper);

  /// Resolves the tint for [preset].
  ///
  /// [narrow] disables every colour matrix. A full-page filter forces the page
  /// into its own layer and keeps it there while scrolling, which is a
  /// measurable heat and battery cost on phones — the bridge made the same
  /// cut (`viewer.css`, `@media (max-width: 899px)`). The paper colour still
  /// follows the theme on those widths, so the reader is never flashed white.
  factory PdfPageTint.forPreset(
    ReaderThemePreset preset, {
    required bool narrow,
  }) {
    final paper = preset.background;
    if (narrow) return PdfPageTint._(paper: paper);
    return switch (preset) {
      ReaderThemePreset.night => PdfPageTint._(
        inverted: true,
        contrast: 0.92,
        brightness: 0.92,
        paper: const Color(0xFF1A1A1A),
      ),
      ReaderThemePreset.green || ReaderThemePreset.sage => PdfPageTint._(
        sepia: 0.18,
        saturation: 0.85,
        brightness: 0.97,
        paper: const Color(0xFFEEF5EA),
      ),
      ReaderThemePreset.paper ||
      ReaderThemePreset.warm ||
      ReaderThemePreset.amber => PdfPageTint._(
        sepia: 0.22,
        saturation: 0.9,
        brightness: 0.98,
        paper: const Color(0xFFF6ECDA),
      ),
      // Day, high contrast, and the two ink presets leave the page alone: an
      // e-ink cast over a PDF would double-tint already-low-saturation art.
      _ => PdfPageTint._(paper: paper),
    };
  }

  /// 4x5 colour matrix (row-major, 20 entries) for this tint.
  ///
  /// Order matches the CSS chain: brightness, contrast, sepia, saturate, then
  /// invert with a hue rotation for night mode. Only the terms that matter are
  /// folded in, so an untouched page returns the identity.
  List<double> _matrix() {
    // Start from the identity and apply each effect in turn.
    var m = _identity();
    if (brightness != 1) m = _brightness(m, brightness);
    if (contrast != 1) m = _contrast(m, contrast);
    if (sepia != 0) m = _sepia(m, sepia);
    if (saturation != 1) m = _saturate(m, saturation);
    if (inverted) m = _hueRotate(_invert(m, 0.9), 180);
    return m;
  }

  static List<double> _identity() => [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static List<double> _brightness(List<double> m, double amount) => _mul(m, [
    amount, 0, 0, 0, 0, //
    0, amount, 0, 0, 0, //
    0, 0, amount, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  static List<double> _contrast(List<double> m, double amount) {
    final t = (1 - amount) * 0.5 * 255;
    return _mul(m, [
      amount, 0, 0, 0, t, //
      0, amount, 0, 0, t, //
      0, 0, amount, 0, t, //
      0, 0, 0, 1, 0, //
    ]);
  }

  static List<double> _sepia(List<double> m, double amount) {
    final a = 1 - amount;
    return _mul(m, [
      0.393 * amount + a, 0.769 * amount, 0.189 * amount, 0, 0, //
      0.349 * amount, 0.686 * amount + a, 0.168 * amount, 0, 0, //
      0.272 * amount, 0.534 * amount, 0.131 * amount + a, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }

  static List<double> _saturate(List<double> m, double amount) => _mul(m, [
    0.213 + 0.787 * amount,
    0.715 - 0.715 * amount,
    0.072 - 0.072 * amount,
    0,
    0, //
    0.213 - 0.213 * amount,
    0.715 + 0.285 * amount,
    0.072 - 0.072 * amount,
    0,
    0, //
    0.213 - 0.213 * amount,
    0.715 - 0.715 * amount,
    0.072 + 0.928 * amount,
    0,
    0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Partial invert: [amount] 1 inverts fully, and the offset keeps the middle
  /// of the range anchored so a soft invert does not crush blacks to white.
  static List<double> _invert(List<double> m, double amount) {
    final a = 1 - 2 * amount;
    final b = 255 * amount;
    return _mul(m, [
      a, 0, 0, 0, b, //
      0, a, 0, 0, b, //
      0, 0, a, 0, b, //
      0, 0, 0, 1, 0, //
    ]);
  }

  static List<double> _hueRotate(List<double> m, double degrees) {
    final rad = degrees * math.pi / 180;
    final cos = math.cos(rad);
    final sin = math.sin(rad);
    return _mul(m, [
      0.213 + cos * 0.787 - sin * 0.213,
      0.715 - cos * 0.715 - sin * 0.715,
      0.072 - cos * 0.072 + sin * 0.928,
      0,
      0,
      0.213 - cos * 0.213 + sin * 0.143,
      0.715 + cos * 0.285 + sin * 0.140,
      0.072 - cos * 0.072 - sin * 0.283,
      0,
      0,
      0.213 - cos * 0.213 - sin * 0.787,
      0.715 - cos * 0.715 + sin * 0.715,
      0.072 + cos * 0.928 + sin * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  /// Multiplies two 4x5 colour matrices: apply [b], then [a].
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row += 1) {
      for (var col = 0; col < 5; col += 1) {
        var sum = 0.0;
        for (var k = 0; k < 4; k += 1) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        if (col == 4) sum += a[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }
}
