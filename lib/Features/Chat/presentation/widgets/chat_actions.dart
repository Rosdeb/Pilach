import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ── Palette — defined as top-level consts so they're compile-time constants ──

const Color kActionUnreadBlue  = Color(0xFF2196F3);
const Color kActionPinPurple   = Color(0xFF9C27B0);
const Color kActionMuteOrange  = Colors.orangeAccent;
const Color kActionDeleteRed   = Colors.redAccent;

/// Left action panel: shown when user swipes right.
/// Reveals "Unread" and "Pin" buttons.
class LeftActionPanel extends StatelessWidget {
  const LeftActionPanel({
    super.key,
    required this.hasUnread,
    required this.isPinned,
    required this.onUnreadTap,
    required this.onPinTap,
  });

  final bool hasUnread;
  final bool isPinned;
  final VoidCallback onUnreadTap;
  final VoidCallback onPinTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _ActionButton(
          color: kActionUnreadBlue,
          icon: hasUnread
              ? CupertinoIcons.envelope_open
              : CupertinoIcons.envelope_badge,
          label: hasUnread ? 'Read' : 'Unread',
          onTap: onUnreadTap,
        ),
        _ActionButton(
          color: kActionPinPurple,
          icon: isPinned
              ? CupertinoIcons.pin_slash
              : CupertinoIcons.pin,
          label: isPinned ? 'Unpin' : 'Pin',
          onTap: onPinTap,
        ),
      ],
    );
  }
}

/// Right action panel: shown when user swipes left.
/// Reveals "Mute" and "Delete" buttons.
class RightActionPanel extends StatelessWidget {
  const RightActionPanel({
    super.key,
    required this.isMuted,
    required this.onMuteTap,
    required this.onDeleteTap,
  });

  final bool isMuted;
  final VoidCallback onMuteTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _ActionButton(
          color: kActionMuteOrange,
          icon: isMuted
              ? CupertinoIcons.bell_fill
              : CupertinoIcons.bell_slash_fill,
          label: isMuted ? 'Unmute' : 'Mute',
          onTap: onMuteTap,
        ),
        _ActionButton(
          color: kActionDeleteRed,
          icon: CupertinoIcons.trash,
          label: 'Delete',
          onTap: onDeleteTap,
        ),
      ],
    );
  }
}

// ── Private reusable action button ────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  // Single action-width constant shared with controller
  static const double _width = 82.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _width,
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
    );
  }
}
