// import 'dart:ui';
//
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import '../../../../../core/utils/app_colour.dart';
//
// class EditProfileScreen extends StatelessWidget {
//   const EditProfileScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: CustomScrollView(
//         physics: const BouncingScrollPhysics(),
//         slivers: [
//
//           // --- APP BAR ---
//           SliverAppBar(
//             pinned: true,
//             floating: false,
//             snap: false,
//             expandedHeight: 100,
//             toolbarHeight: 100,
//             automaticallyImplyLeading: false,
//             backgroundColor: AppColors.textWhite.withOpacity(0.7),
//             elevation: 0,
//
//             flexibleSpace: ClipRect(
//               child: BackdropFilter(
//                 filter: ImageFilter.blur(
//                   sigmaX: 10,
//                   sigmaY: 10,
//                 ),
//                 child: SafeArea(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 12),
//                     child: Row(
//                       children: [
//
//                         // Back Button
//                         IconButton(
//                           icon: const Icon(
//                             Icons.arrow_back_ios_new,
//                             color: AppColors.primary,
//                             size: 20,
//                           ),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//
//                         const SizedBox(width: 8),
//
//                         // Title
//                         const Expanded(
//                           child: Text(
//                             'Edit Profile',
//                             style: TextStyle(
//                               color: AppColors.textDark,
//                               fontSize: 26,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//
//                         // Save Button
//                         TextButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                           },
//                           child: const Text(
//                             'Save',
//                             style: TextStyle(
//                               color: AppColors.primary,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // --- BODY ---
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 children: [
//
//                   const SizedBox(height: 24),
//
//                   // --- PROFILE IMAGE ---
//                   Center(
//                     child: Stack(
//                       children: [
//
//                         const CircleAvatar(
//                           radius: 50,
//                           backgroundColor: AppColors.background_s2,
//                           backgroundImage: NetworkImage(
//                             'https://via.placeholder.com/150',
//                           ),
//                         ),
//
//                         Positioned(
//                           bottom: 0,
//                           right: 0,
//                           child: Container(
//                             padding: const EdgeInsets.all(6),
//                             decoration: const BoxDecoration(
//                               color: AppColors.primary,
//                               shape: BoxShape.circle,
//                             ),
//                             child: const Icon(
//                               CupertinoIcons.camera_fill,
//                               color: AppColors.textWhite,
//                               size: 16,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   const SizedBox(height: 8),
//
//                   TextButton(
//                     onPressed: () {},
//                     child: const Text(
//                       'Change Profile Photo',
//                       style: TextStyle(
//                         color: AppColors.primary,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//
//                   const SizedBox(height: 16),
//
//                   // --- FORM CARD ---
//                   Container(
//                     decoration: BoxDecoration(
//                       color: AppColors.textWhite,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Column(
//                       children: [
//
//                         _buildInputField(
//                           label: 'Name',
//                           initialValue: 'Alex Koch',
//                         ),
//
//                         _buildDivider(),
//
//                         _buildInputField(
//                           label: 'Username',
//                           initialValue: 'alex_koch',
//                         ),
//
//                         _buildDivider(),
//
//                         _buildInputField(
//                           label: 'Phone',
//                           initialValue: '+1 (555) 019-2834',
//                         ),
//
//                         _buildDivider(),
//
//                         _buildInputField(
//                           label: 'Bio',
//                           initialValue: 'App Developer & Designer',
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   const SizedBox(height: 32),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInputField({
//     required String label,
//     required String initialValue,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(
//         horizontal: 16,
//         vertical: 4,
//       ),
//       child: Row(
//         children: [
//
//           SizedBox(
//             width: 100,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 color: AppColors.textDark,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//
//           Expanded(
//             child: TextFormField(
//               initialValue: initialValue,
//               style: const TextStyle(
//                 color: AppColors.textLight,
//                 fontSize: 16,
//               ),
//               decoration: const InputDecoration(
//                 border: InputBorder.none,
//                 isDense: true,
//                 contentPadding: EdgeInsets.symmetric(
//                   vertical: 12,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDivider() {
//     return const Padding(
//       padding: EdgeInsets.only(left: 16),
//       child: Divider(
//         height: 1,
//         thickness: 0.5,
//         color: AppColors.background,
//       ),
//     );
//   }
// }

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/constants/app_constants.dart';

import '../../../../../core/utils/app_colour.dart';
// Import your AppColors here

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
              "Edit Profile",
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
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // --- SECTION 1: NOTIFICATIONS ---
                  _buildSectionHeader('SYSTEM ALERTS'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          title: 'Security Alerts',
                          subtitle: 'Critical login attempts and password changes.',
                          value: _securityAlerts,
                          onChanged: (val) => setState(() => _securityAlerts = val),
                        ),
                        _buildDivider(),
                        _buildSwitchRow(
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
                  _buildSectionHeader('MARKETING & CONTENT'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          title: 'News & Promotions',
                          subtitle: 'Receive updates on new features and offers.',
                          value: _marketingEmails,
                          onChanged: (val) => setState(() => _marketingEmails = val),
                        ),
                        _buildDivider(),
                        _buildSwitchRow(
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

  Widget _buildSwitchRow({
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppColors.textLight, fontSize: 12, height: 1.2),
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
            inactiveColor: Colors.grey.shade300,
            // borderRadius: const BorderRadius.all(
            //   Radius.circular(20),
            // ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 16.0),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.background),
    );
  }
}