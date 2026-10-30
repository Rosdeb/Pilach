import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/utils/app_colour.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/services/permission_service.dart';
import 'package:app/components/FloatingErrorBar/floatingbar.dart';
import 'package:app/Features/auth/presentation/providers/auth_provider.dart';
import '../../providers/security_privacy_providers.dart';
import '../../providers/two_factor_provider.dart';
import '../../providers/device_session_provider.dart';

class SecurityPrivacyScreen extends ConsumerStatefulWidget {
  const SecurityPrivacyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends ConsumerState<SecurityPrivacyScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(twoFactorNotifierProvider.notifier).loadMethods();
      ref.read(privacyNotifierProvider.notifier).loadSettings();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionStatusProvider(Permission.locationWhenInUse));
      ref.invalidate(permissionStatusProvider(Permission.photos));
      ref.invalidate(permissionStatusProvider(Permission.microphone));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBiometricEnabled = ref.watch(biometricProvider);
    final twoFactorState = ref.watch(twoFactorNotifierProvider);
    final privacyState = ref.watch(privacyNotifierProvider);
    final isTwoFactorEnabled = twoFactorState.enrolledMethods.any((m) {
      if (m is Map) {
        return m['isEnabled'] == true || m['is_enabled'] == true || m['enabled'] == true || m['active'] == true || m['is_active'] == true || m['status'] == 'active' || m['status'] == 'enabled';
      }
      return false;
    });
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
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.device_phone_portrait,
                          iconColor: AppColors.successGreen,
                          title: 'Two-Factor Auth (2FA)',
                          trailingText: isTwoFactorEnabled ? 'Enabled' : 'Disabled',
                          onTap: () {
                            context.push(AppPaths.two_factor_settings);
                          },
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.device_laptop,
                          iconColor: AppColors.successGreen,
                          title: 'Devices & Active Sessions',
                          trailingText: '${ref.watch(deviceSessionsProvider).length} Active',
                          onTap: () {
                            context.push(AppPaths.devices);
                          },
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

                  // --- SECTION 2: PRIVACY (WHO CAN SEE MY INFO) ---
                  _buildSectionHeader(context, 'PRIVACY CONTROLS'),
                  Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.eye,
                          iconColor: AppColors.successGreen,
                          title: 'Last Seen & Online',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('LAST_SEEN')),
                          onTap: () => _showPrivacyPicker(context, 'LAST_SEEN', 'Last Seen & Online'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.person_crop_circle,
                          iconColor: AppColors.successGreen,
                          title: 'Profile Photo',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('PROFILE_PHOTO')),
                          onTap: () => _showPrivacyPicker(context, 'PROFILE_PHOTO', 'Profile Photo'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.info_circle,
                          iconColor: AppColors.successGreen,
                          title: 'About / Bio',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('BIO')),
                          onTap: () => _showPrivacyPicker(context, 'BIO', 'About / Bio'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.phone,
                          iconColor: AppColors.successGreen,
                          title: 'Phone Number',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('PHONE_NUMBER')),
                          onTap: () => _showPrivacyPicker(context, 'PHONE_NUMBER', 'Phone Number'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.checkmark_seal,
                          iconColor: AppColors.successGreen,
                          title: 'Read Receipts',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('READ_RECEIPTS')),
                          onTap: () => _showPrivacyPicker(context, 'READ_RECEIPTS', 'Read Receipts'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.phone_fill,
                          iconColor: AppColors.successGreen,
                          title: 'Calls',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('CALLS')),
                          onTap: () => _showPrivacyPicker(context, 'CALLS', 'Calls'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.person_2,
                          iconColor: AppColors.successGreen,
                          title: 'Group Invites',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('GROUP_INVITES')),
                          onTap: () => _showPrivacyPicker(context, 'GROUP_INVITES', 'Group Invites'),
                        ),
                        _buildDivider(context),
                        _buildActionRow(
                          context,
                          icon: CupertinoIcons.play_circle,
                          iconColor: AppColors.successGreen,
                          title: 'Stories',
                          trailingText: _formatPrivacyLevel(privacyState.getLevel('STORIES')),
                          onTap: () => _showPrivacyPicker(context, 'STORIES', 'Stories'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 3: APP PERMISSIONS ---
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
                          onTap: () => _showDeleteAccountSheet(context),
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

  void _showDeleteAccountSheet(BuildContext context) {
    final passwordController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final twoFactorState = ref.watch(twoFactorNotifierProvider);
            final activeMethods = twoFactorState.enrolledMethods
                .where((m) {
                  if (m is Map) {
                    return m['isEnabled'] == true || m['is_enabled'] == true || m['enabled'] == true || m['active'] == true || m['is_active'] == true || m['status'] == 'active' || m['status'] == 'enabled';
                  }
                  return false;
                })
                .toList();
            final is2FaActive = activeMethods.isNotEmpty;
            final isLoading = twoFactorState.isLoading;

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 30,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppText(
                          "Delete Account",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    "Warning: Deleting your account is permanent. All your chats, contacts, profile info, and files will be permanently erased.",
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (is2FaActive) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.shield_fill, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              AppText(
                                "Two-Factor Authentication is Active",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            "You must remove Two-Factor Authentication or confirm with your password before deletion.",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: isLoading
                                ? const CupertinoActivityIndicator(color: Colors.white)
                                : const Icon(CupertinoIcons.shield_slash, size: 16),
                            label: const Text("Remove 2FA Now", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final confirmRemove = await showCupertinoDialog<bool>(
                                      context: sheetContext,
                                      builder: (dialogContext) => CupertinoAlertDialog(
                                        title: const Text("Remove 2FA"),
                                        content: const Text("Are you sure you want to disable all Two-Factor Authentication methods first?"),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text("Cancel"),
                                            onPressed: () => Navigator.pop(dialogContext, false),
                                          ),
                                          CupertinoDialogAction(
                                            isDestructiveAction: true,
                                            child: const Text("Remove"),
                                            onPressed: () => Navigator.pop(dialogContext, true),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmRemove == true) {
                                      bool anySuccess = false;
                                      for (var method in activeMethods) {
                                        final methodId = method['id']?.toString() ?? "";
                                        if (methodId.isNotEmpty) {
                                          final success = await ref.read(twoFactorNotifierProvider.notifier).disableMethod(methodId);
                                          if (success) anySuccess = true;
                                        }
                                      }
                                      setSheetState(() {});
                                      if (anySuccess && sheetContext.mounted) {
                                        showCupertinoDialog(
                                          context: sheetContext,
                                          builder: (dialogContext) => CupertinoAlertDialog(
                                            title: const Text("2FA Removed"),
                                            content: const Text("All active Two-Factor Authentication methods have been successfully removed."),
                                            actions: [
                                              CupertinoDialogAction(
                                                child: const Text("OK"),
                                                onPressed: () => Navigator.pop(dialogContext),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppText(
                    "Confirm with your password:",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: passwordController,
                    placeholder: "Enter account password",
                    obscureText: true,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: AppText("Cancel", style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final password = passwordController.text.trim();
                            if (password.isEmpty) {
                              FloatingErrorBar.show(context, message: "Please enter your password to confirm deletion.");
                              return;
                            }
                            Navigator.pop(sheetContext);
                            showCupertinoDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 15)),
                            );
                            await Future.delayed(const Duration(seconds: 2));
                            if (context.mounted) {
                              Navigator.pop(context);
                              FloatingErrorBar.show(context, message: "Your account has been deleted successfully.");
                              await ref.read(authProvider.notifier).logout();
                            }
                          },
                          child: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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

  String _formatPrivacyLevel(String level) {
    switch (level.toUpperCase()) {
      case 'EVERYONE':
        return 'Everyone';
      case 'CONTACTS':
        return 'My Contacts';
      case 'NOBODY':
        return 'Nobody';
      default:
        return 'Everyone';
    }
  }

  void _showPrivacyPicker(BuildContext context, String scope, String title) {
    final currentLevel = ref.read(privacyNotifierProvider).getLevel(scope);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppText(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                AppText(
                  "Choose who can see your ${title.toLowerCase()}",
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLevelTile(sheetContext, scope, 'Everyone', 'EVERYONE', currentLevel),
                _buildLevelTile(sheetContext, scope, 'My Contacts', 'CONTACTS', currentLevel),
                _buildLevelTile(sheetContext, scope, 'Nobody', 'NOBODY', currentLevel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelTile(
    BuildContext sheetContext,
    String scope,
    String label,
    String level,
    String currentLevel,
  ) {
    final isSelected = currentLevel.toUpperCase() == level.toUpperCase();
    final theme = Theme.of(sheetContext);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.successGreen : theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.successGreen)
          : null,
      onTap: () async {
        Navigator.pop(sheetContext);
        final ok = await ref
            .read(privacyNotifierProvider.notifier)
            .updateScope(scope, level);
        if (mounted) {
          FloatingErrorBar.show(
            context,
            message: ok ? '$label selected' : 'Failed to update privacy setting',
          );
        }
      },
    );
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