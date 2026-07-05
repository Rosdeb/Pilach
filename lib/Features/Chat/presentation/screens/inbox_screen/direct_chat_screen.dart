import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/direct_chat_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat_bundle.dart';

// ── Compile-time constants — zero allocation per build ────────────────────────
const Color _kGreen = Color(0xFF34C759);
const String _kAvatarUrl =
    'https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp';

// ── Deferred-load flag — flips true after first post-frame ───────────────────
// autoDispose: cleaned up when screen is popped, so re-entering resets it.
final _chatReadyProvider = StateProvider.autoDispose<bool>((_) => false);

final _headerTextColorProvider = Provider.autoDispose<Color>((ref) {
  final bg = ref.watch(chatThemeProvider).backgroundColor;
  return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
});

// ─────────────────────────────────────────────────────────────────────────────

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(_chatReadyProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(directChatProvider.notifier).sendMessage(text);
    _messageController.clear();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(chatThemeProvider);
    final headerTextColor = ref.watch(_headerTextColorProvider);

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      appBar: _ChatAppBar(
        activeTheme: activeTheme,
        headerTextColor: headerTextColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _ReadyGate(
                scrollController: _scrollController,
              ),
            ),

            _ComposerBar(
              messageController: _messageController,
              focusNode: _focusNode,
              activeTheme: activeTheme,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyGate extends ConsumerWidget {
  const _ReadyGate({
    required ScrollController scrollController,
  }) : _scrollController = scrollController;
  final ScrollController _scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReady = ref.watch(_chatReadyProvider);
    if (!isReady) return const SizedBox.expand();
    return _MessageList(
      scrollController: _scrollController,
    );
  }
}

class _ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.activeTheme, required this.headerTextColor});

  final dynamic activeTheme;
  final Color headerTextColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(currentChatIdProvider);
    final isTyping = chatId != null ? ref.watch(typingStatusProvider(chatId)) : false;

    final chats = ref.watch(chatProvider);
    final currentChat = chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => ChatModel(
        id: '',
        name: 'Unknown User',
        message: '',
        image: _kAvatarUrl,
        time: '',
        unreadCount: 0,
        isOnline: false,
      ),
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
        onTap: () => context.push(AppPaths.chat_profile, extra: currentChat),
        child: Row(
          children: [
            // RepaintBoundary: avatar image never repaints on message updates
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
                  // Status text
                  Text(
                    isTyping ? 'Typing...' : 'Online',
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(chatWallpaperProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        image: wallpaper != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(wallpaper),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _MessageListView(
        scrollController: scrollController, // ✅ field থেকে pass করো
      ),
    );
  }
}

class _MessageListView extends ConsumerWidget {
  const _MessageListView({
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🟡 MessageListView build');
    final count = ref.watch(directChatProvider.select((state) => state.messageIds.length));

    return ListView.builder(
      reverse: false,
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      addAutomaticKeepAlives: false,
      itemCount: count + 1,
      itemBuilder: (context, index) {
        if (index == 0)
          return const _DateChip(label: 'Today');
        return _BubbleRowByIndex(index: index - 1);
      },
    );
  }
}

class _BubbleRowByIndex extends ConsumerWidget {
  const _BubbleRowByIndex({
    super.key,
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // প্রথমে শুধু id নাও — id same থাকলে rebuild নেই
    final id = ref.watch(directChatProvider.select((state) {
      if (index >= state.messageIds.length || index < 0) return null;
      return state.messageIds[index];
    }));

    if (id == null) return const SizedBox.shrink();

    return _BubbleById(id: id);
  }
}

class _BubbleById extends ConsumerWidget {
  const _BubbleById({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(chatThemeProvider);
    final msg = ref.watch(directChatProvider.select((state) => state.messagesById[id]));

    if (msg == null) {
      return const SizedBox.shrink();
    }

    final chatId = ref.read(currentChatIdProvider);
    final chats = ref.read(chatProvider);
    final currentChat = chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => ChatModel(
        id: '',
        name: '',
        message: '',
        image: _kAvatarUrl,
        time: '',
        unreadCount: 0,
        isOnline: false,
      ),
    );

    return ChatBubble(
      message: msg,
      activeTheme: activeTheme,
      otherUserAvatar: currentChat.image,
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ComposerBar extends ConsumerWidget {
  const _ComposerBar({
    required this.messageController,
    required this.focusNode,
    required this.activeTheme,
    required this.onSend,
  });

  final TextEditingController messageController;
  final FocusNode focusNode;
  final dynamic activeTheme;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnterSend = ref.watch(enterIsSendProvider);
    final isNotEmpty = ref.watch(Provider((ref) => messageController.text.trim().isNotEmpty),);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: activeTheme.backgroundColor ?? Colors.transparent,
        ),
        child: SafeArea(
          child: Row(

            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _WhatsAppInputBox(
                  controller: messageController,
                  focusNode: focusNode,
                  isEnterSend: isEnterSend,
                  onSend: onSend,
                  onTyping: () => ref.read(directChatProvider.notifier).emitTyping(),
                ),
              ),
              const SizedBox(width: 6),

              _SendButton(
                accentColor: activeTheme.accentColor ?? const Color(0xFF00A884),
                onTap: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsAppInputBox extends StatelessWidget {
  const _WhatsAppInputBox({
    required this.controller,
    required this.focusNode,
    required this.isEnterSend,
    required this.onSend,
    required this.onTyping,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnterSend;
  final VoidCallback onSend;
  final VoidCallback onTyping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            IconButton(
              onPressed: () {},
              icon: Icon(
                CupertinoIcons.smiley,
                color: theme.hintColor.withValues(alpha: 0.6),
                size: 24,
              ),
              splashRadius: 20,
            ),


            Expanded(
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => onTyping(),
                textInputAction: isEnterSend
                    ? TextInputAction.send
                    : TextInputAction.newline,
                onFieldSubmitted: isEnterSend ? (_) => onSend() : null,
                style: const TextStyle(fontSize: 16, height: 1.3),
                decoration: InputDecoration(
                  hintText: "Message",
                  hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  fillColor: theme.colorScheme.surface,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),


            IconButton(
              onPressed: () {},
              icon: Icon(
                CupertinoIcons.paperclip,
                color: theme.hintColor.withValues(alpha: 0.6),
                size: 22,
              ),
              splashRadius: 20,
            ),


            IconButton(
              onPressed: () {},
              icon: Icon(
                CupertinoIcons.camera_fill,
                color: theme.hintColor.withValues(alpha: 0.6),
                size: 22,
              ),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}


class _SendButton extends StatelessWidget {
  const _SendButton({required this.accentColor, required this.onTap});

  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            CupertinoIcons.paperplane_fill,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
