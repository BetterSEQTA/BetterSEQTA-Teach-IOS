import Foundation

@MainActor
final class DeepLinkNavigator: ObservableObject {
    static let shared = DeepLinkNavigator()

    @Published var pendingMessageID: Int?

    private init() {}

    func navigateToMessage(_ messageID: Int) {
        pendingMessageID = messageID
    }
}
