//
//  DireqtMessagesView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct DireqtMessagesView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @StateObject private var viewModel = DireqtMessagesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading messages…")
                    .padding()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Messages unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if viewModel.messages.isEmpty {
                ContentUnavailableView("No messages", systemImage: "bubble.left.and.bubble.right", description: Text("You're all caught up."))
            } else {
                List(viewModel.messages) { msg in
                    if let messageID = msg.messageID {
                        NavigationLink {
                            DireqtMessageDetailView(messageID: messageID)
                        } label: {
                            messageRow(msg)
                        }
                    } else {
                        messageRow(msg)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.refresh(session: sessionManager.session)
                }
            }
        }
        .task(id: sessionManager.session?.jsessionId) {
            await viewModel.loadIfNeeded(session: sessionManager.session)
        }
    }

    @ViewBuilder
    private func messageRow(_ msg: TeachMessage) -> some View {
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
}

