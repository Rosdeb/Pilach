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
  });

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
