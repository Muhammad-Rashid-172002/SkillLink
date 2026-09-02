import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/skillnova_typography.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

abstract final class SkillNovaTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: SkillNovaColors.primary,
      onPrimary: Colors.white,
      secondary: SkillNovaColors.accent,
      onSecondary: Colors.white,
      error: SkillNovaColors.error,
      onError: Colors.white,
      surface: isDark ? SkillNovaColors.darkSurface : SkillNovaColors.surface,
      onSurface: isDark
          ? SkillNovaColors.darkTextPrimary
          : SkillNovaColors.textPrimary,
      outline: isDark ? SkillNovaColors.darkBorder : SkillNovaColors.border,
      outlineVariant: isDark
          ? SkillNovaColors.darkBorder
          : SkillNovaColors.border,
      surfaceContainerLowest: isDark
          ? SkillNovaColors.darkBackground
          : SkillNovaColors.background,
      surfaceContainerLow: isDark
          ? SkillNovaColors.darkSurface
          : SkillNovaColors.surface,
      surfaceContainer: isDark
          ? SkillNovaColors.darkSurfaceMuted
          : SkillNovaColors.surfaceMuted,
    );

    final textTheme = SkillNovaTypography.textTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? SkillNovaColors.darkBackground
          : SkillNovaColors.background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SkillNovaSpacing.md,
          vertical: SkillNovaSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkillNovaRadius.small),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
    );
  }
}

/// Single application-level source for Light, Dark, and System mode.
class SkillNovaThemeController {
  SkillNovaThemeController._();

  static ValueNotifier<ThemeMode> get mode => _mode;
  static final ValueNotifier<ThemeMode> _mode = ValueNotifier(ThemeMode.system);

  static void syncFromPreferences() {
    _mode.value = skillNovaPreferences.themeMode;
  }

  static Future<bool> setMode(ThemeMode value) async {
    _mode.value = value;
    return skillNovaPreferences.setThemeMode(value);
  }
}
