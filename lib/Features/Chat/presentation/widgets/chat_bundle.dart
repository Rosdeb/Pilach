import 'dart:io';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/constants/asset_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/chat_theme_model.dart';
import '../../data/models/message_model.dart';
import 'image_preview_viewer.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final ChatTheme activeTheme;
  final String? otherUserAvatar;
  final MessageModel? repliedMessage;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final Function(String)? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;

  const ChatBubble({
    super.key,
    required this.message,
    required this.activeTheme,
    this.otherUserAvatar,
    this.repliedMessage,
    required this.onDelete,
    required this.onPin,
    this.onReact,
    this.onReply,
    this.onEdit,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  late Animation<double> fade;

  late Animation<Offset> slide;

  final GlobalKey _bubbleKey = GlobalKey();
  OverlayEntry? _menuOverlay;

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

    if (widget.message.status == MessageStatus.sending || (!widget.message.isMe && DateTime.now().difference(widget.message.timestamp).inSeconds < 3)) {
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
    _removeOverlay();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = widget.message.mediaUrl != null &&
        widget.message.mediaUrl!.isNotEmpty &&
        !widget.message.isDeleted;

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
                          key: _bubbleKey,
                          clipBehavior: Clip.antiAlias,
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
                          padding: hasImage
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 10.0,
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.repliedMessage != null) ...[
                                Padding(
                                  padding: hasImage
                                      ? const EdgeInsets.only(left: 14.0, right: 14.0, top: 10.0, bottom: 4.0)
                                      : EdgeInsets.zero,
                                  child: Container(
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
                                ),
                              ],
                              if (widget.message.isDeleted) ...[
                                Padding(
                                  padding: hasImage
                                      ? const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0)
                                      : EdgeInsets.zero,
                                  child: Row(
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
                                ),
                              ] else ...[
                                if (hasImage) ...[
                                  Builder(
                                    builder: (context) {
                                      final rawUrl = widget.message.mediaUrl!;
                                      final bool isLocalFile = File(rawUrl).existsSync();
                                      final String networkUrl = (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
                                          ? rawUrl
                                          : 'https://xdtunnel.icu/$rawUrl';
                                      final String heroTag = 'hero_img_${widget.message.id}';

                                      return GestureDetector(
                                        onTap: () => FullScreenImageViewer.open(
                                          context,
                                          imagePathOrUrl: isLocalFile ? rawUrl : networkUrl,
                                          heroTag: heroTag,
                                          title: widget.message.time,
                                        ),
                                        child: Hero(
                                          tag: heroTag,
                                          child: SizedBox(
                                            width: 250.0,
                                            height: 190.0,
                                            child: isLocalFile
                                                ? Image.file(
                                                    File(rawUrl),
                                                    width: 250.0,
                                                    height: 190.0,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.grey[850]
                                                          : Colors.grey[200],
                                                      child: const Icon(Icons.broken_image, size: 40),
                                                    ),
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl: networkUrl,
                                                    width: 250.0,
                                                    height: 190.0,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => const _ShimmerPlaceholder(
                                                      width: 250.0,
                                                      height: 190.0,
                                                    ),
                                                    errorWidget: (context, url, error) => Container(
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.grey[850]
                                                          : Colors.grey[200],
                                                      child: const Icon(Icons.broken_image, size: 40),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                if (widget.message.text.isNotEmpty)
                                  Padding(
                                    padding: hasImage
                                        ? const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 10.0, top: 8.0)
                                        : EdgeInsets.zero,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
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
                                        ),
                                        if (widget.message.isEdited == true && !widget.message.isDeleted)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4.0),
                                          child: Text(
                                            '(Edited)',
                                            style: TextStyle(
                                              color: (widget.message.isMe
                                                      ? (widget.activeTheme.sentMessageColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                                                      : (widget.activeTheme.receivedMessageColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white))
                                                  .withValues(alpha: 0.7),
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
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
                              (widget.message.status == MessageStatus.seen || widget.message.status == MessageStatus.delivered)
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
    final RenderBox? box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final Offset bubbleTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final Size bubbleSize = box.size;
    final Size screenSize = overlayBox.size;
    final double topSafe = MediaQuery.of(context).padding.top;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    const double menuWidth = 230;
    const double estimatedMenuHeight = 250;
    const double gap = 8;

    final double spaceBelow = screenSize.height - bottomSafe - (bubbleTopLeft.dy + bubbleSize.height);
    final bool openBelow = spaceBelow > estimatedMenuHeight;

    final double bubbleLeft = bubbleTopLeft.dx;
    final double bubbleRight = bubbleTopLeft.dx + bubbleSize.width;

    final double top = openBelow
        ? bubbleTopLeft.dy + bubbleSize.height + gap
        : (bubbleTopLeft.dy - estimatedMenuHeight - gap).clamp(topSafe + gap, screenSize.height);

    final double left = widget.message.isMe
        ? (bubbleTopLeft.dx + bubbleSize.width - menuWidth).clamp(12.0, screenSize.width - menuWidth - 12.0)
        : bubbleTopLeft.dx.clamp(12.0, screenSize.width - menuWidth - 12.0);

    final anchorOffset = Offset(
      bubbleTopLeft.dx + bubbleSize.width / 2,
      openBelow ? bubbleTopLeft.dy + bubbleSize.height : bubbleTopLeft.dy,
    );

    _menuOverlay = OverlayEntry(
      builder: (_) => _MessageActionOverlay(
        isMe: widget.message.isMe,   // <-- NEW
        bubbleLeft: bubbleLeft,      // <-- NEW
        bubbleRight: bubbleRight,    // <-- NEW
        screenWidth: screenSize.width,
        top: top,
        left: left,
        menuWidth: menuWidth,
        openBelow: openBelow,
        anchorOffset: anchorOffset,
        onDismiss: _removeOverlay,
        onReact: (emoji) {
          _removeOverlay();
          widget.onReact?.call(emoji);
        },
        onReply: widget.onReply == null
            ? null
            : () {
          _removeOverlay();
          widget.onReply!();
        },
        onEdit: (widget.message.isMe &&
            widget.message.type == MessageType.text &&
            widget.onEdit != null)
            ? () {
          _removeOverlay();
          widget.onEdit!();
        }
            : null,
        onPin: () {
          _removeOverlay();
          widget.onPin();
        },
        onDelete: widget.message.isMe
            ? () {
          _removeOverlay();
          widget.onDelete();
        }
            : null,
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  void _removeOverlay() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

}

class _ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerPlaceholder({
    required this.width,
    required this.height,
  });

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent - 0.5) * 2, 0.0, 0.0);
  }
}

class _MessageActionOverlay extends StatefulWidget {
  final double top;
  final bool isMe;              // <-- NEW
  final double bubbleLeft;      // <-- NEW
  final double bubbleRight;     // <-- NEW
  final double screenWidth;
  final double left;
  final double menuWidth;
  final bool openBelow;
  final Offset anchorOffset;
  final VoidCallback onDismiss;
  final Function(String) onReact;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback onPin;
  final VoidCallback? onDelete;

  const _MessageActionOverlay({
    required this.top,
    required this.isMe,
    required this.bubbleLeft,
    required this.bubbleRight,
    required this.screenWidth,
    required this.left,
    required this.menuWidth,
    required this.openBelow,
    required this.anchorOffset,
    required this.onDismiss,
    required this.onReact,
    required this.onPin,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_MessageActionOverlay> createState() => _MessageActionOverlayState();
}

class _MessageActionOverlayState extends State<_MessageActionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // origin near the bubble edge so scale grows from that point, Messenger-style
    final alignmentX = (widget.anchorOffset.dx - widget.left) / widget.menuWidth;
    final alignment = Alignment(
      (alignmentX.clamp(0.0, 1.0) * 2) - 1,
      widget.openBelow ? -1.0 : 1.0,
    );

    return Stack(
      children: [
        // Dim backdrop — tap outside to close
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: FadeTransition(
              opacity: _fade,
              child: Container(color: Colors.black.withOpacity(0.15)),
            ),
          ),
        ),
        Positioned(
          top: widget.top,
          left: widget.left,
          width: widget.menuWidth,
          child: ScaleTransition(
            scale: _scale,
            alignment: alignment,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.openBelow) _buildEmojiPill(theme),
                    if (widget.openBelow) const SizedBox(height: 6),
                    _buildActionsCard(theme),
                    if (!widget.openBelow) const SizedBox(height: 6),
                    if (!widget.openBelow) _buildEmojiPill(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiPill(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
          return GestureDetector(
            onTap: () => widget.onReact(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme) {
    final items = <Widget>[];

    void addTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      if (items.isNotEmpty) {
        items.add(Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.withOpacity(0.15)));
      }
      items.add(
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color ?? theme.colorScheme.onSurface),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(fontSize: 14, color: color ?? theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.onReply != null) addTile(Icons.reply, 'Reply', widget.onReply!);
    if (widget.onEdit != null) addTile(Icons.edit, 'Edit', widget.onEdit!);
    addTile(Icons.push_pin_outlined, 'Pin Message', widget.onPin);
    if (widget.onDelete != null) {
      addTile(Icons.delete_outline, 'Delete Message', widget.onDelete!, color: Colors.redAccent);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}
