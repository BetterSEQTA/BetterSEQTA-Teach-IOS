//
//  HomePlaceholderView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct HomePlaceholderView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Binding var selectedTab: AppTab
    @StateObject private var viewModel = HomeDashboardViewModel()

    var body: some View {
        Group {
            if sessionManager.session != nil {
                content
            } else {
                ProgressView()
            }
        }
        .task(id: sessionManager.session?.jsessionId) {
            await viewModel.loadIfNeeded(sessionManager: sessionManager)
        }
    }

    private var content: some View {
        List {
            // Today's Lessons Section
            Section {
                if viewModel.lessonsLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else if let err = viewModel.lessonsError {
                    Text("Error: \(err)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if viewModel.todayLessons.isEmpty {
                    Text("No lessons today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.white)
                } else {
                    ForEach(Array(viewModel.todayLessons.prefix(3))) { lesson in
                        lessonRow(lesson)
                    }
                }
            } header: {
                HStack {
                    Text("Today's Lessons")
                        .font(.headline)
                    Spacer()
                    Button("See all") {
                        selectedTab = .timetable
                    }
                    .font(.subheadline)
                }
            }

            // Direqt Messages Section
            Section {
                if viewModel.messagesLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else if let err = viewModel.messagesError {
                    Text("Error: \(err)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if viewModel.messages.isEmpty {
                    Text("No messages")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(viewModel.messages.prefix(3))) { msg in
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
                }
            } header: {
                HStack {
                    Text("Direqt Messages")
                        .font(.headline)
                    Spacer()
                    Button("See all") {
                        selectedTab = .messages
                    }
                    .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .contentMargins(.top, 0, for: .scrollContent)
    }

    @ViewBuilder
    private func lessonRow(_ lesson: TeachLesson) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.green.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.description ?? lesson.code ?? "Lesson")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("\(lesson.from) – \(lesson.until)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let room = lesson.room, !room.isEmpty {
                        Text("· \(room)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
