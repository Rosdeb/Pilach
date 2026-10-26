import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_provider.dart';
import '../theme/theme_provider.dart';
import '../router/app_router.dart';
import '../../components/InAppNotificationBanner/in_app_notification_banner.dart';
import '../../firebase_options.dart';
import '../database/daos/message_dao.dart';
import '../models/message_dto.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.persistRemoteMessage(message);
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = NotificationService(apiService, prefs);
  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  final ApiService _apiService;
  final SharedPreferences _prefs;
  final LinkedHashSet<String> _handledNotificationIds = LinkedHashSet();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? Function()? _activeChatId;
  void Function(String chatId)? _openChat;
  RemoteMessage? _pendingNavigation;

  NotificationService(this._apiService, this._prefs) {
    _requestPermissions();
    _setupFcmListeners();
  }

  void configureNavigation({
    required String? Function() activeChatId,
    required void Function(String chatId) openChat,
  }) {
    _activeChatId = activeChatId;
    _openChat = openChat;
    final pending = _pendingNavigation;
    if (pending != null) {
      _pendingNavigation = null;
      _handleNotificationClick(pending);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint("[NotificationService] Notification permission status: ${settings.authorizationStatus}");
    } catch (e) {
      debugPrint("[NotificationService] Error requesting notification permission: $e");
    }
  }

  void _setupFcmListeners() {
    // 1. Listen to foreground messages
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("[NotificationService] Foreground message received: ${message.messageId}");
      unawaited(_showInAppNotification(message));
    });

    // 2. Listen to background/opened-app messages
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("[NotificationService] Notification clicked (app in background): ${message.messageId}");
      _handleNotificationClick(message);
    });

    // 3. Check if app was opened from terminated state via notification click
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("[NotificationService] Notification clicked (app was terminated): ${message.messageId}");
        _handleNotificationClick(message);
      }
    });

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(registerFcmToken());
    });
  }

  Future<void> _showInAppNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final chatId = _extractConversationId(data);
    if (chatId != null && chatId == _activeChatId?.call()) {
      await persistRemoteMessage(message);
      return;
    }

    final dedupeId = _extractMessageId(data) ?? message.messageId;
    if (dedupeId != null && !_rememberNotification(dedupeId)) return;

    final wasNew = await persistRemoteMessage(message);
    if (!wasNew && _extractMessageId(data) != null) return;

    final title = notification?.title ?? data['title'] ?? 'New Message';
    final body = notification?.body ?? data['body'] ?? '';
    final avatarUrl = data['avatarUrl'] ?? data['image'];

    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState != null) {
      InAppNotificationBanner.show(
        overlayState: overlayState,
        title: title,
        message: body,
        avatarUrl: avatarUrl,
        onTap: () => _handleNotificationClick(message),
      );
    } else {
      debugPrint("[NotificationService] Cannot show in-app notification banner: overlayState is null.");
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    final chatId = _extractConversationId(message.data);
    if (chatId == null) return;
    final handler = _openChat;
    if (handler == null) {
      _pendingNavigation = message;
      return;
    }
    handler(chatId);
  }

  bool _rememberNotification(String id) {
    if (_handledNotificationIds.contains(id)) return false;
    _handledNotificationIds.add(id);
    while (_handledNotificationIds.length > 200) {
      _handledNotificationIds.remove(_handledNotificationIds.first);
    }
    return true;
  }

  static String? _extractConversationId(Map<String, dynamic> data) {
    final nested = data['message'];
    final value = data['conversationId'] ??
        data['conversation_id'] ??
        data['chatId'] ??
        (nested is Map
            ? nested['conversationId'] ?? nested['conversation_id'] ?? nested['chatId']
            : null);
    final result = value?.toString();
    return result == null || result.isEmpty ? null : result;
  }

  static String? _extractMessageId(Map<String, dynamic> data) {
    final nested = data['message'];
    final value = data['messageId'] ??
        data['message_id'] ??
        data['id'] ??
        (nested is Map ? nested['messageId'] ?? nested['id'] : null);
    final result = value?.toString();
    return result == null || result.isEmpty ? null : result;
  }

  static Future<bool> persistRemoteMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final nested = data['message'];
    final payload = nested is Map
        ? <String, dynamic>{...data, ...Map<String, dynamic>.from(nested)}
        : data;
    payload['id'] ??= _extractMessageId(data);
    payload['conversationId'] ??= _extractConversationId(data);
    payload['text'] ??= message.notification?.body;
    payload['createdAt'] ??= DateTime.now().toIso8601String();

    final dto = MessageDto.fromJson(payload);
    if (dto.id.isEmpty || dto.conversationId.isEmpty || dto.senderId.isEmpty) {
      return true;
    }
    final dao = MessageDao();
    final existing = await dao.getMessageById(dto.id);
    await dao.insertOrUpdateMessages([dto.toSqliteMap()]);
    return existing == null;
  }

  static const String _registeredFcmTokenKey = 'registered_fcm_token';
  static const String _deviceIdKey = 'device_id';

  /// Registers the FCM token with the backend if it hasn't been registered yet or has changed.
  Future<void> registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint("[NotificationService] FCM token is null, skipping registration.");
        return;
      }

      final cachedToken = _prefs.getString(_registeredFcmTokenKey);
      if (cachedToken == token) {
        debugPrint("[NotificationService] FCM token is already registered; skipping API call.");
        return;
      }

      final deviceId = await _getOrCreateDeviceId();
      final platform = _getPlatformName();

      debugPrint("[NotificationService] Registering FCM token (platform: $platform, deviceId: $deviceId)");

      final response = await _apiService.post(
        ApiConstants.fcmTokens,
        data: {
          'token': token,
          'platform': platform,
          'deviceId': deviceId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _prefs.setString(_registeredFcmTokenKey, token);
        debugPrint("[NotificationService] FCM token registered successfully and cached locally.");
      } else {
        debugPrint("[NotificationService] Failed to register FCM token. Server returned status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[NotificationService] Error registering FCM token: $e");
    }
  }

  /// Deletes the FCM token from the backend and local storage.
  Future<void> deleteFcmToken() async {
    try {
      final cachedToken = _prefs.getString(_registeredFcmTokenKey);
      if (cachedToken != null && cachedToken.isNotEmpty) {
        debugPrint("[NotificationService] Deleting FCM token from backend: $cachedToken");
        try {
          await _apiService.delete(
            ApiConstants.fcmTokens,
            data: {
              'token': cachedToken,
            },
          );
          debugPrint("[NotificationService] FCM token deleted from backend successfully.");
        } catch (e) {
          debugPrint("[NotificationService] Error deleting FCM token from backend: $e. Proceeding with local cleanup.");
        }
      } else {
        debugPrint("[NotificationService] No cached FCM token found, skipping backend delete.");
      }

      // Delete Firebase Messaging token instance
      try {
        await FirebaseMessaging.instance.deleteToken();
        debugPrint("[NotificationService] FCM token deleted from Firebase Messaging instance.");
      } catch (e) {
        debugPrint("[NotificationService] Error deleting token from Firebase Messaging instance: $e");
      }

      // Clear local storage
      await _prefs.remove(_registeredFcmTokenKey);
      await _prefs.remove(_deviceIdKey);
      debugPrint("[NotificationService] Local FCM token and device ID cached state cleared.");
    } catch (e) {
      debugPrint("[NotificationService] General error in deleteFcmToken: $e");
    }
  }

  /// Helper to get or create a persistent unique device ID.
  Future<String> _getOrCreateDeviceId() async {
    final cachedId = _prefs.getString(_deviceIdKey);
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

    String? deviceId;
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = 'web_${webInfo.userAgent.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId;
      }
    } catch (e) {
      debugPrint("[NotificationService] Error reading device info: $e");
    }

    if (deviceId == null || deviceId.isEmpty) {
      // Simple pseudo-random UUID generator fallback
      final random = Random();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      values[6] = (values[6] & 0x0f) | 0x40; // set version 4
      values[8] = (values[8] & 0x3f) | 0x80; // set variant
      final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
      deviceId = '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
    }

    await _prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  /// Helper to get platform name.
  String _getPlatformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedAppSubscription?.cancel());
    unawaited(_tokenRefreshSubscription?.cancel());
  }
}
