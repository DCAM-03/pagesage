import 'package:flutter/material.dart';

abstract final class AppColors {
  // Cool black + electric blue: high-tech reading workbench.
  // Primary deep enough for AA on light accent surfaces.
  static const seed = Color(0xFF1E40AF);
  static const seedDark = Color(0xFF93C5FD);

  static const lightBackground = Color(0xFFF3F6FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFE8EEF9);
  static const lightBorder = Color(0xFFD0DBEF);
  static const lightBorderStrong = Color(0xFFA9BBDA);
  static const lightTextPrimary = Color(0xFF0B1220);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightAccentSubtle = Color(0xFFE8F0FF);

  // Eye-care: cooler paper with same blue accent.
  static const eyeCareBackground = Color(0xFFEEF2F8);
  static const eyeCareSurface = Color(0xFFF8FAFC);
  static const eyeCareSurfaceSubtle = Color(0xFFE2E8F3);
  static const eyeCareBorder = Color(0xFFC7D2E4);
  static const eyeCareBorderStrong = Color(0xFF9AABC4);
  static const eyeCareTextPrimary = Color(0xFF111827);
  static const eyeCareTextSecondary = Color(0xFF4B5B73);
  static const eyeCareAccentSubtle = Color(0xFFE8F0FF);

  static const highContrastBackground = Color(0xFFFFFFFF);
  static const highContrastSurface = Color(0xFFFFFFFF);
  static const highContrastSurfaceSubtle = Color(0xFFF1F1F1);
  static const highContrastBorder = Color(0xFF000000);
  static const highContrastBorderStrong = Color(0xFF000000);
  static const highContrastTextPrimary = Color(0xFF000000);
  static const highContrastTextSecondary = Color(0xFF1F1F1F);
  static const highContrastAccent = Color(0xFF0039A6);
  static const highContrastAccentSubtle = Color(0xFFE4F0FF);

  // Near-black base with electric blue accents.
  static const darkBackground = Color(0xFF05070D);
  static const darkSurface = Color(0xFF0C111B);
  static const darkSurfaceSubtle = Color(0xFF151C2C);
  static const darkBorder = Color(0xFF273247);
  static const darkBorderStrong = Color(0xFF3F4F6C);
  static const darkTextPrimary = Color(0xFFEAF0FF);
  static const darkTextSecondary = Color(0xFFA5B4CF);
  static const darkAccentSubtle = Color(0xFF102A56);

  static const info = Color(0xFF1E40AF);
  static const infoDark = Color(0xFF93C5FD);
  static const warning = Color(0xFF9A6700);
  static const warningDark = Color(0xFFE7BC62);
  static const danger = Color(0xFFB33A3A);
  static const dangerDark = Color(0xFFF09090);
  static const ai = Color(0xFF6D5AE6);
  static const aiDark = Color(0xFFB8AEFF);
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

  Color get appBorderStrong => outline;

  Color get textSecondary => onSurfaceVariant;

  Color get accentSubtle => secondaryContainer;

  Color get statusInfo =>
      brightness == Brightness.dark ? AppColors.infoDark : AppColors.info;

  Color get statusWarning =>
      brightness == Brightness.dark ? AppColors.warningDark : AppColors.warning;

  Color get aiAccent =>
      brightness == Brightness.dark ? AppColors.aiDark : AppColors.ai;
}
