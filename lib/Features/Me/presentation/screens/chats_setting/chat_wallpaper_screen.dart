import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:messageapp/Features/Me/presentation/providers/setting_providers.dart';

class ChatWallpaperScreen extends ConsumerWidget {
  const ChatWallpaperScreen({super.key});

  static const List<Map<String, String>> wallpapers = [
    {
      "name": "Default Theme Background",
      "url": "",
    },
    {
      "name": "Blue Pink Pastel",
      "url": "https://brunty.me/files/chat-bgs/1.0/blue-pink-20-pct.png",
    },
    {
      "name": "Classic Teal",
      "url": "https://brunty.me/files/chat-bgs/1.0/classic-teal.png",
    },
    {
      "name": "Warm Amber",
      "url": "https://brunty.me/files/chat-bgs/1.0/warm-amber.png",
    }
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(chatThemeProvider);
    final currentWallpaper = ref.watch(chatWallpaperProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          "Chat Wallpaper",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Wallpaper Live Preview
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "PREVIEW",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWallpaperPreview(activeTheme, currentWallpaper),
                ],
              ),
            ),
          ),

          // Wallpaper List Options
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "WALLPAPERS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: List.generate(wallpapers.length, (index) {
                        final wall = wallpapers[index];
                        final wallUrl = wall['url']!;
                        final isSelected = (currentWallpaper == null && wallUrl.isEmpty) || (currentWallpaper == wallUrl);

                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(
                                wall['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.teal, size: 22)
                                  : Icon(CupertinoIcons.circle, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 22),
                              onTap: () {
                                ref.read(chatWallpaperProvider.notifier).update(wallUrl.isEmpty ? null : wallUrl);
                              },
                            ),
                            if (index < wallpapers.length - 1)
                              Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperPreview(dynamic chatTheme, String? wallpaperUrl) {
    final sentTextColor = chatTheme.sentMessageColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final receivedTextColor = chatTheme.receivedMessageColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: chatTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        image: wallpaperUrl != null
            ? DecorationImage(
                image: NetworkImage(wallpaperUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (chatTheme.backgroundOverlay != null && wallpaperUrl == null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: chatTheme.backgroundOverlay,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
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
                      "This is a wallpaper preview.",
                      style: TextStyle(color: receivedTextColor, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
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
                      "Looks incredibly premium!",
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
