import Foundation
import Combine

@MainActor
final class DireqtMessagesViewModel: ObservableObject {
    @Published private(set) var labels: [TeachLabel] = []
    @Published var selectedLabel: String = "inbox"
    @Published var searchText: String = ""
    @Published private(set) var messages: [TeachMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // Local starred tracking since the list endpoint doesn't return starred status
    private var starredIDs: Set<Int> = []

    var displayedMessages: [TeachMessage] {
        var list = messages
        // Apply local starred state
        for i in list.indices {
            if let mid = list[i].messageID {
                list[i].starred = starredIDs.contains(mid)
            }
        }
        if selectedLabel == "starred" {
            return list.filter { $0.starred }
        }
        return list
    }

    private let client: TeachMessagesClient
    private var loadedSessionID: String?
    private var searchTask: Task<Void, Never>?
    private var stateChangeObserver: NSObjectProtocol?

    init(client: TeachMessagesClient = TeachMessagesClient()) {
        self.client = client
        setupStateObserver()
    }
    
    deinit {
        if let observer = stateChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupStateObserver() {
        stateChangeObserver = NotificationCenter.default.addObserver(
            forName: .messageStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let change = notification.userInfo?["change"] as? MessageStateChange else { return }
            Task { @MainActor in
                self?.handleStateChange(change)
            }
        }
    }
    
    private func handleStateChange(_ change: MessageStateChange) {
        switch change {
        case .read(let messageID, let isRead):
            if let idx = messages.firstIndex(where: { $0.messageID == messageID }) {
                messages[idx].read = isRead
            }
            
        case .starred(let messageID, let isStarred):
            if isStarred {
                starredIDs.insert(messageID)
            } else {
                starredIDs.remove(messageID)
            }
            objectWillChange.send()
            
        case .trashed(let messageID):
            messages.removeAll { $0.messageID == messageID }
            starredIDs.remove(messageID)
            
        case .moved(let messageID, _):
            // Remove from current view since it moved to a different label
            messages.removeAll { $0.messageID == messageID }
        }
    }

    func loadIfNeeded(session: TeachSession?) async {
        guard let session else {
            reset()
            return
        }

        guard loadedSessionID != session.jsessionId else { return }
        await loadAll(session: session)
        loadedSessionID = session.jsessionId
    }

    func refresh(session: TeachSession?) async {
        guard let session else {
            reset()
            return
        }

        await loadAll(session: session)
        loadedSessionID = session.jsessionId
    }

    func switchLabel(_ label: String, session: TeachSession?) async {
        selectedLabel = label
        searchText = ""
        guard let session else { return }

        if label == "starred" {
            await loadMessages(session: session, serverLabel: "inbox")
        } else {
            await loadMessages(session: session, serverLabel: label)
        }
    }

    func searchDebounced(session: TeachSession?) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let session else { return }
            let serverLabel = selectedLabel == "starred" ? "inbox" : selectedLabel
            await loadMessages(session: session, serverLabel: serverLabel)
        }
    }

    // MARK: - Mutations

    func toggleRead(_ message: TeachMessage, session: TeachSession?) {
        guard let session, let msgID = message.messageID else { return }
        let newRead = !message.read

        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].read = newRead
        }

        Task {
            try? await client.markRead(session: session, ids: [msgID], read: newRead)
            if let updatedLabels = try? await client.fetchLabels(session: session) {
                labels = updatedLabels
            }
        }
    }

    func toggleStar(_ message: TeachMessage, session: TeachSession?) {
        guard let session, let msgID = message.messageID else { return }

        if starredIDs.contains(msgID) {
            starredIDs.remove(msgID)
        } else {
            starredIDs.insert(msgID)
        }
        // Trigger UI refresh
        objectWillChange.send()

        Task {
            try? await client.toggleStar(session: session, ids: [msgID], starred: starredIDs.contains(msgID))
        }
    }

    func trash(_ message: TeachMessage, session: TeachSession?) {
        guard let session, let msgID = message.messageID else { return }

        messages.removeAll { $0.id == message.id }
        starredIDs.remove(msgID)

        Task {
            try? await client.moveMessage(session: session, ids: [msgID], label: "trash")
            if let updatedLabels = try? await client.fetchLabels(session: session) {
                labels = updatedLabels
            }
        }
    }

    func restore(_ message: TeachMessage, session: TeachSession?) {
        guard let session, let msgID = message.messageID else { return }

        messages.removeAll { $0.id == message.id }

        Task {
            try? await client.moveMessage(session: session, ids: [msgID], label: "inbox")
            if let updatedLabels = try? await client.fetchLabels(session: session) {
                labels = updatedLabels
            }
        }
    }

    // MARK: - Private

    private func loadAll(session: TeachSession) async {
        isLoading = true
        errorMessage = nil

        let serverLabel = selectedLabel == "starred" ? "inbox" : selectedLabel

        async let labelsResult = client.fetchLabels(session: session)
        async let messagesResult = client.fetchMessages(session: session, label: serverLabel, searchValue: searchText)

        do {
            labels = try await labelsResult
            messages = try await messagesResult
            syncStarredFromMessages()
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }

        isLoading = false
    }

    private func loadMessages(session: TeachSession, serverLabel: String) async {
        isLoading = true
        errorMessage = nil

        do {
            messages = try await client.fetchMessages(session: session, label: serverLabel, searchValue: searchText)
            syncStarredFromMessages()
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }

        isLoading = false
    }

    /// If the API does return starred in the future, pick it up
    private func syncStarredFromMessages() {
        for msg in messages {
            if let mid = msg.messageID, msg.starred {
                starredIDs.insert(mid)
            }
        }
        // Seed last-seen IDs so background poll doesn't re-notify for these
        let currentIDs = messages.map { $0.id }
        UserDefaults.standard.set(currentIDs, forKey: "lastSeenMessageIDs")
    }

    private func reset() {
        messages = []
        labels = []
        starredIDs = []
        isLoading = false
        errorMessage = nil
        loadedSessionID = nil
    }
}
