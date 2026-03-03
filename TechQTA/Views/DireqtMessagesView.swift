//
//  DireqtMessagesView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct DireqtMessagesView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @State private var messages: [TeachMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let client = TeachMessagesClient()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading messages…")
                    .padding()
            } else if let errorMessage {
                ContentUnavailableView("Messages unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if messages.isEmpty {
                ContentUnavailableView("No messages", systemImage: "bubble.left.and.bubble.right", description: Text("You're all caught up."))
            } else {
                List(messages) { msg in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(msg.sender ?? "Unknown")
                                .font(.headline)
                                .lineLimit(1)
                            if !msg.read {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                            }
                            Spacer()
                            if let date = msg.date {
                                Text(date, format: .dateTime.day().month().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(msg.subject ?? "No subject")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await load()
                }
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        guard let session = sessionManager.session else { return }

        isLoading = true
        errorMessage = nil
        do {
            messages = try await client.fetchMessages(session: session, limit: 50)
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }
        isLoading = false
    }
}

