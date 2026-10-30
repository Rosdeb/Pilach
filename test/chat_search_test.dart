import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/Features/Chat/presentation/screens/chat_search_screen.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'package:app/Features/Chat/presentation/providers/in_chat_search_provider.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_bundle.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import 'package:app/core/theme/chat_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('ChatSearchScreen Widget Tests', () {
    testWidgets('renders in-chat search mode with chat title placeholder', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: ChatSearchScreen(
              chatId: 'chat-test-123',
              chatTitle: 'Pilach Core Team',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Search in Pilach Core Team...'), findsOneWidget);
      expect(
        find.text('Type at least 2 characters to search messages in this chat'),
        findsOneWidget,
      );
    });

    testWidgets('renders global search mode placeholder when no chatId provided', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: ChatSearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Search chats and messages...'), findsOneWidget);
      expect(
        find.text('Type at least 2 characters to search chats and messages'),
        findsOneWidget,
      );
    });

    testWidgets('targetScrollMessageIdProvider and highlightedMessageIdProvider track message selection', (tester) async {
      final container = ProviderContainer();
      expect(container.read(targetScrollMessageIdProvider), isNull);
      expect(container.read(highlightedMessageIdProvider), isNull);

      container.read(targetScrollMessageIdProvider.notifier).state = 'msg-selected-456';
      container.read(highlightedMessageIdProvider.notifier).state = 'msg-selected-456';

      expect(container.read(targetScrollMessageIdProvider), 'msg-selected-456');
      expect(container.read(highlightedMessageIdProvider), 'msg-selected-456');
    });

    testWidgets('ChatBubble with isHighlighted renders and executes animation without error', (tester) async {
      final testMsg = MessageModel(
        id: 'msg-highlight-1',
        text: 'This is the selected searched message',
        time: '12:30 PM',
        timestamp: DateTime.now(),
        isMe: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: testMsg,
              activeTheme: ChatThemes.defaultWhite,
              isHighlighted: true,
              onDelete: () {},
              onPin: () {},
            ),
          ),
        ),
      );

      expect(find.text('This is the selected searched message'), findsOneWidget);
      // Pump forward frames of highlight animation
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('This is the selected searched message'), findsOneWidget);
    });

    test('InChatSearchNotifier activates, navigates matches, and deactivates', () {
      final container = ProviderContainer();
      final notifier = container.read(inChatSearchProvider.notifier);

      expect(container.read(inChatSearchProvider).isActive, isFalse);

      notifier.activate();
      expect(container.read(inChatSearchProvider).isActive, isTrue);

      // Simulate search results
      notifier.state = InChatSearchState(
        isActive: true,
        query: 'hello',
        matchingMessageIds: ['msg-1', 'msg-2', 'msg-3'],
        currentIndex: 0,
      );

      notifier.nextMatch();
      expect(container.read(inChatSearchProvider).currentIndex, 1);
      expect(container.read(targetScrollMessageIdProvider), 'msg-2');
      expect(container.read(highlightedMessageIdProvider), 'msg-2');

      notifier.nextMatch();
      expect(container.read(inChatSearchProvider).currentIndex, 2);
      expect(container.read(targetScrollMessageIdProvider), 'msg-3');

      notifier.previousMatch();
      expect(container.read(inChatSearchProvider).currentIndex, 1);
      expect(container.read(targetScrollMessageIdProvider), 'msg-2');

      notifier.deactivate();
      expect(container.read(inChatSearchProvider).isActive, isFalse);
      expect(container.read(targetScrollMessageIdProvider), isNull);
      expect(container.read(highlightedMessageIdProvider), isNull);
    });
  });
}
