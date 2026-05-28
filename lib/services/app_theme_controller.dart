import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  AppThemeController._();

  static const String _prefsKey = 'app_theme_mode';
  static const ThemeMode defaultThemeMode = ThemeMode.dark;

  static Future<ThemeMode> loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalize(prefs.getString(_prefsKey));
  }

  static Future<ThemeMode> setDarkMode(bool enabled) {
    return setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  static Future<ThemeMode> setThemeMode(ThemeMode themeMode) async {
    final normalized = _normalize(_themeModeName(themeMode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _themeModeName(normalized));
    return normalized;
  }

  static ThemeMode normalize(String? value) => _normalize(value);

  static ThemeMode _normalize(String? value) {
    if (value == 'light') return ThemeMode.light;
    return defaultThemeMode;
  }

  static String _themeModeName(ThemeMode themeMode) {
    return themeMode == ThemeMode.light ? 'light' : 'dark';
  }
}
