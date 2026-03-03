//
//  TeachMessagesClient.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

struct TeachLabel: Identifiable {
    var id: String { label }
    let label: String
    let unread: Int
}

struct TeachMessage: Identifiable {
    let id: String
    let messageID: Int?
    let sender: String?
    let subject: String?
    let body: String?
    let date: Date?
    var read: Bool
    var starred: Bool
    let attachments: Bool
    let participants: [TeachMessageListParticipant]
}

struct TeachMessageListParticipant {
    let name: String
    let type: String
}

struct TeachMessageParticipant: Identifiable {
    let id: Int
    let name: String
    let type: String
    let read: Bool
}

struct TeachMessageFile: Identifiable {
    let id: Int
    let filename: String
    let mimetype: String
    let size: String
    let uuid: String
}

struct TeachMessageDetail {
    let id: Int
    let sender: String?
    let subject: String?
    let body: String?
    let date: Date?
    let read: Bool
    let starred: Bool
    let participants: [TeachMessageParticipant]
    let files: [TeachMessageFile]
}

struct TeachMessagesClient {
    func fetchLabels(session: TeachSession) async throws -> [TeachLabel] {
        let body: [String: Any] = ["action": "labels"]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/coneqtmessage/load", body: body)
        guard (200...299).contains(response.statusCode) else { return [] }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [[String: Any]] ?? []
        return payload.compactMap { dict in
            guard let label = dict["label"] as? String else { return nil }
            let unread = dict["unread"] as? Int ?? 0
            return TeachLabel(label: label, unread: unread)
        }
    }

    func fetchMessages(session: TeachSession, label: String = "inbox", searchValue: String = "", limit: Int = 100) async throws -> [TeachMessage] {
        let body: [String: Any] = [
            "searchValue": searchValue,
            "sortBy": "date",
            "sortOrder": "desc",
            "action": "list",
            "label": label,
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

    func markRead(session: TeachSession, ids: [Int], read: Bool) async throws {
        let body: [String: Any] = [
            "mode": "x-read",
            "read": read,
            "items": ids
        ]
        let (_, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/coneqtmessage/save", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
    }

    func toggleStar(session: TeachSession, ids: [Int], starred: Bool) async throws {
        let body: [String: Any] = [
            "mode": "x-star",
            "starred": starred,
            "items": ids
        ]
        let (_, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/coneqtmessage/save", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
    }

    func moveMessage(session: TeachSession, ids: [Int], label: String) async throws {
        let body: [String: Any] = [
            "mode": "x-label",
            "label": label,
            "items": ids
        ]
        let (_, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/coneqtmessage/save", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
    }

    func fetchMessageDetail(session: TeachSession, id: Int) async throws -> TeachMessageDetail {
        let body: [String: Any] = [
            "action": "message",
            "id": id
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/coneqtmessage/load", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any] ?? [:]
        return parseMessageDetail(payload)
    }

    private func parseMessage(_ raw: [String: Any]) -> TeachMessage? {
        let listId = raw["id"] as? Int
        let fallbackId = raw["messageID"] as? Int
        let id = listId.map { "\($0)" }
            ?? fallbackId.map { "\($0)" }
            ?? UUID().uuidString
        let messageID = listId ?? fallbackId
        let sender = raw["sender"] as? String
        let subject = raw["subject"] as? String
        let body = raw["body"] as? String ?? raw["content"] as? String
        let read = (raw["read"] as? Int) == 1 || (raw["read"] as? Bool) == true
        let starred = (raw["starred"] as? Int) == 1 || (raw["starred"] as? Bool) == true
        let attachments = (raw["attachments"] as? Bool) == true || (raw["attachmentCount"] as? Int ?? 0) > 0
        let date = parseDate(raw["date"] as? String)

        let participantsRaw = raw["participants"] as? [[String: Any]] ?? []
        let participants: [TeachMessageListParticipant] = participantsRaw.compactMap { dict in
            let name = dict["name"] as? String ?? "Unknown"
            let type = dict["type"] as? String ?? ""
            return TeachMessageListParticipant(name: name, type: type)
        }

        return TeachMessage(id: id, messageID: messageID, sender: sender, subject: subject, body: body, date: date, read: read, starred: starred, attachments: attachments, participants: participants)
    }

    private func parseMessageDetail(_ raw: [String: Any]) -> TeachMessageDetail {
        let id = raw["id"] as? Int ?? 0
        let sender = raw["sender"] as? String
        let subject = raw["subject"] as? String
        let body = raw["contents"] as? String ?? raw["body"] as? String ?? raw["content"] as? String
        let read = (raw["read"] as? Int) == 1 || (raw["read"] as? Bool) == true
        let starred = (raw["starred"] as? Int) == 1 || (raw["starred"] as? Bool) == true
        let date = parseDate(raw["date"] as? String)

        let participantsRaw = raw["participants"] as? [[String: Any]] ?? []
        let participants: [TeachMessageParticipant] = participantsRaw.compactMap { dict in
            guard let id = dict["id"] as? Int else { return nil }
            let name = dict["name"] as? String ?? "Unknown"
            let type = dict["type"] as? String ?? ""
            let read = (dict["read"] as? Int) == 1 || (dict["read"] as? Bool) == true
            return TeachMessageParticipant(id: id, name: name, type: type, read: read)
        }

        let filesRaw = raw["files"] as? [[String: Any]] ?? []
        let files: [TeachMessageFile] = filesRaw.compactMap { dict in
            guard let id = dict["id"] as? Int,
                  let filename = dict["filename"] as? String,
                  let uuid = dict["uuid"] as? String ?? dict["context_uuid"] as? String else { return nil }
            let mimetype = dict["mimetype"] as? String ?? ""
            let size = dict["size"] as? String ?? "0"
            return TeachMessageFile(id: id, filename: filename, mimetype: mimetype, size: size, uuid: uuid)
        }

        return TeachMessageDetail(id: id, sender: sender, subject: subject, body: body, date: date, read: read, starred: starred, participants: participants, files: files)
    }

    private func parseDate(_ dateStr: String?) -> Date? {
        guard let dateStr else { return nil }
        // Try ISO8601 first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateStr) {
            return d
        }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: dateStr) {
            return d
        }
        // Fallback to "yyyy-MM-dd HH:mm:ss.SSSXXXXX" style (e.g. with timezone offset)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSXXXXX"
        return formatter.date(from: dateStr)
    }
}
