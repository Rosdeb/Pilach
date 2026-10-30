import 'package:app/core/utils/message_merge_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mergeMessageRows preserves existing metadata when incoming payload is partial',
    () {
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
        'edited_at': '2024-01-03T00:00:00.000Z',
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
      expect(merged['edited_at'], '2024-01-03T00:00:00.000Z');
      expect(merged['reply_to_json'], '{"id":"reply-1","text":"reply"}');
      expect(merged['reactions_json'], '[{"emoji":"👍"}]');
      expect(
        merged['attachments_json'],
        '[{"url":"https://cdn.test/file.jpg"}]',
      );
      expect(merged['seq'], 10);
    },
  );

  test('mergeMessageRows applies an authoritative empty reaction snapshot', () {
    final existing = {
      'id': 'msg-1',
      'reactions_json': '[{"emoji":"❤️","userId":"u1"}]',
    };
    final incomingEmpty = {'id': 'msg-1', 'reactions_json': '[]'};

    final merged = mergeMessageRows(incomingEmpty, existing);
    expect(merged['reactions_json'], '[]');
  });

  test('mergeMessageRows applies the latest server reaction snapshot', () {
    final existing = {
      'id': 'msg-1',
      'reactions_json': '[{"emoji":"❤️","userId":"u1"}]',
    };
    final incomingUpdated = {
      'id': 'msg-1',
      'reactions_json': '[{"emoji":"👍","userId":"u2"}]',
    };

    final merged = mergeMessageRows(incomingUpdated, existing);
    expect(merged['reactions_json'], '[{"emoji":"👍","userId":"u2"}]');
  });

  test(
    'mergeMessageRows preserves deleted tombstone over incoming un-deleted row',
    () {
      final existingDeleted = {
        'id': 'msg-1',
        'text': 'deleted message',
        'deleted': 1,
      };
      final incomingUndeleted = {
        'id': 'msg-1',
        'text': 'incoming stale message',
        'deleted': 0,
      };

      final merged = mergeMessageRows(incomingUndeleted, existingDeleted);
      expect(merged['deleted'], 1);
      expect(merged['text'], isEmpty);
    },
  );

  test(
    'mergeMessageRows enforces monotonic status progression (seen > sent)',
    () {
      final existingSeen = {'id': 'msg-1', 'status': 'seen'};
      final incomingSent = {'id': 'msg-1', 'status': 'sent'};

      final merged = mergeMessageRows(incomingSent, existingSeen);
      expect(merged['status'], 'seen');
    },
  );

  test('mergeMessageRows respects LWW for text edits based on edited_at', () {
    final newerExisting = {
      'id': 'msg-1',
      'text': 'newest text edit',
      'edited_at': '2026-10-30T01:30:00.000Z',
    };
    final olderIncoming = {
      'id': 'msg-1',
      'text': 'stale text edit',
      'edited_at': '2026-10-30T01:20:00.000Z',
    };

    final merged = mergeMessageRows(olderIncoming, newerExisting);
    expect(merged['text'], 'newest text edit');
    expect(merged['edited_at'], '2026-10-30T01:30:00.000Z');
  });
}
