import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/utils/app_toast.dart';

import '../../../../components/AppText/appText.dart';
import '../../data/models/block_userlist.dart';
import '../providers/block_userlist_providers.dart';

class BlockedUserTile extends ConsumerWidget {
  final BlockedUser user;

  const BlockedUserTile({
    super.key,
    required this.user,
  });

  void _confirmUnblock(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Unblock ${user.displayName}?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('They will now be able to send you messages and call you.'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Unblock'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(blockedUsersProvider.notifier)
                  .unblockUser(user.id);
              if (context.mounted) {
                if (success) {
                  AppToast.show(context, 'Unblocked ${user.displayName}',
                      type: ToastType.success);
                } else {
                  AppToast.show(context, 'Failed to unblock ${user.displayName}',
                      type: ToastType.error);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasValidAvatar = user.avatarUrl != null &&
        user.avatarUrl!.trim().isNotEmpty &&
        user.avatarUrl!.startsWith('http');

    final initials = user.displayName.isNotEmpty
        ? user.displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    final subtitleText = user.handle ??
        (user.createdAt != null
            ? 'Blocked ${_formatBlockedDate(user.createdAt!)}'
            : '');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.brightness == Brightness.dark
            ? const Color(0xFF1A3E40)
            : const Color(0xFFB8D8DA),
        backgroundImage: hasValidAvatar
            ? CachedNetworkImageProvider(user.avatarUrl!.trim())
            : null,
        child: !hasValidAvatar
            ? Text(
                initials,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: AppText(
        user.displayName,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: subtitleText.isNotEmpty
          ? AppText(
              subtitleText,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            )
          : null,
      trailing: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusCircle),
          ),
        ),
        onPressed: () => _confirmUnblock(context, ref),
        child: AppText(
          'Unblock',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _formatBlockedDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'recently';
  }
}