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

  Future<Map<String, dynamic>> getConversations({int limit = 150}) async {
    final response = await _apiService.get(
      '/api/v1/conversations',
      queryParameters: {'limit': limit},
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Get details of a specific conversation (members, profile, etc.)
  /// GET /api/v1/conversations/{id}
  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    final response = await _apiService.get(
      '/api/v1/conversations/$conversationId',
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Creates a new conversation (DM or Group)
  /// POST /api/v1/conversations
  /// Body: { "type": "PRIVATE" | "GROUP", "title": "string", "userIds": ["string"] }
  Future<Map<String, dynamic>> createConversation({
    required String type, // 'PRIVATE' or 'GROUP'
    String? title,
    required List<String> userIds,
  }) async {
    final normalizedType = type.trim().toUpperCase();
    if (normalizedType != 'PRIVATE' && normalizedType != 'GROUP') {
      throw ArgumentError.value(type, 'type', 'Must be PRIVATE or GROUP');
    }
    final normalizedUserIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final payload = <String, dynamic>{
      'type': normalizedType,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (normalizedUserIds.isNotEmpty) 'userIds': normalizedUserIds,
    };
    final response = await _apiService.post(
      '/api/v1/conversations',
      data: payload,
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Adds members to an existing conversation
  /// POST /api/v1/conversations/{id}/members
  /// Body: { "userIds": ["string"] }
  Future<Map<String, dynamic>> addMembers(
    String conversationId,
    List<String> userIds,
  ) async {
    final response = await _apiService.post(
      '/api/v1/conversations/$conversationId/members',
      data: {'userIds': userIds},
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  Future<Map<String, dynamic>> getMessages(
    String chatId, {
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _apiService.get(
      '/api/v1/chats/$chatId/messages?page=$page&limit=$limit',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Returns the highest seq value stored in the most-recent page of messages.
  /// The server sorts newest-first on page 1, so data[0] is the latest message.
  Future<int> getLatestSeq(String chatId) async {
    try {
      final response = await getMessages(chatId, limit: 1);
      final data = response['data'] as List<dynamic>?;
      if (data != null && data.isNotEmpty) {
        return (data.first['seq'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Fetches the most-recent [limit] messages for [chatId].
  ///
  /// The server's messages endpoint only supports cursor / page / limit / query
  /// query params — there is no `afterSeq` filter.  Callers that need to
  /// sync a gap should fetch page 1 and deduplicate against local storage by
  /// message ID (insertOrUpdate semantics).
  Future<Map<String, dynamic>> getRecentMessages(
    String chatId, {
    int limit = 50,
  }) {
    return getMessages(chatId, page: 1, limit: limit);
  }

  Future<Map<String, dynamic>> sendMessage(
    String chatId,
    Map<String, Object?> payload, [
    String? clientMsgId,
  ]) async {
    // Backend SendMessageDto strictly allows: type, text, replyToId, attachments.
    // Must NOT contain conversationId or clientMsgId (server throws 400 validation error).
    final requestBody = <String, Object?>{
      'type': payload['type'] ?? 'TEXT',
      if (payload['text'] != null) 'text': payload['text'],
      if (payload['replyToId'] != null) 'replyToId': payload['replyToId'],
      if (payload['attachments'] is List &&
          (payload['attachments'] as List).isNotEmpty)
        'attachments': payload['attachments'],
    };
    final response = await _apiService.post(
      '/api/v1/chats/$chatId/messages',
      data: requestBody,
      headers: clientMsgId == null || clientMsgId.isEmpty
          ? null
          : {'Idempotency-Key': clientMsgId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeMember(
    String conversationId,
    String userId,
  ) async {
    final response = await _apiService.delete(
      '/api/v1/conversations/$conversationId/members/$userId',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> muteConversation(
    String conversationId,
    bool isMuted,
  ) async {
    final response = await _apiService.patch(
      '/api/v1/conversations/$conversationId/mute',
      data: {
        'mutedUntil': isMuted
            ? DateTime.now()
                  .add(const Duration(days: 365 * 100))
                  .toIso8601String()
            : null,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
