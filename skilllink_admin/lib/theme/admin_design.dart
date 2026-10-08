import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// SkillNova palette for the admin console. Values mirror the mobile app's
// `SkillNovaColors` so the console and the product read as one brand.
// Top-level consts so they work inside existing `const` widget trees.

/// Brand blue for primary actions, selection and focus.
const Color kAdminBrand = Color(0xFF155EEF);
const Color kAdminBrandDark = Color(0xFF0B3A91);
const Color kAdminBrandSoft = Color(0xFFEAF1FF);

/// Semantic colors. Green means success only, never "brand".
const Color kAdminSuccess = Color(0xFF079455);
const Color kAdminWarning = Color(0xFFDC6803);
const Color kAdminDanger = Color(0xFFD92D20);

const Color kAdminInk = Color(0xFF0B1B33);
const Color kAdminText = Color(0xFF101828);
const Color kAdminTextMuted = Color(0xFF667085);
const Color kAdminBorder = Color(0xFFE4E7EC);
const Color kAdminCanvas = Color(0xFFF7F8FA);

abstract final class AdminTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: kAdminBrand,
      primary: kAdminBrand,
      onPrimary: Colors.white,
      error: kAdminDanger,
      surface: Colors.white,
    ).copyWith(outline: kAdminBorder, outlineVariant: kAdminBorder);
    final text = GoogleFonts.interTextTheme().apply(
      bodyColor: kAdminText,
      displayColor: kAdminText,
    );
    final radius = BorderRadius.circular(12);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: kAdminCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kAdminText,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kAdminBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: border(kAdminBorder),
        enabledBorder: border(kAdminBorder),
        focusedBorder: border(kAdminBrand, 1.6),
        errorBorder: border(kAdminDanger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: kAdminText,
          side: const BorderSide(color: kAdminBorder),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: kAdminBrandSoft,
        side: const BorderSide(color: kAdminBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: text.labelMedium,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: kAdminBorder, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: kAdminInk,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kAdminBrand,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: text.labelMedium?.copyWith(
          color: kAdminTextMuted,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: text.bodyMedium,
        dividerThickness: 1,
      ),
    );
  }
}
