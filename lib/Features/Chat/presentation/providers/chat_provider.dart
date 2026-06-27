import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/chat_model.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatModel>>((ref) => ChatNotifier());

class ChatNotifier extends StateNotifier<List<ChatModel>> {
  ChatNotifier() : super(_dummyChats);

  void deleteChat(String id) {
    state = state.where((chat) => chat.id != id).toList();
  }

  void toggleMuteChat(String id) {
    state = state.map((chat) {
      if (chat.id == id) {
        return chat.copyWith(isMuted: !chat.isMuted);
      }
      return chat;
    }).toList();
  }

  static final List<ChatModel> _dummyChats = [
    ChatModel(
      id: "1",
      name: "Rosdeb",
      message: "Hey bro, how are you?",
      image: "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
      isMuted: false,
    ),
    ChatModel(
      id: "2",
      name: "Tony",
      message: "Let's deploy today 🚀",
      image: "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
      isMuted: false,
    ),
    ChatModel(
      id: "3",
      name: "Alex",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
      isMuted: true,
    ),
    ChatModel(
      id: "4",
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      id: "5",
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      id: "6",
      name: "Alex",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
      isMuted: true,
    ),
    ChatModel(
      id: "7",
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      id: "8",
      name: "Alex",
      message: "Send me the design.",
      image:
      "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
    ),
    ChatModel(
      id: "9",
      name: "Alex",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 5,
      isOnline: true,
      isMuted: true,
    ),
    ChatModel(
      id: "10",
      name: "Tony",
      message: "Let's deploy today 🚀",
      image:
      "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
    ),
    ChatModel(
      id: "11",
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