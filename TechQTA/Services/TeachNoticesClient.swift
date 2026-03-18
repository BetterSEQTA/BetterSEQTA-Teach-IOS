//
//  TeachNoticesClient.swift
//  TechQTA
//

import Foundation

struct TeachNotice: Identifiable {
    let id: Int
    let labelTitle: String?
    let staff: String?
    let title: String
    let colour: String?
    let contents: String?
    let from: String?
    let until: String?
    let createdDate: String?
}

struct TeachNoticeLabel: Identifiable {
    let id: Int
    let title: String
    let colour: String?
}

struct TeachNoticesClient {
    func fetchNotices(session: TeachSession, date: String) async throws -> (notices: [TeachNotice], labels: [TeachNoticeLabel]) {
        let body: [String: Any] = ["date": date]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/notices/load", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any] ?? [:]

        let noticesRaw = payload["notices"] as? [[String: Any]] ?? []
        let notices = noticesRaw.compactMap { parseNotice($0) }

        let labelsRaw = payload["labels"] as? [[String: Any]] ?? []
        let labels = labelsRaw.compactMap { parseLabel($0) }

        return (notices, labels)
    }

    private func parseNotice(_ raw: [String: Any]) -> TeachNotice? {
        guard let id = raw["id"] as? Int else { return nil }
        let labelTitle = raw["label_title"] as? String
        let staff = raw["staff"] as? String
        let title = raw["title"] as? String ?? "Untitled"
        let colour = raw["colour"] as? String
        let contents = raw["contents"] as? String
        let from = raw["from"] as? String
        let until = raw["until"] as? String
        let createdDate = raw["created_date"] as? String
        return TeachNotice(
            id: id,
            labelTitle: labelTitle,
            staff: staff,
            title: title,
            colour: colour,
            contents: contents,
            from: from,
            until: until,
            createdDate: createdDate
        )
    }

    private func parseLabel(_ raw: [String: Any]) -> TeachNoticeLabel? {
        guard let id = raw["id"] as? Int else { return nil }
        let title = raw["title"] as? String ?? ""
        let colour = raw["colour"] as? String
        return TeachNoticeLabel(id: id, title: title, colour: colour)
    }
}
