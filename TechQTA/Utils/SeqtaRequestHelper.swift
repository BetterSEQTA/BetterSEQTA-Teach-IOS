//
//  SeqtaRequestHelper.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

enum SeqtaRequestError: Error {
    case invalidURL
    case invalidBody
}

/// Shared helper for SEQTA Teach API POST requests with JSESSIONID cookie.
func seqtaPOST(session: TeachSession, path: String, body: [String: Any]) async throws -> (Data, HTTPURLResponse) {
    let baseString = session.baseUrl.absoluteString
    let trimmed = baseString.hasSuffix("/") ? String(baseString.dropLast()) : baseString
    let pathNormalized = path.hasPrefix("/") ? path : "/" + path
    guard let url = URL(string: trimmed + pathNormalized) else {
        throw SeqtaRequestError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("JSESSIONID=\(session.jsessionId)", forHTTPHeaderField: "Cookie")

    guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
        throw SeqtaRequestError.invalidBody
    }
    request.httpBody = bodyData

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw SeqtaRequestError.invalidURL
    }

    return (data, httpResponse)
}
