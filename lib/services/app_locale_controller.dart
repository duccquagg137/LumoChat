import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController {
  AppLocaleController._();

  static const String _prefsKey = 'app_locale';
  static const String _defaultLanguageCode = 'vi';
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale(_defaultLanguageCode));

  static String get currentLanguageCode => localeNotifier.value.languageCode;

  static Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final code = _normalize(saved);
    localeNotifier.value = Locale(code);
  }

  static Future<void> setLocale(String languageCode) async {
    final code = _normalize(languageCode);
    if (localeNotifier.value.languageCode == code) {
      return;
    }
    localeNotifier.value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  static String _normalize(String? languageCode) {
    if (languageCode == 'en') return 'en';
    return _defaultLanguageCode;
  }
}
