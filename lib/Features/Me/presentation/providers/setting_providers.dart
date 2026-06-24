import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:messageapp/core/theme/theme_provider.dart';

class BoolPreferenceNotifier extends StateNotifier<bool> {
  final SharedPreferences prefs;
  final String prefKey;

  BoolPreferenceNotifier(this.prefs, this.prefKey, bool defaultValue)
      : super(prefs.getBool(prefKey) ?? defaultValue);

  Future<void> update(bool value) async {
    state = value;
    await prefs.setBool(prefKey, value);
  }
}

// Provider to manage Push Notifications state
final pushNotificationsProvider = StateNotifierProvider<BoolPreferenceNotifier, bool>((ref) {
  return BoolPreferenceNotifier(ref.watch(sharedPreferencesProvider), 'push_notifications', true);
});

// Provider to manage Dark Mode state (legacy wrapper)
final darkModeProvider = StateProvider<bool>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.isDarkMode;
});

// Provider to manage Save to Photos state
final saveToPhotosProvider = StateNotifierProvider<BoolPreferenceNotifier, bool>((ref) {
  return BoolPreferenceNotifier(ref.watch(sharedPreferencesProvider), 'save_to_photos', true);
});

// Provider to manage Enter is Send state
final enterIsSendProvider = StateNotifierProvider<BoolPreferenceNotifier, bool>((ref) {
  return BoolPreferenceNotifier(ref.watch(sharedPreferencesProvider), 'enter_is_send', false);
});

class StringPreferenceNotifier extends StateNotifier<String?> {
  final SharedPreferences prefs;
  final String prefKey;

  StringPreferenceNotifier(this.prefs, this.prefKey, String? defaultValue)
      : super(prefs.getString(prefKey) ?? defaultValue);

  Future<void> update(String? value) async {
    state = value;
    if (value != null) {
      await prefs.setString(prefKey, value);
    } else {
      await prefs.remove(prefKey);
    }
  }
}

// Provider to manage Chat Wallpaper URL
final chatWallpaperProvider = StateNotifierProvider<StringPreferenceNotifier, String?>((ref) {
  return StringPreferenceNotifier(ref.watch(sharedPreferencesProvider), 'chat_wallpaper', null);
});