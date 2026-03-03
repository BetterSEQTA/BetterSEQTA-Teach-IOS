import Foundation
import BackgroundTasks
import UserNotifications

final class BackgroundPollManager {
    static let shared = BackgroundPollManager()
    static let taskIdentifier = "com.betterseqta.teach.messagecheck"

    private let messagesClient = TeachMessagesClient()
    private let lastSeenKey = "lastSeenMessageIDs"
    private var foregroundTimer: Timer?

    private init() {}

    // MARK: - Background task

    func registerTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Schedule failed
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let checkTask = Task {
            await checkForNewMessages()
        }

        task.expirationHandler = {
            checkTask.cancel()
        }

        Task {
            _ = await checkTask.result
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Foreground polling

    func startForegroundPolling() {
        stopForegroundPolling()
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.checkForNewMessages() }
        }
    }

    func stopForegroundPolling() {
        foregroundTimer?.invalidate()
        foregroundTimer = nil
    }

    // MARK: - Core check (used by both background + foreground)

    func checkForNewMessages() async {
        guard let baseUrlString = UserDefaults.standard.string(forKey: "baseUrl"),
              let baseUrl = URL(string: baseUrlString),
              let jsessionId = try? KeychainHelper.load(key: "jsessionId"),
              !jsessionId.isEmpty else {
            return
        }

        let session = TeachSession(baseUrl: baseUrl, jsessionId: jsessionId, lastHeartbeatAt: nil)

        do {
            let messages = try await messagesClient.fetchMessages(
                session: session,
                label: "inbox",
                limit: 20
            )

            let unreadMessages = messages.filter { !$0.read }

            let lastSeenIDs = Set(
                UserDefaults.standard.stringArray(forKey: lastSeenKey) ?? []
            )
            let newMessages = unreadMessages.filter { !lastSeenIDs.contains($0.id) }

            if !newMessages.isEmpty {
                await NotificationManager.shared.postNewMessageNotifications(newMessages)
            }

            let currentIDs = messages.map { $0.id }
            UserDefaults.standard.set(currentIDs, forKey: lastSeenKey)
        } catch {
            // Silent failure
        }
    }
}
