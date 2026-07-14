import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/utils/app_colour.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/components/FloatingErrorBar/floatingbar.dart';
import 'package:app/Features/auth/presentation/screens/two_factor_email_verify_screen.dart';
import 'package:app/Features/auth/presentation/screens/two_factor_sms_verify_screen.dart';
import '../../providers/two_factor_provider.dart';

class TwoFactorSettingsScreen extends ConsumerStatefulWidget {
  const TwoFactorSettingsScreen({super.key});

  @override
  ConsumerState<TwoFactorSettingsScreen> createState() => _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState extends ConsumerState<TwoFactorSettingsScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showEnrollEmailDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text("Enroll Email 2FA"),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: _emailController,
            placeholder: "Enter email address",
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () {
              _emailController.clear();
              Navigator.pop(dialogContext);
            },
          ),
          CupertinoDialogAction(
            child: const Text("Send Code"),
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(dialogContext);
              
              final success = await ref.read(twoFactorNotifierProvider.notifier).requestEmailEnrollment(email);
              if (!success) {
                if (mounted) {
                  final errorMsg = ref.read(twoFactorNotifierProvider).errorMessage ?? "Failed to send code";
                  FloatingErrorBar.show(context, message: errorMsg);
                }
                return;
              }
              if (!mounted) return;

              _emailController.clear();
              await context.push(
                AppPaths.two_factor_email_verify,
                extra: TwoFactorEmailVerifyArgs(email: email),
              );
              if (mounted) {
                ref.read(twoFactorNotifierProvider.notifier).loadMethods();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEnrollSmsDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text("Enroll SMS 2FA"),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: _phoneController,
            placeholder: "Enter phone number (e.g., +123456789)",
            keyboardType: TextInputType.phone,
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () {
              _phoneController.clear();
              Navigator.pop(dialogContext);
            },
          ),
          CupertinoDialogAction(
            child: const Text("Send Code"),
            onPressed: () async {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty) return;
              Navigator.pop(dialogContext);

              final success = await ref.read(twoFactorNotifierProvider.notifier).requestSmsEnrollment(phone);
              if (!success) {
                if (mounted) {
                  final errorMsg = ref.read(twoFactorNotifierProvider).errorMessage ?? "Failed to send code";
                  FloatingErrorBar.show(context, message: errorMsg);
                }
                return;
              }
              if (!mounted) return;

              _phoneController.clear();
              await context.push(
                AppPaths.two_factor_sms_verify,
                extra: TwoFactorSmsVerifyArgs(phone: phone),
              );
              if (mounted) {
                ref.read(twoFactorNotifierProvider.notifier).loadMethods();
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDisableMethod(dynamic method) {
    if (method == null) return;
    
    String methodId = "";
    String typeLabel = "";
    
    if (method is Map) {
      methodId = method['id']?.toString() ?? "";
      final type = method['type']?.toString().toLowerCase() ?? "";
      typeLabel = type.contains('email') ? 'Email' : 'SMS';
    } else if (method is String) {
      methodId = method;
      typeLabel = method.toLowerCase().contains('email') ? 'Email' : 'SMS';
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Disable $typeLabel 2FA"),
        content: Text("Are you sure you want to disable Two-Factor Authentication via $typeLabel?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Disable"),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(twoFactorNotifierProvider.notifier).disableMethod(methodId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(twoFactorNotifierProvider);
    final theme = Theme.of(context);

    // Parse enrolled methods
    final emailMethod = state.enrolledMethods.firstWhere(
      (m) {
        if (m is Map) {
          final type = m['type']?.toString().toLowerCase() ?? '';
          final isActive = m['isEnabled'] == true || m['is_enabled'] == true || m['enabled'] == true || m['active'] == true || m['is_active'] == true || m['status'] == 'active' || m['status'] == 'enabled';
          return type.contains('email') && isActive;
        }
        if (m is String) {
          return m.toLowerCase().contains('email');
        }
        return false;
      },
      orElse: () => null,
    );
    final smsMethod = state.enrolledMethods.firstWhere(
      (m) {
        if (m is Map) {
          final type = m['type']?.toString().toLowerCase() ?? '';
          final isActive = m['isEnabled'] == true || m['is_enabled'] == true || m['enabled'] == true || m['active'] == true || m['is_active'] == true || m['status'] == 'active' || m['status'] == 'enabled';
          return type.contains('sms') && isActive;
        }
        if (m is String) {
          return m.toLowerCase().contains('sms');
        }
        return false;
      },
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
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
              onPressed: () => context.pop(),
            ),
            title: AppText(
              "Two-Factor Authentication",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  AppText(
                    "Two-factor authentication adds an extra layer of security to your account. In order to log in, you will be required to provide a verification code sent to your enrolled methods.",
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, "AUTHENTICATION METHODS"),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildMethodRow(
                            context,
                            icon: CupertinoIcons.mail,
                            title: "Email Authentication",
                            subtitle: emailMethod != null
                                ? (emailMethod is Map ? (emailMethod['destination'] ?? "Enrolled") : "Enrolled")
                                : "Not Enrolled",
                            isEnrolled: emailMethod != null,
                            onTap: () {
                              if (emailMethod != null) {
                                _confirmDisableMethod(emailMethod);
                              } else {
                                _showEnrollEmailDialog();
                              }
                            },
                          ),
                          _buildDivider(context),
                          _buildMethodRow(
                            context,
                            icon: CupertinoIcons.phone,
                            title: "SMS Authentication",
                            subtitle: smsMethod != null
                                ? (smsMethod is Map ? (smsMethod['destination'] ?? "Enrolled") : "Enrolled")
                                : "Not Enrolled",
                            isEnrolled: smsMethod != null,
                            onTap: () {
                              if (smsMethod != null) {
                                _confirmDisableMethod(smsMethod);
                              } else {
                                _showEnrollSmsDialog();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor);
  }

  Widget _buildMethodRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnrolled,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (isEnrolled ? AppColors.successGreen : Colors.grey).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isEnrolled ? AppColors.successGreen : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isEnrolled
              ? AppColors.successGreen.withOpacity(0.2)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isEnrolled ? "Enabled" : "Setup",
          style: TextStyle(
            color: isEnrolled ? AppColors.successGreen : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
