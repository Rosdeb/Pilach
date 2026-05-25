import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../components/AppText/appText.dart';
import '../../../../../core/utils/app_colour.dart';
import '../../providers/security_privacy_providers.dart';
// Import your AppColors and providers here

class SecurityPrivacyScreen extends ConsumerWidget {
  const SecurityPrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBiometricEnabled = ref.watch(biometricProvider);
    final isTwoFactorEnabled = ref.watch(twoFactorProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- GLASS EFFECT APP BAR ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            backgroundColor: AppColors.background,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.back_icon, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const AppText(
              "Security & Privacy",
              style: TextStyle(
                color: AppColors.textDark,
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
                  _buildSectionHeader('LOGIN SECURITY'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          icon: CupertinoIcons.lock,
                          iconColor: AppColors.successGreen,
                          title: 'Change Password',
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildSwitchRow(
                          icon: CupertinoIcons.device_phone_portrait,
                          title: 'Two-Factor Auth (2FA)',
                          value: isTwoFactorEnabled,
                          onChanged: (val) => ref.read(twoFactorProvider.notifier).state = val,
                        ),
                        _buildDivider(),
                        _buildSwitchRow(
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
                  _buildSectionHeader('APP PERMISSIONS'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.location,
                          title: 'Location Services',
                          trailingText: 'While Using',
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildActionRow(
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.photo,
                          title: 'Photos Access',
                          trailingText: 'All Photos',
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildActionRow(
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.mic,
                          title: 'Microphone Permissions',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 3: DATA MANAGEMENT ---
                  _buildSectionHeader('DATA MANAGEMENT'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          iconColor: AppColors.successGreen,
                          icon: CupertinoIcons.cloud_download,
                          title: 'Download My Data',
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildActionRow(
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
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textLight,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Helper row divider
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 56.0),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.background),
    );
  }

  // Action Navigation Row Builder
  Widget _buildActionRow({
    required IconData icon,
    Color iconColor = AppColors.primary,
    required String title,
    Color textColor = AppColors.textDark,
    String? trailingText,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
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
        style: TextStyle(color: textColor, fontWeight: FontWeight.w400, fontSize: 16),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
          if (trailingText != null && showArrow) const SizedBox(width: 6),
          if (showArrow) const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.border),
        ],
      ),
    );
  }

  // Toggle Switch Row Builder
  Widget _buildSwitchRow({
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
        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w400, fontSize: 16),
      ),
      trailing: Transform.scale(
        scaleX: 0.75,
        scaleY: 0.80,
        child: AdvancedSwitch(
          controller: switchController,
          width: 45,
          height: 24,
          activeColor: const Color(0xFF34C759),
          inactiveColor: Colors.grey.shade400,
        ),
      ),
    );
  }
}