//
//  TeachSessionManager.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation
import SwiftUI

enum LoginStatus: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn
    case error(String)
}

enum HeartbeatStatus: Equatable {
    case idle
    case loading
    case success(Date)
    case unauthorized
    case error(String)
}

@MainActor
final class TeachSessionManager: ObservableObject {
    static let shared = TeachSessionManager()

    @Published private(set) var session: TeachSession?
    @Published private(set) var staffId: Int?
    @Published private(set) var displayName: String?
    @Published private(set) var userCode: String?
    @Published private(set) var loginStatus: LoginStatus = .loggedOut
    @Published private(set) var heartbeatStatus: HeartbeatStatus = .idle

    var onLogout: (() -> Void)?

    private let heartbeatClient = HeartbeatClient()
    private let userClient = TeachUserClient()
    private let keychainKey = "jsessionId"
    private let baseUrlKey = "baseUrl"
    private let sessionStore = UserDefaults.standard

    init() {
        Task { await restoreSession() }
    }

    func startLogin(with baseUrl: URL) {
        session = TeachSession(baseUrl: baseUrl, jsessionId: "", lastHeartbeatAt: nil)
        loginStatus = .loggingIn
    }

    func completeLogin(with newSession: TeachSession) {
        session = newSession
        loginStatus = .loggedIn
        Task {
            await persistSession()
            await fetchStaffIdAndUserInfoIfNeeded()
        }
    }

    func cancelLogin() {
        session = nil
        loginStatus = .loggedOut
    }

    func logout() {
        session = nil
        staffId = nil
        displayName = nil
        userCode = nil
        loginStatus = .loggedOut
        heartbeatStatus = .idle
        onLogout?()
        Task { await clearPersistedSession() }
    }

    func setLoginError(_ message: String) {
        loginStatus = .error(message)
    }

    func sendHeartbeat() async {
        guard let s = session else {
            heartbeatStatus = .error("No session")
            return
        }
        heartbeatStatus = .loading
        do {
            let result = try await heartbeatClient.sendHeartbeat(for: s)
            switch result {
            case .success(let date):
                var updated = s
                updated.lastHeartbeatAt = date
                session = updated
                heartbeatStatus = .success(date)
            case .unauthorized:
                heartbeatStatus = .unauthorized
                logout()
            case .failure(let msg):
                heartbeatStatus = .error(msg)
            }
        } catch {
            heartbeatStatus = .error(error.localizedDescription)
        }
    }

    private func restoreSession() async {
        guard let baseUrlString = sessionStore.string(forKey: baseUrlKey),
              let baseUrl = URL(string: baseUrlString),
              let jsessionId = try? KeychainHelper.load(key: keychainKey),
              !jsessionId.isEmpty else {
            return
        }
        let restored = TeachSession(baseUrl: baseUrl, jsessionId: jsessionId, lastHeartbeatAt: nil)
        session = restored
        loginStatus = .loggedIn
        await fetchStaffIdAndUserInfoIfNeeded()
    }

    func fetchStaffIdAndUserInfoIfNeeded() async {
        guard let s = session else { return }
        guard staffId == nil || displayName == nil || userCode == nil else { return }
        do {
            let id = try await userClient.getStaffId(session: s)
            staffId = id
            let (name, code) = try await userClient.getUserInfo(session: s)
            if let name = name, !name.isEmpty { displayName = name }
            if let code = code, !code.isEmpty { userCode = code }
        } catch {
            // Non-fatal; views can retry or show limited UI
        }
    }

    private func persistSession() async {
        guard let s = session else { return }
        sessionStore.set(s.baseUrl.absoluteString, forKey: baseUrlKey)
        try? KeychainHelper.save(key: keychainKey, value: s.jsessionId)
    }

    private func clearPersistedSession() async {
        sessionStore.removeObject(forKey: baseUrlKey)
        try? KeychainHelper.delete(key: keychainKey)
    }

}
