import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';

final chatReadyProvider = StateProvider.autoDispose<bool>((_) => false);

final headerTextColorProvider = Provider.autoDispose<Color>((ref) {
  final bg = ref.watch(chatThemeProvider).backgroundColor;
  return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
});

final replyingToProvider = StateProvider.autoDispose<MessageModel?>(
  (ref) => null,
);

final editingMessageProvider = StateProvider.autoDispose<MessageModel?>(
  (ref) => null,
);

final showAttachmentMenuProvider = StateProvider.autoDispose<bool>(
  (_) => false,
);
