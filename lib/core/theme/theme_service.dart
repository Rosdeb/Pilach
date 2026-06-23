import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'selected_theme_mode';

  final SharedPreferences _prefs;

  ThemeService(this._prefs);

  /// Loads the saved ThemeMode. Defaults to ThemeMode.system if none is saved.
  ThemeMode getThemeMode() {
    final String? themeString = _prefs.getString(_themeKey);
    if (themeString == null) {
      return ThemeMode.system;
    }
    
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Persists the selected ThemeMode.
  Future<bool> saveThemeMode(ThemeMode themeMode) async {
    String themeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    return _prefs.setString(_themeKey, themeString);
  }
}
