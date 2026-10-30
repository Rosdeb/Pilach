import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import 'package:app/Features/Chat/presentation/providers/chat_provider.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_bundle.dart';
import 'package:app/Features/bottom_nav_bar/presentation/widgets/nav_item.dart';
import 'package:app/core/theme/chat_themes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bottom Nav Unread Count & Badge Tests', () {
    test('totalUnreadCountProvider sums unread messages across all chats correctly', () {
      final container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith((ref) => _FakeChatNotifier([
                ChatModel(
                  id: 'c1',
                  name: 'Alice',
                  message: 'Hello',
                  image: '',
                  time: '12:00',
                  unreadCount: 4,
                  isOnline: true,
                ),
                ChatModel(
                  id: 'c2',
                  name: 'Bob',
                  message: 'Hey',
                  image: '',
                  time: '12:05',
                  unreadCount: 7,
                  isOnline: false,
                ),
                ChatModel(
                  id: 'c3',
                  name: 'Group',
                  message: 'Hi all',
                  image: '',
                  time: '12:10',
                  unreadCount: 0,
                  isOnline: false,
                ),
              ])),
        ],
      );

      final total = container.read(totalUnreadCountProvider);
      expect(total, 11);
    });

    test('totalUnreadCountProvider returns 0 when no unread messages', () {
      final container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith((ref) => _FakeChatNotifier([
                ChatModel(
                  id: 'c1',
                  name: 'Alice',
                  message: 'Hello',
                  image: '',
                  time: '12:00',
                  unreadCount: 0,
                  isOnline: true,
                ),
              ])),
        ],
      );

      final total = container.read(totalUnreadCountProvider);
      expect(total, 0);
    });

    testWidgets('NavItem does not show badge when badgeCount is 0', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NavItem(
                icon: CupertinoIcons.chat_bubble_2,
                label: 'Chat',
                index: 0,
                isSelected: true,
                badgeCount: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('NavItem displays badge count when badgeCount > 0', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NavItem(
                icon: CupertinoIcons.chat_bubble_2,
                label: 'Chat',
                index: 0,
                isSelected: true,
                badgeCount: 5,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('NavItem displays 99+ when badgeCount exceeds 99', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NavItem(
                icon: CupertinoIcons.chat_bubble_2,
                label: 'Chat',
                index: 0,
                isSelected: true,
                badgeCount: 120,
              ),
            ),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('NavItem uses green color when selected and red for badge number text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NavItem(
                icon: CupertinoIcons.chat_bubble_2,
                label: 'Chat',
                index: 0,
                isSelected: true,
                badgeCount: 3,
              ),
            ),
          ),
        ),
      );

      // Icon should have selected green color (0xFF0EB587)
      final iconWidget = tester.widget<Icon>(find.byIcon(CupertinoIcons.chat_bubble_2));
      expect(iconWidget.color, const Color(0xFF0EB587));

      // Number text should have red color (0xFFE53935)
      final textWidget = tester.widget<Text>(find.text('3'));
      expect(textWidget.style?.color, const Color(0xFFE53935));

      // Badge container border should be red (0xFFE53935)
      final badgeContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('3'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = badgeContainer.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, const Color(0xFFE53935));
    });
  });

  group('Quick Message Dialog Copy Option Tests', () {
    testWidgets('ChatBubble long-press opens menu with Copy option', (tester) async {
      bool copied = false;

      final message = MessageModel(
        id: 'msg-1',
        text: 'Important meeting notes here',
        time: '10:30 AM',
        timestamp: DateTime.now(),
        isMe: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ChatBubble(
                  message: message,
                  activeTheme: ChatThemes.defaultWhite,
                  onDelete: () {},
                  onPin: () {},
                  onReply: () {},
                  onCopy: () {
                    copied = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Long press on the message bubble to trigger quick message dialog
      await tester.longPress(find.text('Important meeting notes here'));
      await tester.pumpAndSettle();

      // Check for quick action options
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Pin Message'), findsOneWidget);

      // Tap Copy
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, isTrue);
    });

    testWidgets('ChatBubble default onCopy copies text to clipboard', (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      final message = MessageModel(
        id: 'msg-2',
        text: 'Copy this specific sentence',
        time: '10:35 AM',
        timestamp: DateTime.now(),
        isMe: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ChatBubble(
                  message: message,
                  activeTheme: ChatThemes.defaultWhite,
                  onDelete: () {},
                  onPin: () {},
                  onReply: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Copy this specific sentence'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect(clipboardText, 'Copy this specific sentence');
    });
  });
}

class _FakeChatNotifier extends StateNotifier<List<ChatModel>>
    implements ChatNotifier {
  _FakeChatNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
