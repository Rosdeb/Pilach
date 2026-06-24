import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/utils/app_colour.dart';
import 'package:messageapp/core/constants/app_constants.dart';
import 'package:messageapp/core/services/permission_service.dart';
import '../../providers/security_privacy_providers.dart';

class SecurityPrivacyScreen extends ConsumerWidget {
  const SecurityPrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBiometricEnabled = ref.watch(biometricProvider);
    final isTwoFactorEnabled = ref.watch(twoFactorProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- GLASS EFFECT APP BAR ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: AppText(
              "Security & Privacy",
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
                  // --- SECTION 1: SECURITY ---
                  _buildSectionHeader(context, 'LOGIN SECURITY'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.lock,
                          iconColor: AppColors.successGreen,
                          title: 'Change Password',
                          onTap: () {
                            context.push(AppPaths.change_password);
                          },
                        ),
                        _buildDivider(context),
                        _buildSwitchRow(
                          context,
                          icon: CupertinoIcons.device_phone_portrait,
                          title: 'Two-Factor Auth (2FA)',
                          value: isTwoFactorEnabled,
                          onChanged: (val) => ref.read(twoFactorProvider.notifier).state = val,
                        ),
                        _buildDivider(context),
                        _buildSwitchRow(
                          context,
                          icon: CupertinoIcons.qrcode,
                          title: 'Face ID / Touch ID',
                          value: isBiometricEnabled,
                          onChanged: (val) => ref.read(biometricProvider.notifier).state = val,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 2: PRIVACY & PERMISSIONS ---
                  _buildSectionHeader(context, 'APP PERMISSIONS'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.location,
                          title: 'Location Services',
                          trailingText: _getPermissionText(ref.watch(permissionStatusProvider(Permission.locationWhenInUse))),
                          onTap: () => _handlePermissionRequest(context, ref, Permission.locationWhenInUse),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.photo,
                          title: 'Photos Access',
                          trailingText: _getPermissionText(ref.watch(permissionStatusProvider(Permission.photos))),
                          onTap: () => _handlePermissionRequest(context, ref, Permission.photos),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.mic,
                          title: 'Microphone Permissions',
                          trailingText: _getPermissionText(ref.watch(permissionStatusProvider(Permission.microphone))),
                          onTap: () => _handlePermissionRequest(context, ref, Permission.microphone),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 3: DATA MANAGEMENT ---
                  _buildSectionHeader(context, 'DATA MANAGEMENT'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.cloud_download,
                          title: 'Download My Data',
                          onTap: () {},
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.trash,
                          iconColor: Colors.red,
                          title: 'Delete Account',
                          textColor: Colors.red,
                          showArrow: false,
                          onTap: () {},
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

  // Helper Section Header
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

  String _getPermissionText(AsyncValue<PermissionStatus> statusAsync) {
    return statusAsync.when(
      data: (status) {
        if (status.isGranted) return 'Granted';
        if (status.isDenied) return 'Denied';
        if (status.isPermanentlyDenied) return 'Blocked';
        if (status.isLimited) return 'Limited';
        if (status.isRestricted) return 'Restricted';
        return 'Unknown';
      },
      loading: () => 'Checking...',
      error: (_, __) => 'Error',
    );
  }

  Future<void> _handlePermissionRequest(BuildContext context, WidgetRef ref, Permission permission) async {
    final service = ref.read(permissionServiceProvider);
    var status = await service.checkPermission(permission);
    
    if (!context.mounted) return;
    
    if (status.isPermanentlyDenied || status.isRestricted) {
      final openSettings = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Permission Required'),
          content: const Text('This permission is permanently denied or restricted. Please enable it in your app settings.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              child: const Text('Open Settings'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await service.openSettings();
      }
    } else if (!status.isGranted) {
      status = await service.requestPermission(permission);
    }
    
    ref.invalidate(permissionStatusProvider(permission));
  }

  // Helper row divider
  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor);
  }

  // Action Navigation Row Builder
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
        style: TextStyle(color: textColor ?? theme.colorScheme.onSurface, fontWeight: FontWeight.w400, fontSize: 16),
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
          if (showArrow) Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ],
      ),
    );
  }

  // Toggle Switch Row Builder
  Widget _buildSwitchRow(
    BuildContext context, {
    required IconData icon,
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
          color: AppColors.successGreen.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.successGreen, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w400, fontSize: 16),
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