import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/core/constants/app_constants.dart';

import '../../../../components/AppText/appText.dart';
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
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),

      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF1A3E40) : const Color(0xFFB8D8DA),
        backgroundImage: NetworkImage(user.avatarUrl),
      ),

      title: AppText(
        user.name,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),

      subtitle: AppText(
        user.email,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: 13,
        ),
      ),

      trailing: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusCircle),
          ),
        ),

        onPressed: () {
          ref.read(blockedUsersProvider.notifier)
              .unblockUser(user.id);
        },

        child: AppText(
          'Unblock',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}