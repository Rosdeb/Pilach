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
    return ListTile(
      onTap: (){
        context.push(AppPaths.chat);
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
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
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),

      title: Text(
        chat.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),

      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          chat.message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey.shade600,
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
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 6),

          if (chat.unreadCount > 0)
            Container(
              padding:
              const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
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