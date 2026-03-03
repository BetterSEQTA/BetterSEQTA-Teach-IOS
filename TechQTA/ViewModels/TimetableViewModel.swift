import Foundation

@MainActor
final class TimetableViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published private(set) var lessons: [TeachLesson] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: TeachTimetableClient

    init(client: TeachTimetableClient = TeachTimetableClient()) {
        self.client = client
    }

    func load(sessionManager: TeachSessionManager) async {
        guard let session = sessionManager.session else {
            reset()
            return
        }

        isLoading = true
        errorMessage = nil
        lessons = []

        if sessionManager.staffId == nil {
            await sessionManager.fetchStaffIdIfNeeded()
        }

        guard let staffId = sessionManager.staffId else {
            errorMessage = "Could not load staff ID."
            isLoading = false
            return
        }

        let dateString = AppDateFormatters.isoYMD.string(from: selectedDate)

        do {
            lessons = try await client.fetchLessons(
                session: session,
                staffId: staffId,
                dateFrom: dateString,
                dateTo: dateString
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func reset() {
        lessons = []
        errorMessage = nil
        isLoading = false
    }
}
