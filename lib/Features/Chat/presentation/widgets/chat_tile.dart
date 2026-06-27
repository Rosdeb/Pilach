import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';

class ChatTile extends ConsumerStatefulWidget {
  final ChatModel chat;

  const ChatTile({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends ConsumerState<ChatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _leftSlide;  // tile slides RIGHT (reveals left actions)
  late final Animation<Offset> _rightSlide; // tile slides LEFT (reveals right actions)

  double _dragExtent = 0.0;
  bool _isLeftOpen = false;

  static const double _actionWidth = 82.0;
  static const double _maxDrag = _actionWidth * 2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    // Pre-build both animations once — not on every rebuild
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _leftSlide  = Tween<Offset>(begin: Offset.zero, end: const Offset( 0.4, 0.0)).animate(curved);
    _rightSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.4, 0.0)).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.primaryDelta! * 0.82; // resistance factor — 1.0 = no resistance
    final next = (_dragExtent + delta).clamp(-_maxDrag, _maxDrag);
    if (next == _dragExtent) return;

    if (_dragExtent == 0.0) {
      setState(() => _isLeftOpen = next > 0);
    }

    if (_isLeftOpen && next < 0) return;
    if (!_isLeftOpen && next > 0) return;

    _dragExtent = next;
    _controller.value = _dragExtent.abs() / _maxDrag;
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;

    // Fast fling → direction অনুযায়ী সরাসরি open/close
    if (velocity.abs() > 400) {
      if (_isLeftOpen && velocity > 0) {
        _controller.forward();
        _dragExtent = _maxDrag;
      } else if (!_isLeftOpen && velocity < 0) {
        _controller.forward();
        _dragExtent = -_maxDrag;
      } else {
        _closeSlider(); // opposite direction fling → close
      }
      return;
    }

