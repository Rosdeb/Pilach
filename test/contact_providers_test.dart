import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/Features/Contact/presentation/providers/contact_providers.dart';
import 'package:flutter_test/flutter_test.dart';

ChatModel _chat({
  required String id,
  required String type,
  String? userId,
  String name = 'Member',
}) {
  return ChatModel(
    id: id,
    userId: userId,
    name: name,
    message: 'Hello',
    image: '',
    time: '',
    unreadCount: 0,
    isOnline: false,
    type: type,
  );
}

void main() {
  test('group member candidates use user IDs, never conversation IDs', () {
    final contacts = extractEligibleContacts([
      _chat(
        id: 'conversation-private',
        type: 'PRIVATE',
        userId: '9ac8fd12-312a-4ed6-80a8-a68423c5bd86',
      ),
      _chat(id: 'conversation-without-user', type: 'PRIVATE'),
      _chat(
        id: 'conversation-group',
        type: 'GROUP',
        userId: 'd08eb019-5a5f-4977-a18f-18275bf340ab',
      ),
    ]);

    expect(contacts, hasLength(1));
    expect(contacts.single.id, '9ac8fd12-312a-4ed6-80a8-a68423c5bd86');
    expect(contacts.single.conversationId, 'conversation-private');
  });

  test('duplicate private chats produce one selectable member', () {
    const userId = '9ac8fd12-312a-4ed6-80a8-a68423c5bd86';
    final contacts = extractEligibleContacts([
      _chat(id: 'conversation-1', type: 'PRIVATE', userId: userId),
      _chat(id: 'conversation-2', type: 'PRIVATE', userId: userId),
    ]);

    expect(contacts, hasLength(1));
    expect(contacts.single.id, userId);
  });
}
