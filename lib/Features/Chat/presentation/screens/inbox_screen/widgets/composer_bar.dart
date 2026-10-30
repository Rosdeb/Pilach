import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';

class ComposerBar extends ConsumerWidget {
  const ComposerBar({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.activeTheme,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController messageController;
  final FocusNode focusNode;
  final dynamic activeTheme;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnterSend = ref.watch(enterIsSendProvider);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: activeTheme.backgroundColor ?? Colors.transparent,
        ),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: WhatsAppInputBox(
                  controller: messageController,
                  focusNode: focusNode,
                  isEnterSend: isEnterSend,
                  onSend: onSend,
                  onTyping: () =>
                      ref.read(directChatProvider.notifier).emitTyping(),
                  onAttach: onAttach,
                ),
              ),
              const SizedBox(width: 6),
              SendButton(
                accentColor: activeTheme.accentColor ?? const Color(0xFF00A884),
                onTap: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WhatsAppInputBox extends StatelessWidget {
  const WhatsAppInputBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isEnterSend,
    required this.onSend,
    required this.onTyping,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnterSend;
  final VoidCallback onSend;
  final VoidCallback onTyping;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                CupertinoIcons.smiley,
                color: theme.hintColor.withValues(alpha: 0.6),
                size: 24,
              ),
              splashRadius: 20,
            ),
            Expanded(
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => onTyping(),
                textInputAction: isEnterSend
                    ? TextInputAction.send
                    : TextInputAction.newline,
                onFieldSubmitted: isEnterSend ? (_) => onSend() : null,
                style: const TextStyle(fontSize: 16, height: 1.3),
                decoration: InputDecoration(
                  hintText: "Message",
                  hintStyle: TextStyle(
                    color: theme.hintColor.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  fillColor: theme.colorScheme.surface,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            IconButton(
              onPressed: onAttach,
              icon: Icon(
                CupertinoIcons.paperclip,
                color: theme.hintColor.withValues(alpha: 0.6),
                size: 22,
              ),
              splashRadius: 20,
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(
                CupertinoIcons.camera_fill,
                color: theme.hintColor.withValues(alpha: 0.6),
                size: 22,
              ),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class SendButton extends StatelessWidget {
  const SendButton({
    super.key,
    required this.accentColor,
    required this.onTap,
  });

  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            CupertinoIcons.paperplane_fill,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
