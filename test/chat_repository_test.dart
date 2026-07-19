import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:app/core/services/api_service.dart';

class FakeApiService extends ApiService {
  String? lastEndpoint;
  dynamic lastData;

  FakeApiService() : super(Dio());

  @override
  Future<Response> post(String endpoint, {dynamic data}) async {
    lastEndpoint = endpoint;
    lastData = data;
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
}

void main() {
  test('sendMessage posts to the chat REST endpoint with the expected payload', () async {
    final apiService = FakeApiService();
    final repository = ChatRepository(apiService);

    await repository.sendMessage(
      'chat-1',
      {
        'type': 'TEXT',
        'text': 'Hello world',
        'attachments': [],
      },
      'client-1',
    );

    expect(apiService.lastEndpoint, '/api/v1/chats/chat-1/messages');
    expect(apiService.lastData['text'], 'Hello world');
    expect(apiService.lastData['clientMsgId'], 'client-1');
  });
}
