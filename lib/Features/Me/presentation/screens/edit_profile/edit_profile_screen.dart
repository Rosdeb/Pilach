import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:app/components/AppText/appText.dart';
import '../../../../../core/utils/app_colour.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- APP BAR ---
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            automaticallyImplyLeading: false,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // Back Button
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: theme.colorScheme.onSurface,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        // Title
                        AppText(
                          'Edit Profile',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        // Save Button
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Save',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- BODY ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // --- PROFILE IMAGE ---
                  Center(
                    child: Stack(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.background_s2,
                          backgroundImage: NetworkImage(
                            'https://cdn.motor1.com/images/mgl/bglVnv/s3/best-new-cars-coming-out-in-2025.webp',
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.camera_fill,
                              color: theme.colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Change Profile Photo',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- FORM CARD ---
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInputField(
                          context,
                          label: 'Name',
                          initialValue: 'Alex Koch',
                        ),
                        _buildDivider(context),
                        _buildInputField(
                          context,
                          label: 'Username',
                          initialValue: 'alex_koch',
                        ),
                        _buildDivider(context),
                        _buildInputField(
                          context,
                          label: 'Phone',
                          initialValue: '+1 (555) 019-2834',
                        ),
                        _buildDivider(context),
                        _buildInputField(
                          context,
                          label: 'Bio',
                          initialValue: 'App Developer & Designer',
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

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required String initialValue,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: initialValue,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                fillColor: theme.colorScheme.surface,
                hint: const AppText("|"),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}
