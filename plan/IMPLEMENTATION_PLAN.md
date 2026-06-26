# Implementation Plan – Native In‑App Notification System

## 1️⃣ Goal
Create a high‑performance in‑app notification system for the **Pilach** Flutter app that uses the existing `InAppNotificationBanner` for UI while delegating time‑critical delivery to native Android / iOS code via a MethodChannel.

---

## 2️⃣ High‑Level Architecture
```
Flutter UI (Dart) ──► MethodChannel ──► Android (Kotlin) / iOS (Swift)
      │                         │                │
      │   In‑App overlay (banner)   │   Native Notification APIs
      │                         │                │
      └─► Optional fallback for non‑critical alerts
```

- **Dart**: keeps the beautiful overlay already implemented in `in_app_notification_banner.dart`.
- **Native**: responsible for high‑priority, background‑aware notifications (quick delivery, sound, vibration, badge, etc.).
- **Bridge**: thin wrapper (`NativeNotifier`) exposing `show` / `cancel` methods.

---

## 3️⃣ Step‑by‑Step Tasks
| # | Description | Owner | Files / Artifacts | Estimated Time |
|---|-------------|-------|-------------------|----------------|
| 1 | Create **plan** folder & add this markdown (done). | — | `plan/IMPLEMENTATION_PLAN.md` | 5 min |
| 2 | Add Dart wrapper (`native_notifier.dart`). | You | `lib/services/native_notifier.dart` | 15 min |
| 3 | Android: add Kotlin plugin class (`NotificationPlugin.kt`). | You | `android/src/main/kotlin/com/rosde/pilach/notification/NotificationPlugin.kt` | 30 min |
| 4 | iOS: add Swift plugin class (`NotificationPlugin.swift`). | You | `ios/Classes/NotificationPlugin.swift` | 30 min |
| 5 | Register plugin in `MainActivity.kt` / `AppDelegate.swift`. | You | `android/app/src/main/kotlin/.../MainActivity.kt`<br>`ios/Runner/AppDelegate.swift` | 10 min |
| 6 | Add a small notification icon (`ic_notification.xml` or PNG). | You | `android/app/src/main/res/drawable/ic_notification.xml` | 5 min |
| 7 | Update `pubspec.yaml` (optional if you turn this into a standalone plugin). | You | `pubspec.yaml` | 5 min |
| 8 | Refactor `InAppNotificationBanner.show` to call the wrapper when `forceNative == true`. | You | `lib/components/InAppNotificationBanner/in_app_notification_banner.dart` | 15 min |
| 9 | Write a utility `showBanner` method that picks the correct path (Dart overlay vs native). | You | `lib/utilities/notification_helper.dart` | 10 min |
|10| Write unit tests for the wrapper (mock MethodChannel). | You | `test/native_notifier_test.dart` | 20 min |
|11| Manual QA: test on Android & iOS (foreground, background, killed). | You | – | 30 min |
|12| Performance profiling (profile mode, Android Studio Profiler). | You | – | 15 min |

---

## 4️⃣ Detailed Code Sketches
### 4.1 Dart Wrapper (`native_notifier.dart`)
```dart
import 'package:flutter/services.dart';

class NativeNotifier {
  static const _channel = MethodChannel('com.rosde/pilach/notification');

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

  static Future<void> cancel(int id) async {
    await _channel.invokeMethod('cancelNotification', {'id': id});
  }
}
```

### 4.2 Android (`NotificationPlugin.kt`)
*(see full snippet in the previous answer – create channel, `showNotification`, `cancelNotification`).*

### 4.3 iOS (`NotificationPlugin.swift`)
*(see full snippet in the previous answer – request permission, build `UNMutableNotificationContent`, attach avatar, fire `UNTimeIntervalNotificationTrigger`).*

### 4.4 Refactor Banner Call
```dart
static void show({
  required OverlayState overlayState,
  required String title,
  required String message,
  String? avatarUrl,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
  bool forceNative = false,
}) async {
  if (forceNative) {
    await NativeNotifier.show(
      title: title,
      body: message,
      avatarUrl: avatarUrl,
    );
    return;
  }
  // existing overlay logic …
}
```

---

## 5️⃣ Testing & Validation
1. **Unit tests** – mock `MethodChannel` and assert that `invokeMethod` receives correct arguments.
2. **Integration test** – run on a real device:
   - Foreground: banner appears instantly.
   - Background: native notification pops up (check sound/vibration).
   - App killed: notification still arrives (iOS may require APNs – test with a local trigger only).
3. **Performance** – use `flutter run --profile` and the Android Studio Profiler to confirm CPU usage stays < 2 % during a burst of 20 notifications.

---

## 6️⃣ Roll‑out Checklist
- [ ] All files added and compiled without errors.
- [ ] Android `AndroidManifest.xml` contains permission `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` for API 33+.
- [ ] iOS `Info.plist` includes `UIBackgroundModes` with `remote-notification` if you later integrate push.
- [ ] Icons & assets are correctly placed.
- [ ] Documentation added to `README.md` (brief usage example).

---

## 7️⃣ Next Steps for You
- Clone the repo, create the files listed above, paste the snippets.
- Run `flutter pub get` and rebuild the app on Android & iOS.
- Verify the UI overlay still works and the native notifications fire when `forceNative: true`.
- Adjust any project‑specific naming (package IDs, icon names) as needed.

Feel free to ask for any missing files or further details on a specific step!
