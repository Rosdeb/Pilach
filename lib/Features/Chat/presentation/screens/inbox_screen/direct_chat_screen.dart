import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/direct_chat_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chatAppbar.dart';
import '../../widgets/chat_bundle.dart';
import '../../widgets/connection_status_banner.dart';
import 'package:app/core/utils/date_formatter.dart';
import 'package:app/core/models/link_preview.dart';
import 'package:app/core/services/link_preview_service.dart';
import 'package:app/core/utils/url_launcher_utils.dart';

final _chatReadyProvider = StateProvider.autoDispose<bool>((_) => false);

final _headerTextColorProvider = Provider.autoDispose<Color>((ref) {
  final bg = ref.watch(chatThemeProvider).backgroundColor;
  return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
});

final replyingToProvider = StateProvider.autoDispose<MessageModel?>(
  (ref) => null,
);
final editingMessageProvider = StateProvider.autoDispose<MessageModel?>(
  (ref) => null,
);
final showAttachmentMenuProvider = StateProvider.autoDispose<bool>(
  (_) => false,
);

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _draftDebounce;
  DirectChatNotifier? _directChatNotifier;
  bool _isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _directChatNotifier = ref.read(directChatProvider.notifier);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _messageController.addListener(_onTextChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(_chatReadyProvider.notifier).state = true;
        final chatId = ref.read(currentChatIdProvider);
        if (chatId != null) {
          ref.read(chatProvider.notifier).clearUnreadCount(chatId);
          // Restore draft message if present
          ref.read(directChatProvider.notifier).getDraft().then((savedDraft) {
            if (mounted &&
                savedDraft != null &&
                savedDraft.isNotEmpty &&
                _messageController.text.isEmpty) {
              _messageController.text = savedDraft;
              _messageController.selection = TextSelection.collapsed(
                offset: savedDraft.length,
              );
            }
          });
        }
      }
    });
  }

  void _onTextChanged() {
    final editingMsg = ref.read(editingMessageProvider);
    if (editingMsg != null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref
            .read(directChatProvider.notifier)
            .saveDraft(_messageController.text);
      }
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      ref.read(showAttachmentMenuProvider.notifier).state = false;
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    if (!_isEditing) {
      _directChatNotifier?.saveDraft(_messageController.text);
    }
    _messageController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(directChatProvider.notifier).saveDraft(null);

    final editingMsg = ref.read(editingMessageProvider);
    if (editingMsg != null) {
      ref.read(directChatProvider.notifier).editMessage(editingMsg.id, text);
      ref.read(editingMessageProvider.notifier).state = null;
    } else {
      final replyTo = ref.read(replyingToProvider);
      ref
          .read(directChatProvider.notifier)
          .sendMessage(text, replyToId: replyTo?.id);
      ref.read(replyingToProvider.notifier).state = null;
    }

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
    ref.listen(editingMessageProvider, (previous, next) {
      _isEditing = next != null;
      if (next != null) {
        _messageController.text = next.text;
        _focusNode.requestFocus();
      }
    });

    final activeTheme = ref.watch(chatThemeProvider);
    final headerTextColor = ref.watch(_headerTextColorProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          if (!_isEditing) {
            _directChatNotifier?.saveDraft(_messageController.text);
          }
          ref.read(currentChatIdProvider.notifier).state = null;
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: activeTheme.backgroundColor,
        appBar: ChatAppBar(
          activeTheme: activeTheme,
          headerTextColor: headerTextColor,
        ),
        body: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(
                  child: _ReadyGate(scrollController: _scrollController),
                ),
                const _EditPreviewBar(),
                const _ReplyPreviewBar(),
                _ComposerBar(
                  messageController: _messageController,
                  focusNode: _focusNode,
                  activeTheme: activeTheme,
                  onSend: _sendMessage,
                  onAttach: () async {
                    final current = ref.read(showAttachmentMenuProvider);
                    if (current) {
                      ref.read(showAttachmentMenuProvider.notifier).state =
                          false;
                      _focusNode.requestFocus();
                    } else {
                      final wasKeyboardOpen = _focusNode.hasFocus;
                      FocusScope.of(context).unfocus();

                      if (wasKeyboardOpen) {
                        await Future.delayed(const Duration(milliseconds: 260));
                        if (!mounted) return;
                      }

                      ref.read(showAttachmentMenuProvider.notifier).state =
                          true;
                    }
                  },
                ),
                const _AttachmentDrawerSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentDrawerOverlay extends ConsumerWidget {
  const _AttachmentDrawerOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showAttachmentMenuProvider);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: show ? 0 : -260,
      child: const _AttachmentDrawer(),
    );
  }
}

