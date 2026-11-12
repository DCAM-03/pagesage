import 'package:flutter/material.dart';

abstract final class AppColors {
  // Neutral cool greys with an electric-blue accent used only for selection,
  // primary actions and links. Every surface is spelled out explicitly: a
  // seeded ColorScheme derives its remaining tones from the blue seed, which
  // tints panels purple-grey and makes the whole shell look dirty.
  static const seed = Color(0xFF1E40AF);
  static const seedDark = Color(0xFF8FB4FF);

  static const lightBackground = Color(0xFFF7F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF0F2F5);
  static const lightBorder = Color(0xFFDDE1E6);
  static const lightBorderStrong = Color(0xFFBFC6CF);
  static const lightTextPrimary = Color(0xFF1A1D21);
  static const lightTextSecondary = Color(0xFF5B6470);
  static const lightTextMuted = Color(0xFF8A939E);
  static const lightAccentSubtle = Color(0xFFE8EEFB);
  static const lightInverseSurface = Color(0xFF23272C);

  // Eye-care: the same neutral shell with a faintly warm paper cast.
  static const eyeCareBackground = Color(0xFFF4F5F2);
  static const eyeCareSurface = Color(0xFFFCFCFA);
  static const eyeCareSurfaceSubtle = Color(0xFFECEEE9);
  static const eyeCareBorder = Color(0xFFD8DCD4);
  static const eyeCareBorderStrong = Color(0xFFB8BFB5);
  static const eyeCareTextPrimary = Color(0xFF1D211E);
  static const eyeCareTextSecondary = Color(0xFF5A615B);
  static const eyeCareAccentSubtle = Color(0xFFE6EEEA);

  static const highContrastBackground = Color(0xFFFFFFFF);
  static const highContrastSurface = Color(0xFFFFFFFF);
  static const highContrastSurfaceSubtle = Color(0xFFF1F1F1);
  static const highContrastBorder = Color(0xFF000000);
  static const highContrastBorderStrong = Color(0xFF000000);
  static const highContrastTextPrimary = Color(0xFF000000);
  static const highContrastTextSecondary = Color(0xFF1F1F1F);
  static const highContrastAccent = Color(0xFF0039A6);
  static const highContrastAccentSubtle = Color(0xFFE4F0FF);

  // Neutral near-black shell; blue stays an accent, never a wash.
  static const darkBackground = Color(0xFF111316);
  static const darkSurface = Color(0xFF1A1D21);
  static const darkSurfaceSubtle = Color(0xFF24282D);
  static const darkBorder = Color(0xFF33383F);
  static const darkBorderStrong = Color(0xFF4A515B);
  static const darkTextPrimary = Color(0xFFE9EBEE);
  static const darkTextSecondary = Color(0xFFA2AAB4);
  static const darkTextMuted = Color(0xFF7B838D);
  static const darkAccentSubtle = Color(0xFF1E2A44);
  static const darkInverseSurface = Color(0xFFE9EBEE);

  static const info = Color(0xFF1E40AF);
  static const infoDark = Color(0xFF8FB4FF);
  static const warning = Color(0xFF8A6100);
  static const warningDark = Color(0xFFE6B95C);
  static const danger = Color(0xFFB03030);
  static const dangerDark = Color(0xFFF09191);
  static const ai = Color(0xFF6152D0);
  static const aiDark = Color(0xFFB3A9FF);
}

abstract final class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
}

abstract final class AppRadius {
  // Slightly softer than the old 3–8 system, still tool-like not bubble-like.
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const full = 999.0;
}

abstract final class AppDurations {
  static const hover = Duration(milliseconds: 120);
  static const panel = Duration(milliseconds: 180);
  static const toolbar = Duration(milliseconds: 150);
}

extension AppColorScheme on ColorScheme {
  Color get pageBackground => surfaceContainerLowest;

  Color get surfaceSubtle => surfaceContainerHighest;

  Color get appBorder => outlineVariant;

  Color get textSecondary => onSurfaceVariant;

  Color get accentSubtle => secondaryContainer;

  /// Snackbars and other high-emphasis inverse surfaces.
  Color get inverseSurface => brightness == Brightness.dark
      ? AppColors.darkInverseSurface
      : AppColors.lightInverseSurface;

  Color get statusInfo =>
      brightness == Brightness.dark ? AppColors.infoDark : AppColors.info;

  Color get statusWarning =>
      brightness == Brightness.dark ? AppColors.warningDark : AppColors.warning;

  Color get aiAccent =>
      brightness == Brightness.dark ? AppColors.aiDark : AppColors.ai;
}
