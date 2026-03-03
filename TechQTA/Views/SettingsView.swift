//
//  SettingsView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager

    var body: some View {
        List {
            if let session = sessionManager.session {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.hostDisplay)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text(session.jsessionId.isEmpty ? "Not connected" : "Session active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        heartbeatStatusView
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }

                Section {
                    Button(role: .destructive) {
                        sessionManager.logout()
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Not logged in")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
        .task(id: sessionManager.session?.jsessionId) {
            if sessionManager.session != nil {
                await sessionManager.sendHeartbeat()
            }
        }
    }

    @ViewBuilder
    private var heartbeatStatusView: some View {
        HStack(spacing: 8) {
            Image(systemName: heartbeatStatusIcon)
                .font(.subheadline)
                .foregroundStyle(heartbeatStatusColor)
            switch sessionManager.heartbeatStatus {
            case .idle:
                Text("Last heartbeat: —")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 6) {
                    Text("Sending heartbeat…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            case .success(let date):
                Text("Last heartbeat: \(date, format: .dateTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unauthorized:
                Text("Session expired")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .error(let msg):
                Text("Error: \(msg)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var heartbeatStatusIcon: String {
        switch sessionManager.heartbeatStatus {
        case .success: return "checkmark.circle.fill"
        case .unauthorized, .error: return "exclamationmark.triangle.fill"
        default: return "circle.dotted"
        }
    }

    private var heartbeatStatusColor: Color {
        switch sessionManager.heartbeatStatus {
        case .success: return .green
        case .unauthorized, .error: return .red
        default: return .secondary
        }
    }
}
