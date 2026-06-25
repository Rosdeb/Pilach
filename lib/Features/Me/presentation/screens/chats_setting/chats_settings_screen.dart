import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/core/utils/app_colour.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';

class ChatsSettingsScreen extends ConsumerWidget {
  const ChatsSettingsScreen({Key? key}) : super(key: key);

  void _showThemeSelectionDialog(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Theme'),
        message: const Text('Choose your preferred display appearance.'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Light Mode'),
            onPressed: () {
              ref.read(themeProvider.notifier).setLightTheme();
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Dark Mode'),
            onPressed: () {
              ref.read(themeProvider.notifier).setDarkTheme();
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('System Default'),
            onPressed: () {
              ref.read(themeProvider.notifier).setSystemTheme();
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current theme states from Riverpod
    final themeState = ref.watch(themeProvider);
    final isSaveToPhotosEnabled = ref.watch(saveToPhotosProvider);
    final isEnterIsSendEnabled = ref.watch(enterIsSendProvider);

    final String currentThemeName;
    switch (themeState.themeMode) {
      case ThemeMode.light:
        currentThemeName = 'Light Mode';
        break;
      case ThemeMode.dark:
        currentThemeName = 'Dark Mode';
        break;
      case ThemeMode.system:
        currentThemeName = 'System Default';
        break;
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- APP BAR ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: AppText(
              "Chats",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8.0),

                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          _buildChatThemeTile(context, "Default chat theme", () {
                            context.push(AppPaths.chat_theme_selection);
                          }),
                          _buildDivider(context),
                          _buildChatThemeTile(context, "Export chat", () {}),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24.0),
                  // --- SECTION 1: DISPLAY & THEME ---
                  _buildSectionHeader(context, 'DISPLAY'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.brightness,
                          iconColor: Colors.purple,
                          title: 'Theme Mode',
                          trailingText: currentThemeName,
                          onTap: () => _showThemeSelectionDialog(context, ref),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.photo_on_rectangle,
                          iconColor: Colors.teal,
                          title: 'Chat Wallpaper',
                          onTap: () {
                            context.push(AppPaths.chat_wallpaper);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 2: CHAT PREFERENCES ---
                  _buildSectionHeader(context, 'CHAT SETTINGS'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchRow(
                          icon: CupertinoIcons.return_icon,
                          iconColor: Colors.blue,
                          title: 'Enter is Send',
                          value: isEnterIsSendEnabled,
                          onChanged: (val) =>
                              ref.read(enterIsSendProvider.notifier).update(val),
                        ),
                        _buildDivider(context),
                        SwitchRow(
                          icon: CupertinoIcons.square_arrow_down,
                          iconColor: AppColors.successGreen,
                          title: 'Save to Photos',
                          value: isSaveToPhotosEnabled,
                          onChanged: (val) =>
                              ref.read(saveToPhotosProvider.notifier).update(val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 3: MAINTENANCE & ARCHIVE ---
                  _buildSectionHeader(context, 'BACKUP & HISTORY'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.cloud_upload,
                          iconColor: Colors.blueAccent,
                          title: 'Chat Backup',
                          trailingText: 'Auto: Weekly',
                          onTap: () {
                            // Navigate to Backup management view
                          },
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.archivebox,
                          iconColor: Colors.orange,
                          title: 'Archive All Chats',
                          showArrow: false,
                          onTap: () {
                            // Trigger Batch Archive Action
                          },
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.trash,
                          iconColor: Colors.red,
                          title: 'Clear All Chats',
                          textColor: Colors.red,
                          showArrow: false,
                          onTap: () {
                            // Trigger Clear Data confirmation dialog
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatThemeTile(BuildContext context, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppText(
              title,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w400,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  // Helper Section Header Layout
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Inline List Item Divider Blueprint
  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor);
  }

  // Navigation Row Component
  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    Color iconColor = AppColors.primary,
    required String title,
    Color? textColor,
    String? trailingText,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? theme.colorScheme.onSurface,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
            ),
          if (trailingText != null && showArrow) const SizedBox(width: 6),
          if (showArrow)
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
        ],
      ),
    );
  }

}

class SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchRow({
    Key? key,
    required this.icon,
    this.iconColor = AppColors.successGreen,
    required this.title,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      trailing: Transform.scale(
        scaleX: 0.80,
        scaleY: 0.80,
        child: CupertinoSwitch(
          value: value,
          activeColor: const Color(0xFF34C759),
          trackColor: theme.colorScheme.onSurface.withOpacity(0.2),
          onChanged: (val) {
            HapticFeedback.lightImpact();
            onChanged(val);
          },
        ),
      ),
    );
  }
}

