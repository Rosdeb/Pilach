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
import '../../providers/direct_chat_provider.dart';
import '../../widgets/chat_bundle.dart';

// ── Compile-time constants — zero allocation per build ────────────────────────
const Color _kGreen = Color(0xFF34C759);
const String _kAvatarUrl =
    'https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp';

// ── Deferred-load flag — flips true after first post-frame ───────────────────
// autoDispose: cleaned up when screen is popped, so re-entering resets it.
final _chatReadyProvider = StateProvider.autoDispose<bool>((_) => false);

// ── Granular selectors — each widget watches only what it needs ───────────────

/// Only the message count — ListView itemCount source of truth.
final _messageCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(directChatProvider).length,
);

/// Single message by index — only that bubble rebuilds when its data changes.
final _messageAtProvider = Provider.autoDispose.family<MessageModel, String>(
  (ref, id) => ref.watch(directChatProvider).firstWhere((m) => m.id == id),
);

final _messageIdsProvider = Provider.autoDispose<List<String>>(
  (ref) => ref.watch(directChatProvider).map((m) => m.id!).toList(),
);

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(chatThemeProvider);
    final headerTextColor = activeTheme.backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

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
                activeTheme: activeTheme,
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
    required this.activeTheme,
    required ScrollController scrollController,
  }) : _scrollController = scrollController;
  final dynamic activeTheme;
  final ScrollController _scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReady = ref.watch(_chatReadyProvider);
    if (!isReady) return const SizedBox.expand();
    return _MessageList(
      activeTheme: activeTheme,
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
        onTap: () => context.push(AppPaths.chat_profile),
        child: Row(
          children: [
            // RepaintBoundary: avatar image never repaints on message updates
            RepaintBoundary(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundImage: CachedNetworkImageProvider(_kAvatarUrl),
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
                    'Alexandra Sterling',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: headerTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // const: 'Online' text never changes
                  const Text(
                    'Online',
                    style: TextStyle(
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
    required this.activeTheme,
    required this.scrollController,
  });

  final dynamic activeTheme;
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
        activeTheme: activeTheme,
      ),
    );
  }
}

class _MessageListView extends ConsumerWidget {
  const _MessageListView({
    required this.scrollController,
    required this.activeTheme,
  });

  final ScrollController scrollController;
  final dynamic activeTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🟡 MessageListView build');
    final count = ref.watch(directChatProvider.select((msgs) => msgs.length));

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
        return _BubbleRowByIndex(index: index - 1, activeTheme: activeTheme);
      },
    );
  }
}

class _BubbleRowByIndex extends ConsumerWidget {
  const _BubbleRowByIndex({
    super.key,
    required this.index,
    required this.activeTheme,
  });

  final int index;
  final dynamic activeTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // প্রথমে শুধু id নাও — id same থাকলে rebuild নেই
    final id = ref.watch(directChatProvider.select((msgs) => msgs[index].id));

    return _BubbleById(id: id, activeTheme: activeTheme);
  }
}

class _BubbleById extends ConsumerWidget {
  const _BubbleById({super.key, required this.id, required this.activeTheme});

  final String id;
  final dynamic activeTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🔴 BubbleRow build: $id');

    final msg = ref.watch(
      directChatProvider.select((msgs) => msgs.firstWhere((m) => m.id == id)),
    );

    return ChatBubble(
      key: ValueKey(id),
      message: msg,
      activeTheme: activeTheme,
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
    final theme = Theme.of(context);
    final isEnterSend = ref.watch(enterIsSendProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: activeTheme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.12),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.add, color: _kGreen, size: 24),
              onPressed: () {},
            ),
            Expanded(
              child: _InputBox(
                controller: messageController,
                focusNode: focusNode,
                isEnterSend: isEnterSend,
                onSend: onSend,
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(accentColor: activeTheme.accentColor, onTap: onSend),
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.focusNode,
    required this.isEnterSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnterSend;
  final VoidCallback onSend;

  // Static borders — defined once, reused across builds (no allocation).
  static const _transparentBorder = OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.80),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: isEnterSend
                      ? TextInputAction.send
                      : TextInputAction.newline,
                  onSubmitted: isEnterSend ? (_) => onSend() : null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Type a message',
                    border: InputBorder.none,
                    enabledBorder: _transparentBorder,
                    focusedBorder: _transparentBorder,
                    fillColor: theme.colorScheme.surface,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  CupertinoIcons.smiley,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onPressed: () {},
                padding: const EdgeInsets.all(5),
              ),
            ],
          ),
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
