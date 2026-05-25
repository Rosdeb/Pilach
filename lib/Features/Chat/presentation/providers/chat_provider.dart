import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/chat_model.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatModel>>((ref) => ChatNotifier(),);

class ChatNotifier extends StateNotifier<List<ChatModel>> {
  ChatNotifier() : super(_dummyChats);

  static final List<ChatModel> _dummyChats = [
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image:
      "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),

  ];
}

final chatSearchProviders = StateProvider<String>((ref) => '');