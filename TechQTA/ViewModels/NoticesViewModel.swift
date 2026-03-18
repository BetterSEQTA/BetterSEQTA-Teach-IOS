//
//  NoticesViewModel.swift
//  TechQTA
//

import Foundation

@MainActor
final class NoticesViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published private(set) var notices: [TeachNotice] = []
    @Published private(set) var labels: [TeachNoticeLabel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: TeachNoticesClient

    init(client: TeachNoticesClient = TeachNoticesClient()) {
        self.client = client
    }

    func load(session: TeachSession?) async {
        guard let session else {
            reset()
            return
        }

        isLoading = true
        errorMessage = nil
        notices = []
        labels = []

        let dateString = AppDateFormatters.isoYMD.string(from: selectedDate)

        do {
            let result = try await client.fetchNotices(session: session, date: dateString)
            notices = result.notices
            labels = result.labels
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func reset() {
        notices = []
        labels = []
        errorMessage = nil
        isLoading = false
    }
}
