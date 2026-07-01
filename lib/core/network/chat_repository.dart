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

  Future<Map<String, dynamic>> getMessages(String chatId) async {
    final response = await _apiService.get('/api/v1/chats/$chatId/messages');
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
}
