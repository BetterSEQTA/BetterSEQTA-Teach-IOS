import Foundation

@MainActor
final class MessageDetailViewModel: ObservableObject {
    @Published private(set) var detail: TeachMessageDetail?
    @Published private(set) var labels: [TeachLabel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var didTrash = false

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

    // MARK: - Mutations

    func toggleStar(session: TeachSession?) {
        guard let session, let detail else { return }
        let newStarred = !detail.starred

        self.detail = TeachMessageDetail(
            id: detail.id, sender: detail.sender, subject: detail.subject,
            body: detail.body, date: detail.date, read: detail.read,
            starred: newStarred, participants: detail.participants, files: detail.files
        )

        Task {
            try? await client.toggleStar(session: session, ids: [detail.id], starred: newStarred)
        }
    }

    func trash(session: TeachSession?) {
        guard let session, let detail else { return }
        Task {
            try? await client.moveMessage(session: session, ids: [detail.id], label: "trash")
            didTrash = true
        }
    }

    func moveToLabel(_ label: String, session: TeachSession?) {
        guard let session, let detail else { return }
        Task {
            try? await client.moveMessage(session: session, ids: [detail.id], label: label)
        }
    }

    func toggleRead(session: TeachSession?) {
        guard let session, let detail else { return }
        let newRead = !detail.read

        self.detail = TeachMessageDetail(
            id: detail.id, sender: detail.sender, subject: detail.subject,
            body: detail.body, date: detail.date, read: newRead,
            starred: detail.starred, participants: detail.participants, files: detail.files
        )

        Task {
            try? await client.markRead(session: session, ids: [detail.id], read: newRead)
        }
    }

    // MARK: - Private

    private func load(session: TeachSession, messageID: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            async let detailResult = client.fetchMessageDetail(session: session, id: messageID)
            async let labelsResult = client.fetchLabels(session: session)
            detail = try await detailResult
            labels = (try? await labelsResult) ?? []
        } catch {
            errorMessage = error.localizedDescription
            detail = nil
        }

        isLoading = false
    }

    private func reset() {
        detail = nil
        labels = []
        isLoading = false
        errorMessage = nil
        loadedKey = nil
        didTrash = false
    }
}
