import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_service.dart';

// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in ProviderScope');
});

// Provider for ThemeService
final themeServiceProvider = Provider<ThemeService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeService(prefs);
});

// ThemeState representation matching the plan
class ThemeState {
  final ThemeMode themeMode;
  final bool isDarkMode;
  final bool isSystemMode;

  const ThemeState({
    required this.themeMode,
    required this.isDarkMode,
    required this.isSystemMode,
  });

  bool get isLightMode => !isDarkMode;

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDarkMode,
    bool? isSystemMode,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isSystemMode: isSystemMode ?? this.isSystemMode,
    );
  }
}

// ThemeNotifier using Notifier to manage ThemeState
class ThemeNotifier extends Notifier<ThemeState> {
  late ThemeService _themeService;

  @override
  ThemeState build() {
    _themeService = ref.watch(themeServiceProvider);
    final themeMode = _themeService.getThemeMode();
    return _resolveState(themeMode);
  }

  ThemeState _resolveState(ThemeMode themeMode) {
    bool isDark;
    if (themeMode == ThemeMode.system) {
      // Read initial system brightness
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } else {
      isDark = themeMode == ThemeMode.dark;
    }

    return ThemeState(
      themeMode: themeMode,
      isDarkMode: isDark,
      isSystemMode: themeMode == ThemeMode.system,
    );
  }

  /// Sets the theme mode and persists the choice.
  Future<void> setTheme(ThemeMode themeMode) async {
    state = _resolveState(themeMode);
    await _themeService.saveThemeMode(themeMode);
  }

  /// Toggles between Light and Dark mode.
  Future<void> toggleTheme() async {
    if (state.themeMode == ThemeMode.light) {
      await setDarkTheme();
    } else {
      await setLightTheme();
    }
  }

  Future<void> setLightTheme() => setTheme(ThemeMode.light);
  Future<void> setDarkTheme() => setTheme(ThemeMode.dark);
  Future<void> setSystemTheme() => setTheme(ThemeMode.system);

  /// Synchronizes dynamic changes (e.g. system brightness updates at runtime)
  void updateResolvedDarkMode(bool isDark) {
    if (state.isDarkMode != isDark) {
      state = state.copyWith(isDarkMode: isDark);
    }
  }
}

// Global provider for ThemeState
final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
