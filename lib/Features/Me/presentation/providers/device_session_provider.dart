import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/device_session_model.dart';
import '../../data/repositories/security_repository.dart';

final defaultDeviceSessions = <DeviceSessionModel>[
  const DeviceSessionModel(
    id: 'session-this-device',
    deviceName: 'iPhone 15 Pro',
    platformType: DevicePlatformType.ios,
    clientName: 'Pilach for iOS',
    appVersion: 'v1.2.0 (Build 412)',
    osVersion: 'iOS 18.2',
    location: 'Dhaka, Bangladesh',
    ipAddress: '103.145.74.22',
    lastActive: 'Active now',
    loginDate: 'Today, 08:15 AM',
    isCurrentDevice: true,
  ),
  const DeviceSessionModel(
    id: 'session-mac-work',
    deviceName: 'MacBook Pro 16"',
    platformType: DevicePlatformType.macos,
    clientName: 'Pilach Desktop for macOS',
    appVersion: 'v1.1.8 (Build 204)',
    osVersion: 'macOS Sonoma 14.6',
    location: 'Dhaka, Bangladesh',
    ipAddress: '103.145.74.25',
    lastActive: '12 minutes ago',
    loginDate: 'Oct 28, 2026, 10:30 AM',
    isCurrentDevice: false,
  ),
  const DeviceSessionModel(
    id: 'session-windows-pc',
    deviceName: 'Windows 11 PC',
    platformType: DevicePlatformType.windows,
    clientName: 'Pilach Desktop for Windows',
    appVersion: 'v1.1.4 (Build 182)',
    osVersion: 'Windows 11 Pro (23H2)',
    location: 'Singapore',
    ipAddress: '165.225.112.40',
    lastActive: '3 hours ago',
    loginDate: 'Oct 25, 2026, 03:45 PM',
    isCurrentDevice: false,
  ),
  const DeviceSessionModel(
    id: 'session-ipad-air',
    deviceName: 'iPad Air (5th Gen)',
    platformType: DevicePlatformType.tablet,
    clientName: 'Pilach for iPadOS',
    appVersion: 'v1.2.0 (Build 412)',
    osVersion: 'iPadOS 17.5.1',
    location: 'Dhaka, Bangladesh',
    ipAddress: '103.145.74.22',
    lastActive: 'Yesterday, 07:15 PM',
    loginDate: 'Oct 19, 2026, 09:12 AM',
    isCurrentDevice: false,
  ),
  const DeviceSessionModel(
    id: 'session-samsung-galaxy',
    deviceName: 'Samsung Galaxy S24 Ultra',
    platformType: DevicePlatformType.android,
    clientName: 'Pilach for Android',
    appVersion: 'v1.2.0 (Build 390)',
    osVersion: 'Android 15 (One UI 7.0)',
    location: 'London, United Kingdom',
    ipAddress: '82.165.197.1',
    lastActive: 'Oct 22, 2026',
    loginDate: 'Oct 12, 2026, 11:40 AM',
    isCurrentDevice: false,
  ),
];

class DeviceSessionNotifier extends StateNotifier<List<DeviceSessionModel>> {
  static const int maxLinkedDevices = 5;

  DeviceSessionNotifier([this._repository]) : super(defaultDeviceSessions) {
    if (_repository != null) {
      unawaited(refresh());
    }
  }

  final SecurityRepository? _repository;

  Future<void> refresh() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final rows = await repo.getSessions();
      if (rows.isNotEmpty) {
        state = rows
            .map(DeviceSessionModel.fromJson)
            .where((session) => session.id.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
  }

  bool addSession(DeviceSessionModel session) {
    if (state.length >= maxLinkedDevices) {
      return false;
    }
    state = [...state, session];
    return true;
  }

  Future<void> terminateSession(String sessionId) async {
    final session = state.where((item) => item.id == sessionId).firstOrNull;
    if (session?.isCurrentDevice == true) return;
    final repo = _repository;
    if (repo != null) {
      try {
        await repo.revokeSession(sessionId);
      } catch (_) {}
    }
    state = state.where((item) => item.id != sessionId).toList();
  }

  Future<void> terminateAllOtherSessions() async {
    final repo = _repository;
    if (repo != null) {
      try {
        await repo.revokeOtherSessions();
      } catch (_) {}
    }
    state = state.where((s) => s.isCurrentDevice).toList();
  }

  Future<void> resetToDefaults() async {
    if (_repository != null) {
      await refresh();
    } else {
      state = defaultDeviceSessions;
    }
  }
}

final deviceSessionsProvider =
    StateNotifierProvider<DeviceSessionNotifier, List<DeviceSessionModel>>(
  (ref) {
    try {
      final repo = ref.watch(securityRepositoryProvider);
      return DeviceSessionNotifier(repo);
    } catch (_) {
      return DeviceSessionNotifier();
    }
  },
);

final maxLinkedDevicesLimitProvider = Provider<int>((ref) => DeviceSessionNotifier.maxLinkedDevices);

final isMaxDevicesReachedProvider = Provider<bool>((ref) {
  final count = ref.watch(deviceSessionsProvider).length;
  return count >= DeviceSessionNotifier.maxLinkedDevices;
});

final deviceSessionSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredOtherDeviceSessionsProvider = Provider<List<DeviceSessionModel>>((ref) {
  final sessions = ref.watch(deviceSessionsProvider);
  final query = ref.watch(deviceSessionSearchQueryProvider).trim().toLowerCase();

  final otherSessions = sessions.where((s) => !s.isCurrentDevice).toList();
  if (query.isEmpty) return otherSessions;

  return otherSessions.where((s) {
    return s.deviceName.toLowerCase().contains(query) ||
        s.location.toLowerCase().contains(query) ||
        s.osVersion.toLowerCase().contains(query) ||
        s.clientName.toLowerCase().contains(query) ||
        s.ipAddress.toLowerCase().contains(query);
  }).toList();
});

final currentDeviceSessionProvider = Provider<DeviceSessionModel?>((ref) {
  final sessions = ref.watch(deviceSessionsProvider);
  return sessions.where((s) => s.isCurrentDevice).firstOrNull;
});
