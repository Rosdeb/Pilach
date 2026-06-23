import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/constants/app_constants.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({Key? key}) : super(key: key);

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  // Local state properties for the option settings toggles
  bool _securityAlerts = true;
  bool _activityNotifications = true;
  bool _marketingEmails = false;
  bool _weeklyDigest = true;

  @override
  Widget build(BuildContext context) {
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
              "Email setting",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: NOTIFICATIONS ---
                  _buildSectionHeader(context, 'SYSTEM ALERTS'),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          title: 'Security Alerts',
                          subtitle: 'Critical login attempts and password changes.',
                          value: _securityAlerts,
                          onChanged: (val) => setState(() => _securityAlerts = val),
                        ),
                        _buildDivider(context),
                        _buildSwitchRow(
                          context,
                          title: 'Activity Updates',
                          subtitle: 'Emails about direct interactions and tags.',
                          value: _activityNotifications,
                          onChanged: (val) => setState(() => _activityNotifications = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 2: MARKETING ---
                  _buildSectionHeader(context, 'MARKETING & CONTENT'),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          title: 'News & Promotions',
                          subtitle: 'Receive updates on new features and offers.',
                          value: _marketingEmails,
                          onChanged: (val) => setState(() => _marketingEmails = val),
                        ),
                        _buildDivider(context),
                        _buildSwitchRow(
                          context,
                          title: 'Weekly Digest',
                          subtitle: 'A summary roundup of missed ecosystem updates.',
                          value: _weeklyDigest,
                          onChanged: (val) => setState(() => _weeklyDigest = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
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

  Widget _buildSwitchRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final switchController = ValueNotifier<bool>(value);

    // Hook up a listener to catch toggle events from AdvancedSwitch and forward them safely to your parent tree callback.
    switchController.addListener(() {
      onChanged(switchController.value);
    });

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w400, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            subtitle,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12, height: 1.2),
          ),
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
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor),
    );
  }
}