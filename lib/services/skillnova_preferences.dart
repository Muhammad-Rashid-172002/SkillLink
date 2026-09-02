import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SkillNovaPreferenceStore {
  Future<String?> readString(String key);
  Future<bool?> readBool(String key);
  Future<bool> writeString(String key, String value);
  Future<bool> writeBool(String key, bool value);
}

class SharedPreferencesStore implements SkillNovaPreferenceStore {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<String?> readString(String key) async =>
      (await _preferences).getString(key);

  @override
  Future<bool?> readBool(String key) async => (await _preferences).getBool(key);

  @override
  Future<bool> writeString(String key, String value) async =>
      (await _preferences).setString(key, value);

  @override
  Future<bool> writeBool(String key, bool value) async =>
      (await _preferences).setBool(key, value);
}

/// Device-only preferences that have genuine behavior in the current app.
class SkillNovaPreferencesController extends ChangeNotifier {
  SkillNovaPreferencesController({SkillNovaPreferenceStore? store})
    : _store = store ?? SharedPreferencesStore();

  static const String themeKey = 'skillnova_theme_mode';
  static const String notificationKey = 'notifications_enabled';

  final SkillNovaPreferenceStore _store;
  ThemeMode _themeMode = ThemeMode.system;
  bool _localNotificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  bool get localNotificationsEnabled => _localNotificationsEnabled;

  Future<void> load() async {
    final values = await Future.wait<Object?>([
      _store.readString(themeKey),
      _store.readBool(notificationKey),
    ]);
    _themeMode = _themeFromName(values[0] as String?);
    _localNotificationsEnabled = values[1] as bool? ?? true;
    notifyListeners();
  }

  Future<bool> setThemeMode(ThemeMode value) async {
    final saved = await _store.writeString(themeKey, value.name);
    if (!saved) return false;
    _themeMode = value;
    notifyListeners();
    return true;
  }

  Future<bool> setLocalNotificationsEnabled(bool value) async {
    final saved = await _store.writeBool(notificationKey, value);
    if (!saved) return false;
    _localNotificationsEnabled = value;
    notifyListeners();
    return true;
  }

  ThemeMode _themeFromName(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final SkillNovaPreferencesController skillNovaPreferences =
    SkillNovaPreferencesController();
