import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SkillNova design foundation supports light, dark, and system modes',
    () {
      expect(SkillNovaTheme.light.brightness, Brightness.light);
      expect(SkillNovaTheme.dark.brightness, Brightness.dark);

      SkillNovaThemeController.setMode(ThemeMode.light);
      expect(SkillNovaThemeController.mode.value, ThemeMode.light);

      SkillNovaThemeController.setMode(ThemeMode.dark);
      expect(SkillNovaThemeController.mode.value, ThemeMode.dark);

      SkillNovaThemeController.setMode(ThemeMode.system);
      expect(SkillNovaThemeController.mode.value, ThemeMode.system);
    },
  );
}
