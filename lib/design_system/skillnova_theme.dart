import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/skillnova_typography.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

abstract final class SkillNovaTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark
        ? SkillNovaColors.darkSurface
        : SkillNovaColors.surface;
    final onSurface = isDark
        ? SkillNovaColors.darkTextPrimary
        : SkillNovaColors.textPrimary;
    final onSurfaceVariant = isDark
        ? SkillNovaColors.darkTextSecondary
        : SkillNovaColors.textSecondary;
    final outline = isDark
        ? SkillNovaColors.darkBorder
        : SkillNovaColors.border;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFF528BFF) : SkillNovaColors.primary,
      // In dark mode the lighter blue keeps links readable (5.3:1 on the
      // surface); dark text on it keeps filled buttons AA too (5.8:1), where
      // white would only reach 3.2:1.
      onPrimary: isDark ? SkillNovaColors.darkBackground : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF14284F)
          : SkillNovaColors.primarySoft,
      onPrimaryContainer: isDark
          ? const Color(0xFFD6E4FF)
          : SkillNovaColors.primaryDark,
      secondary: SkillNovaColors.accent,
      onSecondary: Colors.white,
      // Tonal buttons and selected segments use secondaryContainer; keep
      // them in the brand blue family so every tonal control matches.
      secondaryContainer: isDark
          ? const Color(0xFF1B2F55)
          : const Color(0xFFE3ECFF),
      onSecondaryContainer: isDark
          ? const Color(0xFFD6E4FF)
          : SkillNovaColors.primaryDark,
      tertiary: SkillNovaColors.worker,
      onTertiary: Colors.white,
      error: SkillNovaColors.error,
      onError: Colors.white,
      errorContainer: isDark
          ? const Color(0xFF4A1512)
          : SkillNovaColors.errorSoft,
      onErrorContainer: isDark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF912018),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outline,
      surfaceContainerLowest: isDark
          ? SkillNovaColors.darkBackground
          : SkillNovaColors.background,
      surfaceContainerLow: surface,
      surfaceContainer: isDark
          ? SkillNovaColors.darkSurfaceMuted
          : SkillNovaColors.surfaceMuted,
      surfaceContainerHigh: isDark
          ? const Color(0xFF223047)
          : const Color(0xFFEAEEF3),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2A3A52)
          : const Color(0xFFE3E8EF),
      inverseSurface: isDark
          ? SkillNovaColors.surface
          : SkillNovaColors.secondary,
      onInverseSurface: isDark
          ? SkillNovaColors.textPrimary
          : SkillNovaColors.darkTextPrimary,
      shadow: Colors.black,
      scrim: Colors.black54,
    );

    final textTheme = SkillNovaTypography.textTheme(brightness);
    final radiusMedium = BorderRadius.circular(SkillNovaRadius.medium);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      canvasColor: scheme.surfaceContainerLowest,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.large),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        minVerticalPadding: SkillNovaSpacing.sm,
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? SkillNovaColors.darkSurfaceMuted : scheme.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark
              ? SkillNovaColors.darkTextSecondary
              : SkillNovaColors.textTertiary,
        ),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 3,
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? scheme.primary
              : onSurfaceVariant,
        ),
        suffixIconColor: onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SkillNovaSpacing.md,
          vertical: SkillNovaSpacing.md,
        ),
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outline),
        focusedBorder: inputBorder(scheme.primary, 1.6),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.6),
        disabledBorder: inputBorder(scheme.outline.withValues(alpha: 0.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainer,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark ? scheme.primary : const Color(0xFF8CB3FF),
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SkillNovaRadius.large),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        iconColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          // 12px with tight tracking so the longest label ("Messages") fits
          // a 64px destination on 320px-wide phones without wrapping.
          return textTheme.labelMedium?.copyWith(
            fontSize: 12,
            letterSpacing: -0.1,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.10),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium,
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
