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

const Color _kGreen = Color(0xFF34C759);
const String _kAvatarUrl = 'https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp';

final _chatReadyProvider = StateProvider.autoDispose<bool>((_) => false);

final _headerTextColorProvider = Provider.autoDispose<Color>((ref) {
  final bg = ref.watch(chatThemeProvider).backgroundColor;
  return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
});

final replyingToProvider = StateProvider.autoDispose<MessageModel?>((ref) => null);


class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showAttachmentMenu = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showAttachmentMenu) {
        setState(() {
          _showAttachmentMenu = false;
        });
      }
    });
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

    final replyTo = ref.read(replyingToProvider);
    ref.read(directChatProvider.notifier).sendMessage(text, replyToId: replyTo?.id);
    
    ref.read(replyingToProvider.notifier).state = null; // Clear reply state
    _messageController.clear();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0.0,
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
            
            Consumer(
              builder: (context, ref, _) {
                final replyTo = ref.watch(replyingToProvider);
                if (replyTo == null) return const SizedBox.shrink();
                final theme = Theme.of(context);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply, color: activeTheme.accentColor ?? Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(replyTo.isMe ? 'Replying to yourself' : 'Replying to message', style: TextStyle(color: activeTheme.accentColor ?? Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(replyTo.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => ref.read(replyingToProvider.notifier).state = null,
                      ),
                    ],
                  ),
                );
              },
            ),

            _ComposerBar(
              messageController: _messageController,
              focusNode: _focusNode,
              activeTheme: activeTheme,
              onSend: _sendMessage,
              onAttach: () {
                if (_showAttachmentMenu) {
                  setState(() { _showAttachmentMenu = false; });
                  _focusNode.requestFocus();
                } else {
                  _focusNode.unfocus();
                  setState(() { _showAttachmentMenu = true; });
                }
              },
            ),
            if (_showAttachmentMenu) const _AttachmentDrawer(),
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
    return Column(
      children: [
        Expanded(
          child: _MessageList(scrollController: _scrollController),
        ),
        // ⬇️ Typing bubble — ISOLATED: শুধু এই widget rebuild হবে typing change এ
        // Message list কে touch করবে না
        const _TypingIndicatorWidget(),
      ],
    );
  }
}

// ⬇️ Typing indicator — সম্পূর্ণ আলাদা widget
// isTyping change হলে শুধু এটাই rebuild হয়, ListView rebuild হয় না
class _TypingIndicatorWidget extends ConsumerWidget {
  const _TypingIndicatorWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(currentChatIdProvider);
    final isTyping = chatId != null ? ref.watch(typingStatusProvider(chatId)) : false;
    if (!isTyping) return const SizedBox.shrink();
    return const _TypingBubble();
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

    // শুধু stable data (name, image) watch করো — typing/online আলাদা widget-এ
    final currentChat = ref.watch(chatProvider.select((chats) => chats.firstWhere(
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
            // ✅ RepaintBoundary — avatar কখনো repaint হবে না typing/message-এ
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
                  // ✅ Status text আলাদা Consumer — শুধু এটাই rebuild হবে
                  // typing বা isOnline পরিবর্তে name/avatar rebuild হবে না
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

// ✅ Isolated status text — শুধু typing/online change এ rebuild হয়
// Avatar বা name-এ কোনো প্রভাব নেই
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

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('📜 [BUILD] _MessageList');
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
    final messageIds = ref.watch(directChatProvider.select((state) => state.messageIds),);
    final isLoadingMore = ref.watch(directChatProvider.select((state) => state.isLoadingMore),);
    final hasMore = ref.watch(directChatProvider.select((state) => state.hasMore),);
    return ListView.custom(
      reverse: true,
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      childrenDelegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == messageIds.length) {
            if (hasMore) {
              Future.microtask(() {
                ref.read(directChatProvider.notifier).loadMore();
              });
            }
            return const _DateChip(label: 'Today');
          }
          if (index == messageIds.length + 1) {
            if (isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          final id = messageIds[index];
          return _BubbleById(key: ValueKey(id), id: id);
        },
        childCount: messageIds.length + (hasMore ? 2 : 1),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        findChildIndexCallback: (Key key) {
          final valueKey = key as ValueKey<String>;
          final index = messageIds.indexOf(valueKey.value);
          return index == -1 ? null : index;
        },
      ),
    );
  }
}

class _TypingBubble extends ConsumerWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(chatThemeProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: activeTheme.receivedMessageColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Typing...', style: TextStyle(color: (activeTheme.receivedMessageColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70), fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
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

    final repliedMsg = msg.replyToMessageId != null
        ? ref.watch(directChatProvider.select((state) => state.messagesById[msg.replyToMessageId]))
        : null;

    return ChatBubble(
      key: ValueKey(id),
      message: msg,
      activeTheme: activeTheme,
      otherUserAvatar: currentChat.image,
      repliedMessage: repliedMsg,
      onDelete: () => ref.read(directChatProvider.notifier).deleteMessage(msg.id),
      onPin: () => ref.read(directChatProvider.notifier).pinMessage(msg.id, !(msg.isPinned ?? false)),
      onReact: (emoji) => ref.read(directChatProvider.notifier).reactToMessage(msg.id, emoji),
      onReply: () => ref.read(replyingToProvider.notifier).state = msg,
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
    required this.onAttach,
  });

  final TextEditingController messageController;
  final FocusNode focusNode;
  final dynamic activeTheme;
  final VoidCallback onSend;
  final VoidCallback onAttach;

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
                  onAttach: onAttach,
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
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnterSend;
  final VoidCallback onSend;
  final VoidCallback onTyping;
  final VoidCallback onAttach;

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
              onPressed: onAttach,
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

class _AttachmentDrawer extends StatelessWidget {
  const _AttachmentDrawer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          _AttachmentIcon(icon: Icons.insert_drive_file, color: Colors.indigo, label: 'Document'),
          _AttachmentIcon(icon: Icons.camera_alt, color: Colors.pink, label: 'Camera'),
          _AttachmentIcon(icon: Icons.image, color: Colors.purple, label: 'Gallery'),
          _AttachmentIcon(icon: Icons.headset, color: Colors.orange, label: 'Audio'),
          _AttachmentIcon(icon: Icons.location_on, color: Colors.green, label: 'Location'),
          _AttachmentIcon(icon: Icons.person, color: Colors.blue, label: 'Contact'),
        ],
      ),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
