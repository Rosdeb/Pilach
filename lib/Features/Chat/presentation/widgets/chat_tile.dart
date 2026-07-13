import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';

import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../providers/direct_chat_provider.dart';
import 'chat_actions.dart';
import 'chat_avatar.dart';
import 'chat_badge.dart';
import 'chat_slide_controller.dart';

// ── App-wide palette constants (compile-time) ─────────────────────────────────

const Color _kWaGreen    = Color(0xFF25D366);
const Color _kBlueTick   = Color(0xFF34B7F1);
const Color _kDraftRed   = Color(0xFFE94235);
const Color _kActiveBlue  = Color(0xFF007AFF);
const _kMutedGrey        = Color(0xFF9E9E9E); // Grey.shade500 as const

/// WhatsApp-style chat list tile with bidirectional swipe-to-reveal actions.
///
/// ## Performance contract
/// - **Zero [setState]** calls during drag. The [AnimationController] value is
///   driven directly from gesture deltas, so the raster thread composites the
///   slide entirely on the GPU without rebuilding the widget tree.
/// - **[ValueListenableBuilder]** rebuilds only the action-panel [Positioned]
///   when the open direction changes (≈ twice per swipe gesture — open and close).
/// - The main tile content is wrapped in a single [RepaintBoundary] so it gets
///   its own compositing layer and can slide without repainting its children.
/// - [_ChatTileContent] is a separate [ConsumerWidget] that reads only the
///   fields it needs via `select`, so a mute-toggle on a different chat won't
///   rebuild this tile.
class ChatTile extends ConsumerStatefulWidget {
  const ChatTile({super.key, required this.chat});

  final ChatModel chat;

  @override
  ConsumerState<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends ConsumerState<ChatTile> with SingleTickerProviderStateMixin {
  late final ChatSlideController _slide;

  late final Animation<Offset> _leftOffset;  // tile moves right (reveals left panel)
  late final Animation<Offset> _rightOffset; // tile moves left  (reveals right panel)

  @override
  void initState() {
    super.initState();
    _slide = ChatSlideController(vsync: this);

    _leftOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.4, 0),
    ).animate(_slide.animation);

