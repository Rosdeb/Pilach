import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';
import 'package:app/core/utils/date_formatter.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'package:app/Features/Chat/presentation/providers/chat_provider.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_bundle.dart';
import 'inbox_providers.dart';
import 'pinned_message_bar.dart';
import 'typing_indicator_widget.dart';
import 'date_chip.dart';

class ReadyGate extends ConsumerWidget {
  const ReadyGate({super.key, required ScrollController scrollController})
      : _scrollController = scrollController;

  final ScrollController _scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReady = ref.watch(chatReadyProvider);
    if (!isReady) return const SizedBox.expand();
    return Column(
      children: [
        const PinnedMessageBar(),
        Expanded(child: MessageList(scrollController: _scrollController)),
        const TypingIndicatorWidget(),
      ],
    );
  }
}

class MessageList extends ConsumerWidget {
  const MessageList({super.key, required this.scrollController});

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
      child: MessageListView(scrollController: scrollController),
    );
  }
}

class MessageListView extends ConsumerStatefulWidget {
  const MessageListView({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends ConsumerState<MessageListView> {
  final GlobalKey _targetKey = GlobalKey();
  String? _currentTargetId;
  bool _isScrollingToTarget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialTarget = ref.read(targetScrollMessageIdProvider);
      if (initialTarget != null) {
        _scrollToTarget(initialTarget);
      }
    });
  }

  void _scrollToTarget(String targetId) async {
    if (_isScrollingToTarget) return;
    _isScrollingToTarget = true;
    setState(() {
      _currentTargetId = targetId;
    });

    try {
      // 1. Ensure the message is loaded into state
      await ref.read(directChatProvider.notifier).ensureMessageLoaded(targetId);
      if (!mounted) return;

      final messageIds = ref.read(directChatProvider).messageIds;
      final targetIndex = messageIds.indexOf(targetId);
      if (targetIndex == -1) {
        ref.read(targetScrollMessageIdProvider.notifier).state = null;
        return;
      }

      // 2. Schedule scroll
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !widget.scrollController.hasClients) return;

        final controller = widget.scrollController;
        final maxScroll = controller.position.maxScrollExtent;
        final avgHeight = (maxScroll > 0 && messageIds.isNotEmpty)
            ? (maxScroll / messageIds.length).clamp(55.0, 110.0)
            : 75.0;

        final estimatedOffset = (targetIndex * avgHeight).clamp(0.0, maxScroll);

        // Jump near target offset if far away so sliver builds the child
        if ((controller.offset - estimatedOffset).abs() > 300) {
          controller.jumpTo(estimatedOffset);
          await Future.delayed(const Duration(milliseconds: 60));
        }

        if (!mounted) return;

        final ctx = _targetKey.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            alignment: 0.5,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        } else if (controller.hasClients) {
          controller.animateTo(
            estimatedOffset,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        }

        if (mounted) {
          ref.read(targetScrollMessageIdProvider.notifier).state = null;
        }
      });
    } finally {
      if (mounted) {
        _isScrollingToTarget = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(targetScrollMessageIdProvider, (previous, next) {
      if (next != null && next != previous) {
        _scrollToTarget(next);
      }
    });

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
      controller: widget.scrollController,
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
          final isTarget = id == _currentTargetId;

          return MessageItem(
            key: isTarget ? _targetKey : ValueKey(id),
            id: id,
            olderId: olderId,
            isOldest: isOldest,
          );
        },
        childCount: messageIds.length + (hasMore ? 1 : 0),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            return indexById[key.value];
          }
          if (key == _targetKey && _currentTargetId != null) {
            return indexById[_currentTargetId!];
          }
          return null;
        },
      ),
    );
  }
}

class MessageItem extends ConsumerWidget {
  const MessageItem({
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
          DateChip(label: DateFormatter.formatChatDate(currentTimestamp)),
        BubbleById(key: ValueKey(id), id: id),
      ],
    );
  }
}

class BubbleById extends ConsumerWidget {
  const BubbleById({super.key, required this.id});

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

    final highlightedId = ref.watch(highlightedMessageIdProvider);
    final isHighlighted = (highlightedId != null && highlightedId == id);

    return ChatBubble(
      key: ValueKey(id),
      message: msg,
      activeTheme: activeTheme,
      otherUserAvatar: senderAvatar,
      repliedMessage: repliedMsg,
      isHighlighted: isHighlighted,
      onReplyTap: repliedMsg?.id != null
          ? () {
              ref.read(targetScrollMessageIdProvider.notifier).state =
                  repliedMsg!.id;
              ref.read(highlightedMessageIdProvider.notifier).state =
                  repliedMsg!.id;
            }
          : null,
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
