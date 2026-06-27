import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/chat_model.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatModel>>((ref) => ChatNotifier());

class ChatNotifier extends StateNotifier<List<ChatModel>> {
  ChatNotifier() : super(_dummyChats);

  void deleteChat(String id) {
    state = state.where((chat) => chat.id != id).toList();
  }

  void toggleUnreadChat(String id) {
    state = state.map((c) => c.id == id
        ? c.copyWith(unreadCount: c.unreadCount > 0 ? 0 : 1)
        : c,
    ).toList();
  }



  void toggleMuteChat(String id) {
    state = state.map((chat) {
      if (chat.id == id) {
        return chat.copyWith(isMuted: !chat.isMuted);
      }
      return chat;
    }).toList();
  }

  void togglePinChat(String id) {
    state = state.map((chat) {
      if (chat.id == id) {
        return chat.copyWith(isPinned: !chat.isPinned);
      }
      return chat;
    }).toList();
    // Sort pinned chats to the top
    final pinned = state.where((chat) => chat.isPinned).toList();
    final unpinned = state.where((chat) => !chat.isPinned).toList();
    state = [...pinned, ...unpinned];
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
      isRead: false,
      draft: null,
      isPinned: true,
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
      isRead: true,
      draft: "Don't forget the package...",
      isPinned: false,
    ),
    ChatModel(
      id: "3",
      name: "Alex",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),
    ChatModel(
      id: "4",
      name: "Koch",
      message: "Hey bro, how are you?",
      image: "https://i.pravatar.cc/300?img=1",
      time: "2:30 PM",
      unreadCount: 2,
      isOnline: true,
      isMuted: false,
      isRead: false,
      draft: null,
      isPinned: true,
    ),
    ChatModel(
      id: "5",
      name: "Motin",
      message: "Let's deploy today 🚀",
      image: "https://i.pravatar.cc/300?img=2",
      time: "1:10 PM",
      unreadCount: 0,
      isOnline: false,
      isMuted: false,
      isRead: true,
      draft: "Don't forget the package...",
      isPinned: false,
    ),
    ChatModel(
      id: "6",
      name: "Anik Fucker",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),

    ChatModel(
      id: "7",
      name: "Fahim Fucker",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),
    ChatModel(
      id: "8",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),

    ChatModel(
      id: "9",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),

    ChatModel(
      id: "10",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),
    ChatModel(
      id: "11",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),
    ChatModel(
      id: "12",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),
    ChatModel(
      id: "13",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),
    ChatModel(
      id: "14",
      name: "Niga",
      message: "Send me the design.",
      image: "https://i.pravatar.cc/300?img=3",
      time: "Yesterday",
      unreadCount: 0,
      isOnline: true,
      isMuted: true,
      isRead: true,
      draft: null,
      isPinned: false,
    ),

  ];
}

final chatSearchProviders = StateProvider<String>((ref) => '');