    _rightOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.4, 0),
    ).animate(_slide.animation);
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _handleUnread() {
    _slide.close();
    ref.read(chatProvider.notifier).toggleUnreadChat(widget.chat.id);
  }

  void _handlePin() {
    _slide.close();
    ref.read(chatProvider.notifier).togglePinChat(widget.chat.id);
  }

  void _handleMute() {
    _slide.close();
    ref.read(chatProvider.notifier).toggleMuteChat(widget.chat.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.chat.isMuted ? 'Unmuted' : 'Muted'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _handleDelete() async {
    _slide.close();
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Delete conversation with ${widget.chat.name}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(chatProvider.notifier).deleteChat(widget.chat.id);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: 72, // fixed height prevents layout thrash in the sliver
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Solid bg — covers the gap on the opposite side when tile slides ──
          Positioned.fill(child: ColoredBox(color: bgColor)),

          // ── Action panels — only rebuilt when direction changes ──────────
          ValueListenableBuilder<SlideDirection>(
            valueListenable: _slide.direction,
            builder: (context, dir, _) {
              if (dir == SlideDirection.none) return const SizedBox.shrink();

              if (dir == SlideDirection.left) {
                return RepaintBoundary(
                  child: LeftActionPanel(
                    hasUnread: chat.unreadCount > 0,
                    isPinned: chat.isPinned,
                    onUnreadTap: _handleUnread,
                    onPinTap: _handlePin,
                  ),
                );
              }

              // SlideDirection.right
              return RepaintBoundary(
                child: RightActionPanel(
                  isMuted: chat.isMuted,
                  onMuteTap: _handleMute,
                  onDeleteTap: _handleDelete,
                ),
              );
            },
          ),

          // ── Main tile — direction-aware slide ────────────────────────────
          // ValueListenableBuilder rebuilds only when direction is locked
          // (once per swipe), picking the correct offset animation.
          // During the actual drag the AnimationController drives the GPU
          // layer transform with zero Dart rebuilds.
          ValueListenableBuilder<SlideDirection>(
            valueListenable: _slide.direction,
            builder: (context, dir, child) {
              return SlideTransition(
                position: dir == SlideDirection.right
                    ? _rightOffset
                    : _leftOffset,
                child: child,
              );
            },
            // child is constant across direction changes — never rebuilt.
            child: RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _slide.onDragUpdate,
                onHorizontalDragEnd: _slide.onDragEnd,
                onTap: () {
                  if (_slide.direction.value != SlideDirection.none) {
                    _slide.close();
                  } else {
                    ref.read(chatProvider.notifier).clearUnreadCount(chat.id);
                    ref.read(currentChatIdProvider.notifier).state = chat.id;
                    context.push(AppPaths.chat);
                  }
                },
                child: ColoredBox(
                  color: bgColor,
                  child: _ChatTileContent(
                    chat: chat,
                    bgColor: bgColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content widget — isolated rebuild domain
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the visible tile content (avatar, name, preview, badges).
///
/// Separated from [ChatTile] so that animation state changes don't force this
/// subtree to rebuild, and Riverpod can surgically update only changed fields.
class _ChatTileContent extends ConsumerWidget {
  const _ChatTileContent({
    required this.chat,
    required this.bgColor,
  });

  final ChatModel chat;
  final Color bgColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasUnread = chat.unreadCount > 0;

    return InkWell(
      // onTap handled by parent GestureDetector — InkWell here is purely for
      // the ripple visual. We absorb taps at GestureDetector level.
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // Avatar — gets its own RepaintBoundary: image decode is expensive
            // and we never want it to repaint just because unread count changed.
            RepaintBoundary(
              child: ChatAvatar(
                imageUrl: chat.image,
                isOnline: chat.isOnline,
                onlineColor: _kActiveBlue,
                borderColor: bgColor,
              ),
            ),
            const SizedBox(width: 12),

            // Text body
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + timestamp row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                chat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              chat.time,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: hasUnread
                                    ? (chat.isMuted
                                    ? _kMutedGrey
                                    : _kWaGreen)
                                    : theme.colorScheme.onSurface
                                    .withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Preview row
                        Row(
                          children: [
                            _LeadingPreviewIcon(
                              hasUnread: hasUnread,
                              hasDraft: chat.draft != null,
                              isMuted: chat.isMuted,
                              isRead: chat.isRead,
                            ),
                            Expanded(
                              child: Text(
                                chat.draft ?? chat.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: chat.draft != null
                                      ? theme.colorScheme.onSurface
                                      .withOpacity(0.85)
                                      : theme.colorScheme.onSurface
                                      .withOpacity(0.55),
                                  fontStyle: chat.draft != null
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Pin + unread badge
                  ChatBadge(
                    isPinned: chat.isPinned,
                    hasUnread: hasUnread,
                    unreadCount: chat.unreadCount,
                    isMuted: chat.isMuted,
                    mutedGrey: _kMutedGrey,
                    accentColor: _kWaGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leading preview icon — stateless, const-safe
// ─────────────────────────────────────────────────────────────────────────────

/// The small icon/label shown before the message preview:
/// • Draft label  (when draft != null)
/// • Read receipt (when no unread and no draft)
/// • Mute icon    (when muted)
/// Returns [SizedBox.shrink()] when nothing should show (has unread, no extras).
class _LeadingPreviewIcon extends StatelessWidget {
  const _LeadingPreviewIcon({
    required this.hasUnread,
    required this.hasDraft,
    required this.isMuted,
    required this.isRead,
  });

  final bool hasUnread;
  final bool hasDraft;
  final bool isMuted;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    if (hasDraft) {
      return const Padding(
        padding: EdgeInsets.only(right: 3),
        child: Text(
          'Draft:',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _kDraftRed,
          ),
        ),
      );
    }

    // Show mute icon + read receipt together when not unread
    if (!hasUnread) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMuted)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(
                CupertinoIcons.bell_slash,
                size: 13,
                color: _kMutedGrey,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: isRead ? _kBlueTick : _kMutedGrey,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}