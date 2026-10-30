import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/Features/Chat/presentation/providers/chat_provider.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';

class TypingIndicatorWidget extends ConsumerWidget {
  const TypingIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(currentChatIdProvider);
    final isTyping = chatId != null
        ? ref.watch(typingStatusProvider(chatId))
        : false;
    if (!isTyping) return const SizedBox.shrink();
    return const TypingBubble();
  }
}

class TypingBubble extends ConsumerStatefulWidget {
  const TypingBubble({super.key});

  @override
  ConsumerState<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends ConsumerState<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(chatThemeProvider);
    final isDarkBg = activeTheme.receivedMessageColor.computeLuminance() <= 0.5;
    final dotColor = isDarkBg ? Colors.white70 : Colors.black54;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 25),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: activeTheme.receivedMessageColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 32,
          height: 12,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // Stagger each dot's phase by 0.2 of the cycle
                  final t = (_controller.value - (i * 0.2)) % 1.0;
                  // Bounce curve: 0 -> 1 -> 0 over the cycle, eased
                  final bounce = t < 0.5
                      ? Curves.easeOut.transform(t * 2)
                      : Curves.easeIn.transform((1 - t) * 2);
                  final scale = 0.6 + (bounce * 0.4);
                  final opacity = 0.4 + (bounce * 0.6);

                  return Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 5.0 : 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
