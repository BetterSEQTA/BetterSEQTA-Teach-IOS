import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func setUp() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func postNewMessageNotifications(_ messages: [TeachMessage]) async {
        for message in messages.prefix(5) {
            let content = UNMutableNotificationContent()
            content.title = message.sender ?? "New Message"
            content.body = message.subject ?? "You have a new message"
            content.sound = .default

            if let messageID = message.messageID {
                content.userInfo = ["messageID": messageID]
            }

            let request = UNNotificationRequest(
                identifier: "message-\(message.id)",
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let messageID = userInfo["messageID"] as? Int {
            DispatchQueue.main.async {
                DeepLinkNavigator.shared.navigateToMessage(messageID)
            }
        }
        completionHandler()
    }
}
