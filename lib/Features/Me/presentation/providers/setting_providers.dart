import 'package:flutter_riverpod/legacy.dart';
// Provider to manage Push Notifications state
final pushNotificationsProvider = StateProvider<bool>((ref) => true);

// Provider to manage Dark Mode state
final darkModeProvider = StateProvider<bool>((ref) => false);