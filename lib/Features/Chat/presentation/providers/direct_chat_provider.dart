// direct_chat_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/message_model.dart';

final directChatProvider =
StateNotifierProvider<DirectChatNotifier, List<MessageModel>>((ref) {
  return DirectChatNotifier();
});

class DirectChatNotifier extends StateNotifier<List<MessageModel>> {
  DirectChatNotifier() : super(_initialMessages);

  int _nextId = 100;
  Timer? _timer;

  static final List<MessageModel> _initialMessages = [
    MessageModel(
      id: '1',
      text: "I think you'll like it. It feels very clean and intuitive now. I'll share my screen during the call at 2 PM.",
      time: "10:48 AM",
      isMe: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      status: MessageStatus.seen,
    ),
    MessageModel(
      id: '2',
      text: "That sounds great. I'm really curious to see how you handled the bento grid section. 🍱",
      time: "10:46 AM",
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isMe: false,
    ),
    MessageModel(
      id: '3',
      text: "Absolutely! I've just finished the final mockups for the new dashboard.",
      time: "10:45 AM",
      isMe: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    MessageModel(
      id: '4',
      text: "Hey! Are we still on for the project review this afternoon?",
      time: "10:42 AM",
      status: MessageStatus.seen,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isMe: false,
    ),
  ];

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    // ✅ শেষে add করো, আগে না — index shift হবে না
    state = [
      ...state,
      MessageModel(
        id: '${_nextId++}',
        text: text,
        time: "Now",
        timestamp: DateTime.now(),
        isMe: true,
        status: MessageStatus.sent,
      ),
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}