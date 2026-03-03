//
//  HeartbeatClient.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

enum HeartbeatResponse {
    case success(Date)
    case unauthorized
    case failure(String)
}

struct HeartbeatClient {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.S"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    func sendHeartbeat(for session: TeachSession) async throws -> HeartbeatResponse {
        let baseString = session.baseUrl.absoluteString
        let trimmed = baseString.hasSuffix("/") ? String(baseString.dropLast()) : baseString
        guard let url = URL(string: trimmed + "/seqta/ta/heartbeat") else {
            return .failure("Invalid heartbeat URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session.jsessionId)", forHTTPHeaderField: "Cookie")

        let timestamp = Self.formatter.string(from: Date())
        let body: [String: String] = [
            "hash": "",
            "timestamp": timestamp
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return .success(Date())
        case 401, 403:
            return .unauthorized
        default:
            return .failure("HTTP \(httpResponse.statusCode)")
        }
    }
}
