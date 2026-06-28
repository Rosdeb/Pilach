import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Right-column badge widget: pin icon + unread count bubble.
///
/// Fully stateless and const-constructable so Flutter can short-circuit
/// reconciliation when inputs haven't changed.
class ChatBadge extends StatelessWidget {
  const ChatBadge({
    super.key,
    required this.isPinned,
    required this.hasUnread,
    required this.unreadCount,
    required this.isMuted,
    required this.mutedGrey,
    required this.accentColor,
  });

  final bool isPinned;
  final bool hasUnread;
  final int unreadCount;
  final bool isMuted;
  final Color mutedGrey;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (!isPinned && !hasUnread) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isPinned)
          Transform.rotate(
            angle: 0.785, // 45°
            child: Icon(CupertinoIcons.pin, size: 14, color: mutedGrey),
          ),
        if (isPinned && hasUnread) const SizedBox(height: 4),
        if (hasUnread) _UnreadBubble(
          count: unreadCount,
          color: isMuted ? mutedGrey : accentColor,
        ),
      ],
    );
  }
}

class _UnreadBubble extends StatelessWidget {
  const _UnreadBubble({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
