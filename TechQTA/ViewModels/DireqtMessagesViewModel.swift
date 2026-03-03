import Foundation

@MainActor
final class DireqtMessagesViewModel: ObservableObject {
    @Published private(set) var messages: [TeachMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: TeachMessagesClient
    private var loadedSessionID: String?

    init(client: TeachMessagesClient = TeachMessagesClient()) {
        self.client = client
    }

    func loadIfNeeded(session: TeachSession?) async {
        guard let session else {
            reset()
            return
        }

        guard loadedSessionID != session.jsessionId else { return }
        await load(session: session)
        loadedSessionID = session.jsessionId
    }

    func refresh(session: TeachSession?) async {
        guard let session else {
            reset()
            return
        }

        await load(session: session)
        loadedSessionID = session.jsessionId
    }

    private func load(session: TeachSession) async {
        isLoading = true
        errorMessage = nil

        do {
            messages = try await client.fetchMessages(session: session, limit: 50)
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }

        isLoading = false
    }

    private func reset() {
        messages = []
        isLoading = false
        errorMessage = nil
        loadedSessionID = nil
    }
}
