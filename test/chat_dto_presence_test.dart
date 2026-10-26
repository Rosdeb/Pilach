import 'package:app/core/models/chat_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatDto presence mapping', () {
    test('maps nested online status for the other private-chat member', () {
      final dto = ChatDto.fromJson({
        'id': 'chat-1',
        'type': 'PRIVATE',
        'createdAt': '2026-10-27T10:00:00Z',
        'members': [
          {
            'userId': 'me',
            'user': {'id': 'me', 'status': 'ONLINE'},
          },
          {
            'userId': 'other',
            'user': {
              'id': 'other',
              'status': 'online',
              'lastSeen': '2026-10-27T09:59:00Z',
            },
          },
        ],
      });

      final row = dto.toSqliteMap('me');

      expect(row['other_user_id'], 'other');
      expect(row['is_online'], 1);
      expect(row['last_active_at'], '2026-10-27T09:59:00Z');
    });

    test('maps direct member presence aliases', () {
      final dto = ChatDto.fromJson({
        'id': 'chat-2',
        'type': 'PRIVATE',
        'createdAt': '2026-10-27T10:00:00Z',
        'members': [
          {'userId': 'me'},
          {
            'userId': 'other',
            'online': true,
            'last_active_at': '2026-10-27T09:58:00Z',
          },
        ],
      });

      final row = dto.toSqliteMap('me');

      expect(row['is_online'], 1);
      expect(row['last_active_at'], '2026-10-27T09:58:00Z');
    });
  });
}
