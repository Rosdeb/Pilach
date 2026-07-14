import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../providers/api_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ChatRepository(apiService);
});

class ChatRepository {
  final ApiService _apiService;

  ChatRepository(this._apiService);

  Future<Map<String, dynamic>> getConversations() async {
    final response = await _apiService.get('/api/v1/conversations');
    // Since Dio handles JSON, response.data should be a Map<String, dynamic>
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMessages(String chatId, {int page = 1, int limit = 30}) async {
    final response = await _apiService.get('/api/v1/chats/$chatId/messages?page=$page&limit=$limit');
    return response.data as Map<String, dynamic>;
  }

  Future<int> getLatestSeq(String chatId) async {
    final response = await _apiService.get('/api/v1/conversations/$chatId/latest-seq');
    return response.data['latestSeq'] ?? 0;
  }

  Future<Map<String, dynamic>> getMessagesAfterSeq(String chatId, int afterSeq) async {
    final response = await _apiService.get('/api/v1/chats/$chatId/messages?afterSeq=$afterSeq');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(String chatId, String text, String clientMsgId) async {
    final response = await _apiService.post('/api/v1/messages/send', data: {
      'conversationId': chatId,
      'text': text,
      'clientMsgId': clientMsgId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeMember(String conversationId, String userId) async {
    final response = await _apiService.delete('/api/v1/conversations/$conversationId/members/$userId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> muteConversation(String conversationId, bool isMuted) async {
    final response = await _apiService.patch('/api/v1/conversations/$conversationId/mute', data: {
      'mutedUntil': isMuted ? DateTime.now().add(const Duration(days: 365 * 100)).toIso8601String() : null,
    });
    return response.data as Map<String, dynamic>;
  }
}
