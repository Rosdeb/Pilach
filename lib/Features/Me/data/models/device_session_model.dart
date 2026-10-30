import 'dart:io';
import 'package:flutter/foundation.dart';

enum DevicePlatformType {
  ios,
  android,
  macos,
  windows,
  linux,
  tablet,
}

class DeviceSessionModel {
  final String id;
  final String deviceName;
  final DevicePlatformType platformType;
  final String clientName; // e.g. "Pilach for iOS", "Pilach Desktop for Windows"
  final String appVersion; // e.g. "v1.2.0 (Build 412)"
  final String osVersion; // e.g. "iOS 18.2", "macOS Sonoma 14.6"
  final String location; // e.g. "Dhaka, Bangladesh"
  final String ipAddress; // e.g. "103.145.74.22"
  final String lastActive; // e.g. "Active now", "15 minutes ago"
  final String loginDate; // e.g. "Oct 30, 2026 at 09:15 AM"
  final bool isCurrentDevice;
  final bool isPrimary;

  const DeviceSessionModel({
    required this.id,
    required this.deviceName,
    required this.platformType,
    required this.clientName,
    required this.appVersion,
    required this.osVersion,
    required this.location,
    required this.ipAddress,
    required this.lastActive,
    required this.loginDate,
    this.isCurrentDevice = false,
    this.isPrimary = false,
  });

  /// Detects the current device OS cleanly without raw "unknown"
  static String getCurrentDeviceOS() {
    if (kIsWeb) return 'Web Client';
    try {
      if (Platform.isIOS) {
        final version = Platform.operatingSystemVersion;
        final match = RegExp(r'Version\s+([\d\.]+)').firstMatch(version);
        final verStr = match != null ? match.group(1) : '';
        return verStr != null && verStr.isNotEmpty ? 'iOS $verStr' : 'iOS';
      } else if (Platform.isAndroid) {
        final version = Platform.operatingSystemVersion;
        return version.isNotEmpty ? 'Android $version' : 'Android';
      } else if (Platform.isMacOS) {
        final version = Platform.operatingSystemVersion;
        final match = RegExp(r'Version\s+([\d\.]+)').firstMatch(version);
        final verStr = match != null ? match.group(1) : '';
        return verStr != null && verStr.isNotEmpty ? 'macOS $verStr' : 'macOS';
      } else if (Platform.isWindows) {
        return 'Windows';
      } else if (Platform.isLinux) {
        return 'Linux';
      }
      return Platform.operatingSystem;
    } catch (_) {
      return 'Mobile Device';
    }
  }

