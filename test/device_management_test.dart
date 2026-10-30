import 'package:app/Features/Me/data/models/device_session_model.dart';
import 'package:app/Features/Me/presentation/providers/device_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device & Session Management UI Logic Tests', () {
    test('Default sessions initialize with current device and other sessions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sessions = container.read(deviceSessionsProvider);
      expect(sessions.isNotEmpty, isTrue);

      final current = container.read(currentDeviceSessionProvider);
      expect(current, isNotNull);
      expect(current!.isCurrentDevice, isTrue);
      expect(current.deviceName, 'iPhone 15 Pro');

      final otherSessions = container.read(filteredOtherDeviceSessionsProvider);
      expect(otherSessions.length, 4);
      expect(otherSessions.every((s) => !s.isCurrentDevice), isTrue);
    });

    test('terminateSession removes specific session and protects current device', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceSessionsProvider.notifier);
      
      // Attempt to terminate a non-current device
      notifier.terminateSession('session-mac-work');
      var sessions = container.read(deviceSessionsProvider);
      expect(sessions.any((s) => s.id == 'session-mac-work'), isFalse);
      expect(sessions.length, 4);

      // Attempt to terminate the current device (should be protected)
      notifier.terminateSession('session-this-device');
      sessions = container.read(deviceSessionsProvider);
      expect(sessions.any((s) => s.id == 'session-this-device'), isTrue);
    });

    test('terminateAllOtherSessions leaves only current device', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceSessionsProvider.notifier);
      notifier.terminateAllOtherSessions();

      final sessions = container.read(deviceSessionsProvider);
      expect(sessions.length, 1);
      expect(sessions.first.isCurrentDevice, isTrue);

      final others = container.read(filteredOtherDeviceSessionsProvider);
      expect(others.isEmpty, isTrue);
    });

    test('deviceSessionSearchQueryProvider filters sessions by name, os, and location', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Search by location: Singapore
      container.read(deviceSessionSearchQueryProvider.notifier).state = 'Singapore';
      var filtered = container.read(filteredOtherDeviceSessionsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.deviceName, contains('Windows'));

      // Search by OS: Android
      container.read(deviceSessionSearchQueryProvider.notifier).state = 'Android';
      filtered = container.read(filteredOtherDeviceSessionsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.deviceName, contains('Samsung'));

      // Search with no match
      container.read(deviceSessionSearchQueryProvider.notifier).state = 'NonExistentOS';
      filtered = container.read(filteredOtherDeviceSessionsProvider);
      expect(filtered.isEmpty, isTrue);
    });

    test('enforces 5 devices maximum limit and restricts linking 6th device', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceSessionsProvider.notifier);
      expect(container.read(deviceSessionsProvider).length, 5);
      expect(container.read(isMaxDevicesReachedProvider), isTrue);

      // Attempt to add a 6th device
      const extraDevice = DeviceSessionModel(
        id: 'session-6',
        deviceName: 'Linux Desktop',
        platformType: DevicePlatformType.linux,
        clientName: 'Pilach Linux Client',
        appVersion: 'v1.0.0',
        osVersion: 'Ubuntu 24.04',
        location: 'Paris, France',
        ipAddress: '192.0.2.1',
        lastActive: 'Just now',
        loginDate: 'Oct 30, 2026',
      );

      final added = notifier.addSession(extraDevice);
      expect(added, isFalse);
      expect(container.read(deviceSessionsProvider).length, 5);

      // Free up a slot by terminating one session
      notifier.terminateSession('session-windows-pc');
      expect(container.read(deviceSessionsProvider).length, 4);
      expect(container.read(isMaxDevicesReachedProvider), isFalse);

      // Now adding the 5th device succeeds
      final addedAfterSlotFreed = notifier.addSession(extraDevice);
      expect(addedAfterSlotFreed, isTrue);
      expect(container.read(deviceSessionsProvider).length, 5);
      expect(container.read(isMaxDevicesReachedProvider), isTrue);
    });
  });
}
