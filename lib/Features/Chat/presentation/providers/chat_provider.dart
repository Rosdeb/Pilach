import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/chat_model.dart';
import '../../../../core/database/daos/chat_dao.dart';
import '../../../../core/models/chat_dto.dart';
import '../../../../core/network/chat_repository.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatModel>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return ChatNotifier(chatRepo);
});

class ChatNotifier extends StateNotifier<List<ChatModel>> {
  final ChatDao _chatDao = ChatDao();
  final ChatRepository _chatRepository;

  ChatNotifier(this._chatRepository) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // 1. Instantly load from local SQLite (Offline-first)
    await loadFromDb();

    // 2. Real API fetch from server 
    await fetchFromServer();
  }

  Future<void> loadFromDb() async {
    final chatRows = await _chatDao.getAllChats();
    final models = chatRows.map((row) => row.toChatModel()).toList();
    
    // Sort pinned to top
    final pinned = models.where((chat) => chat.isPinned).toList();
    final unpinned = models.where((chat) => !chat.isPinned).toList();
    state = [...pinned, ...unpinned];
  }

  Future<void> fetchFromServer() async {
    try {
      // Call the real API: GET /api/v1/conversations without limit/page
      final responseData = await _chatRepository.getConversations();
      
      // Print the raw API response to the console for debugging
      print('🚀 API RESPONSE (/api/v1/conversations): $responseData');
      
      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> data = responseData['data'];
        
        // Convert JSON to DTO, then to SQLite Map
        final List<Map<String, dynamic>> sqliteRows = data.map((item) {
          final dto = ChatDto.fromJson(item as Map<String, dynamic>);
          return dto.toSqliteMap();
        }).toList();

        // Save to SQLite
        await _chatDao.insertOrUpdateChats(sqliteRows);
        
        // Reload UI from DB
        await loadFromDb();
      }
    } catch (e) {
      print('Failed to fetch chats from server: $e');
      // On failure, UI naturally stays populated from the SQLite DB (offline-first)!
    }
  }

  void deleteChat(String id) {
    state = state.where((chat) => chat.id != id).toList();
    // In full implementation: queue a DELETE request in OutboxDao
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
    _sortChats();
  }

  void _sortChats() {
    final pinned = state.where((chat) => chat.isPinned).toList();
    final unpinned = state.where((chat) => !chat.isPinned).toList();
    state = [...pinned, ...unpinned];
  }
}

final chatSearchProviders = StateProvider<String>((ref) => '');