  /// Detects current device name cleanly
  static String getCurrentDeviceName() {
    if (kIsWeb) return 'Web Client';
    try {
      if (Platform.isIOS) return 'Apple iPhone';
      if (Platform.isAndroid) return 'Android Phone';
      if (Platform.isMacOS) return 'MacBook / Mac';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isLinux) return 'Linux PC';
    } catch (_) {}
    return 'This Device';
  }

  /// Resolves the Operating System name and version from all available session metadata
  static String resolveOS({
    required String? rawOs,
    required String? deviceLabel,
    required String? browser,
    required String? platform,
    required bool isCurrent,
  }) {
    final cleanOs = (rawOs ?? '').trim();
    final osLower = cleanOs.toLowerCase();
    final isOsUnknown = cleanOs.isEmpty ||
        osLower == 'unknown' ||
        osLower == 'null' ||
        osLower == '—' ||
        osLower.contains('dart');

    // 1. If this is current device and server OS is unknown or Dart, use local runtime OS
    if (isCurrent && isOsUnknown) {
      return getCurrentDeviceOS();
    }

    // 2. If server provided a valid OS string, format and return it
    if (!isOsUnknown) {
      return cleanOs;
    }

    // 3. Infer from deviceLabel and browser headers (e.g. "Chrome on Windows", "Safari on iOS")
    final combined =
        '${deviceLabel ?? ''} ${browser ?? ''} ${platform ?? ''}'.toLowerCase();
    if (combined.contains('ipad') || combined.contains('ipados')) {
      return 'iPadOS';
    }
    if (combined.contains('ios') || combined.contains('iphone')) {
      return 'iOS';
    }
    if (combined.contains('android')) {
      return 'Android';
    }
    if (combined.contains('mac') ||
        combined.contains('macos') ||
        combined.contains('darwin') ||
        combined.contains('macintosh')) {
      return 'macOS';
    }
    if (combined.contains('win') || combined.contains('windows')) {
      return 'Windows';
    }
    if (combined.contains('linux')) {
      return 'Linux';
    }

    // 4. Fallback based on platform category
    final p = (platform ?? '').toLowerCase();
    if (p == 'mobile') return 'Mobile OS';
    if (p == 'tablet') return 'Tablet OS';
    if (p == 'desktop') return 'Desktop OS';

    return isCurrent ? getCurrentDeviceOS() : 'Not detected';
  }

  factory DeviceSessionModel.fromJson(Map<String, dynamic> json) {
    final platformStr = json['platform']?.toString().toLowerCase() ?? '';
    final rawOs = json['os']?.toString();
    final rawBrowser = json['browser']?.toString()?.trim() ?? '';
    final browserLower = rawBrowser.toLowerCase();
    final isBrowserDartOrUnknown = browserLower.isEmpty ||
        browserLower.contains('dart') ||
        browserLower == 'unknown' ||
        browserLower == 'null';
    final cleanBrowser = isBrowserDartOrUnknown ? '' : rawBrowser;

    final isCurrent = json['isCurrent'] == true || json['current'] == true;
    final isPrimary = json['isPrimary'] == true;

    final resolvedOs = resolveOS(
      rawOs: rawOs,
      deviceLabel: json['deviceLabel']?.toString(),
      browser: cleanBrowser,
      platform: platformStr,
      isCurrent: isCurrent,
    );

    // 1. Determine platform type
    final osLower = resolvedOs.toLowerCase();
    DevicePlatformType platformType;
    if (osLower.contains('ipad')) {
      platformType = DevicePlatformType.tablet;
    } else if (osLower.contains('ios') || platformStr == 'ios') {
      platformType = DevicePlatformType.ios;
    } else if (platformStr == 'tablet' || osLower.contains('tablet')) {
      platformType = DevicePlatformType.tablet;
    } else if (osLower.contains('android') || platformStr == 'android') {
      platformType = DevicePlatformType.android;
    } else if (osLower.contains('mac') || platformStr == 'macos') {
      platformType = DevicePlatformType.macos;
    } else if (osLower.contains('win') || platformStr == 'windows') {
      platformType = DevicePlatformType.windows;
    } else if (osLower.contains('linux') || platformStr == 'linux') {
      platformType = DevicePlatformType.linux;
    } else if (platformStr == 'mobile') {
      platformType = DevicePlatformType.ios;
    } else {
      platformType = DevicePlatformType.linux;
    }

    // 2. Resolve a user-friendly device name (filter out internal Dart/unknown tokens)
    String? rawLabel = json['deviceLabel']?.toString()?.trim();
    final labelLower = (rawLabel ?? '').toLowerCase();
    if (labelLower.isEmpty ||
        labelLower.contains('dart') ||
        labelLower == 'unknown' ||
        labelLower == 'unknown device' ||
        labelLower == 'null') {
      rawLabel = null;
    }

    String deviceName;
    if (isCurrent && rawLabel == null) {
      deviceName = getCurrentDeviceName();
    } else if (rawLabel != null) {
      deviceName = rawLabel;
    } else if (resolvedOs.isNotEmpty &&
        resolvedOs != 'Not detected' &&
        cleanBrowser.isNotEmpty) {
      deviceName = '$resolvedOs ($cleanBrowser)';
    } else if (resolvedOs.isNotEmpty && resolvedOs != 'Not detected') {
      deviceName = switch (osLower) {
        final s when s.contains('ipad') => 'Apple iPad',
        final s when s.contains('ios') => 'Apple iPhone',
        final s when s.contains('android') =>
          platformStr == 'tablet' ? 'Android Tablet' : 'Android Device',
        final s when s.contains('mac') => 'MacBook / Mac',
        final s when s.contains('win') => 'Windows PC',
        final s when s.contains('linux') => 'Linux PC',
        _ => resolvedOs,
      };
    } else if (platformStr.isNotEmpty && platformStr != 'unknown') {
      deviceName = switch (platformStr) {
        'mobile' => 'Mobile Device',
        'tablet' => 'Tablet',
        'desktop' => 'Desktop Computer',
        _ => 'Connected Device',
      };
    } else {
      deviceName = isCurrent ? getCurrentDeviceName() : 'Connected Device';
    }

    // 3. Resolve client / app name without ever displaying "Dart"
    final clientName = cleanBrowser.isNotEmpty
        ? cleanBrowser
        : (platformType == DevicePlatformType.ios
            ? 'Pilach for iOS'
            : platformType == DevicePlatformType.android
                ? 'Pilach for Android'
                : platformType == DevicePlatformType.macos
                    ? 'Pilach Desktop for macOS'
                    : platformType == DevicePlatformType.windows
                        ? 'Pilach Desktop for Windows'
                        : platformType == DevicePlatformType.tablet
                            ? 'Pilach for iPadOS'
                            : 'Pilach Client');

    return DeviceSessionModel(
      id: json['id']?.toString() ?? '',
      deviceName: deviceName,
      platformType: platformType,
      clientName: clientName,
      appVersion: json['appVersion']?.toString() ?? 'v1.0.0',
      osVersion: resolvedOs,
      location: json['location']?.toString() ?? 'IP location unavailable',
      ipAddress: json['ipAddress']?.toString() ?? '—',
      lastActive: isCurrent
          ? 'Active now'
          : _displayTimestamp(json['lastActiveAt']),
      loginDate: _displayTimestamp(json['createdAt']),
      isCurrentDevice: isCurrent,
      isPrimary: isPrimary,
    );
  }

  static String _displayTimestamp(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return 'Unknown';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  DeviceSessionModel copyWith({
    String? id,
    String? deviceName,
    DevicePlatformType? platformType,
    String? clientName,
    String? appVersion,
    String? osVersion,
    String? location,
    String? ipAddress,
    String? lastActive,
    String? loginDate,
    bool? isCurrentDevice,
  }) {
    return DeviceSessionModel(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      platformType: platformType ?? this.platformType,
      clientName: clientName ?? this.clientName,
      appVersion: appVersion ?? this.appVersion,
      osVersion: osVersion ?? this.osVersion,
      location: location ?? this.location,
      ipAddress: ipAddress ?? this.ipAddress,
      lastActive: lastActive ?? this.lastActive,
      loginDate: loginDate ?? this.loginDate,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }
}
