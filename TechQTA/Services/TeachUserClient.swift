//
//  TeachUserClient.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

struct TeachUserClient {
    func getStaffId(session: TeachSession) async throws -> Int {
        // Teach reliably returns staff ID here, and requires a valid JSESSIONID.
        let redirectUrl = buildRedirectUrl(session.baseUrl)
        let body: [String: Any] = [
            "mode": "normal",
            "query": NSNull(),
            "redirect_url": redirectUrl
        ]

        do {
            let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/login", body: body)
            guard (200...299).contains(response.statusCode) else {
                throw SeqtaRequestError.invalidURL
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let payload = json?["payload"] as? [String: Any]
            if let id = payload?["id"] as? Int {
                return id
            }
        } catch {
            // Fall through to fallback endpoint
        }

        // Fallback (some instances may support it)
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
        // Prefer /seqta/ta/login because it includes a nice display name (userDesc)
        let redirectUrl = buildRedirectUrl(session.baseUrl)
        let body: [String: Any] = [
            "mode": "normal",
            "query": NSNull(),
            "redirect_url": redirectUrl
        ]

        if let (data, response) = try? await seqtaPOST(session: session, path: "/seqta/ta/login", body: body),
           (200...299).contains(response.statusCode) {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let payload = json?["payload"] as? [String: Any]
            if let userDesc = payload?["userDesc"] as? String, !userDesc.isEmpty {
                return userDesc.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/user/get", body: [:])
        guard (200...299).contains(response.statusCode) else { return nil }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any]
        if let firstName = payload?["firstName"] as? String, !firstName.isEmpty { return firstName.trimmingCharacters(in: .whitespaces) }
        if let name = payload?["name"] as? String, !name.isEmpty { return name.trimmingCharacters(in: .whitespaces) }
        if let displayName = payload?["displayName"] as? String, !displayName.isEmpty { return displayName.trimmingCharacters(in: .whitespaces) }
        return nil
    }

    /// Returns displayName (userDesc) and userCode from the login endpoint payload.
    func getUserInfo(session: TeachSession) async throws -> (displayName: String?, userCode: String?) {
        let redirectUrl = buildRedirectUrl(session.baseUrl)
        let body: [String: Any] = [
            "mode": "normal",
            "query": NSNull(),
            "redirect_url": redirectUrl
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/login", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidURL
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any]
        let displayName = (payload?["userDesc"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userCode = (payload?["userCode"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (displayName, userCode)
    }

    private func buildRedirectUrl(_ baseUrl: URL) -> String {
        let baseString = baseUrl.absoluteString
        let trimmed = baseString.hasSuffix("/") ? String(baseString.dropLast()) : baseString
        if trimmed.hasSuffix("/welcome") {
            return trimmed
        }
        return trimmed + "/welcome"
    }
}
