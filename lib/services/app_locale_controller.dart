import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController {
  AppLocaleController._();

  static const String _prefsKey = 'app_locale';
  static const String _defaultLanguageCode = 'vi';
  static const Locale defaultLocale = Locale(_defaultLanguageCode);

  static Future<Locale> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final code = _normalize(saved);
    return Locale(code);
  }

  static Future<Locale> setLocale(String languageCode) async {
    final code = _normalize(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
    return Locale(code);
  }

  static String normalize(String? languageCode) => _normalize(languageCode);

  static String _normalize(String? languageCode) {
    if (languageCode == 'en') return 'en';
    return _defaultLanguageCode;
  }
}
