import 'package:app/core/utils/message_merge_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mergeMessageRows preserves existing metadata when incoming payload is partial', () {
    final existing = {
      'id': 'msg-1',
      'client_msg_id': 'client-1',
      'conversation_id': 'chat-1',
      'text': 'older text',
      'status': 'sent',
      'created_at': '2024-01-01T00:00:00.000Z',
      'edited_at': '2024-01-02T00:00:00.000Z',
      'reply_to_id': 'reply-1',
      'reply_to_json': '{"id":"reply-1","text":"reply"}',
      'reactions_json': '[{"emoji":"👍"}]',
      'attachments_json': '[{"url":"https://cdn.test/file.jpg"}]',
      'deleted': 0,
    };

    final incoming = {
      'id': 'msg-1',
      'client_msg_id': 'client-1',
      'conversation_id': 'chat-1',
      'text': 'new text',
      'status': 'delivered',
      'created_at': '2024-01-03T00:00:00.000Z',
      'seq': 10,
      'reply_to_id': null,
      'reply_to_json': null,
      'reactions_json': null,
      'attachments_json': null,
      'deleted': 0,
    };

    final merged = mergeMessageRows(incoming, existing);

    expect(merged['text'], 'new text');
    expect(merged['status'], 'delivered');
    expect(merged['created_at'], '2024-01-03T00:00:00.000Z');
    expect(merged['edited_at'], '2024-01-02T00:00:00.000Z');
    expect(merged['reply_to_json'], '{"id":"reply-1","text":"reply"}');
    expect(merged['reactions_json'], '[{"emoji":"👍"}]');
    expect(merged['attachments_json'], '[{"url":"https://cdn.test/file.jpg"}]');
    expect(merged['seq'], 10);
  });
}
