import 'package:flutter_riverpod/legacy.dart';
import 'package:messageapp/core/theme/theme_provider.dart';

// Provider to manage Push Notifications state
final pushNotificationsProvider = StateProvider<bool>((ref) => true);

// Provider to manage Dark Mode state (legacy wrapper)
final darkModeProvider = StateProvider<bool>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.isDarkMode;
});