import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_tile.dart';

void main() {
  testWidgets('ChatTile displays regular preview when not typing', (tester) async {
    final chat = ChatModel(
      id: 'chat-1',
      name: 'Alice',
      message: 'Hello there!',
      image: 'https://example.com/alice.png',
      time: '10:30 AM',
      unreadCount: 0,
      isOnline: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatTile(chat: chat),
          ),
        ),
      ),
    );

    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.text('typing'), findsNothing);
  });

  testWidgets('ChatTile displays animated typing indicator when typingStatusProvider is true', (tester) async {
    final chat = ChatModel(
      id: 'chat-1',
      name: 'Alice',
      message: 'Hello there!',
      image: 'https://example.com/alice.png',
      time: '10:30 AM',
      unreadCount: 0,
      isOnline: true,
    );

    final container = ProviderContainer();
    container.read(typingStatusProvider('chat-1').notifier).state = true;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ChatTile(chat: chat),
          ),
        ),
      ),
    );

    // Initial frame shows 'typing' and hides 'Hello there!'
    expect(find.text('typing'), findsOneWidget);
    expect(find.text('Hello there!'), findsNothing);

    // Pump frames to verify animation runs without error
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('typing'), findsOneWidget);

    // When typing stops
    container.read(typingStatusProvider('chat-1').notifier).state = false;
    await tester.pump();

    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.text('typing'), findsNothing);

    container.dispose();
  });

  testWidgets('ChatTile displays group sender name when typingUserNameProvider is set', (tester) async {
    final chat = ChatModel(
      id: 'group-1',
      name: 'Dev Team',
      message: 'Standup at 10',
      image: 'https://example.com/team.png',
      time: '09:45 AM',
      unreadCount: 0,
      isOnline: true,
      userId: '', // Group chat has empty userId
    );

    final container = ProviderContainer();
    container.read(typingStatusProvider('group-1').notifier).state = true;
    container.read(typingUserNameProvider('group-1').notifier).state = 'Rahim';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ChatTile(chat: chat),
          ),
        ),
      ),
    );

    expect(find.text('Rahim is typing'), findsOneWidget);
    expect(find.text('Standup at 10'), findsNothing);

    container.dispose();
  });
}
