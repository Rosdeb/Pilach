import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
import '../database/daos/chat_dao.dart';
import '../models/message_dto.dart';
import 'socket_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.persistRemoteMessage(message);
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final socketService = ref.watch(socketServiceProvider);
  final service = NotificationService(apiService, prefs, socketService);
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
  StreamSubscription<Map<String, dynamic>>? _socketMessageSubscription;
  String? Function()? _activeChatId;
  bool Function()? _isMessageSurfaceVisible;
  void Function(String chatId)? _openChat;
  RemoteMessage? _pendingNavigation;

  NotificationService(
    this._apiService,
    this._prefs,
    SocketService socketService,
  ) {
    _requestPermissions();
    _setupFcmListeners();
    _socketMessageSubscription = socketService.onNewMessage.listen(
      (payload) => unawaited(_showSocketNotification(payload)),
    );
  }

  void configureNavigation({
    required String? Function() activeChatId,
    required bool Function() isMessageSurfaceVisible,
    required void Function(String chatId) openChat,
  }) {
    _activeChatId = activeChatId;
    _isMessageSurfaceVisible = isMessageSurfaceVisible;
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
      debugPrint(
        "[NotificationService] Notification permission status: ${settings.authorizationStatus}",
      );
    } catch (e) {
      debugPrint(
        "[NotificationService] Error requesting notification permission: $e",
      );
    }
  }

  void _setupFcmListeners() {
    // 1. Listen to foreground messages
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      debugPrint(
        "[NotificationService] Foreground message received: ${message.messageId}",
      );
      unawaited(_showInAppNotification(message));
    });

    // 2. Listen to background/opened-app messages
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      debugPrint(
        "[NotificationService] Notification clicked (app in background): ${message.messageId}",
      );
      _handleNotificationClick(message);
    });

    // 3. Check if app was opened from terminated state via notification click
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint(
          "[NotificationService] Notification clicked (app was terminated): ${message.messageId}",
        );
        _handleNotificationClick(message);
      }
    });

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((_) {
          unawaited(registerFcmToken());
        });
  }

  Future<void> _showInAppNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final chatId = _extractConversationId(data);
    if (_isMessageSurfaceVisible?.call() == true) {
      await persistRemoteMessage(message);
      return;
    }
    if (chatId != null && chatId == _activeChatId?.call()) {
      await persistRemoteMessage(message);
      return;
    }

    final dedupeId = _extractMessageId(data) ?? message.messageId;
    if (dedupeId != null && !_rememberNotification(dedupeId)) return;

    final wasNew = await persistRemoteMessage(message);
    if (!wasNew && _extractMessageId(data) != null) return;

    final nested = _nestedMessage(data);
    final nestedSender = nested?['sender'];
    final senderMap = nestedSender is Map
        ? Map<String, dynamic>.from(nestedSender)
        : null;
    final localChat = chatId == null
        ? null
        : await ChatDao().getChatById(chatId);
    if (localChat?['is_muted'] == 1 || localChat?['is_muted'] == true) return;
    final title =
        _firstNonEmpty([
          notification?.title,
          data['title'],
          senderMap?['name'],
          senderMap?['displayName'],
          nested?['senderName'],
          localChat?['title'],
        ]) ??
        'New message';
    final notificationBody = _firstNonEmpty([
      notification?.body,
      data['body'],
      nested?['text'],
    ]);
    final body =
        notificationBody ??
        (nested == null ? 'Sent you a message' : _socketPreview(nested));
    final avatarUrl = _firstNonEmpty([
      data['avatarUrl'],
      data['image'],
      senderMap?['avatarUrl'],
      senderMap?['profileImage'],
      nested?['senderAvatar'],
      localChat?['avatar_url'],
    ]);
    final createdAt = nested?['createdAt'] ?? data['createdAt'];

    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState != null) {
      InAppNotificationBanner.show(
        overlayState: overlayState,
        title: title,
        message: body,
        timeLabel: _formatBannerTime(createdAt, fallback: message.sentTime),
        avatarUrl: avatarUrl,
        onTap: () => _handleNotificationClick(message),
      );
    } else {
      debugPrint(
        "[NotificationService] Cannot show in-app notification banner: overlayState is null.",
      );
    }
  }

  /// Socket events are the fastest and most reliable signal while the app is
  /// in the foreground. FCM remains the background/terminated delivery path.
  /// Both paths share [_handledNotificationIds], so the same message cannot
  /// flash twice when the backend emits a socket event and sends a push.
  Future<void> _showSocketNotification(Map<String, dynamic> event) async {
    final nested = event['message'];
    final message = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(event);

    final chatId = _extractConversationId({...event, 'message': message});
    if (chatId == null ||
        _isMessageSurfaceVisible?.call() == true ||
        chatId == _activeChatId?.call()) {
      return;
    }

    final sender = message['sender'];
    final senderMap = sender is Map ? Map<String, dynamic>.from(sender) : null;
    final senderId =
        (message['senderId'] ??
                senderMap?['id'] ??
                senderMap?['_id'] ??
                event['senderId'])
            ?.toString();
    final currentUserId = _prefs.getString('user_id');
    if (senderId != null &&
        currentUserId != null &&
        senderId == currentUserId) {
      return;
    }

    final messageId = _extractMessageId({...event, 'message': message});
    if (messageId != null && !_rememberNotification(messageId)) return;

    final localChat = await ChatDao().getChatById(chatId);
    if (localChat?['is_muted'] == 1 || localChat?['is_muted'] == true) return;

    final title =
        _firstNonEmpty([
          senderMap?['name'],
          senderMap?['displayName'],
          message['senderName'],
          event['senderName'],
          event['title'],
          localChat?['title'],
        ]) ??
        'New message';
    final body = _socketPreview(message);
    final avatarUrl = _firstNonEmpty([
      senderMap?['avatarUrl'],
      senderMap?['profileImage'],
      message['senderAvatar'],
      event['avatarUrl'],
      event['image'],
      localChat?['avatar_url'],
    ]);

    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;
    await InAppNotificationBanner.show(
      overlayState: overlayState,
      title: title,
      message: body,
      timeLabel: _formatBannerTime(message['createdAt']),
      avatarUrl: avatarUrl,
      onTap: () {
        final handler = _openChat;
        if (handler != null) handler(chatId);
      },
    );
  }

  static String _socketPreview(Map<String, dynamic> message) {
    final text = message['text']?.toString().trim();
    if (text != null && text.isNotEmpty) return text;

    final attachments = message['attachments'];
    dynamic attachmentType;
    if (attachments is List && attachments.isNotEmpty) {
      final first = attachments.first;
      if (first is Map) attachmentType = first['type'];
    }
    final type = (attachmentType ?? message['type'])?.toString().toUpperCase();
    switch (type) {
      case 'IMAGE':
        return '📷 Photo';
      case 'VIDEO':
        return '🎥 Video';
      case 'AUDIO':
        return '🎧 Audio';
      case 'FILE':
      case 'DOCUMENT':
        return '📄 Document';
      default:
        return 'Sent you a message';
    }
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static String _formatBannerTime(dynamic value, {DateTime? fallback}) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    final time = (parsed ?? fallback ?? DateTime.now()).toLocal();
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
    final nested = _nestedMessage(data);
    final value =
        data['conversationId'] ??
        data['conversation_id'] ??
        data['chatId'] ??
        nested?['conversationId'] ??
        nested?['conversation_id'] ??
        nested?['chatId'];
    final result = value?.toString();
    return result == null || result.isEmpty ? null : result;
  }

  static String? _extractMessageId(Map<String, dynamic> data) {
    final nested = _nestedMessage(data);
    final value =
        data['messageId'] ??
        data['message_id'] ??
        data['id'] ??
        nested?['messageId'] ??
        nested?['id'];
    final result = value?.toString();
    return result == null || result.isEmpty ? null : result;
  }

  static Future<bool> persistRemoteMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final nested = _nestedMessage(data);
    final payload = nested != null
        ? <String, dynamic>{...data, ...nested}
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

  static Map<String, dynamic>? _nestedMessage(Map<String, dynamic> data) {
    final value = data['message'];
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Some push providers deliver only top-level data fields.
      }
    }
    return null;
  }

  static const String _registeredFcmTokenKey = 'registered_fcm_token';
  static const String _deviceIdKey = 'device_id';

  /// Registers the FCM token with the backend if it hasn't been registered yet or has changed.
  Future<void> registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint(
          "[NotificationService] FCM token is null, skipping registration.",
        );
        return;
      }

      final cachedToken = _prefs.getString(_registeredFcmTokenKey);
      if (cachedToken == token) {
        debugPrint(
          "[NotificationService] FCM token is already registered; skipping API call.",
        );
        return;
      }

      final deviceId = await _getOrCreateDeviceId();
      final platform = _getPlatformName();

      debugPrint(
        "[NotificationService] Registering FCM token (platform: $platform, deviceId: $deviceId)",
      );

      final response = await _apiService.post(
        ApiConstants.fcmTokens,
        data: {'token': token, 'platform': platform, 'deviceId': deviceId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _prefs.setString(_registeredFcmTokenKey, token);
        debugPrint(
          "[NotificationService] FCM token registered successfully and cached locally.",
        );
      } else {
        debugPrint(
          "[NotificationService] Failed to register FCM token. Server returned status code: ${response.statusCode}",
        );
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
        debugPrint(
          "[NotificationService] Deleting FCM token from backend: $cachedToken",
        );
        try {
          await _apiService.delete(
            ApiConstants.fcmTokens,
            data: {'token': cachedToken},
          );
          debugPrint(
            "[NotificationService] FCM token deleted from backend successfully.",
          );
        } catch (e) {
          debugPrint(
            "[NotificationService] Error deleting FCM token from backend: $e. Proceeding with local cleanup.",
          );
        }
      } else {
        debugPrint(
          "[NotificationService] No cached FCM token found, skipping backend delete.",
        );
      }

      // Delete Firebase Messaging token instance
      try {
        await FirebaseMessaging.instance.deleteToken();
        debugPrint(
          "[NotificationService] FCM token deleted from Firebase Messaging instance.",
        );
      } catch (e) {
        debugPrint(
          "[NotificationService] Error deleting token from Firebase Messaging instance: $e",
        );
      }

      // Clear local storage
      await _prefs.remove(_registeredFcmTokenKey);
      await _prefs.remove(_deviceIdKey);
      debugPrint(
        "[NotificationService] Local FCM token and device ID cached state cleared.",
      );
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
        deviceId =
            'web_${webInfo.userAgent.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
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
      final hex = values
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .toList();
      deviceId =
          '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
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
    unawaited(_socketMessageSubscription?.cancel());
  }
}
