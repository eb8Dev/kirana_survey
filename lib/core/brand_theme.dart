import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandColors {
  static const Color primary = Color(0xFF2182BF);
  static const Color secondary = Color(0xFF78A64B);
  static const Color accent = Color(0xFFAEBF2C);
  static const Color surfaceTint = Color(0xFFF2F2F2);
  static const Color background = Colors.white;
  static const Color ink = Color(0xFF163047);
  static const Color muted = Color(0xFF6C7A89);
  static const Color border = Color(0xFFDDE5EC);
}

ThemeData buildBrandTheme() {
  final baseTextTheme = GoogleFonts.dmSansTextTheme();

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: BrandColors.background,
    colorScheme: const ColorScheme.light(
      primary: BrandColors.primary,
      secondary: BrandColors.secondary,
      tertiary: BrandColors.accent,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: BrandColors.ink,
      outline: BrandColors.border,
    ),
    textTheme: baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: BrandColors.ink,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: BrandColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: BrandColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: BrandColors.ink,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: BrandColors.ink,
        height: 1.45,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: BrandColors.muted,
        height: 1.45,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: BrandColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: BrandColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrandColors.surfaceTint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: BrandColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: BrandColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: BrandColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: baseTextTheme.bodyMedium?.copyWith(color: BrandColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BrandColors.border,
        disabledForegroundColor: BrandColors.muted,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.ink,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: BrandColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: BrandColors.surfaceTint,
      selectedColor: BrandColors.primary.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: BrandColors.border),
      ),
      labelStyle: baseTextTheme.labelMedium?.copyWith(
        color: BrandColors.ink,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: BrandColors.border),
    ),
  );
}
