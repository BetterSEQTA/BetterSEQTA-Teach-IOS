//
//  TeachUserClient.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

struct TeachUserClient {
    func getStaffId(session: TeachSession) async throws -> Int {
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/user/get", body: [:])
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidURL
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any]
        guard let id = payload?["id"] as? Int else {
            throw SeqtaRequestError.invalidURL
        }
        return id
    }

    func getUserName(session: TeachSession) async throws -> String? {
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/user/get", body: [:])
        guard (200...299).contains(response.statusCode) else {
            return nil
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any]
        if let firstName = payload?["firstName"] as? String, !firstName.isEmpty { return firstName.trimmingCharacters(in: .whitespaces) }
        if let name = payload?["name"] as? String, !name.isEmpty { return name.trimmingCharacters(in: .whitespaces) }
        if let displayName = payload?["displayName"] as? String, !displayName.isEmpty { return displayName.trimmingCharacters(in: .whitespaces) }
        return nil
    }
}
