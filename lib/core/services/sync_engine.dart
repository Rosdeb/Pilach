import '../database/daos/chat_dao.dart';
import '../database/daos/message_dao.dart';
import '../database/daos/sync_state_dao.dart';
import 'api_service.dart';

class SyncEngine {
  final ChatDao _chatDao;
  final MessageDao _messageDao;
  final SyncStateDao _syncStateDao;
  final ApiService _apiService; // REST calls

  SyncEngine(this._chatDao, this._messageDao, this._syncStateDao, this._apiService);

  Future<void> onAppStart() async {
    // 1. Check local chats
    // 2. Fetch remote chat list
    // Example: final response = await _apiService.get('/conversations');
    // Save to SQLite
    // await _chatDao.insertOrUpdateChats(parsedChats);
  }

  Future<void> syncMessagesForChat(String chatId) async {
    final chat = await _chatDao.getChatById(chatId);
    if (chat == null) return;

    final syncState = await _syncStateDao.getSyncState(chatId);
    
    final int chatLastSeq = chat['last_message_seq'] ?? 0;
    final int newestSyncedSeq = (syncState != null) ? (syncState['newest_synced_seq'] ?? 0) : 0;

    if (chatLastSeq > newestSyncedSeq) {
      // Gap exists, fetch delta
      try {
        // final response = await _apiService.get('/chats/$chatId/messages?cursor=$newestSyncedSeq');
        // final List<Map<String, dynamic>> missingMessages = parse(response.data);
        
        // await _messageDao.insertOrUpdateMessages(missingMessages);
        
        // Update sync state
        await _syncStateDao.updateSyncState({
          'conversation_id': chatId,
          'newest_synced_seq': chatLastSeq,
          // maintain oldest if we had one
          'oldest_synced_seq': syncState?['oldest_synced_seq'], 
          'last_synced_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Error syncing chat $chatId: $e');
      }
    }
  }
}
