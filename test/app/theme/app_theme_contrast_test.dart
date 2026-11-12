import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/app/theme/app_tokens.dart';
import 'package:pagesage/domain/books/reader_settings.dart';

void main() {
  group('AppTheme contrast', () {
    final themes = <String, ThemeData Function()>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
      'eyeCare': AppTheme.eyeCare,
      'highContrast': AppTheme.highContrast,
    };

    for (final entry in themes.entries) {
      test('${entry.key} meets WCAG AA for text and status accents', () {
        final colorScheme = entry.value().colorScheme;

        _expectTextContrast(
          '${entry.key} onSurface/surface',
          colorScheme.onSurface,
          colorScheme.surface,
        );
        _expectTextContrast(
          '${entry.key} onSurface/pageBackground',
          colorScheme.onSurface,
          colorScheme.pageBackground,
        );
        _expectTextContrast(
          '${entry.key} onSurface/surfaceSubtle',
          colorScheme.onSurface,
          colorScheme.surfaceSubtle,
        );
        _expectTextContrast(
          '${entry.key} onSurfaceVariant/surface',
          colorScheme.onSurfaceVariant,
          colorScheme.surface,
        );
        _expectTextContrast(
          '${entry.key} onSurfaceVariant/surfaceSubtle',
          colorScheme.onSurfaceVariant,
          colorScheme.surfaceSubtle,
        );
        _expectTextContrast(
          '${entry.key} primary/surface',
          colorScheme.primary,
          colorScheme.surface,
        );
        _expectTextContrast(
          '${entry.key} primary/accentSubtle',
          colorScheme.primary,
          colorScheme.accentSubtle,
        );
        _expectTextContrast(
          '${entry.key} onSurface/accentSubtle',
          colorScheme.onSurface,
          colorScheme.accentSubtle,
        );
        _expectTextContrast(
          '${entry.key} error/surface',
          colorScheme.error,
          colorScheme.surface,
        );
        _expectTextContrast(
          '${entry.key} warning/surface',
          colorScheme.statusWarning,
          colorScheme.surface,
        );
        _expectTextContrast(
          '${entry.key} info/surface',
          colorScheme.statusInfo,
          colorScheme.surface,
        );
        _expectTextContrast(
          '${entry.key} ai/surface',
          colorScheme.aiAccent,
          colorScheme.surface,
        );
      });
    }

    test('high contrast theme uses explicit black and white base colors', () {
      final colorScheme = AppTheme.highContrast().colorScheme;

      expect(colorScheme.surface, AppColors.highContrastSurface);
      expect(colorScheme.pageBackground, AppColors.highContrastBackground);
      expect(colorScheme.onSurface, AppColors.highContrastTextPrimary);
      expect(colorScheme.outline, AppColors.highContrastBorderStrong);
      expect(colorScheme.outlineVariant, AppColors.highContrastBorder);
    });
  });

  group('ReaderThemePreset contrast', () {
    for (final preset in ReaderThemePreset.values) {
      test('${preset.label} reader chrome preserves readable surfaces', () {
        final theme = AppTheme.reader(preset);
        final colors = theme.colorScheme;
        expect(colors.surface, preset.background);
        expect(theme.appBarTheme.backgroundColor, colors.surface);
        expect(theme.dialogTheme.backgroundColor, colors.surface);
        expect(theme.bottomSheetTheme.backgroundColor, colors.surface);
        expect(
          theme
              .appBarTheme
              .systemOverlayStyle
              ?.systemNavigationBarIconBrightness,
          colors.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        );
        for (final surface in [
          colors.surface,
          colors.surfaceContainerHighest,
          colors.secondaryContainer,
        ]) {
          _expectTextContrast(preset.name, colors.onSurface, surface);
          _expectTextContrast(preset.name, colors.onSurfaceVariant, surface);
          _expectTextContrast(preset.name, colors.primary, surface);
        }
      });
      test('${preset.label} text and links meet WCAG AA', () {
        _expectTextContrast(
          '${preset.label} foreground/background',
          preset.foreground,
          preset.background,
        );
        _expectTextContrast(
          '${preset.label} link/background',
          preset.link,
          preset.background,
        );
      });
    }
  });
}

void _expectTextContrast(String label, Color foreground, Color background) {
  final ratio = _contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason:
        '$label contrast ratio is ${ratio.toStringAsFixed(2)}, expected >= 4.5',
  );
}

double _contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = math.max(aLuminance, bLuminance);
  final darker = math.min(aLuminance, bLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}
