import 'package:flutter/services.dart';

class NativeNotifier {
  static const MethodChannel _channel = MethodChannel('com.rosde/pilach/notification');

  /// Shows a native notification.
  /// [title] and [body] are required. [avatarUrl] can be a network image URL.
  /// [id] is optional – if omitted a unique timestamp‑based id is used.
  static Future<void> show({
    required String title,
    required String body,
    String? avatarUrl,
    int? id,
  }) async {
    await _channel.invokeMethod('showNotification', {
      'title': title,
      'body': body,
      'avatarUrl': avatarUrl,
      'id': id ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Cancels a previously shown native notification.
  static Future<void> cancel(int id) async {
    await _channel.invokeMethod('cancelNotification', {'id': id});
  }
}
