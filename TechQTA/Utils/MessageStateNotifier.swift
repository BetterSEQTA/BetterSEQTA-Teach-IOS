import Foundation

enum MessageStateChange {
    case read(messageID: Int, isRead: Bool)
    case starred(messageID: Int, isStarred: Bool)
    case trashed(messageID: Int)
    case moved(messageID: Int, toLabel: String)
}

extension Notification.Name {
    static let messageStateChanged = Notification.Name("messageStateChanged")
}

@MainActor
final class MessageStateNotifier {
    static let shared = MessageStateNotifier()
    
    private init() {}
    
    func post(_ change: MessageStateChange) {
        NotificationCenter.default.post(
            name: .messageStateChanged,
            object: nil,
            userInfo: ["change": change]
        )
    }
}
