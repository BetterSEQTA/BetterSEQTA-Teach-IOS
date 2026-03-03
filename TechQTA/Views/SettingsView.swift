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
        ScrollView {
            VStack(spacing: 24) {
                if let session = sessionManager.session {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(session.hostDisplay, systemImage: "globe")
                            .font(.headline)

                        HStack {
                            Text("JSESSIONID:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(session.jsessionId.isEmpty ? "None" : "Present")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        heartbeatStatusView
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                    Button(role: .destructive) {
                        sessionManager.logout()
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.red.opacity(0.2), radius: 8, x: 0, y: 4)
                } else {
                    Text("Not logged in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)
            }
            .padding()
            .padding(.top, 12)
        }
        .task(id: sessionManager.session?.jsessionId) {
            if sessionManager.session != nil {
                await sessionManager.sendHeartbeat()
            }
        }
    }

    @ViewBuilder
    private var heartbeatStatusView: some View {
        switch sessionManager.heartbeatStatus {
        case .idle:
            Text("Last heartbeat: —")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Sending heartbeat...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success(let date):
            Text("Last heartbeat: \(date, format: .dateTime)")
                .font(.caption)
                .foregroundStyle(.green)
        case .unauthorized:
            Text("Session expired (401/403)")
                .font(.caption)
                .foregroundStyle(.red)
        case .error(let msg):
            Text("Error: \(msg)")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