    // Slow drag → threshold দিয়ে decide
    if (_dragExtent.abs() > _actionWidth * 0.5) { // 50% open হলে snap open
      _controller.forward();
      _dragExtent = _isLeftOpen ? _maxDrag : -_maxDrag;
    } else {
      _closeSlider();
    }
  }

  void _closeSlider() {
    _controller.animateBack(0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOutCubic,
    );
    _dragExtent = 0.0;
  }

  // ── Action button (stateless-safe, const-friendly) ───────────────────
  Widget _actionBtn({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: SizedBox(
          width: _actionWidth,
          height: double.infinity,
          child: ColoredBox(
            color: color,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final theme = Theme.of(context);
    final hasUnread = chat.unreadCount > 0;

    // Colors — defined once per build, not recreated inside subtrees
    const waGreen    = Color(0xFF25D366);
    const waBlueTick = Color(0xFF34B7F1);
    const draftRed   = Color(0xFFE94235);
    const muteOrange = Colors.orangeAccent;
    const deleteRed  = Colors.redAccent;
    const pinPurple  = Color(0xFF9C27B0);
    const unreadBlue = Color(0xFF2196F3);
    final mutedGrey  = Colors.grey.shade500;

    return Stack(
      children: [
        // ── Left actions (pin + unread) — only paint when open ──────────
        if (_isLeftOpen || _dragExtent > 0)
          Positioned.fill(
            child: RepaintBoundary(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _actionBtn(
                    color: unreadBlue,
                    icon: hasUnread ? CupertinoIcons.envelope_open : CupertinoIcons.envelope_badge,
                    label: hasUnread ? 'Read' : 'Unread',
                    onTap: () {
                      _closeSlider();
                      ref.read(chatProvider.notifier).toggleUnreadChat(chat.id);
                    },
                  ),
                  _actionBtn(
                    color: pinPurple,
                    icon: chat.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                    label: chat.isPinned ? 'Unpin' : 'Pin',
                    onTap: () {
                      _closeSlider();
                      ref.read(chatProvider.notifier).togglePinChat(chat.id);
                    },
                  ),
                ],
              ),
            ),
          ),

        // ── Right actions (mute + delete) — only paint when open ────────
        if (!_isLeftOpen || _dragExtent < 0)
          Positioned.fill(
            child: RepaintBoundary(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionBtn(
                    color: muteOrange,
                    icon: chat.isMuted ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
                    label: chat.isMuted ? 'Unmute' : 'Mute',
                    onTap: () {
                      _closeSlider();
                      ref.read(chatProvider.notifier).toggleMuteChat(chat.id);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(chat.isMuted ? 'Unmuted' : 'Muted'),
                        duration: const Duration(seconds: 1),
                      ));
                    },
                  ),
                  _actionBtn(
                    color: deleteRed,
                    icon: CupertinoIcons.trash,
                    label: 'Delete',
                    onTap: () async {
                      _closeSlider();
                      final confirm = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Delete Conversation'),
                          content: Text('Delete conversation with ${chat.name}?'),
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
                      if (confirm == true) {
                        ref.read(chatProvider.notifier).deleteChat(chat.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

        // ── Main tile ────────────────────────────────────────────────────
        SlideTransition(
          // SlideTransition uses the animation directly — zero rebuilds
          position: _isLeftOpen ? _leftSlide : _rightSlide,
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: InkWell(
                  onTap: () => _dragExtent != 0.0 ? _closeSlider() : context.push(AppPaths.chat),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        // Avatar
                        RepaintBoundary(
                          child: _Avatar(
                            chat: chat,
                            onlineColor: waGreen,
                            bgColor: theme.scaffoldBackgroundColor,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Body + right col
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Name + time
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
                                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                            color: hasUnread
                                                ? (chat.isMuted ? mutedGrey : waGreen)
                                                : theme.colorScheme.onSurface.withOpacity(0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),

                                    // Preview row
                                    Row(
                                      children: [
                                        if (!hasUnread && chat.draft == null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 3),
                                            child: Icon(
                                              chat.isRead ? Icons.done_all : Icons.done,
                                              size: 16,
                                              color: chat.isRead ? waBlueTick : mutedGrey,
                                            ),
                                          ),
                                        if (chat.draft != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 3),
                                            child: const Text(
                                              'Draft:',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                                color: draftRed,
                                              ),
                                            ),
                                          ),
                                        if (chat.isMuted)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 3),
                                            child: Icon(
                                              CupertinoIcons.bell_slash,
                                              size: 13,
                                              color: mutedGrey,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            chat.draft ?? chat.message,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: chat.draft != null
                                                  ? theme.colorScheme.onSurface.withOpacity(0.85)
                                                  : theme.colorScheme.onSurface.withOpacity(0.55),
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

                              // Pin + badge
                              _RightCol(
                                isPinned: chat.isPinned,
                                hasUnread: hasUnread,
                                unreadCount: chat.unreadCount,
                                isMuted: chat.isMuted,
                                mutedGrey: mutedGrey,
                                waGreen: waGreen,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Extracted stateless widgets — no unnecessary rebuilds ─────────────────

class _Avatar extends StatelessWidget {
  final ChatModel chat;
  final Color onlineColor;
  final Color bgColor;

  const _Avatar({
    required this.chat,
    required this.onlineColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: chat.image,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
              cacheKey: chat.name + chat.image,
              placeholder: (_, __) => const CupertinoActivityIndicator(),
              errorWidget: (_, __, ___) => const Icon(Icons.person),
            ),
          ),
        ),
        if (chat.isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
                border: Border.all(color: bgColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _RightCol extends StatelessWidget {
  final bool isPinned;
  final bool hasUnread;
  final int unreadCount;
  final bool isMuted;
  final Color mutedGrey;
  final Color waGreen;

  const _RightCol({
    required this.isPinned,
    required this.hasUnread,
    required this.unreadCount,
    required this.isMuted,
    required this.mutedGrey,
    required this.waGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isPinned)
          Transform.rotate(
            angle: 0.785,
            child: Icon(CupertinoIcons.pin, size: 14, color: mutedGrey),
          ),
        if (isPinned && hasUnread) const SizedBox(height: 4),
        if (hasUnread)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 20),
            decoration: BoxDecoration(
              color: isMuted ? mutedGrey : waGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}