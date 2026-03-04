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
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading lessons…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                } else if let err = viewModel.lessonsError {
                    Text("Error: \(err)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if viewModel.todayLessons.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No lessons today")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Check the timetable for other days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(viewModel.todayLessons.prefix(3))) { lesson in
                        if lesson.classunitId != nil {
                            NavigationLink {
                                LessonAttendanceView(
                                    lesson: lesson,
                                    date: AppDateFormatters.isoYMD.string(from: Date())
                                )
                            } label: {
                                lessonRow(lesson)
                            }
                        } else {
                            lessonRow(lesson)
                        }
                    }
                }
            } header: {
                HStack {
                    Label("Today's Lessons", systemImage: "calendar.day")
                        .font(.headline)
                    Spacer()
                    Button {
                        FeedbackManager.light()
                        selectedTab = .timetable
                    } label: {
                        Text("See all")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }

            // Direqt Messages Section
            Section {
                if viewModel.messagesLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading messages…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                } else if let err = viewModel.messagesError {
                    Text("Error: \(err)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if viewModel.messages.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No messages")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Your Direqt messages will appear here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
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
                    Label("Direqt Messages", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline)
                    Spacer()
                    Button {
                        FeedbackManager.light()
                        selectedTab = .messages
                    } label: {
                        Text("See all")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .contentMargins(.top, 0, for: .scrollContent)
    }

    @ViewBuilder
    private func lessonRow(_ lesson: TeachLesson) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(Color.green.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.description ?? lesson.code ?? "Lesson")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let period = lesson.period, !period.isEmpty {
                        Text(period)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
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
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func messageRow(_ msg: TeachMessage) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String((msg.sender ?? "U").prefix(1)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .overlay(alignment: .topTrailing) {
                    if !msg.read {
                        Circle()
                            .fill(.blue)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(msg.sender ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(msg.read ? .medium : .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    if let date = msg.date {
                        Text(date, format: .dateTime.day().month().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(msg.subject ?? "No subject")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

}
