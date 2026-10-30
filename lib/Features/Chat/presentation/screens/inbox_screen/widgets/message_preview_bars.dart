import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/core/models/link_preview.dart';
import 'package:app/core/services/link_preview_service.dart';
import 'package:app/core/utils/url_launcher_utils.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import 'inbox_providers.dart';

class EditPreviewBar extends ConsumerWidget {
  const EditPreviewBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMsg = ref.watch(editingMessageProvider);
    if (editMsg == null) return const SizedBox.shrink();
    final activeTheme = ref.watch(chatThemeProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit,
            color: activeTheme.accentColor ?? Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing message',
                  style: TextStyle(
                    color: activeTheme.accentColor ?? Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  editMsg.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              ref.read(editingMessageProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }
}

class ReplyPreviewBar extends ConsumerWidget {
  const ReplyPreviewBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyTo = ref.watch(replyingToProvider);
    if (replyTo == null) return const SizedBox.shrink();
    final activeTheme = ref.watch(chatThemeProvider);
    final theme = Theme.of(context);
    final accentColor = activeTheme.accentColor ?? Colors.green;

    final bool isImageType =
        replyTo.type == MessageType.image ||
        replyTo.type == MessageType.gif ||
        replyTo.type == MessageType.video;
    final bool showMediaThumb =
        isImageType && replyTo.mediaUrl != null && replyTo.mediaUrl!.isNotEmpty;

    // Check if it's a URL reply (when not image/video)
    final String? url = (!isImageType)
        ? LinkPreviewService.firstUrl(replyTo.text)
        : null;

    String previewText;
    if (replyTo.text.isNotEmpty) {
      previewText = replyTo.text;
    } else {
      switch (replyTo.type) {
        case MessageType.image:
          previewText = '📷 Photo';
          break;
        case MessageType.gif:
          previewText = '🎞 GIF';
          break;
        case MessageType.video:
          previewText = '🎥 Video';
          break;
        case MessageType.audio:
          previewText = '🎵 Audio';
          break;
        case MessageType.voice:
          previewText = '🎙 Voice message';
          break;
        case MessageType.file:
          previewText = '📁 File';
          break;
        default:
          previewText = '📎 Attachment';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Content section
          Expanded(
            child: url != null
                ? FutureBuilder<LinkPreview?>(
                    future: LinkPreviewService.instance.previewForText(
                      replyTo.text,
                    ),
                    builder: (context, snapshot) {
                      final preview = snapshot.data;
                      final parsedUri = Uri.tryParse(url);
                      final fallbackHost = parsedUri?.host.isNotEmpty == true
                          ? parsedUri!.host
                          : url;
                      final title =
                          (preview != null && preview.title.isNotEmpty)
                          ? preview.title
                          : fallbackHost;
                      final domain =
                          (preview != null && preview.host.isNotEmpty)
                          ? preview.host
                          : fallbackHost;
                      final hasImage =
                          preview?.imageUrl != null &&
                          preview!.imageUrl!.isNotEmpty;

                      return InkWell(
                        onTap: () => UrlLauncherUtils.openUrl(context, url),
                        onLongPress: () =>
                            UrlLauncherUtils.showLinkOptions(context, url),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            // Small thumbnail for URL reply
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: hasImage
                                  ? CachedNetworkImage(
                                      imageUrl: preview!.imageUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 40,
                                        height: 40,
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.public,
                                          size: 18,
                                          color: accentColor,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 40,
                                        height: 40,
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.public,
                                          size: 18,
                                          color: accentColor,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.public,
                                        size: 20,
                                        color: accentColor,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            // Title and domain
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.link_rounded,
                                        size: 12,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          domain,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.65),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 11,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Row(
                    children: [
                      // Thumbnail for image/video replies only
                      if (showMediaThumb) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: replyTo.mediaUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 40,
                              height: 40,
                              color: theme.dividerColor,
                              child: const Icon(
                                Icons.image,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: theme.dividerColor,
                              child: const Icon(
                                Icons.broken_image,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      // Text column (text-only if no media thumb)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              replyTo.isMe
                                  ? 'Replying to yourself'
                                  : 'Replying to message',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          // Cancel button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(replyingToProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }
}
