import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/constants/app_constants.dart';
import 'package:messageapp/core/utils/app_colour.dart';
import 'package:messageapp/core/theme/theme_provider.dart';
import 'package:messageapp/Features/auth/presentation/providers/auth_provider.dart';

import '../providers/setting_providers.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

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
    // Watch the states from Riverpod
    final isPushEnabled = ref.watch(pushNotificationsProvider);
    final themeState = ref.watch(themeProvider);

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

    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- GLASS EFFECT APP BAR ---
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            automaticallyImplyLeading: false,
            expandedHeight: 65.0, // Gives room for the large iOS title layout
            toolbarHeight: 65.0,
            backgroundColor: theme.scaffoldBackgroundColor, // Semi-transparent base
            surfaceTintColor:  theme.scaffoldBackgroundColor,
            centerTitle: false,
            // This is where the magic glass blur effect happens
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24.0, bottom: 16.0),
                  centerTitle: false,
                  title: AppText(
                    'Settings',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use your requested SizedBox here to push content beautifully down
                  const SizedBox(height: 16.0),

                  // --- Your profile card and settings items continue here ---
                  _buildSectionCard(context, [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage('https://cdn.motor1.com/images/mgl/bglVnv/s3/best-new-cars-coming-out-in-2025.webp'), // Replace with actual asset/image
                      ),
                      title: const AppText(
                        'Alex Koch',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: AppText(
                        'alex.koch@brand.com',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
                      ),
                      trailing: Icon(Icons.qr_code_scanner, size: 20, color: theme.colorScheme.onSurface),
                      onTap: () {

                        context.push(AppPaths.qr_screen);

                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // --- ACCOUNT SECTION ---
                  _buildSectionHeader('ACCOUNT'),
                  _buildSectionCard(context, [
                    _buildListTile(
                      context,
                      icon: Icons.person_outline,
                      iconColor: AppColors.successGreen,
                      title: 'Edit Profile',
                      onTap: () {
                        context.push(AppPaths.edit_profile);
                      },
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.mail_outline,
                      iconColor: AppColors.successGreen,
                      title: 'Email Settings',
                      onTap: () {
                        context.push(AppPaths.email_setting);
                      },
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.chat_bubble_outline,
                      iconColor: AppColors.successGreen,
                      title: 'Chats',
                      onTap: () {
                        context.push(AppPaths.chats_setting);
                      },
                    ),

                  ]),
                  const SizedBox(height: 24),

                  // --- PREFERENCES SECTION ---
                  _buildSectionHeader('PREFERENCES'),
                  _buildSectionCard(context, [
                    _buildSwitchTile(
                      context,
                      icon: Icons.notifications_none,
                      iconColor: AppColors.successGreen,
                      title: 'Push Notifications',
                      value: isPushEnabled,
                      onChanged: (val) => ref.read(pushNotificationsProvider.notifier).state = val,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // --- PRIVACY SECTION ---
                  _buildSectionHeader('PRIVACY'),
                  _buildSectionCard(context, [
                    _buildListTile(
                      context,
                      icon: Icons.security,
                      iconColor: AppColors.successGreen,
                      title: 'Security & Privacy',
                      onTap: () {
                        context.push(AppPaths.security_privacy);

                      },
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.block,
                      iconColor: AppColors.successGreen,
                      title: 'Blocked Users',
                      onTap: () {
                        context.push(AppPaths.block_userlist);
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // --- APP CONFIGURATION SECTION ---
                  _buildSectionHeader('APP CONFIGURATION'),
                  _buildSectionCard(context, [
                    _buildListTile(
                      context,
                      icon: Icons.brightness_medium,
                      iconColor: AppColors.successGreen,
                      title: 'Theme Mode',
                      trailingText: currentThemeName,
                      onTap: () => _showThemeSelectionDialog(context, ref),
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.language,
                      iconColor: AppColors.successGreen,
                      title: 'Language',
                      trailingText: 'English (US)',
                      onTap: () {},
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.info_outline,
                      iconColor: AppColors.successGreen,
                      title: 'App Version',
                      trailingText: 'v2.4.0',
                      showArrow: false,
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // --- LOG OUT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: AppColors.destructiveRed,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('Log Out'),
                            content: const Text('Are you sure you want to log out?'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(context),
                              ),
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                onPressed: () {
                                  Navigator.pop(context);
                                  ref.read(authProvider.notifier).logout();
                                },
                                child: const Text('Log Out'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const AppText(
                        'Log Out',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- FOOTER ---
                  Center(
                    child: Column(
                      children: [
                        AppText('Terms of Service • Privacy Policy',
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        AppText('©2026 Pilach Chat Inc.',
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to construct iOS style header labels
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: AppText(title,style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),),
    );
  }

  // Helper container that mimics iOS grouped list appearance
  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  // Helper custom tile line separator
  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56.0),
      child: Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor),
    );
  }

  // Standard Action Row Helper
  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    bool showArrow = true,
    VoidCallback? onTap,
  }) {
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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: theme.colorScheme.onSurface),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
            ),
          if (trailingText != null && showArrow) const SizedBox(width: 8),
          if (showArrow) Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ],
      ),
      onTap: onTap,
    );
  }

  // Toggle Switch Row Helper
  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final switchController = ValueNotifier<bool>(value);

    // Hook up a listener to catch toggle events from AdvancedSwitch and forward them safely to your parent tree callback.
    switchController.addListener(() {
      onChanged(switchController.value);
    });

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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: theme.colorScheme.onSurface),
      ),
      trailing: Transform.scale(
        scaleX: 0.75,
        scaleY: 0.80,
        child: AdvancedSwitch(
          controller: switchController,
          width: 45,
          height: 24,
          activeColor: const Color(0xFF34C759),
          inactiveColor: theme.colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
    );
  }
}