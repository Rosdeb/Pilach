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

  factory DeviceSessionModel.fromJson(Map<String, dynamic> json) {
    final platformStr = json['platform']?.toString().toLowerCase() ?? '';
    final rawOs = json['os']?.toString() ?? '';
    final osStr = rawOs.toLowerCase();
    final browser = json['browser']?.toString() ?? '';
    final isCurrent = json['isCurrent'] == true || json['current'] == true;
    final isPrimary = json['isPrimary'] == true;

    // 1. Determine platform type
    DevicePlatformType platformType;
    if (osStr.contains('ipad') || (platformStr == 'tablet' && osStr.contains('ios'))) {
      platformType = DevicePlatformType.tablet;
    } else if (osStr.contains('ios') || platformStr == 'ios') {
      platformType = DevicePlatformType.ios;
    } else if (platformStr == 'tablet' || osStr.contains('tablet')) {
      platformType = DevicePlatformType.tablet;
    } else if (osStr.contains('android') || platformStr == 'android') {
      platformType = DevicePlatformType.android;
    } else if (osStr.contains('mac') || platformStr == 'macos') {
      platformType = DevicePlatformType.macos;
    } else if (osStr.contains('win') || platformStr == 'windows') {
      platformType = DevicePlatformType.windows;
    } else if (osStr.contains('linux') || platformStr == 'linux') {
      platformType = DevicePlatformType.linux;
    } else if (platformStr == 'mobile') {
      platformType = DevicePlatformType.ios;
    } else {
      platformType = DevicePlatformType.linux;
    }

    // 2. Resolve a user-friendly device name
    String? rawLabel = json['deviceLabel']?.toString();
    if (rawLabel == null ||
        rawLabel.trim().isEmpty ||
        rawLabel.trim().toLowerCase() == 'unknown' ||
        rawLabel.trim().toLowerCase() == 'unknown device') {
      rawLabel = null;
    }

    String deviceName;
    if (rawLabel != null) {
      deviceName = rawLabel;
    } else if (rawOs.isNotEmpty && browser.isNotEmpty) {
      deviceName = '$rawOs ($browser)';
    } else if (rawOs.isNotEmpty) {
      deviceName = switch (osStr) {
        final s when s.contains('ipad') => 'Apple iPad',
        final s when s.contains('ios') => 'Apple iPhone',
        final s when s.contains('android') =>
          platformStr == 'tablet' ? 'Android Tablet' : 'Android Device',
        final s when s.contains('mac') => 'MacBook / Mac',
        final s when s.contains('win') => 'Windows PC',
        final s when s.contains('linux') => 'Linux PC',
        _ => rawOs,
      };
    } else if (platformStr.isNotEmpty && platformStr != 'unknown') {
      deviceName = switch (platformStr) {
        'mobile' => 'Mobile Device',
        'tablet' => 'Tablet',
        'desktop' => 'Desktop Computer',
        _ => 'Connected Device',
      };
    } else {
      deviceName = isCurrent ? 'This Device' : 'Connected Device';
    }

    // 3. Resolve client / app name
    final clientName = browser.isNotEmpty
        ? browser
        : (platformStr == 'mobile' ||
                platformType == DevicePlatformType.ios ||
                platformType == DevicePlatformType.android
            ? 'Pilach for Mobile'
            : 'Pilach Client');

    return DeviceSessionModel(
      id: json['id']?.toString() ?? '',
      deviceName: deviceName,
      platformType: platformType,
      clientName: clientName,
      appVersion: json['appVersion']?.toString() ?? '—',
      osVersion:
          rawOs.isNotEmpty ? rawOs : (platformStr.isNotEmpty ? platformStr : '—'),
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
