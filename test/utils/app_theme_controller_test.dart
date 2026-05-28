import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/services/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeController', () {
    test('defaults to dark mode', () async {
      SharedPreferences.setMockInitialValues({});

      final themeMode = await AppThemeController.loadSavedThemeMode();

      expect(themeMode, ThemeMode.dark);
    });

    test('persists light and dark mode selections', () async {
      SharedPreferences.setMockInitialValues({});

      final lightMode = await AppThemeController.setDarkMode(false);
      final loadedLightMode = await AppThemeController.loadSavedThemeMode();

      final darkMode = await AppThemeController.setDarkMode(true);
      final loadedDarkMode = await AppThemeController.loadSavedThemeMode();

      expect(lightMode, ThemeMode.light);
      expect(loadedLightMode, ThemeMode.light);
      expect(darkMode, ThemeMode.dark);
      expect(loadedDarkMode, ThemeMode.dark);
    });
  });
}
