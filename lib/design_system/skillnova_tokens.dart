import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/user_role.dart';

/// Semantic colors for SkillNova surfaces and states.
///
/// Product screens should prefer [Theme.of] color values. These constants are
/// the shared source used to build the light and dark color schemes.
/// Palette: "Trusted Green" (UI UX Pro Max — service/trust pattern, green
/// primary #15803D on white = 5.0:1, AA). Every text pairing below was
/// checked for >= 4.5:1; decorative-only tones are marked.
abstract final class SkillNovaColors {
  // Brand -------------------------------------------------------------------
  static const Color primary = Color(0xFF15803D);
  static const Color primaryDark = Color(0xFF14532D);
  static const Color primarySoft = Color(0xFFDCFCE7);
  static const Color secondary = Color(0xFF052E16);
  static const Color accent = Color(0xFF0F766E);
  static const Color accentBright = Color(0xFF34D399);

  /// Role accents. Customer = brand green, Worker = deep teal. Both stay in
  /// the green family so the app reads as one brand.
  static const Color customer = primary;
  static const Color customerSoft = primarySoft;
  static const Color worker = Color(0xFF0F766E);
  static const Color workerDark = Color(0xFF134E4A);
  static const Color workerSoft = Color(0xFFCCFBF1);

  // Neutrals (green-tinted) -------------------------------------------------
  static const Color background = Color(0xFFF6FAF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF5F0);
  static const Color card = surface;
  static const Color textPrimary = Color(0xFF0F1A14);
  static const Color textSecondary = Color(0xFF52615A);

  /// Decorative / disabled only (3:1) — never body text.
  static const Color textTertiary = Color(0xFF8A988F);
  static const Color border = Color(0xFFDDE7E0);
  static const Color borderStrong = Color(0xFFC6D3CA);

  // States ------------------------------------------------------------------
  static const Color success = Color(0xFF067647);
  static const Color successSoft = Color(0xFFDCFAE6);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3E2);
  static const Color error = Color(0xFFD92D20);
  static const Color errorSoft = Color(0xFFFDECEA);
  static const Color info = Color(0xFF0369A1);
  static const Color infoSoft = Color(0xFFE0F2FE);
  static const Color disabled = Color(0xFF8A988F);
  static const Color rating = Color(0xFFF59E0B);

  // Dark --------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF07130D);
  static const Color darkSurface = Color(0xFF0E1D15);
  static const Color darkSurfaceMuted = Color(0xFF15291E);
  static const Color darkTextPrimary = Color(0xFFEEF5F0);
  static const Color darkTextSecondary = Color(0xFFA9BDB1);
  static const Color darkBorder = Color(0xFF24392C);
  static const Color darkPrimary = Color(0xFF4ADE80);

  /// Deep forest used behind brand moments (splash, onboarding hero).
  static const Color ink = Color(0xFF04150C);
  static const Color inkRaised = Color(0xFF0B2416);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B3D20), Color(0xFF15803D), Color(0xFF22C55E)],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B2E1A), ink],
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

  /// Cards and sheets.
  static const double large = 20;
  static const double xlarge = 28;
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
