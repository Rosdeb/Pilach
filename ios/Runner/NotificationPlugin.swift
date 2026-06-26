import Flutter
import UIKit
import UserNotifications

public class NotificationPlugin: NSObject, FlutterPlugin {
    private let channelId = "pilach_inapp_channel"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.rosde/pilach/notification",
                                          binaryMessenger: registrar.messenger())
        let instance = NotificationPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.requestPermission()
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            // No additional handling needed for now
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showNotification":
            guard let args = call.arguments as? [String: Any],
                  let title = args["title"] as? String,
                  let body = args["body"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing title/body", details: nil))
                return
            }
            let id = args["id"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = channelId

            if let avatar = args["avatarUrl"] as? String, let url = URL(string: avatar) {
                if let data = try? Data(contentsOf: url), let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("avatar.jpg", isDirectory: false) as URL? {
                    try? data.write(to: tmp)
                    if let attachment = try? UNNotificationAttachment(identifier: "avatar", url: tmp, options: nil) {
                        content.attachments = [attachment]
                    }
                }
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: "\(id)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    result(FlutterError(code: "IOS_ERR", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        case "cancelNotification":
            if let args = call.arguments as? [String: Any], let id = args["id"] as? Int {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["\(id)"])
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(id)"])
                result(nil)
            } else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing id", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
