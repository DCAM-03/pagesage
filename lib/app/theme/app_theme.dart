import 'package:flutter/material.dart';

import 'app_tokens.dart';

final class AppTheme {
  static ThemeData light() {
    return _build(
      _scheme(
        brightness: Brightness.light,
        primary: AppColors.seed,
        onPrimary: Colors.white,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surfaceSubtle: AppColors.lightSurfaceSubtle,
        border: AppColors.lightBorder,
        borderStrong: AppColors.lightBorderStrong,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        accentSubtle: AppColors.lightAccentSubtle,
        error: AppColors.danger,
      ),
    );
  }

  static ThemeData dark() {
    return _build(
      _scheme(
        brightness: Brightness.dark,
        primary: AppColors.seedDark,
        onPrimary: const Color(0xFF0B1220),
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        surfaceSubtle: AppColors.darkSurfaceSubtle,
        border: AppColors.darkBorder,
        borderStrong: AppColors.darkBorderStrong,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        accentSubtle: AppColors.darkAccentSubtle,
        error: AppColors.dangerDark,
      ),
    );
  }

  static ThemeData eyeCare() {
    return _build(
      _scheme(
        brightness: Brightness.light,
        primary: AppColors.seed,
        onPrimary: Colors.white,
        background: AppColors.eyeCareBackground,
        surface: AppColors.eyeCareSurface,
        surfaceSubtle: AppColors.eyeCareSurfaceSubtle,
        border: AppColors.eyeCareBorder,
        borderStrong: AppColors.eyeCareBorderStrong,
        textPrimary: AppColors.eyeCareTextPrimary,
        textSecondary: AppColors.eyeCareTextSecondary,
        accentSubtle: AppColors.eyeCareAccentSubtle,
        error: AppColors.danger,
      ),
    );
  }

  static ThemeData highContrast() {
    return _build(
      _scheme(
        brightness: Brightness.light,
        primary: AppColors.highContrastAccent,
        onPrimary: Colors.white,
        background: AppColors.highContrastBackground,
        surface: AppColors.highContrastSurface,
        surfaceSubtle: AppColors.highContrastSurfaceSubtle,
        border: AppColors.highContrastBorder,
        borderStrong: AppColors.highContrastBorderStrong,
        textPrimary: AppColors.highContrastTextPrimary,
        textSecondary: AppColors.highContrastTextSecondary,
        accentSubtle: AppColors.highContrastAccentSubtle,
        error: AppColors.danger,
      ),
      highContrast: true,
    );
  }

  /// Explicit Material 3 scheme.
  ///
  /// Every role the app paints is named here instead of being derived by
  /// [ColorScheme.fromSeed]: the seed-derived tones carry a blue-violet cast
  /// that reads as dirty next to the neutral surfaces.
  static ColorScheme _scheme({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color background,
    required Color surface,
    required Color surfaceSubtle,
    required Color border,
    required Color borderStrong,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentSubtle,
    required Color error,
  }) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: accentSubtle,
      onPrimaryContainer: primary,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: accentSubtle,
      onSecondaryContainer: primary,
      tertiary: AppColors.ai,
      onTertiary: Colors.white,
      tertiaryContainer: accentSubtle,
      onTertiaryContainer: primary,
      error: error,
      onError: Colors.white,
      errorContainer: brightness == Brightness.dark
          ? const Color(0xFF3A1E1E)
          : const Color(0xFFFDE7E7),
      onErrorContainer: error,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceDim: background,
      surfaceBright: surface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceSubtle,
      surfaceContainerHighest: surfaceSubtle,
      outline: borderStrong,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: brightness == Brightness.dark
          ? AppColors.darkInverseSurface
          : AppColors.lightInverseSurface,
      onInverseSurface: brightness == Brightness.dark
          ? AppColors.lightTextPrimary
          : AppColors.darkTextPrimary,
      inversePrimary: brightness == Brightness.dark
          ? AppColors.seed
          : AppColors.seedDark,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(
    ColorScheme colorScheme, {
    bool highContrast = false,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final textColor = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final border = colorScheme.outlineVariant;
    final baseTextTheme = Typography.material2021(
      platform: TargetPlatform.windows,
    ).black.apply(bodyColor: textColor, displayColor: textColor);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.pageBackground,
      useMaterial3: true,
      fontFamilyFallback: const ['Segoe UI', 'Microsoft YaHei UI'],
      textTheme: baseTextTheme.copyWith(
        labelSmall: TextStyle(color: secondaryText, fontSize: 12, height: 1.33),
        labelMedium: TextStyle(
          color: secondaryText,
          fontSize: 13,
          height: 1.38,
        ),
        bodySmall: TextStyle(color: secondaryText, fontSize: 14, height: 1.42),
        bodyMedium: TextStyle(color: textColor, fontSize: 16, height: 1.5),
        titleSmall: TextStyle(color: textColor, fontSize: 16, height: 1.37),
        titleMedium: TextStyle(color: textColor, fontSize: 18, height: 1.33),
        titleLarge: TextStyle(color: textColor, fontSize: 22, height: 1.36),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        shape: Border(bottom: BorderSide(color: border.withValues(alpha: 0.9))),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border.withValues(alpha: 0.95)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceSubtle,
        selectedColor: colorScheme.accentSubtle,
        disabledColor: colorScheme.surfaceSubtle,
        side: BorderSide(color: border.withValues(alpha: 0.9)),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.9),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceSubtle.withValues(alpha: 0.55)
            : colorScheme.surfaceSubtle.withValues(alpha: 0.65),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: secondaryText.withValues(alpha: 0.9)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          foregroundColor: colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        selectedColor: colorScheme.primary,
        selectedTileColor: colorScheme.accentSubtle.withValues(alpha: 0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.accentSubtle,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colorScheme.primary : secondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? colorScheme.primary : secondaryText,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.accentSubtle,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: secondaryText),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: secondaryText),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border.withValues(alpha: 0.9)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      ),
      focusColor: colorScheme.primary.withValues(alpha: 0.14),
      hoverColor: colorScheme.primary.withValues(
        alpha: highContrast ? 0.12 : 0.06,
      ),
    );
  }
}
