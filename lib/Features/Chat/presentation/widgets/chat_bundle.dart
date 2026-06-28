import 'package:flutter/material.dart';
import '../../../../core/theme/chat_theme_model.dart';
import '../../data/models/message_model.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final ChatTheme activeTheme;

  const ChatBubble({
    super.key,
    required this.message,
    required this.activeTheme,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  late Animation<double> fade;

  late Animation<Offset> slide;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);

    slide = Tween(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Align(
          alignment: widget.message.isMe
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: widget.message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Bubble Layer Canvas Block Box
                Container(
                  decoration: BoxDecoration(
                    color: widget.message.isMe
                        ? widget.activeTheme.sentMessageColor
                        : widget.activeTheme.receivedMessageColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(widget.message.isMe ? 16 : 4),
                      bottomRight: Radius.circular(
                        widget.message.isMe ? 4 : 16,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 10.0,
                  ),
                  child: Text(
                    widget.message.text,
                    style: TextStyle(
                      color: widget.message.isMe
                          ? (widget.activeTheme.sentMessageColor
                                        .computeLuminance() >
                                    0.5
                                ? Colors.black87
                                : Colors.white)
                          : (widget.activeTheme.receivedMessageColor
                                        .computeLuminance() >
                                    0.5
                                ? Colors.black87
                                : Colors.white),
                      fontSize: 15,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Timestamp and Delivery Status indicators block line
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.message.time,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    if (widget.message.isMe &&
                        widget.message.status != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        widget.message.status == MessageStatus.seen
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        color: widget.message.status == MessageStatus.seen
                            ? const Color(0xFF34C759)
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