class _ReadyGate extends ConsumerWidget {
  const _ReadyGate({required ScrollController scrollController})
    : _scrollController = scrollController;

  final ScrollController _scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReady = ref.watch(_chatReadyProvider);
    if (!isReady) return const SizedBox.expand();
    return Column(
      children: [
        const _PinnedMessageBar(),
        Expanded(child: _MessageList(scrollController: _scrollController)),
        const _TypingIndicatorWidget(),
      ],
    );
  }
}

class _PinnedMessageBar extends ConsumerWidget {
  const _PinnedMessageBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedMessage = ref.watch(
      directChatProvider.select((state) {
        try {
          return state.messagesById.values.firstWhere(
            (m) => m.isPinned == true,
          );
        } catch (_) {
          return null;
        }
      }),
    );

    if (pinnedMessage == null) return const SizedBox.shrink();

    final theme = ref.watch(chatThemeProvider);
    final headerTextColor = ref.watch(_headerTextColorProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: headerTextColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pinned Message',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pinnedMessage.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: headerTextColor, fontSize: 14),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (pinnedMessage.id != null) {
                ref
                    .read(directChatProvider.notifier)
                    .pinMessage(pinnedMessage.id!, false);
              }
            },
            child: Icon(
              Icons.close,
              size: 20,
              color: headerTextColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(chatWallpaperProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        image: (wallpaper != null && wallpaper.isNotEmpty)
            ? DecorationImage(
                image: CachedNetworkImageProvider(wallpaper),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _MessageListView(scrollController: scrollController),
    );
  }
}

class _MessageListView extends ConsumerWidget {
  const _MessageListView({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageIds = ref.watch(
      directChatProvider.select((state) => state.messageIds),
    );
    final isLoadingMore = ref.watch(
      directChatProvider.select((state) => state.isLoadingMore),
    );
    final hasMore = ref.watch(
      directChatProvider.select((state) => state.hasMore),
    );
    final indexById = <String, int>{
      for (var index = 0; index < messageIds.length; index++)
        messageIds[index]: index,
    };

    return ListView.custom(
      reverse: true,
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= messageIds.length) {
            if (hasMore) {
              Future.microtask(() {
                ref.read(directChatProvider.notifier).loadMore();
              });
            }
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
          final olderId = (index + 1 < messageIds.length)
              ? messageIds[index + 1]
              : null;
          final isOldest = index == messageIds.length - 1;

          return _MessageItem(
            key: ValueKey(id),
            id: id,
            olderId: olderId,
            isOldest: isOldest,
          );
        },
        childCount: messageIds.length + (hasMore ? 1 : 0),
        // Message widgets are cheap to recreate from immutable state. Avoid
        // retaining every off-screen bubble in long conversations.
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            return indexById[key.value];
          }
          return null;
        },
      ),
    );
  }
}

class _MessageItem extends ConsumerWidget {
  const _MessageItem({
    super.key,
    required this.id,
    this.olderId,
    required this.isOldest,
  });

  final String id;
  final String? olderId;
  final bool isOldest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTimestamp = ref.watch(
      directChatProvider.select((state) => state.messagesById[id]?.timestamp),
    );
    final olderTimestamp = olderId != null
        ? ref.watch(
            directChatProvider.select(
              (state) => state.messagesById[olderId]?.timestamp,
            ),
          )
        : null;

    final bool showDateChip;
    if (currentTimestamp == null) {
      showDateChip = false;
    } else if (isOldest || olderTimestamp == null) {
      showDateChip = true;
    } else {
      showDateChip = !DateFormatter.isSameDay(currentTimestamp, olderTimestamp);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDateChip && currentTimestamp != null)
          _DateChip(label: DateFormatter.formatChatDate(currentTimestamp)),
        _BubbleById(key: ValueKey(id), id: id),
      ],
    );
  }
}

class _BubbleById extends ConsumerWidget {
  const _BubbleById({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(chatThemeProvider);
    final msg = ref.watch(
      directChatProvider.select((state) => state.messagesById[id]),
    );

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
        image: '',
        time: '',
        unreadCount: 0,
        isOnline: false,
      ),
    );

