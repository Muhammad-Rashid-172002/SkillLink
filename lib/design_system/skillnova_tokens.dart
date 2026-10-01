import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/user_role.dart';

/// Semantic colors for SkillNova surfaces and states.
///
/// Product screens should prefer [Theme.of] color values. These constants are
/// the shared source used to build the light and dark color schemes.
abstract final class SkillNovaColors {
  // Brand -------------------------------------------------------------------
  static const Color primary = Color(0xFF155EEF);
  static const Color primaryDark = Color(0xFF0B3A91);
  static const Color primarySoft = Color(0xFFEAF1FF);
  static const Color secondary = Color(0xFF0B1B33);
  static const Color accent = Color(0xFF0E9384);
  static const Color accentBright = Color(0xFF14B8A6);

  /// Role accents. Customer = trust blue, Worker = growth emerald.
  static const Color customer = primary;
  static const Color customerSoft = primarySoft;
  static const Color worker = Color(0xFF0E9F6E);
  static const Color workerDark = Color(0xFF05603A);
  static const Color workerSoft = Color(0xFFE7F8F0);

  // Neutrals ----------------------------------------------------------------
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F4F8);
  static const Color card = surface;
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textTertiary = Color(0xFF98A2B3);
  static const Color border = Color(0xFFE4E7EC);
  static const Color borderStrong = Color(0xFFD0D5DD);

  // States ------------------------------------------------------------------
  static const Color success = Color(0xFF079455);
  static const Color successSoft = Color(0xFFE7F7EF);
  static const Color warning = Color(0xFFDC6803);
  static const Color warningSoft = Color(0xFFFEF4E6);
  static const Color error = Color(0xFFD92D20);
  static const Color errorSoft = Color(0xFFFDECEA);
  static const Color info = Color(0xFF1570EF);
  static const Color infoSoft = Color(0xFFEAF2FF);
  static const Color disabled = Color(0xFF98A2B3);
  static const Color rating = Color(0xFFF79009);

  // Dark --------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF121B2B);
  static const Color darkSurfaceMuted = Color(0xFF1A2536);
  static const Color darkTextPrimary = Color(0xFFF2F4F7);
  static const Color darkTextSecondary = Color(0xFFAAB4C5);
  static const Color darkBorder = Color(0xFF2A374A);

  /// Deep navy used behind brand moments (splash, onboarding hero).
  static const Color ink = Color(0xFF07111F);
  static const Color inkRaised = Color(0xFF0E1C33);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF155EEF), Color(0xFF0BA5C4), Color(0xFF16B364)],
    stops: [0, 0.6, 1],
  );

  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1B33), ink],
  );

  static Color roleColor(UserRole? role) =>
      role == UserRole.worker ? worker : customer;

  static Color roleSoft(UserRole? role) =>
      role == UserRole.worker ? workerSoft : customerSoft;
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
  static const double huge = 48;
  static const double giant = 64;

  /// Standard horizontal page gutter on phones.
  static const double gutter = 20;
}

abstract final class SkillNovaRadius {
  static const double xsmall = 8;
  static const double small = 10;
  static const double medium = 16;
  static const double large = 24;
  static const double xlarge = 32;
  static const double pill = 999;
}

abstract final class SkillNovaElevation {
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1F101828), blurRadius: 40, offset: Offset(0, 18)),
  ];
}

/// Motion tokens. Keep animations short and purposeful.
abstract final class SkillNovaMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Honour the OS "reduce motion" accessibility setting.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Responsive breakpoints.
abstract final class SkillNovaBreakpoints {
  static const double tablet = 720;
  static const double desktop = 1080;
  static const double maxReadableWidth = 560;
  static const double maxContentWidth = 1200;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}
