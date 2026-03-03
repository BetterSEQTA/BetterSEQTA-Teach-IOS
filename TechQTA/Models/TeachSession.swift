//
//  TeachSession.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

struct TeachSession: Equatable {
    let baseUrl: URL
    let jsessionId: String
    var lastHeartbeatAt: Date?

    var isAuthenticated: Bool {
        !jsessionId.isEmpty
    }

    var hostDisplay: String {
        baseUrl.host ?? baseUrl.absoluteString
    }
}
