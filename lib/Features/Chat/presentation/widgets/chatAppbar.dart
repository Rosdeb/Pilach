import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../providers/direct_chat_provider.dart';
import '../providers/in_chat_search_provider.dart';
import 'chat_avatar.dart';

const Color _kGreen = Color(0xFF082DE3);


class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key, required this.activeTheme, required this.headerTextColor});

  final dynamic activeTheme;
  final Color headerTextColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(inChatSearchProvider);

    if (searchState.isActive) {
      return AppBar(
        backgroundColor: activeTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: headerTextColor),
          onPressed: () {
            ref.read(inChatSearchProvider.notifier).deactivate();
          },
        ),
        titleSpacing: 0,
        title: _InChatSearchField(headerTextColor: headerTextColor),
        actions: [
          if (searchState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: headerTextColor,
                ),
              ),
            )
          else if (searchState.query.isNotEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  searchState.matchingMessageIds.isEmpty
                      ? '0/0'
                      : '${searchState.currentIndex + 1}/${searchState.matchingMessageIds.length}',
                  style: TextStyle(
                    color: headerTextColor.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: searchState.matchingMessageIds.isNotEmpty
                    ? headerTextColor
                    : headerTextColor.withOpacity(0.3),
                size: 26,
              ),
              tooltip: 'Previous match',
              onPressed: searchState.matchingMessageIds.isNotEmpty
                  ? () =>
                      ref.read(inChatSearchProvider.notifier).previousMatch()
                  : null,
            ),
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: searchState.matchingMessageIds.isNotEmpty
                    ? headerTextColor
                    : headerTextColor.withOpacity(0.3),
                size: 26,
              ),
              tooltip: 'Next match',
              onPressed: searchState.matchingMessageIds.isNotEmpty
                  ? () => ref.read(inChatSearchProvider.notifier).nextMatch()
                  : null,
            ),
          ],
          const SizedBox(width: 4),
        ],
      );
    }

    final chatId = ref.watch(currentChatIdProvider);

    final currentChat = ref.watch(
      chatProvider.select((chats) {
        try {
          return chats.firstWhere((c) => c.id == chatId);
        } catch (_) {
          return null;
        }
      }),
    );

    if (currentChat == null && chatId != null && chatId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).ensureConversationLoaded(chatId);
      });
    }

    final effectiveChat =
        currentChat ??
        ChatModel(
          id: chatId ?? '',
          name: '',
          message: '',
          image: '',
          time: '',
          unreadCount: 0,
          isOnline: false,
        );

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
        onTap: () => context.push(AppPaths.chat_profile, extra: effectiveChat),
        child: Row(
          children: [
            RepaintBoundary(
              child: ChatAvatar(
                radius: 20,
                imageUrl: effectiveChat.image,
                memberAvatars: effectiveChat.memberAvatars,
                isGroup: effectiveChat.isGroup,
                isOnline: effectiveChat.isOnline && !effectiveChat.isGroup,
                onlineColor: _kGreen,
                borderColor: activeTheme.backgroundColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveChat.name.isNotEmpty
                        ? effectiveChat.name
                        : 'Conversation',
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
                      chatIsOnline: effectiveChat.isOnline,
                      isGroup: effectiveChat.isGroup,
                      lastActive: effectiveChat.lastActive,
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
          icon: Icon(
            CupertinoIcons.search,
            color: headerTextColor,
            size: 20,
          ),
          tooltip: 'Search in conversation',
          onPressed: () {
            ref.read(inChatSearchProvider.notifier).activate();
          },
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

class _InChatSearchField extends ConsumerStatefulWidget {
  const _InChatSearchField({required this.headerTextColor});

  final Color headerTextColor;

  @override
  ConsumerState<_InChatSearchField> createState() => _InChatSearchFieldState();
}

class _InChatSearchFieldState extends ConsumerState<_InChatSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
      ref.read(inChatSearchProvider.notifier).onQueryChanged(_controller.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: TextStyle(color: widget.headerTextColor, fontSize: 16),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: TextStyle(
          color: widget.headerTextColor.withOpacity(0.5),
          fontSize: 16,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: widget.headerTextColor.withOpacity(0.7),
                  size: 18,
                ),
                onPressed: () {
                  _controller.clear();
                  ref.read(inChatSearchProvider.notifier).onQueryChanged('');
                },
              )
            : null,
      ),
    );
  }
}


class _AppBarStatusText extends ConsumerStatefulWidget {
  const _AppBarStatusText({
    required this.chatId,
    required this.chatIsOnline,
    this.isGroup = false,
    required this.lastActive,
    required this.headerTextColor,
  });

  final String chatId;
  final bool chatIsOnline;
  final bool isGroup;
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
    final typingUser = ref.watch(typingUserNameProvider(widget.chatId));

    final String statusText;
    if (isTyping) {
      statusText = typingUser != null && typingUser.isNotEmpty
          ? '$typingUser is typing...'
          : 'Typing...';
    } else if (widget.isGroup) {
      statusText = 'Group';
    } else if (widget.chatIsOnline) {
      statusText = 'Online';
    } else {
      statusText = _formatLastActive(widget.lastActive);
    }

    return Text(
      statusText,
      style: TextStyle(
        color: isTyping || (!widget.isGroup && widget.chatIsOnline)
            ? _kGreen
            : Colors.grey.shade400,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

