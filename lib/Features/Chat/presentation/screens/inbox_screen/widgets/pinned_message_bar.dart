import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'inbox_providers.dart';

class PinnedMessageBar extends ConsumerWidget {
  const PinnedMessageBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedMessage = ref.watch(
      directChatProvider.select((state) {
        try {
          return state.messagesById.values.firstWhere(
            (m) => m.isPinned == true,
          );
        } catch (_) {
          return null;
        }
      }),
    );

    if (pinnedMessage == null) return const SizedBox.shrink();

    final theme = ref.watch(chatThemeProvider);
    final headerTextColor = ref.watch(headerTextColorProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: headerTextColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pinned Message',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pinnedMessage.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: headerTextColor, fontSize: 14),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (pinnedMessage.id != null) {
                ref
                    .read(directChatProvider.notifier)
                    .pinMessage(pinnedMessage.id!, false);
              }
            },
            child: Icon(
              Icons.close,
              size: 20,
              color: headerTextColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
