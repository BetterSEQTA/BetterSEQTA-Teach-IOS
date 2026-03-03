import Foundation

@MainActor
final class HomeDashboardViewModel: ObservableObject {
    @Published private(set) var todayLessons: [TeachLesson] = []
    @Published private(set) var messages: [TeachMessage] = []
    @Published private(set) var lessonsLoading = false
    @Published private(set) var messagesLoading = false
    @Published private(set) var lessonsError: String?
    @Published private(set) var messagesError: String?

    private let timetableClient: TeachTimetableClient
    private let messagesClient: TeachMessagesClient
    private var loadedSessionID: String?

    init(
        timetableClient: TeachTimetableClient = TeachTimetableClient(),
        messagesClient: TeachMessagesClient = TeachMessagesClient()
    ) {
        self.timetableClient = timetableClient
        self.messagesClient = messagesClient
    }

    func loadIfNeeded(sessionManager: TeachSessionManager) async {
        guard let session = sessionManager.session else {
            reset()
            return
        }

        guard loadedSessionID != session.jsessionId else { return }
        await load(sessionManager: sessionManager)
        loadedSessionID = session.jsessionId
    }

    func refresh(sessionManager: TeachSessionManager) async {
        guard sessionManager.session != nil else {
            reset()
            return
        }

        await load(sessionManager: sessionManager)
        loadedSessionID = sessionManager.session?.jsessionId
    }

    private func load(sessionManager: TeachSessionManager) async {
        guard let session = sessionManager.session else { return }

        let today = AppDateFormatters.isoYMD.string(from: Date())

        lessonsLoading = true
        lessonsError = nil

        if sessionManager.staffId == nil {
            await sessionManager.fetchStaffIdIfNeeded()
        }

        if let staffId = sessionManager.staffId {
            do {
                todayLessons = try await timetableClient.fetchLessons(
                    session: session,
                    staffId: staffId,
                    dateFrom: today,
                    dateTo: today
                )
            } catch {
                lessonsError = error.localizedDescription
                todayLessons = []
            }
        } else {
            lessonsError = "Could not load staff ID"
            todayLessons = []
        }

        lessonsLoading = false

        messagesLoading = true
        messagesError = nil

        do {
            messages = try await messagesClient.fetchMessages(session: session, limit: 5)
        } catch {
            messagesError = error.localizedDescription
            messages = []
        }

        messagesLoading = false
    }

    private func reset() {
        todayLessons = []
        messages = []
        lessonsLoading = false
        messagesLoading = false
        lessonsError = nil
        messagesError = nil
        loadedSessionID = nil
    }
}
