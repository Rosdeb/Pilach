import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/core/constants/app_constants.dart';

import '../../../../components/AppText/appText.dart';
import '../../../../core/utils/app_colour.dart';
import '../../data/models/block_userlist.dart';
import '../providers/block_userlist_providers.dart';
class BlockedUserTile extends ConsumerWidget {
  final BlockedUser user;

  const BlockedUserTile({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),

      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.background_s2,
        backgroundImage: NetworkImage(user.avatarUrl),
      ),

      title: AppText(
        user.name,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),

      subtitle: AppText(
        user.email,
        style: const TextStyle(
          color: AppColors.textLight,
          fontSize: 13,
        ),
      ),

      trailing: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusCircle),
          ),
        ),

        onPressed: () {
          ref.read(blockedUsersProvider.notifier)
              .unblockUser(user.id);
        },

        child: const AppText(
          'Unblock',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}