    MessageModel? repliedMsg;
    if (msg.replyToMessage != null) {
      repliedMsg = MessageModel(
        id: msg.replyToMessage!.id,
        text: msg.replyToMessage!.text,
        time: '',
        timestamp: DateTime.now(),
        isMe: false,
        type: messageTypeFromWire(msg.replyToMessage!.type),
        mediaUrl: msg.replyToMessage!.mediaUrl,
      );
    } else if (msg.replyToMessageId != null) {
      repliedMsg = ref.watch(
        directChatProvider.select(
          (state) => state.messagesById[msg.replyToMessageId],
        ),
      );
    }

    final String? senderAvatar =
        (msg.senderAvatar != null && msg.senderAvatar!.trim().isNotEmpty)
            ? msg.senderAvatar
            : currentChat.image;

    return ChatBubble(
      key: ValueKey(id),
      message: msg,
      activeTheme: activeTheme,
      otherUserAvatar: senderAvatar,
      repliedMessage: repliedMsg,
      onDelete: () =>
          ref.read(directChatProvider.notifier).deleteMessage(msg.id),
      onPin: () => ref
          .read(directChatProvider.notifier)
          .pinMessage(msg.id, !(msg.isPinned ?? false)),
      onReact: (emoji) =>
          ref.read(directChatProvider.notifier).reactToMessage(msg.id, emoji),
      onReply: () => ref.read(replyingToProvider.notifier).state = msg,
      onEdit: () {
        ref.read(editingMessageProvider.notifier).state = msg;
      },
      onRetry: () => ref.read(directChatProvider.notifier).retryMessage(msg.id),
      onCancel: () =>
          ref.read(directChatProvider.notifier).cancelFailedMessage(msg.id),
    );
  }
}

class _TypingIndicatorWidget extends ConsumerWidget {
  const _TypingIndicatorWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(currentChatIdProvider);
    final isTyping = chatId != null
        ? ref.watch(typingStatusProvider(chatId))
        : false;
    if (!isTyping) return const SizedBox.shrink();
    return const _TypingBubble();
  }
}

class _TypingBubble extends ConsumerStatefulWidget {
  const _TypingBubble();

