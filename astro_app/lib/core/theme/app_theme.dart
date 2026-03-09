import 'package:flutter/material.dart';
import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/constants/app_typography.dart';

/// Sistema de temas de ASTRO — Dark (default) y Light.
/// Inspirado en Nothing Phone: monocromático + acento rojo.
abstract final class AppTheme {
  // ══════════════════════════════════════════════════════════
  //  DARK THEME (default)
  // ══════════════════════════════════════════════════════════

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.nothingRed,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      primary: AppColors.nothingRed,
      onPrimary: AppColors.white,
      secondary: AppColors.grey400,
      onSecondary: AppColors.black,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.nothingRed.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.labelMedium.copyWith(color: AppColors.grey400),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.nothingRed.withValues(alpha: 0.15),
        selectedIconTheme: const IconThemeData(color: AppColors.nothingRed),
        unselectedIconTheme: const IconThemeData(color: AppColors.grey600),
        selectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.nothingRed,
        ),
        unselectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.grey600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.nothingRed, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey400),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.nothingRed,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.nothingRed,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkCard,
        side: const BorderSide(color: AppColors.darkBorder),
        labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkElevated,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ══════════════════════════════════════════════════════════

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.nothingRed,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
      primary: AppColors.nothingRed,
      onPrimary: AppColors.white,
      secondary: AppColors.grey600,
      onSecondary: AppColors.white,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.black,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.nothingRed.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.labelMedium.copyWith(color: AppColors.grey600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.nothingRed.withValues(alpha: 0.12),
        selectedIconTheme: const IconThemeData(color: AppColors.nothingRed),
        unselectedIconTheme: const IconThemeData(color: AppColors.grey600),
        selectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.nothingRed,
        ),
        unselectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.grey600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.nothingRed, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey600),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.nothingRed,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.nothingRed,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightElevated,
        side: const BorderSide(color: AppColors.lightBorder),
        labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.grey800,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TEXT THEME BUILDER
  // ══════════════════════════════════════════════════════════

  static TextTheme _buildTextTheme(Brightness brightness) {
    final Color onSurface = brightness == Brightness.dark
        ? AppColors.white
        : AppColors.black;
    final Color onSurfaceVariant = brightness == Brightness.dark
        ? AppColors.grey400
        : AppColors.grey600;

    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: onSurface),
      displayMedium: AppTypography.displayMedium.copyWith(color: onSurface),
      displaySmall: AppTypography.displaySmall.copyWith(color: onSurface),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: onSurface),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: onSurface),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: onSurface),
      titleLarge: AppTypography.titleLarge.copyWith(color: onSurface),
      titleMedium: AppTypography.titleMedium.copyWith(color: onSurface),
      titleSmall: AppTypography.titleSmall.copyWith(color: onSurfaceVariant),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: onSurface),
      bodySmall: AppTypography.bodySmall.copyWith(color: onSurfaceVariant),
      labelLarge: AppTypography.labelLarge.copyWith(color: onSurface),
      labelMedium: AppTypography.labelMedium.copyWith(color: onSurfaceVariant),
      labelSmall: AppTypography.labelSmall.copyWith(color: onSurfaceVariant),
    );
  }
}
