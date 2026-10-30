import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/Features/Contact/presentation/providers/contact_providers.dart';
import 'package:app/core/models/chat_dto.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:app/core/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockApiService extends ApiService {
  String? lastEndpoint;
  dynamic lastData;

  MockApiService() : super(Dio());

  @override
  Future<Response> post(
    String endpoint, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    lastEndpoint = endpoint;
    lastData = data;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': {
          'id': 'new-group-123',
          'type': 'GROUP',
          'title': data['title'],
          'unreadCount': 0,
          'createdAt': '2026-10-30T10:00:00.000Z',
          'members': [
            {'userId': 'user-1', 'role': 'MEMBER'},
            {'userId': 'user-2', 'role': 'MEMBER'},
          ],
        },
      },
    );
  }
}

void main() {
  group('Group Creation & Integration Tests', () {
    test(
      'ChatRepository.createConversation posts according to API spec',
      () async {
        final api = MockApiService();
        final repo = ChatRepository(api);

        final result = await repo.createConversation(
          type: 'GROUP',
          title: 'Pilach Developers',
          userIds: ['user-1', 'user-2'],
        );

        expect(api.lastEndpoint, '/api/v1/conversations');
        expect(api.lastData['type'], 'GROUP');
        expect(api.lastData['title'], 'Pilach Developers');
        expect(api.lastData['userIds'], ['user-1', 'user-2']);

        final data = result['data'] as Map<String, dynamic>;
        expect(data['id'], 'new-group-123');
        expect(data['type'], 'GROUP');
      },
    );

    test('ChatModel accurately identifies group chat vs private chat', () {
      final groupChat = ChatModel(
        id: 'group-1',
        name: 'Pilach Core Team',
        message: 'Welcome everyone',
        image: 'https://cdn.example.com/group.png',
        time: '10:00 AM',
        unreadCount: 0,
        isOnline: false,
        type: 'GROUP',
      );

      final privateChat = ChatModel(
        id: 'chat-1',
        userId: 'user-2',
        name: 'Alice',
        message: 'Hello',
        image: 'https://cdn.example.com/alice.png',
        time: '09:30 AM',
        unreadCount: 1,
        isOnline: true,
        type: 'PRIVATE',
      );

      expect(groupChat.isGroup, isTrue);
      expect(privateChat.isGroup, isFalse);
    });

    test('ChatSqliteMapper preserves GROUP type when mapping to ChatModel', () {
      final sqliteRow = {
        'id': 'group-999',
        'type': 'GROUP',
        'title': 'Flutter Enthusiasts',
        'avatar_url': 'https://cdn.example.com/avatar.png',
        'last_message_preview': 'Group created',
        'last_message_at': '2026-10-30T10:00:00.000Z',
        'unread_count': 0,
        'is_online': 0,
        'is_muted': 0,
        'is_pinned': 0,
      };

      final chatModel = sqliteRow.toChatModel();
      expect(chatModel.id, 'group-999');
      expect(chatModel.name, 'Flutter Enthusiasts');
      expect(chatModel.type, 'GROUP');
      expect(chatModel.isGroup, isTrue);
    });

    test('ChatDto toSqliteMap preserves GROUP type and title correctly', () {
      final dto = ChatDto(
        id: 'group-555',
        type: 'GROUP',
        title: 'Engineering All-Hands',
        unreadCount: 0,
        createdAt: '2026-10-30T10:00:00.000Z',
      );

      final sqliteMap = dto.toSqliteMap('my-user-id');
      expect(sqliteMap['id'], 'group-555');
      expect(sqliteMap['type'], 'GROUP');
      expect(sqliteMap['title'], 'Engineering All-Hands');
      expect(sqliteMap['other_user_id'], isNull);
    });

    test(
      'ChatRepository.addMembers posts userIds to conversation members endpoint',
      () async {
        final api = MockApiService();
        final repo = ChatRepository(api);

        final res = await repo.addMembers('group-123', ['user-3', 'user-4']);
        expect(api.lastEndpoint, '/api/v1/conversations/group-123/members');
        expect(api.lastData['userIds'], ['user-3', 'user-4']);
        expect(res['success'], isTrue);
      },
    );

    test(
      'Conversation list contacts are extracted with member IDs for group members',
      () {
        final conversationList = [
          ChatModel(
            id: 'conv-1',
            userId: 'user-alice-123',
            name: 'Alice Smith',
            message: 'Hey, how are you?',
            image: 'https://example.com/alice.jpg',
            time: '10:00 AM',
            unreadCount: 0,
            isOnline: true,
            type: 'PRIVATE',
          ),
          ChatModel(
            id: 'conv-2',
            userId: null, // Legacy or direct where id is user id
            name: 'Bob Johnson',
            message: 'See you tomorrow!',
            image: 'https://example.com/bob.jpg',
            time: '09:00 AM',
            unreadCount: 0,
            isOnline: false,
            type: 'PRIVATE',
          ),
          ChatModel(
            id: 'conv-3',
            userId: null,
            name: 'Existing Group Chat',
            message: 'General chat',
            image: 'https://example.com/group.jpg',
            time: 'Yesterday',
            unreadCount: 0,
            isOnline: false,
            type: 'GROUP', // Should be excluded from individual member choices
          ),
        ];

        final contacts = extractEligibleContacts(conversationList);

        // Groups and private conversations without a real member userId are
        // excluded; conversation IDs must never be submitted as userIds.
        expect(contacts, hasLength(1));
        expect(contacts.single.id, 'user-alice-123');
        expect(contacts.single.name, 'Alice Smith');
        expect(contacts.single.status, 'Hey, how are you?');
      },
    );
  });
}
