import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_avatar.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_bundle.dart';
import 'package:app/core/models/chat_dto.dart';
import 'package:app/core/theme/chat_themes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group Avatar & Member Avatars Tests', () {
    test('ChatDto extracts member avatars from group response without car fallback', () {
      final json = {
        'id': 'group-1',
        'type': 'GROUP',
        'title': 'Core Team',
        'avatarUrl': null,
        'unreadCount': 0,
        'createdAt': '2026-10-30T05:00:00.000Z',
        'members': [
          {
            'user': {
              'id': 'u1',
              'profile': {'name': 'Alice', 'avatarUrl': 'https://example.com/alice.jpg'},
            },
          },
          {
            'user': {
              'id': 'u2',
              'profile': {'name': 'Bob', 'avatarUrl': 'https://example.com/bob.jpg'},
            },
          },
          {
            'user': {
              'id': 'u3',
              'profile': {'name': 'Charlie', 'avatarUrl': null},
            },
          },
        ],
      };

      final dto = ChatDto.fromJson(json);
      final sqliteMap = dto.toSqliteMap();

      expect(sqliteMap['avatar_url'], 'MEMBERS_AVATARS:https://example.com/alice.jpg,https://example.com/bob.jpg');

      final domainModel = dto.toDomain();
      expect(domainModel.isGroup, true);
      expect(domainModel.memberAvatars, [
        'https://example.com/alice.jpg',
        'https://example.com/bob.jpg',
      ]);
      expect(domainModel.image, '');
      expect(domainModel.image.contains('motor1.com'), false);

      final fromDb = sqliteMap.toChatModel();
      expect(fromDb.isGroup, true);
      expect(fromDb.memberAvatars, [
        'https://example.com/alice.jpg',
        'https://example.com/bob.jpg',
      ]);
      expect(fromDb.image, '');
    });

    test('ChatDto keeps dedicated group avatar if provided', () {
      final json = {
        'id': 'group-2',
        'type': 'GROUP',
        'title': 'Design Team',
        'avatarUrl': 'https://example.com/group-logo.png',
        'unreadCount': 0,
        'createdAt': '2026-10-30T05:00:00.000Z',
        'members': [
          {
            'user': {
              'id': 'u1',
              'profile': {'name': 'Alice', 'avatarUrl': 'https://example.com/alice.jpg'},
            },
          },
        ],
      };

      final dto = ChatDto.fromJson(json);
      final sqliteMap = dto.toSqliteMap();
      expect(sqliteMap['avatar_url'], 'https://example.com/group-logo.png');

      final model = sqliteMap.toChatModel();
      expect(model.image, 'https://example.com/group-logo.png');
      expect(model.memberAvatars.isEmpty, true);
    });

    testWidgets('ChatAvatar displays 2-member Messenger composite avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              isGroup: true,
              memberAvatars: [
                'https://example.com/member1.jpg',
                'https://example.com/member2.jpg',
              ],
              isOnline: false,
              onlineColor: Colors.blue,
              borderColor: Colors.white,
            ),
          ),
        ),
      );

      final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
      expect(images.length, 2);
      expect(images[0].imageUrl, 'https://example.com/member1.jpg');
      expect(images[1].imageUrl, 'https://example.com/member2.jpg');
    });

    testWidgets('ChatAvatar displays 3-member Messenger composite avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              isGroup: true,
              memberAvatars: [
                'https://example.com/m1.jpg',
                'https://example.com/m2.jpg',
                'https://example.com/m3.jpg',
              ],
              isOnline: false,
              onlineColor: Colors.blue,
              borderColor: Colors.white,
            ),
          ),
        ),
      );

      final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
      expect(images.length, 3);
      expect(images[0].imageUrl, 'https://example.com/m1.jpg');
      expect(images[1].imageUrl, 'https://example.com/m2.jpg');
      expect(images[2].imageUrl, 'https://example.com/m3.jpg');
    });

    testWidgets('ChatAvatar displays default Cupertino group icon when member avatars < 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              isGroup: true,
              memberAvatars: [],
              isOnline: false,
              onlineColor: Colors.blue,
              borderColor: Colors.white,
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.person_2_fill), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('ChatAvatar displays single group image if dedicated group photo exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              isGroup: true,
              imageUrl: 'https://example.com/custom-group.jpg',
              memberAvatars: [
                'https://example.com/m1.jpg',
                'https://example.com/m2.jpg',
              ],
              isOnline: false,
              onlineColor: Colors.blue,
              borderColor: Colors.white,
            ),
          ),
        ),
      );

      final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
      expect(images.length, 1);
      expect(images.first.imageUrl, 'https://example.com/custom-group.jpg');
    });

    testWidgets('ChatBubble incoming message displays person fallback icon when no avatar provided', (tester) async {
      final msg = MessageModel(
        id: 'msg-1',
        text: 'Hello from someone',
        time: '10:00 AM',
        timestamp: DateTime.now(),
        isMe: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: msg,
              activeTheme: ChatThemes.defaultWhite,
              otherUserAvatar: null,
              onDelete: () {},
              onPin: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.person_fill), findsOneWidget);
    });

    testWidgets('ChatBubble incoming message displays network image when avatar provided', (tester) async {
      final msg = MessageModel(
        id: 'msg-2',
        text: 'Hello with photo',
        time: '10:01 AM',
        timestamp: DateTime.now(),
        isMe: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: msg,
              activeTheme: ChatThemes.defaultWhite,
              otherUserAvatar: 'https://example.com/sender.jpg',
              onDelete: () {},
              onPin: () {},
            ),
          ),
        ),
      );

      final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
      expect(images.length, 1);
      expect(images.first.imageUrl, 'https://example.com/sender.jpg');
    });
  });
}
