import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/constants/asset_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/chat_theme_model.dart';
import '../../data/models/message_model.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final ChatTheme activeTheme;
  final String? otherUserAvatar;
  final MessageModel? repliedMessage;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final Function(String)? onReact;
  final VoidCallback? onReply;

  const ChatBubble({
    super.key,
    required this.message,
    required this.activeTheme,
    this.otherUserAvatar,
    this.repliedMessage,
    this.onDelete,
    this.onPin,
    this.onReact,
    this.onReply,
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

    // ✅ Prevents list blinking when temp message is replaced by real message:
    // Only animate when initially sending or when receiving a brand-new incoming message.
    if (widget.message.status == MessageStatus.sending || 
        (!widget.message.isMe && DateTime.now().difference(widget.message.timestamp).inSeconds < 3)) {
      controller.forward();
    } else {
      controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!widget.message.isMe && widget.otherUserAvatar != null) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundImage: widget.otherUserAvatar!.startsWith('http')
                      ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                      : AssetImage(widget.otherUserAvatar!) as ImageProvider,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.70,
                  ),
                  child: Column(
                    crossAxisAlignment: widget.message.isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Bubble Layer Canvas Block Box
                      GestureDetector(
                        onLongPress: widget.message.isDeleted ? null : () => _showMessageOptions(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.message.isMe
                                ? widget.activeTheme.sentMessageColor
                                : widget.activeTheme.receivedMessageColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(
                                widget.message.isMe ? 16 : 4,
                              ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.repliedMessage != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6.0),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(left: BorderSide(color: widget.activeTheme.accentColor ?? Colors.green, width: 3)),
                                  ),
                                  child: Text(
                                    widget.repliedMessage!.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.message.isMe 
                                        ? Colors.white.withOpacity(0.9) 
                                        : Colors.black.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              if (widget.message.isDeleted) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.block,
                                      size: 15,
                                      color: widget.message.isMe
                                          ? (widget.activeTheme.sentMessageColor.computeLuminance() > 0.5
                                              ? Colors.black54
                                              : Colors.white70)
                                          : (widget.activeTheme.receivedMessageColor.computeLuminance() > 0.5
                                              ? Colors.black54
                                              : Colors.white70),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.message.isMe
                                          ? 'You deleted this message'
                                          : 'This message was deleted',
                                      style: TextStyle(
                                        color: widget.message.isMe
                                            ? (widget.activeTheme.sentMessageColor.computeLuminance() > 0.5
                                                ? Colors.black54
                                                : Colors.white70)
                                            : (widget.activeTheme.receivedMessageColor.computeLuminance() > 0.5
                                                ? Colors.black54
                                                : Colors.white70),
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  widget.message.text,
                                  style: TextStyle(
                                    color: widget.message.isMe
                                        ? (widget.activeTheme.sentMessageColor.computeLuminance() > 0.5
                                              ? Colors.black87
                                              : Colors.white)
                                        : (widget.activeTheme.receivedMessageColor.computeLuminance() > 0.5
                                              ? Colors.black87
                                              : Colors.white),
                                    fontSize: 15,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
  
                      const SizedBox(height: 4),
  
                      // Timestamp and Delivery Status indicators block line
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.message.reactions != null &&
                              widget.message.reactions!.isNotEmpty) ...[
                            Wrap(
                              spacing: 4.0,
                              runSpacing: 4.0,
                              children: _buildReactions(
                                widget.message.reactions!,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
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
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReactions(List<Map<String, dynamic>> reactions) {
    final counts = <String, int>{};
    for (var r in reactions) {
      final e = r['emoji'] as String?;
      if (e != null) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
    }

    return counts.entries
        .map(
          (e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12)),
                if (e.value > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${e.value}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
        .toList();
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Emoji Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (widget.onReact != null) widget.onReact!(emoji);
                        },
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Actions Card
                Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.reply, size: 22),
                        title: Text('Reply', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          if (widget.onReply != null) widget.onReply!();
                        },
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.withValues(alpha: 0.2)),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.push_pin_outlined, size: 22),
                        title: Text('Pin Message', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          if (widget.onPin != null) widget.onPin!();
                        },
                      ),
                      if (widget.message.isMe) ...[
                        Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.withValues(alpha: 0.2)),
                        ListTile(
                          dense: true,
                          leading: Image.asset(Assets.trash, color: Colors.red, height: 22,width: 22,),
                          title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                          onTap: () {
                            Navigator.pop(context);
                            if (widget.onDelete != null) widget.onDelete!();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
