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
                .contentMargins(.top, 0, for: .scrollContent)
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
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String((msg.sender ?? "U").prefix(1)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(msg.sender ?? "Unknown")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    if let date = msg.date {
                        Text(date, format: .dateTime.day().month().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .bottom) {
                    Text(msg.subject ?? "No subject")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    if !msg.read {
                        Circle()
                            .fill(.blue)
                            .frame(width: 10, height: 10)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

