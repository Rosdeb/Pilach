import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/utils/app_colour.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/core/services/permission_service.dart';
import 'package:app/Features/auth/presentation/providers/auth_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/setting_providers.dart';
import '../providers/two_factor_provider.dart';
import '../providers/profile_provider.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(twoFactorNotifierProvider.notifier).loadMethods();
    });
    _syncNotificationPermissionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permission whenever the app comes back to foreground
      _syncNotificationPermissionState();
    }
  }

  Future<void> _syncNotificationPermissionState() async {
    final permissionService = ref.read(permissionServiceProvider);
    final status = await permissionService.checkPermission(Permission.notification);

    if (status.isGranted) {
      // Permission is granted — reflect whatever the user last saved
      final prefs = ref.read(sharedPreferencesProvider);
      final saved = prefs.getBool('push_notifications') ?? true;
      ref.read(pushNotificationsProvider.notifier).update(saved);
    } else {
      // Permission not granted — force toggle off
      ref.read(pushNotificationsProvider.notifier).update(false);
    }
  }

  /// Called when the user flips the Push Notifications toggle.
  Future<void> _handlePushToggle(bool enable) async {
    final permissionService = ref.read(permissionServiceProvider);

    if (enable) {
      PermissionStatus status =
          await permissionService.checkPermission(Permission.notification);

      if (status.isDenied) {
        status = await permissionService.requestPermission(Permission.notification);
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          await showCupertinoDialog(
            context: context,
            builder: (c) => CupertinoAlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                  'Please enable push notifications in your device settings.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(c),
                ),
                CupertinoDialogAction(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.pop(c);
                    permissionService.openSettings();
                  },
                ),
              ],
            ),
          );
        }
        // Keep toggle off since permission is permanently denied
        await ref.read(pushNotificationsProvider.notifier).update(false);
        return;
      }

      if (status.isGranted) {
        await ref.read(pushNotificationsProvider.notifier).update(true);
      } else {
        await ref.read(pushNotificationsProvider.notifier).update(false);
      }
    } else {
      await ref.read(pushNotificationsProvider.notifier).update(false);
    }
  }

  void _showThemeSelectionDialog(BuildContext context) {
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
  Widget build(BuildContext context) {
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
            expandedHeight: 65.0,
            toolbarHeight: 65.0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            centerTitle: false,
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
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16.0),

                  // --- PROFILE CARD ---
                  _buildSectionCard(context, [
                    Consumer(
                      builder: (context, ref, child) {
                        ref.watch(profileNotifierProvider);
                        final authState = ref.watch(authProvider);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            backgroundImage: authState.profileImage != null
                                ? CachedNetworkImageProvider(
                                    authState.profileImage!)
                                : null,
                            child: authState.profileImage == null
                                ? Icon(Icons.person,
                                    size: 30,
                                    color: theme.colorScheme.primary)
                                : null,
                          ),
                          title: AppText(
                            authState.name ?? 'Guest User',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: AppText(
                            authState.email ?? 'No email available',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 14),
                          ),
                          trailing: Icon(Icons.qr_code_scanner,
                              size: 20, color: theme.colorScheme.onSurface),
                          onTap: () {
                            context.push(AppPaths.qr_screen);
                          },
                        );
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
                      onTap: () => context.push(AppPaths.edit_profile),
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.mail_outline,
                      iconColor: AppColors.successGreen,
                      title: 'Email Settings',
                      onTap: () => context.push(AppPaths.email_setting),
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.chat_bubble_outline,
                      iconColor: AppColors.successGreen,
                      title: 'Chats',
                      onTap: () => context.push(AppPaths.chats_setting),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // --- PREFERENCES SECTION ---
                  _buildSectionHeader('PREFERENCES'),
                  _buildSectionCard(context, [
                    Consumer(
                      builder: (context, ref, child) {
                        // Watch the provider — rebuilds automatically when value changes
                        final isPushEnabled =
                            ref.watch(pushNotificationsProvider);
                        return _buildSwitchTile(
                          context,
                          icon: Icons.notifications_none,
                          iconColor: AppColors.successGreen,
                          title: 'Push Notifications',
                          value: isPushEnabled,
                          onChanged: (bool enabled) {
                            _handlePushToggle(enabled);
                          },
                        );
                      },
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
                      onTap: () => context.push(AppPaths.security_privacy),
                    ),
                    _buildDivider(context),
                    _buildListTile(
                      context,
                      icon: Icons.block,
                      iconColor: AppColors.successGreen,
                      title: 'Blocked Users',
                      onTap: () => context.push(AppPaths.block_userlist),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // --- APP CONFIGURATION SECTION ---
                  _buildSectionHeader('APP CONFIGURATION'),
                  _buildSectionCard(context, [
                    Consumer(
                      builder: (context, ref, child) {
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
                        return _buildListTile(
                          context,
                          icon: Icons.brightness_medium,
                          iconColor: AppColors.successGreen,
                          title: 'Theme Mode',
                          trailingText: currentThemeName,
                          onTap: () => _showThemeSelectionDialog(context),
                        );
                      },
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
                            content:
                                const Text('Are you sure you want to log out?'),
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
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- FOOTER ---
                  Center(
                    child: Column(
                      children: [
                        AppText(
                          'Terms of Service • Privacy Policy',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          '©2026 Pilach Chat Inc.',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                              fontSize: 12),
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

  // ─── Helper: iOS-style section label ─────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: AppText(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ─── Helper: grouped card container ──────────────────────────────────────
  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  // ─── Helper: separator line ───────────────────────────────────────────────
  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56.0),
      child: Divider(
          height: 1,
          thickness: 0.5,
          color: Theme.of(context).dividerColor),
    );
  }

  // ─── Helper: standard action row ─────────────────────────────────────────
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
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16),
            ),
          if (trailingText != null && showArrow) const SizedBox(width: 8),
          if (showArrow)
            Icon(Icons.arrow_forward_ios,
                size: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required void Function(bool) onChanged,
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
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface),
      ),
      trailing: Transform.scale(
        scaleX: 0.85,
        scaleY: 0.85,
        child: AdvancedSwitch(
          initialValue: value,
          onChanged: (val) => onChanged(val),
          activeColor: const Color(0xFF34C759),
          inactiveColor: theme.colorScheme.onSurface.withOpacity(0.15),
        ),
      ),
    );
  }
}
