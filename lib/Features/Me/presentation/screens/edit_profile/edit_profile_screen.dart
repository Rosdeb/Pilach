import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:messageapp/components/AppText/appText.dart';
import '../../../../../core/utils/app_colour.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            backgroundColor: AppColors.background,
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
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.back_icon,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),

                        const Spacer(),

                        // Title
                        const AppText(
                            'Edit Profile',
                            style: TextStyle(
                              color: AppColors.textDark,
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
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: AppColors.primary,
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
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              color: AppColors.textWhite,
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
                    child: const Text(
                      'Change Profile Photo',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- FORM CARD ---
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [

                        _buildInputField(
                          label: 'Name',
                          initialValue: 'Alex Koch',
                        ),

                        _buildDivider(),

                        _buildInputField(
                          label: 'Username',
                          initialValue: 'alex_koch',
                        ),

                        _buildDivider(),

                        _buildInputField(
                          label: 'Phone',
                          initialValue: '+1 (555) 019-2834',
                        ),

                        _buildDivider(),

                        _buildInputField(
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

  Widget _buildInputField({
    required String label,
    required String initialValue,
  }) {
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
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            child: TextFormField(
              initialValue: initialValue,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                fillColor: AppColors.textWhite,
                hint: AppText("|"),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.background,
      ),
    );
  }
}
