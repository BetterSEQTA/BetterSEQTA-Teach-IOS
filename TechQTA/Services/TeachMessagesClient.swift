//
//  TeachMessagesClient.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

struct TeachMessage: Identifiable {
    let id: String
    let messageID: Int?
    let sender: String?
    let subject: String?
    let body: String?
    let date: Date?
    let read: Bool
}

struct TeachMessagesClient {
    func fetchMessages(session: TeachSession, limit: Int = 5) async throws -> [TeachMessage] {
        let body: [String: Any] = [
            "searchValue": "",
            "sortBy": "date",
            "sortOrder": "desc",
            "action": "list",
            "label": "inbox",
            "offset": 0,
            "limit": limit,
            "datetimeUntil": NSNull()
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/coneqtmessage/load", body: body)
        guard (200...299).contains(response.statusCode) else {
            return []
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any]
        let messages = payload?["messages"] as? [[String: Any]] ?? []
        return messages.compactMap { parseMessage($0) }
    }

    private func parseMessage(_ raw: [String: Any]) -> TeachMessage? {
        let id = (raw["id"] as? Int).map { "\($0)" }
            ?? (raw["messageID"] as? Int).map { "\($0)" }
            ?? UUID().uuidString
        let messageID = raw["messageID"] as? Int ?? raw["id"] as? Int
        let sender = raw["sender"] as? String
        let subject = raw["subject"] as? String
        let body = raw["body"] as? String ?? raw["content"] as? String
        let read = (raw["read"] as? Int) == 1 || (raw["read"] as? Bool) == true
        var date: Date?
        if let dateStr = raw["date"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: dateStr)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: dateStr)
            }
        }
        return TeachMessage(id: id, messageID: messageID, sender: sender, subject: subject, body: body, date: date, read: read)
    }
}
