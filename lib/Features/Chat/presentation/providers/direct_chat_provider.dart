import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/message_model.dart';

final directChatProvider = StateNotifierProvider<DirectChatNotifier, List<MessageModel>>((ref) {
  return DirectChatNotifier();
});

class DirectChatNotifier extends StateNotifier<List<MessageModel>> {
  DirectChatNotifier() : super(_initialMessages);

  static final List<MessageModel> _initialMessages = [
    MessageModel(
      text: "I think you'll like it. It feels very clean and intuitive now. I'll share my screen during the call at 2 PM.",
      time: "10:48 AM",
      isMe: true,
      status: MessageStatus.seen,
    ),
    MessageModel(
      text: "That sounds great. I'm really curious to see how you handled the bento grid section. 🍱",
      time: "10:46 AM",
      isMe: false,
    ),
    MessageModel(
      text: "Absolutely! I've just finished the final mockups for the new dashboard.",
      time: "10:45 AM",
      isMe: true,
      status: MessageStatus.seen,
    ),
    MessageModel(
      text: "Hey! Are we still on for the project review this afternoon?",
      time: "10:42 AM",
      isMe: false,
    ),
  ];

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    state = [
      MessageModel(
        text: text.trim(),
        time: "Now",
        isMe: true,
        status: MessageStatus.sent,
      ),
      ...state,
    ];
  }
}
