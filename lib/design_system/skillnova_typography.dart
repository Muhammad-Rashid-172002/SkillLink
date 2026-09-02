import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class SkillNovaTypography {
  static TextTheme textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFFF2F4F7) : const Color(0xFF101828);
    final secondary = isDark
        ? const Color(0xFFAAB4C5)
        : const Color(0xFF667085);

    return GoogleFonts.interTextTheme(
      TextTheme(
        displaySmall: TextStyle(
          color: primary,
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          color: primary,
          fontSize: 24,
          height: 1.2,
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
        labelLarge: TextStyle(
          color: primary,
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: secondary,
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: TextStyle(
          color: secondary,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