  @override
  ConsumerState<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends ConsumerState<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(chatThemeProvider);
    final isDarkBg = activeTheme.receivedMessageColor.computeLuminance() <= 0.5;
    final dotColor = isDarkBg ? Colors.white70 : Colors.black54;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 25),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: activeTheme.receivedMessageColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 32,
          height: 12,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // Stagger each dot's phase by 0.2 of the cycle
                  final t = (_controller.value - (i * 0.2)) % 1.0;
                  // Bounce curve: 0 -> 1 -> 0 over the cycle, eased
                  final bounce = t < 0.5
                      ? Curves.easeOut.transform(t * 2)
                      : Curves.easeIn.transform((1 - t) * 2);
                  final scale = 0.6 + (bounce * 0.4);
                  final opacity = 0.4 + (bounce * 0.6);

                  return Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 5.0 : 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
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
          color: theme.dividerColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EditPreviewBar extends ConsumerWidget {
  const _EditPreviewBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMsg = ref.watch(editingMessageProvider);
    if (editMsg == null) return const SizedBox.shrink();
    final activeTheme = ref.watch(chatThemeProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit,
            color: activeTheme.accentColor ?? Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing message',
                  style: TextStyle(
                    color: activeTheme.accentColor ?? Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  editMsg.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              ref.read(editingMessageProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }
}

class _ReplyPreviewBar extends ConsumerWidget {
  const _ReplyPreviewBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyTo = ref.watch(replyingToProvider);
    if (replyTo == null) return const SizedBox.shrink();
    final activeTheme = ref.watch(chatThemeProvider);
    final theme = Theme.of(context);
    final accentColor = activeTheme.accentColor ?? Colors.green;

    final bool isImageType =
        replyTo.type == MessageType.image ||
        replyTo.type == MessageType.gif ||
        replyTo.type == MessageType.video;
    final bool showMediaThumb =
        isImageType && replyTo.mediaUrl != null && replyTo.mediaUrl!.isNotEmpty;

    // Check if it's a URL reply (when not image/video)
    final String? url = (!isImageType)
        ? LinkPreviewService.firstUrl(replyTo.text)
        : null;

    String previewText;
    if (replyTo.text.isNotEmpty) {
      previewText = replyTo.text;
    } else {
      switch (replyTo.type) {
        case MessageType.image:
          previewText = '📷 Photo';
          break;
        case MessageType.gif:
          previewText = '🎞 GIF';
          break;
        case MessageType.video:
          previewText = '🎥 Video';
          break;
        case MessageType.audio:
          previewText = '🎵 Audio';
          break;
        case MessageType.voice:
          previewText = '🎙 Voice message';
          break;
        case MessageType.file:
          previewText = '📁 File';
          break;
        default:
          previewText = '📎 Attachment';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Content section
          Expanded(
            child: url != null
                ? FutureBuilder<LinkPreview?>(
                    future: LinkPreviewService.instance.previewForText(
                      replyTo.text,
                    ),
                    builder: (context, snapshot) {
                      final preview = snapshot.data;
                      final parsedUri = Uri.tryParse(url);
                      final fallbackHost = parsedUri?.host.isNotEmpty == true
                          ? parsedUri!.host
                          : url;
                      final title =
                          (preview != null && preview.title.isNotEmpty)
                          ? preview.title
                          : fallbackHost;
                      final domain =
                          (preview != null && preview.host.isNotEmpty)
                          ? preview.host
                          : fallbackHost;
                      final hasImage =
                          preview?.imageUrl != null &&
                          preview!.imageUrl!.isNotEmpty;

                      return InkWell(
                        onTap: () => UrlLauncherUtils.openUrl(context, url),
                        onLongPress: () =>
                            UrlLauncherUtils.showLinkOptions(context, url),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            // Small thumbnail for URL reply
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: hasImage
                                  ? CachedNetworkImage(
                                      imageUrl: preview!.imageUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 40,
                                        height: 40,
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.public,
                                          size: 18,
                                          color: accentColor,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 40,
                                        height: 40,
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.public,
                                          size: 18,
                                          color: accentColor,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.public,
                                        size: 20,
                                        color: accentColor,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            // Title and domain
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.link_rounded,
                                        size: 12,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          domain,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.65),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 11,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Row(
                    children: [
                      // Thumbnail for image/video replies only
                      if (showMediaThumb) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: replyTo.mediaUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 40,
                              height: 40,
                              color: theme.dividerColor,
                              child: const Icon(
                                Icons.image,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: theme.dividerColor,
                              child: const Icon(
                                Icons.broken_image,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      // Text column (text-only if no media thumb)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              replyTo.isMe
                                  ? 'Replying to yourself'
                                  : 'Replying to message',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          // Cancel button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(replyingToProvider.notifier).state = null,
          ),
        ],
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
                  onTyping: () =>
                      ref.read(directChatProvider.notifier).emitTyping(),
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
                  hintStyle: TextStyle(
                    color: theme.hintColor.withValues(alpha: 0.6),
                  ),
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

class _AttachmentDrawerSection extends ConsumerWidget {
  const _AttachmentDrawerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showAttachmentMenuProvider);
    if (!show) return const SizedBox.shrink();
    return const _AttachmentDrawer();
  }
}

class _AttachmentDrawer extends ConsumerWidget {
  const _AttachmentDrawer();

  Future<void> _pickAndSendImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file != null) {
        ref.read(showAttachmentMenuProvider.notifier).state = false;
        final chatId = ref.read(currentChatIdProvider);
        if (chatId != null) {
          await ref
              .read(directChatProvider.notifier)
              .sendImageAttachment(file.path);
        }
      }
    } catch (e) {
      print('Failed to pick image: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 250,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AttachmentIcon(
            icon: Icons.insert_drive_file,
            color: Colors.indigo,
            label: 'Document',
            onTap: () => _pickAndSendDocument(context, ref),
          ),
          _AttachmentIcon(
            icon: Icons.camera_alt,
            color: Colors.pink,
            label: 'Camera',
            onTap: () => _pickAndSendImage(context, ref, ImageSource.camera),
          ),
          _AttachmentIcon(
            icon: Icons.image,
            color: Colors.purple,
            label: 'Gallery',
            onTap: () => _pickAndSendImage(context, ref, ImageSource.gallery),
          ),
          const _AttachmentIcon(
            icon: Icons.headset,
            color: Colors.orange,
            label: 'Audio',
          ),
          const _AttachmentIcon(
            icon: Icons.location_on,
            color: Colors.green,
            label: 'Location',
          ),
          const _AttachmentIcon(
            icon: Icons.person,
            color: Colors.blue,
            label: 'Contact',
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendDocument(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          ref.read(showAttachmentMenuProvider.notifier).state = false;
          final chatId = ref.read(currentChatIdProvider);
          if (chatId != null) {
            await ref
                .read(directChatProvider.notifier)
                .sendFileAttachment(path);
          }
        }
      }
    } catch (e) {
      print('Failed to pick document: $e');
    }
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
      ),
    );
  }
}
