import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/chat_theme_model.dart';
import '../../../../core/models/link_preview.dart';
import '../../../../core/services/link_preview_service.dart';
import '../../../../core/utils/url_launcher_utils.dart';
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
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

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
    this.onRetry,
    this.onCancel,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with TickerProviderStateMixin {
  late AnimationController controller;
  late AnimationController _swipeController;

  late Animation<double> fade;

  late Animation<Offset> slide;

  final GlobalKey _bubbleKey = GlobalKey();
  OverlayEntry? _menuOverlay;
  Future<LinkPreview?>? _linkPreviewFuture;

  bool _isReplyTriggered = false;
  final double _maxDragDistance = 60.0;

  @override
  void initState() {
    super.initState();
    _prepareLinkPreview();

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);

    slide = Tween(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    if (widget.message.status == MessageStatus.sending ||
        (!widget.message.isMe &&
            DateTime.now().difference(widget.message.timestamp).inSeconds <
                3)) {
      controller.forward();
    } else {
      controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.text != widget.message.text) {
      _prepareLinkPreview();
    }
  }

  void _prepareLinkPreview() {
    final url = LinkPreviewService.firstUrl(widget.message.text);
    _linkPreviewFuture = url == null
        ? null
        : LinkPreviewService.instance.previewForText(widget.message.text);
  }

  @override
  void dispose() {
    _removeOverlay();
    controller.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage =
        widget.message.mediaUrl != null &&
        widget.message.mediaUrl!.isNotEmpty &&
        !widget.message.isDeleted;

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: GestureDetector(
          onHorizontalDragStart: (details) {
            if (widget.message.isDeleted || widget.onReply == null) return;
            _swipeController.stop();
          },
          onHorizontalDragUpdate: (details) {
            if (widget.message.isDeleted || widget.onReply == null) return;
            double newVal =
                _swipeController.value - (details.delta.dx / _maxDragDistance);
            if (newVal < 0) newVal = 0;
            if (newVal > 1.5) newVal = 1.5;
            _swipeController.value = newVal;

            if (_swipeController.value >= 1.0 && !_isReplyTriggered) {
              _isReplyTriggered = true;
              HapticFeedback.lightImpact();
              widget.onReply!();
            } else if (_swipeController.value < 1.0) {
              _isReplyTriggered = false;
            }
          },
          onHorizontalDragEnd: (details) {
            _isReplyTriggered = false;
            _swipeController.animateTo(0.0, curve: Curves.easeOutBack);
          },
          onHorizontalDragCancel: () {
            _isReplyTriggered = false;
            _swipeController.animateTo(0.0, curve: Curves.easeOutBack);
          },
          child: AnimatedBuilder(
            animation: _swipeController,
            builder: (context, child) {
              final double offset =
                  -(_swipeController.value * _maxDragDistance);
              return Stack(
                children: [
                  Positioned(
                    right: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (_swipeController.value > 0.1)
                            ? ((_swipeController.value - 0.1) / 0.9).clamp(
                                0.0,
                                1.0,
                              )
                            : 0.0,
                        child: Transform.scale(
                          scale: _swipeController.value >= 1.0 ? 1.2 : 1.0,
                          child: Icon(
                            Icons.reply,
                            color: _swipeController.value >= 1.0
                                ? (widget.activeTheme.accentColor ??
                                      Colors.green)
                                : Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(offset: Offset(offset, 0), child: child),
                ],
              );
            },
            child: Align(
              alignment: widget.message.isMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.message.isMe &&
                      widget.otherUserAvatar != null) ...[
                    CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          widget.otherUserAvatar!.startsWith('http')
                          ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                          : AssetImage(widget.otherUserAvatar!)
                                as ImageProvider,
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
                            onTap: widget.message.status == MessageStatus.failed
                                ? () =>
                                      _showFailedMessageRecoveryDialog(context)
                                : null,
                            onLongPress: widget.message.isDeleted
                                ? null
                                : () => _showMessageOptions(context),
                            child: _buildBubbleContent(
                              context,
                              hasImage,
                              isOverlay: false,
                            ),
                          ),

                          if (_hasValidReactions(widget.message.reactions)) ...[
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 4.0,
                              runSpacing: 4.0,
                              children: _buildReactions(
                                widget.message.reactions!,
                              ),
                            ),
                          ],

                          const SizedBox(height: 3),

                          // Timestamp and Delivery Status indicators block line
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.message.time,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                              if (widget.message.isMe) ...[
                                const SizedBox(width: 4),
                                _buildStatusIcon(context, theme),
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
        ),
      ),
    );
  }

  void _showFailedMessageRecoveryDialog(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Message Not Sent'),
        message: const Text(
          'This message failed to send. Would you like to retry or delete it?',
        ),
        actions: [
          if (widget.onRetry != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onRetry!();
              },
              child: const Text('Retry Sending'),
            ),
          if (widget.onCancel != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                widget.onCancel!();
              },
              child: const Text('Cancel & Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Dismiss'),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, ThemeData theme) {
    switch (widget.message.status) {
      case MessageStatus.failed:
        return GestureDetector(
          onTap: () => _showFailedMessageRecoveryDialog(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 2.0),
            child: Icon(
              Icons.error_outline_rounded,
              size: 15,
              color: Colors.redAccent,
            ),
          ),
        );
      case MessageStatus.queued:
      case MessageStatus.sending:
        return Padding(
          padding: const EdgeInsets.only(left: 2.0),
          child: Icon(
            CupertinoIcons.clock,
            size: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );
      case MessageStatus.seen:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF34C759));
    }
  }

  Widget _buildBubbleContent(
    BuildContext context,
    bool hasImage, {
    bool isOverlay = false,
  }) {
    return Container(
      key: isOverlay ? null : _bubbleKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.message.isMe
            ? widget.activeTheme.sentMessageColor
            : widget.activeTheme.receivedMessageColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(widget.message.isMe ? 16 : 4),
          bottomRight: Radius.circular(widget.message.isMe ? 4 : 16),
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
          : const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.repliedMessage != null) ...[
            Padding(
              padding: hasImage
                  ? const EdgeInsets.only(
                      left: 14.0,
                      right: 14.0,
                      top: 10.0,
                      bottom: 4.0,
                    )
                  : EdgeInsets.zero,
              child: _ReplyPreviewBlock(
                repliedMessage: widget.repliedMessage!,
                accentColor: widget.activeTheme.accentColor ?? Colors.green,
                isMe: widget.message.isMe,
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
                        ? (widget.activeTheme.sentMessageColor
                                      .computeLuminance() >
                                  0.5
                              ? Colors.black54
                              : Colors.white70)
                        : (widget.activeTheme.receivedMessageColor
                                      .computeLuminance() >
                                  0.5
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
                          ? (widget.activeTheme.sentMessageColor
                                        .computeLuminance() >
                                    0.5
                                ? Colors.black54
                                : Colors.white70)
                          : (widget.activeTheme.receivedMessageColor
                                        .computeLuminance() >
                                    0.5
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
            if (_linkPreviewFuture != null)
              Padding(
                padding: hasImage
                    ? const EdgeInsets.fromLTRB(10, 10, 10, 2)
                    : const EdgeInsets.only(bottom: 8),
                child: _LinkPreviewCard(future: _linkPreviewFuture!),
              ),
            if (hasImage) ...[
              Builder(
                builder: (context) {
                  final rawUrl = widget.message.mediaUrl!;
                  final bool isLocalFile = File(rawUrl).existsSync();
                  final String networkUrl =
                      (rawUrl.startsWith('http://') ||
                          rawUrl.startsWith('https://'))
                      ? rawUrl
                      : 'https://xdtunnel.icu/$rawUrl';
                  final String heroTag = isOverlay
                      ? 'hero_img_overlay_${widget.message.id}'
                      : 'hero_img_${widget.message.id}';

                  return GestureDetector(
                    onTap: () {
                      if (!isOverlay) {
                        FullScreenImageViewer.open(
                          context,
                          imagePathOrUrl: isLocalFile ? rawUrl : networkUrl,
                          heroTag: heroTag,
                          title: widget.message.time,
                        );
                      }
                    },
                    child: Hero(
                      tag: heroTag,
                      child: SizedBox(
                        width: 250.0,
                        height: 190.0,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isLocalFile)
                              Image.file(
                                File(rawUrl),
                                width: 250.0,
                                height: 190.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[850]
                                          : Colors.grey[200],
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                      ),
                                    ),
                              )
                            else
                              CachedNetworkImage(
                                imageUrl: networkUrl,
                                width: 250.0,
                                height: 190.0,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const _ShimmerPlaceholder(
                                      width: 250.0,
                                      height: 190.0,
                                    ),
                                errorWidget: (context, url, error) => Container(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[850]
                                      : Colors.grey[200],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                  ),
                                ),
                              ),

                            // Show an upload spinner overlay for local files that are still sending
                            if (widget.message.status ==
                                    MessageStatus.sending &&
                                isLocalFile)
                              Container(
                                color: Colors.black.withOpacity(0.35),
                                child: const Center(
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                    ? const EdgeInsets.only(
                        left: 14.0,
                        right: 14.0,
                        bottom: 10.0,
                        top: 8.0,
                      )
                    : EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: RichLinkText(
                        text: widget.message.text,
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
                        linkStyle: TextStyle(
                          color: widget.message.isMe
                              ? (widget.activeTheme.sentMessageColor
                                            .computeLuminance() >
                                        0.5
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF90CAF9))
                              : (widget.activeTheme.receivedMessageColor
                                            .computeLuminance() >
                                        0.5
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF90CAF9)),
                          decoration: TextDecoration.underline,
                          decorationColor: widget.message.isMe
                              ? (widget.activeTheme.sentMessageColor
                                            .computeLuminance() >
                                        0.5
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF90CAF9))
                              : (widget.activeTheme.receivedMessageColor
                                            .computeLuminance() >
                                        0.5
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF90CAF9)),
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.message.isEdited == true &&
                        !widget.message.isDeleted)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          '(Edited)',
                          style: TextStyle(
                            color:
                                (widget.message.isMe
                                        ? (widget.activeTheme.sentMessageColor
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black87
                                              : Colors.white)
                                        : (widget
                                                      .activeTheme
                                                      .receivedMessageColor
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black87
                                              : Colors.white))
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
    );
  }

  bool _hasValidReactions(List<Map<String, dynamic>>? reactions) {
    if (reactions == null || reactions.isEmpty) return false;
    for (final r in reactions) {
      final e = (r['emoji'] ?? r['reaction'] ?? r['code'])?.toString();
      if (e != null && e.trim().isNotEmpty) return true;
    }
    return false;
  }

  List<Widget> _buildReactions(List<Map<String, dynamic>> reactions) {
    final counts = <String, int>{};
    for (var r in reactions) {
      final e = (r['emoji'] ?? r['reaction'] ?? r['code'])?.toString();
      if (e != null && e.trim().isNotEmpty) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
    }

    return counts.entries
        .map(
          (e) => GestureDetector(
            onTap: () => widget.onReact?.call(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
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
          ),
        )
        .toList();
  }

  void _showMessageOptions(BuildContext context) {
    final RenderBox? box =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final Offset bubbleTopLeft = box.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final Size bubbleSize = box.size;
    final media = MediaQuery.of(context);

    final double screenHeight = media.size.height - media.viewInsets.bottom;

    final double screenWidth = media.size.width;

    final double topSafe = media.padding.top;
    final double bottomSafe = media.padding.bottom;

    const double menuWidth = 230;
    const double estimatedMenuHeight = 170;
    const double gap = 8;

    final double spaceBelow =
        screenHeight - bottomSafe - (bubbleTopLeft.dy + bubbleSize.height);

    final bool openBelow = spaceBelow > estimatedMenuHeight;

    final top = openBelow
        ? bubbleTopLeft.dy + bubbleSize.height + gap
        : (bubbleTopLeft.dy - estimatedMenuHeight - gap).clamp(
            topSafe + gap,
            screenHeight,
          );

    final double left = widget.message.isMe
        ? (bubbleTopLeft.dx + bubbleSize.width - menuWidth).clamp(
            12.0,
            screenWidth - menuWidth - 12.0,
          )
        : bubbleTopLeft.dx.clamp(12.0, screenWidth - menuWidth - 12.0);

    final anchorOffset = Offset(
      bubbleTopLeft.dx + bubbleSize.width / 2,
      openBelow ? bubbleTopLeft.dy + bubbleSize.height : bubbleTopLeft.dy,
    );

    final hasImage =
        widget.message.mediaUrl != null &&
        widget.message.mediaUrl!.isNotEmpty &&
        !widget.message.isDeleted;
    final copiedBubble = _buildBubbleContent(
      context,
      hasImage,
      isOverlay: true,
    );

    _menuOverlay = OverlayEntry(
      builder: (_) => _MessageActionOverlay(
        isMe: widget.message.isMe,
        bubbleKey: _bubbleKey,
        copiedBubble: copiedBubble,
        screenWidth: screenWidth,
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
        onEdit:
            (widget.message.isMe &&
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
        isFailed: widget.message.status == MessageStatus.failed,
        onRetry: widget.onRetry == null
            ? null
            : () {
                _removeOverlay();
                widget.onRetry!();
              },
        onCancel: widget.onCancel == null
            ? null
            : () {
                _removeOverlay();
                widget.onCancel!();
              },
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  void _removeOverlay() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }
}

class _LinkPreviewCard extends StatelessWidget {
  const _LinkPreviewCard({required this.future});

  final Future<LinkPreview?> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreview?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 250,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final preview = snapshot.data;
        if (preview == null) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        final hasImage = preview.imageUrl?.isNotEmpty == true;
        return Material(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => UrlLauncherUtils.openUrl(context, preview.url),
            onLongPress: () =>
                UrlLauncherUtils.showLinkOptions(context, preview.url),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: preview.imageUrl!,
                      width: 250,
                      height: 125,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const _ShimmerPlaceholder(width: 250, height: 125),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preview.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (preview.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            preview.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 12,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                preview.siteName?.isNotEmpty == true
                                    ? preview.siteName!
                                    : preview.host,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerPlaceholder({required this.width, required this.height});

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
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
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
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent - 0.5) * 2,
      0.0,
      0.0,
    );
  }
}

// ---------------------------------------------------------------------------
// Reply preview block shown inside every chat bubble that is a reply.
// Shows a small image thumbnail for IMAGE/GIF/VIDEO messages, an icon label
// for other media types, and plain text for text messages.
// ---------------------------------------------------------------------------
class _ReplyPreviewBlock extends StatelessWidget {
  final MessageModel repliedMessage;
  final Color accentColor;
  final bool isMe;

  const _ReplyPreviewBlock({
    required this.repliedMessage,
    required this.accentColor,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe
        ? Colors.white.withOpacity(0.9)
        : Colors.black.withOpacity(0.75);
    final subColor = isMe
        ? Colors.white.withOpacity(0.65)
        : Colors.black.withOpacity(0.5);

    final bool isDeleted = repliedMessage.isDeleted;
    final MessageType type = repliedMessage.type;
    final String? mediaUrl = repliedMessage.mediaUrl;

    // 1. Image / video reply (features small thumbnail)
    final bool isMediaThumb =
        !isDeleted &&
        mediaUrl != null &&
        mediaUrl.isNotEmpty &&
        (type == MessageType.image ||
            type == MessageType.gif ||
            type == MessageType.video);

    // 2. URL reply (features small thumbnail, title, and domain derived from link-preview)
    final String? url = (!isDeleted && !isMediaThumb)
        ? LinkPreviewService.firstUrl(repliedMessage.text)
        : null;

    if (url != null) {
      return _UrlReplyPreviewBlock(
        url: url,
        rawText: repliedMessage.text,
        accentColor: accentColor,
        textColor: textColor,
        subColor: subColor,
      );
    }

    // 3. Text-only or media reply
    String labelText;
    if (isDeleted) {
      labelText = 'Deleted message';
    } else if (repliedMessage.text.isNotEmpty) {
      labelText = repliedMessage.text;
    } else {
      switch (type) {
        case MessageType.image:
          labelText = '📷 Photo';
          break;
        case MessageType.gif:
          labelText = '🎞 GIF';
          break;
        case MessageType.video:
          labelText = '🎥 Video';
          break;
        case MessageType.audio:
          labelText = '🎵 Audio';
          break;
        case MessageType.voice:
          labelText = '🎙 Voice message';
          break;
        case MessageType.file:
          labelText = '📁 File';
          break;
        case MessageType.location:
          labelText = '📍 Location';
          break;
        case MessageType.contact:
          labelText = '👤 Contact';
          break;
        default:
          labelText = '📎 Attachment';
      }
    }

    return IntrinsicWidth(
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accentColor, width: 3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Text section
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Media type badge when there is a thumbnail
                    if (isMediaThumb && type != MessageType.image) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == MessageType.video
                                ? Icons.videocam_rounded
                                : Icons.gif_box_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            type == MessageType.video ? 'Video' : 'GIF',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      labelText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDeleted ? subColor : textColor,
                        fontSize: 13,
                        fontStyle: isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Small thumbnail for image / video
            if (isMediaThumb)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: mediaUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: Colors.black12,
                        child: const Icon(
                          Icons.image,
                          size: 20,
                          color: Colors.white54,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: Colors.black12,
                        child: const Icon(
                          Icons.broken_image,
                          size: 20,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    // Play icon overlay for video
                    if (type == MessageType.video)
                      Container(
                        width: 52,
                        height: 52,
                        color: Colors.black26,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
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

class _UrlReplyPreviewBlock extends StatefulWidget {
  final String url;
  final String rawText;
  final Color accentColor;
  final Color textColor;
  final Color subColor;

  const _UrlReplyPreviewBlock({
    required this.url,
    required this.rawText,
    required this.accentColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  State<_UrlReplyPreviewBlock> createState() => _UrlReplyPreviewBlockState();
}

class _UrlReplyPreviewBlockState extends State<_UrlReplyPreviewBlock> {
  late Future<LinkPreview?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = LinkPreviewService.instance.previewForText(widget.rawText);
  }

  @override
  void didUpdateWidget(covariant _UrlReplyPreviewBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawText != widget.rawText) {
      _previewFuture = LinkPreviewService.instance.previewForText(
        widget.rawText,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedUri = Uri.tryParse(widget.url);
    final fallbackHost = parsedUri?.host.isNotEmpty == true
        ? parsedUri!.host
        : widget.url;

    return FutureBuilder<LinkPreview?>(
      future: _previewFuture,
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final title = (preview != null && preview.title.isNotEmpty)
            ? preview.title
            : fallbackHost;
        final domain = (preview != null && preview.host.isNotEmpty)
            ? preview.host
            : fallbackHost;
        final hasImage =
            preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => UrlLauncherUtils.openUrl(context, widget.url),
            onLongPress: () =>
                UrlLauncherUtils.showLinkOptions(context, widget.url),
            borderRadius: BorderRadius.circular(8),
            child: IntrinsicWidth(
              child: Container(
                margin: const EdgeInsets.only(bottom: 6.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: widget.accentColor, width: 3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text section: title and domain
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 12,
                                  color: widget.subColor,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    domain,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.subColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 11,
                                  color: widget.subColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Small thumbnail
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      child: hasImage
                          ? CachedNetworkImage(
                              imageUrl: preview.imageUrl!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.public,
                                  size: 20,
                                  color: widget.accentColor.withOpacity(0.7),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.public,
                                  size: 20,
                                  color: widget.accentColor.withOpacity(0.7),
                                ),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.public,
                                size: 22,
                                color: widget.accentColor.withOpacity(0.7),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageActionOverlay extends StatefulWidget {
  final double top;
  final bool isMe; // <-- NEW
  final GlobalKey bubbleKey;
  final Widget copiedBubble; // <-- NEW
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
  final bool isFailed;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const _MessageActionOverlay({
    required this.top,
    required this.isMe,
    required this.bubbleKey,
    required this.copiedBubble,
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
    this.isFailed = false,
    this.onRetry,
    this.onCancel,
  });

  @override
  State<_MessageActionOverlay> createState() => _MessageActionOverlayState();
}

class _MessageActionOverlayState extends State<_MessageActionOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  double _bubbleTop = 0;
  double _bubbleLeft = 0;
  Size _bubbleSize = Size.zero;

  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBubblePosition();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateBubblePosition();
      }
    });
  }

  void _updateBubblePosition() {
    final box =
        widget.bubbleKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null) {
      debugPrint("BOX NULL");
      return;
    }

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);

    debugPrint("Top: ${offset.dy}");
    debugPrint("Left: ${offset.dx}");
    debugPrint("Size: ${box.size}");

    setState(() {
      _bubbleTop = offset.dy;
      _bubbleLeft = offset.dx;
      _bubbleSize = box.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignmentX =
        (widget.anchorOffset.dx - widget.left) / widget.menuWidth;
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
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.20),
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: _bubbleTop,
          left: _bubbleLeft,
          width: _bubbleSize.width,
          height: _bubbleSize.height,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(_controller),
            child: Material(
              color: Colors.transparent,
              child: widget.copiedBubble,
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme) {
    final items = <Widget>[];

    void addTile(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) {
      if (items.isNotEmpty) {
        items.add(
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: Colors.grey.withOpacity(0.15),
          ),
        );
      }
      items.add(
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: color ?? theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: color ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.isFailed) {
      if (widget.onRetry != null) {
        addTile(
          Icons.refresh_rounded,
          'Retry Sending',
          widget.onRetry!,
          color: Colors.blueAccent,
        );
      }
      if (widget.onCancel != null) {
        addTile(
          Icons.close_rounded,
          'Cancel & Delete',
          widget.onCancel!,
          color: Colors.redAccent,
        );
      }
    }

    if (widget.onReply != null) addTile(Icons.reply, 'Reply', widget.onReply!);
    if (widget.onEdit != null) addTile(Icons.edit, 'Edit', widget.onEdit!);
    addTile(Icons.push_pin_outlined, 'Pin Message', widget.onPin);
    if (widget.onDelete != null) {
      addTile(
        Icons.delete_outline,
        'Delete Message',
        widget.onDelete!,
        color: Colors.redAccent,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}
