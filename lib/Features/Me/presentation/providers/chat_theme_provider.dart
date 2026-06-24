import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:messageapp/core/theme/theme_provider.dart';
import 'package:messageapp/core/theme/chat_theme_model.dart';
import 'package:messageapp/core/theme/chat_themes.dart';

class ChatThemeNotifier extends Notifier<ChatTheme> {
  static const _themeKey = 'selected_chat_theme_id';

  @override
  ChatTheme build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedThemeId = prefs.getString(_themeKey);
    
    if (savedThemeId != null) {
      try {
        return ChatThemes.availableThemes.firstWhere((theme) => theme.id == savedThemeId);
      } catch (_) {
        return ChatThemes.defaultWhite;
      }
    }
    return ChatThemes.defaultWhite;
  }

  Future<void> setTheme(ChatTheme theme) async {
    state = theme;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_themeKey, theme.id);
  }
}

final chatThemeProvider = NotifierProvider<ChatThemeNotifier, ChatTheme>(ChatThemeNotifier.new);
