import 'package:flutter/material.dart';

/// Semantic colors for SkillNova surfaces and states.
///
/// Product screens should prefer [Theme.of] color values. These constants are
/// the shared source used to build the light and dark color schemes.
abstract final class SkillNovaColors {
  static const Color primary = Color(0xFF155EEF);
  static const Color primaryDark = Color(0xFF0B3A91);
  static const Color accent = Color(0xFF0E9384);

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F4F8);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);

  static const Color success = Color(0xFF079455);
  static const Color warning = Color(0xFFDC6803);
  static const Color error = Color(0xFFD92D20);
  static const Color disabled = Color(0xFF98A2B3);
  static const Color rating = Color(0xFFF79009);

  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF121B2B);
  static const Color darkSurfaceMuted = Color(0xFF1A2536);
  static const Color darkTextPrimary = Color(0xFFF2F4F7);
  static const Color darkTextSecondary = Color(0xFFAAB4C5);
  static const Color darkBorder = Color(0xFF2A374A);
}

abstract final class SkillNovaSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class SkillNovaRadius {
  static const double small = 10;
  static const double medium = 16;
  static const double large = 24;
  static const double pill = 999;
}

abstract final class SkillNovaElevation {
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
