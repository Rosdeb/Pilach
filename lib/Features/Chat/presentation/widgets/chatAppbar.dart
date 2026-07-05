import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../providers/direct_chat_provider.dart';

const String kAvatarUrl = 'https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp';
const Color _kGreen = Color(0xFF34C759);


class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatAppBar({required this.activeTheme, required this.headerTextColor});

  final dynamic activeTheme;
  final Color headerTextColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(currentChatIdProvider);

    final currentChat = ref.watch(chatProvider.select((chats) => chats.firstWhere((c) => c.id == chatId,
      orElse: () => ChatModel(
        id: '',
        name: 'Unknown User',
        message: '',
        image: kAvatarUrl,
        time: '',
        unreadCount: 0,
        isOnline: false,
      ),
    )));

    return AppBar(
      backgroundColor: activeTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(CupertinoIcons.back, color: headerTextColor),
        onPressed: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
      ),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () => context.push(AppPaths.chat_profile, extra: currentChat),
        child: Row(
          children: [
            RepaintBoundary(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: currentChat.image.startsWith('http')
                        ? CachedNetworkImageProvider(currentChat.image)
                        : AssetImage(currentChat.image) as ImageProvider,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _kGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: const SizedBox(width: 10, height: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentChat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: headerTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (chatId != null)
                    _AppBarStatusText(
                      chatId: chatId,
                      chatIsOnline: currentChat.isOnline,
                      headerTextColor: headerTextColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.phone, color: _kGreen, size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(
            CupertinoIcons.video_camera,
            color: _kGreen,
            size: 26,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(
            CupertinoIcons.ellipsis_vertical,
            color: headerTextColor,
            size: 20,
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}


class _AppBarStatusText extends ConsumerWidget {
  const _AppBarStatusText({
    required this.chatId,
    required this.chatIsOnline,
    required this.headerTextColor,
  });

  final String chatId;
  final bool chatIsOnline;
  final Color headerTextColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTyping = ref.watch(typingStatusProvider(chatId));
    return Text(
      isTyping ? 'Typing...' : (chatIsOnline ? 'Online' : 'Offline'),
      style: TextStyle(
        color: isTyping || chatIsOnline ? _kGreen : Colors.grey.shade400,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

