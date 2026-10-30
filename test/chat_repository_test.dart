import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:app/core/services/api_service.dart';

class FakeApiService extends ApiService {
  String? lastEndpoint;
  dynamic lastData;
  Map<String, String>? lastHeaders;
  Map<String, dynamic>? lastQueryParameters;

  FakeApiService() : super(Dio());

  @override
  Future<Response> post(
    String endpoint, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    lastEndpoint = endpoint;
    lastData = data;
    lastHeaders = headers;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'success': true,
        'data': {
          'id': 'server-msg-1',
          'clientMsgId': 'client-1',
          'conversationId': 'chat-1',
          'text': 'Hello world',
          'type': 'TEXT',
          'senderId': 'user-1',
          'status': 'sent',
          'createdAt': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  @override
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastEndpoint = endpoint;
    lastQueryParameters = queryParameters;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {'success': true, 'data': <dynamic>[]},
    );
  }
}

void main() {
  test(
    'sendMessage posts to the chat REST endpoint with the expected payload',
    () async {
      final apiService = FakeApiService();
      final repository = ChatRepository(apiService);

      await repository.sendMessage('chat-1', {
        'type': 'TEXT',
        'text': 'Hello world',
        'attachments': [],
      }, 'client-1');

      expect(apiService.lastEndpoint, '/api/v1/chats/chat-1/messages');
      expect(apiService.lastData['text'], 'Hello world');
      expect(apiService.lastData['type'], 'TEXT');
      expect(apiService.lastHeaders?['Idempotency-Key'], 'client-1');
    },
  );

  test('createConversation sends the documented GROUP payload', () async {
    final apiService = FakeApiService();
    final repository = ChatRepository(apiService);

    await repository.createConversation(
      type: 'group',
      title: '  Product Team  ',
      userIds: ['user-1', ' user-2 ', 'user-1', ''],
    );

    expect(apiService.lastEndpoint, '/api/v1/conversations');
    expect(apiService.lastData, {
      'type': 'GROUP',
      'title': 'Product Team',
      'userIds': ['user-1', 'user-2'],
    });
  });

  test('getConversations requests the API maximum page size', () async {
    final apiService = FakeApiService();
    final repository = ChatRepository(apiService);

    await repository.getConversations();

    expect(apiService.lastEndpoint, '/api/v1/conversations');
    expect(apiService.lastQueryParameters, {'limit': 150});
  });
}
