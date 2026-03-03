import Foundation

@MainActor
final class MessageDetailViewModel: ObservableObject {
    @Published private(set) var detail: TeachMessageDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: TeachMessagesClient
    private var loadedKey: String?

    init(client: TeachMessagesClient = TeachMessagesClient()) {
        self.client = client
    }

    func loadIfNeeded(session: TeachSession?, messageID: Int) async {
        guard let session else {
            reset()
            errorMessage = "You're not logged in."
            return
        }

        let key = "\(session.jsessionId)-\(messageID)"
        guard loadedKey != key else { return }

        await load(session: session, messageID: messageID)
        loadedKey = key
    }

    private func load(session: TeachSession, messageID: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            detail = try await client.fetchMessageDetail(session: session, id: messageID)
        } catch {
            errorMessage = error.localizedDescription
            detail = nil
        }

        isLoading = false
    }

    private func reset() {
        detail = nil
        isLoading = false
        errorMessage = nil
        loadedKey = nil
    }
}
