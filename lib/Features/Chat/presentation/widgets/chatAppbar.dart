import 'dart:async';
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
const Color _kGreen = Color(0xFF082DE3);


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
                  if (currentChat.isOnline)
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
                      lastActive: currentChat.lastActive,
                      headerTextColor: headerTextColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(CupertinoIcons.phone, color: _kGreen, size: 22),
        //   onPressed: () {},
        // ),
        // IconButton(
        //   icon: const Icon(
        //     CupertinoIcons.video_camera,
        //     color: _kGreen,
        //     size: 26,
        //   ),
        //   onPressed: () {},
        // ),
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


class _AppBarStatusText extends ConsumerStatefulWidget {
  const _AppBarStatusText({
    required this.chatId,
    required this.chatIsOnline,
    required this.lastActive,
    required this.headerTextColor,
  });

  final String chatId;
  final bool chatIsOnline;
  final String? lastActive;
  final Color headerTextColor;

  @override
  ConsumerState<_AppBarStatusText> createState() => _AppBarStatusTextState();
}

class _AppBarStatusTextState extends ConsumerState<_AppBarStatusText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Smoothly refresh relative time every 30 seconds
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatLastActive(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Offline';

    DateTime? dt;
    final trimmed = isoString.trim();

    // Check if it's a numeric epoch string (10 digits seconds or 13 digits ms)
    final parsedInt = int.tryParse(trimmed);
    if (parsedInt != null) {
      dt = (parsedInt > 100000000000
              ? DateTime.fromMillisecondsSinceEpoch(parsedInt)
              : DateTime.fromMillisecondsSinceEpoch(parsedInt * 1000))
          .toLocal();
    } else {
      // If ISO format has no timezone indicator, treat as UTC
      final hasTimezone = trimmed.endsWith('Z') ||
          trimmed.contains('+') ||
          (trimmed.length > 10 && trimmed.substring(10).contains('-'));
      final toParse = hasTimezone ? trimmed : '${trimmed}Z';
      dt = DateTime.tryParse(toParse)?.toLocal();
    }

    if (dt == null) return 'Offline';

    final now = DateTime.now();
    final diff = now.difference(dt);

    // Guard against server clock skew where diff is negative
    if (diff.isNegative || diff.inSeconds < 45) {
      return 'Last active: Just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Last active: $m ${m == 1 ? "min" : "mins"} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Last active: $h ${h == 1 ? "hour" : "hours"} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return 'Last active: $d ${d == 1 ? "day" : "days"} ago';
    }
    if (diff.inDays < 30) {
      final w = diff.inDays ~/ 7;
      return 'Last active: $w ${w == 1 ? "week" : "weeks"} ago';
    }
    final months = diff.inDays ~/ 30;
    return 'Last active: $months ${months == 1 ? "month" : "months"} ago';
  }

  @override
  Widget build(BuildContext context) {
    final isTyping = ref.watch(typingStatusProvider(widget.chatId));
    final statusText = isTyping
        ? 'Typing...'
        : (widget.chatIsOnline
            ? 'Online'
            : _formatLastActive(widget.lastActive));

    return Text(
      statusText,
      style: TextStyle(
        color: isTyping || widget.chatIsOnline ? _kGreen : Colors.grey.shade400,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

