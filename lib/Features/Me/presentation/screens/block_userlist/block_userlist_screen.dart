import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/components/AppText/appText.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/app_colour.dart';
import '../../providers/block_userlist_providers.dart';
import '../../widgets/block_list.dart';
import '../../widgets/block_list_search.dart';
// Import your AppColors and providers here

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsers = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- GLASS EFFECT APP BAR ---
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            expandedHeight: 60,
            toolbarHeight: 60,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.back_icon, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const AppText(
              'Blocked Users',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // --- MAIN CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- iOS SEARCH BAR ---
                  IOSSearchBar(
                    hintText: "Search blocked contacts",
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 24.0),

                  // --- LIST HEADER DESCRIPTION ---
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: AppText(
                      'BLOCKED CONTACTS',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // --- BLOCKED LIST CONTAINER ---
                  if (blockedUsers.isEmpty)
                    _buildEmptyState()
                  else
                    BlockedUserList(blockedUsers: blockedUsers),

                  const SizedBox(height: 12),
                  // --- iOS FOOTER EXPLANATION ---
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: AppText(
                      'Blocked users will not be able to send you messages, view your profile updates, or initiate voice/video calls with you.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        height: 1.3,
                      ),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.textWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: const [
          Icon(
            CupertinoIcons.checkmark_shield,
            size: 48,
            color: AppColors.textLight,
          ),
          SizedBox(height: 12),
          AppText(
            'No Blocked Users',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          AppText(
            'Contacts you block will appear here.',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
