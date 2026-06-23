import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messageapp/core/constants/app_constants.dart';

import '../../data/models/chat_model.dart';

class ChatTile extends StatelessWidget {
  final ChatModel chat;

  const ChatTile({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = const Color(0xFF34C759);

    return ListTile(
      onTap: (){
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
            backgroundImage:
            NetworkImage(chat.image),
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

      title: Text(
        chat.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: theme.colorScheme.onSurface,
        ),
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
        mainAxisAlignment:
        MainAxisAlignment.center,
        crossAxisAlignment:
        CrossAxisAlignment.end,
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
              padding:
              const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: successColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}