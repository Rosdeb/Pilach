import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/core/services/location_service.dart';
import 'package:app/Features/Chat/presentation/screens/inbox_screen/widgets/attachment_drawer.dart';
import 'package:app/Features/Chat/presentation/screens/inbox_screen/widgets/inbox_providers.dart';
import 'package:app/Features/Chat/presentation/widgets/chat_bundle.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import 'package:app/core/theme/chat_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocationService.mockServiceEnabled = null;
    LocationService.mockCheckPermission = null;
    LocationService.mockRequestPermission = null;
    LocationService.mockCurrentPosition = null;
  });

  tearDown(() {
    LocationService.mockServiceEnabled = null;
    LocationService.mockCheckPermission = null;
    LocationService.mockRequestPermission = null;
    LocationService.mockCurrentPosition = null;
  });

  group('AttachmentDrawer Location Option Tests', () {
    testWidgets('renders Location option with icon and label', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AttachmentDrawer(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Location'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('tapping Location option closes drawer menu', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(showAttachmentMenuProvider.notifier).state = true;

      LocationService.mockServiceEnabled = () async => true;
      LocationService.mockCheckPermission = () async => LocationPermission.always;
      LocationService.mockCurrentPosition = ({LocationSettings? locationSettings}) async {
        return Position(
          latitude: 23.8103,
          longitude: 90.4125,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      };

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AttachmentDrawer(),
            ),
          ),
        ),
      );
      await tester.pump();

      final locationFinder = find.widgetWithText(AttachmentIcon, 'Location');
      expect(locationFinder, findsOneWidget);

      await tester.tap(locationFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Drawer should be instructed to close
      expect(container.read(showAttachmentMenuProvider), isFalse);
    });
  });

  group('ChatBubble Location Card Tests', () {
    testWidgets('renders Location card inside ChatBubble when message contains map URL', (tester) async {
      final message = MessageModel(
        id: 'msg-loc-1',
        text: '📍 Meeting Point\nhttps://maps.google.com/?q=23.8103,90.4125',
        time: '12:00 PM',
        timestamp: DateTime.now(),
        isMe: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: message,
              activeTheme: ChatThemes.defaultWhite,
              onDelete: () {},
              onPin: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Meeting Point'), findsOneWidget);
      expect(find.text('Open in Maps'), findsOneWidget);
      expect(find.textContaining('23.8103, 90.4125'), findsOneWidget);
    });

    testWidgets('tapping Location card opens map options bottom sheet', (tester) async {
      final message = MessageModel(
        id: 'msg-loc-2',
        text: '📍 Meeting Point\nhttps://maps.apple.com/?q=37.7749,-122.4194',
        time: '12:00 PM',
        timestamp: DateTime.now(),
        isMe: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: message,
              activeTheme: ChatThemes.defaultWhite,
              onDelete: () {},
              onPin: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      final cardFinder = find.text('Open in Maps');
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.text('Copy Coordinates'), findsOneWidget);
    });
  });
}
