import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SkillNova type scale (Inter).
///
/// | Role       | Material slot   | Size / weight |
/// |------------|-----------------|---------------|
/// | Display    | displaySmall    | 32 / 800      |
/// | Heading 1  | headlineMedium  | 28 / 800      |
/// | Heading 2  | headlineSmall   | 24 / 700      |
/// | Heading 3  | titleLarge      | 20 / 700      |
/// | Title      | titleMedium     | 16 / 700      |
/// | Body       | bodyLarge       | 16 / 400      |
/// | Body (sec) | bodyMedium      | 14 / 400      |
/// | Caption    | bodySmall       | 12 / 400      |
/// | Button     | labelLarge      | 15 / 600      |
/// | Label      | labelMedium     | 13 / 600      |
/// | Overline   | labelSmall      | 11 / 700      |
abstract final class SkillNovaTypography {
  static TextTheme textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFFF2F4F7) : const Color(0xFF101828);
    final secondary = isDark
        ? const Color(0xFFAAB4C5)
        : const Color(0xFF667085);

    return GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          color: primary,
          fontSize: 48,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
        ),
        displayMedium: TextStyle(
          color: primary,
          fontSize: 40,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        displaySmall: TextStyle(
          color: primary,
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        headlineLarge: TextStyle(
          color: primary,
          fontSize: 30,
          height: 1.18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineMedium: TextStyle(
          color: primary,
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: TextStyle(
          color: primary,
          fontSize: 24,
          height: 1.22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
        ),
        titleLarge: TextStyle(
          color: primary,
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleMedium: TextStyle(
          color: primary,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(
          color: primary,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: primary,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: secondary,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: secondary,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: primary,
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: secondary,
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          color: secondary,
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
