import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_exceptions.dart';
import '../constants/api_constants.dart';
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

  /// Rename a conversation
  /// PATCH /api/v1/conversations/{id}
  /// Note: The REST endpoint strictly accepts `title` only.
  /// To update `avatarUrl`, `about`, `slowModeSeconds`, or `allowedReactions`,
  /// emit the `chat:update` socket event as defined in the Developer Guide.
  Future<Map<String, dynamic>> updateConversation(
    String conversationId, {
    required String title,
  }) async {
    final response = await _apiService.patch(
      '/api/v1/conversations/$conversationId',
      data: {
        'title': title.trim(),
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Upload a group avatar directly
  /// POST /api/v1/conversations/{id}/avatar
  Future<String> uploadGroupAvatar(
    String conversationId,
    String filePath,
  ) async {
    final response = await _apiService.uploadFile(
      '/api/v1/conversations/$conversationId/avatar',
      filePath: filePath,
      fieldName: 'file',
    );
    final data = response.data;
    String? rawAvatarUrl;
    if (data is Map) {
      if (data['data'] is Map && data['data']['avatarUrl'] != null) {
        rawAvatarUrl = data['data']['avatarUrl']?.toString();
      } else if (data['avatarUrl'] != null) {
        rawAvatarUrl = data['avatarUrl']?.toString();
      }
    }
    if (rawAvatarUrl != null && rawAvatarUrl.isNotEmpty) {
      if (!rawAvatarUrl.startsWith('http')) {
        return '${ApiConstants.baseUrl}/$rawAvatarUrl';
      }
      return rawAvatarUrl;
    }
    throw ApiException(
      data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Failed to upload group avatar',
    );
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

  /// List members of a conversation (paginated)
  /// GET /api/v1/conversations/{id}/members
  Future<Map<String, dynamic>> getMembers(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _apiService.get(
      '/api/v1/conversations/$conversationId/members',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Promote or demote an admin
  /// PATCH /api/v1/conversations/{id}/members/{userId}/role
  Future<Map<String, dynamic>> updateMemberRole(
    String conversationId,
    String userId, {
    required String role, // 'ADMIN' or 'MEMBER'
    Map<String, dynamic>? adminRights,
  }) async {
    final response = await _apiService.patch(
      '/api/v1/conversations/$conversationId/members/$userId/role',
      data: {
        'role': role.toUpperCase(),
        'adminRights': ?adminRights,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Kick a member from a conversation
  /// DELETE /api/v1/conversations/{id}/members/{userId}
  Future<Map<String, dynamic>> removeMember(
    String conversationId,
    String userId,
  ) async {
    final response = await _apiService.delete(
      '/api/v1/conversations/$conversationId/members/$userId',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Leave conversation (owner passes ownership to oldest admin/member)
  /// POST /api/v1/conversations/{id}/leave
  Future<Map<String, dynamic>> leaveConversation(String conversationId) async {
    final response = await _apiService.post(
      '/api/v1/conversations/$conversationId/leave',
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Transfer ownership of conversation to another user
  /// POST /api/v1/conversations/{id}/owner/transfer
  Future<Map<String, dynamic>> transferOwnership(
    String conversationId,
    String userId,
  ) async {
    final response = await _apiService.post(
      '/api/v1/conversations/$conversationId/owner/transfer',
      data: {'userId': userId},
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Update group permissions (the 6 can* flags)
  /// PATCH /api/v1/conversations/{id}/permissions
  Future<Map<String, dynamic>> updatePermissions(
    String conversationId,
    Map<String, bool> permissions,
  ) async {
    final response = await _apiService.patch(
      '/api/v1/conversations/$conversationId/permissions',
      data: permissions,
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Update personal per-chat settings
  /// PATCH /api/v1/conversations/{id}/settings
  Future<Map<String, dynamic>> updateConversationSettings(
    String conversationId, {
    bool? isPinned,
    bool? isArchived,
    String? mutedUntil,
  }) async {
    final response = await _apiService.patch(
      '/api/v1/conversations/$conversationId/settings',
      data: {
        'isPinned': ?isPinned,
        'isArchived': ?isArchived,
        'mutedUntil': mutedUntil,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Convenience mute using /settings
  Future<Map<String, dynamic>> muteConversation(
    String conversationId,
    bool isMuted,
  ) async {
    return updateConversationSettings(
      conversationId,
      mutedUntil: isMuted
          ? DateTime.now()
              .add(const Duration(days: 365 * 100))
              .toIso8601String()
          : null,
    );
  }

  /// Search messages within a single chat
  /// GET /api/v1/chats/{chatId}/messages/search
  Future<Map<String, dynamic>> searchMessagesInChat(
    String chatId, {
    required String query,
    String? from,
    String? to,
    String? senderId,
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiService.get(
      '/api/v1/chats/$chatId/messages/search',
      queryParameters: {
        'q': query,
        'from': ?from,
        'to': ?to,
        'senderId': ?senderId,
        'type': ?type,
        'page': page,
        'limit': limit,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Search messages across all user's chats
  /// GET /api/v1/messages/search
  Future<Map<String, dynamic>> searchMessagesGlobal({
    required String query,
    String? chatId,
    String? from,
    String? to,
    String? senderId,
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiService.get(
      '/api/v1/messages/search',
      queryParameters: {
        'q': query,
        'chatId': ?chatId,
        'from': ?from,
        'to': ?to,
        'senderId': ?senderId,
        'type': ?type,
        'page': page,
        'limit': limit,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'data': response.data};
  }

  /// Gallery media for a chat
  /// GET /api/v1/chats/{chatId}/media?kind=media|files|links|audio
  Future<Map<String, dynamic>> getChatMedia(
    String chatId, {
    required String kind, // 'media' | 'files' | 'links' | 'audio'
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _apiService.get(
      '/api/v1/chats/$chatId/media',
      queryParameters: {
        'kind': kind,
        'page': page,
        'limit': limit,
      },
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
    String? query,
  }) async {
    final response = await _apiService.get(
      '/api/v1/chats/$chatId/messages',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    return response.data as Map<String, dynamic>;
  }

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
}
