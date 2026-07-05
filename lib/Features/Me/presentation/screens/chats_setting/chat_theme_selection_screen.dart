import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/theme/chat_theme_model.dart';
import 'package:app/core/theme/chat_themes.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';

class ChatThemeSelectionScreen extends ConsumerWidget {
  const ChatThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(chatThemeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AppText(
          "Chat Theme",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        physics: const BouncingScrollPhysics(),
        itemCount: ChatThemes.availableThemes.length,
        itemBuilder: (context, index) {
          final chatTheme = ChatThemes.availableThemes[index];
          final isSelected = activeTheme.id == chatTheme.id;

          return GestureDetector(
            onTap: () {
              ref.read(chatThemeProvider.notifier).setTheme(chatTheme);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      chatTheme.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isSelected)
                      Icon(CupertinoIcons.checkmark_alt_circle_fill, color: chatTheme.accentColor, size: 24)
                    else
                      Icon(CupertinoIcons.circle, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                _buildThemePreview(chatTheme),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemePreview(ChatTheme chatTheme) {
    final sentTextColor = chatTheme.sentMessageColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final receivedTextColor = chatTheme.receivedMessageColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: chatTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          if (chatTheme.backgroundOverlay != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: chatTheme.backgroundOverlay,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Received Bubble
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: chatTheme.receivedMessageColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      "Hey, how is it going?",
                      style: TextStyle(color: receivedTextColor, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Sent Bubble
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: chatTheme.sentMessageColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      "I'm doing great! The new theme looks amazing.",
                      style: TextStyle(color: sentTextColor, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
