import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';

class ChatTile extends ConsumerWidget {
  final ChatModel chat;

  const ChatTile({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final successColor = const Color(0xFF34C759);

    return Dismissible(
      key: Key(chat.id),

      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.orangeAccent,
        child: Icon(
          chat.isMuted ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.redAccent,
        child: const Icon(
          CupertinoIcons.trash,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Mute / Unmute Action
          ref.read(chatProvider.notifier).toggleMuteChat(chat.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(chat.isMuted ? 'Conversation unmuted' : 'Conversation muted'),
              duration: const Duration(seconds: 1),
            ),
          );
          return false; // Prevent sliding out / deletion
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Confirm Deletion Dialog
          final bool? confirm = await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Delete Conversation'),
              content: Text('Are you sure you want to delete conversation with ${chat.name}?'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            ref.read(chatProvider.notifier).deleteChat(chat.id);
            return true;
          }
          return false;
        }
        return false;
      },
      child: ListTile(
        onTap: () {
          context.push(AppPaths.chat);
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: chat.image,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  cacheKey: chat.name + chat.image,
                  placeholder: (context, url) => const Center(child: CupertinoActivityIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.person),
                ),
              ),
            ),
            if (chat.isOnline)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  height: 14,
                  width: 14,
                  decoration: BoxDecoration(
                    color: successColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chat.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (chat.isMuted)
              const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Icon(
                  CupertinoIcons.bell_slash,
                  size: 14,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            chat.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              chat.time,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            if (chat.unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: successColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  chat.unreadCount.toString(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}