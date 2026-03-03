//
//  HomePlaceholderView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

struct HomePlaceholderView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Binding var selectedTab: AppTab
    @State private var todayLessons: [TeachLesson] = []
    @State private var messages: [TeachMessage] = []
    @State private var lessonsLoading = false
    @State private var messagesLoading = false
    @State private var lessonsError: String?
    @State private var messagesError: String?

    private let timetableClient = TeachTimetableClient()
    private let messagesClient = TeachMessagesClient()

    var body: some View {
        Group {
            if sessionManager.session != nil {
                content
            } else {
                ProgressView()
            }
        }
        .task { await loadDashboardData() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                todayLessonsPreview

                direqtMessagesPreview

                Spacer(minLength: 24)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var todayLessonsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Lessons")
                    .font(.headline)
                Spacer()
                Button("See all") {
                    selectedTab = .timetable
                }
                .font(.subheadline)
                .padding(.vertical, 8) // hit target
            }

            if lessonsLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let err = lessonsError {
                Text("Error: \(err)")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if todayLessons.isEmpty {
                Text("No lessons today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(todayLessons.prefix(3))) { lesson in
                    lessonRow(lesson)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func lessonRow(_ lesson: TeachLesson) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lesson.description ?? "Lesson")
                .font(.subheadline)
                .fontWeight(.medium)
            HStack {
                Text("\(lesson.from) – \(lesson.until)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let room = lesson.room, !room.isEmpty {
                    Text("· \(room)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var direqtMessagesPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Direqt Messages")
                    .font(.headline)
                Spacer()
                Button("See all") {
                    selectedTab = .messages
                }
                .font(.subheadline)
                .padding(.vertical, 8) // hit target
            }

            if messagesLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if let err = messagesError {
                Text("Error: \(err)")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if messages.isEmpty {
                Text("No messages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(messages.prefix(3))) { msg in
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func messageRow(_ msg: TeachMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(msg.sender ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !msg.read {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                }
            }
            Text(msg.subject ?? "No subject")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let date = msg.date {
                Text(date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func loadDashboardData() async {
        guard let session = sessionManager.session else { return }

        let today = dateFormatter.string(from: Date())

        lessonsLoading = true
        lessonsError = nil
        if let staffId = sessionManager.staffId {
            do {
                todayLessons = try await timetableClient.fetchLessons(session: session, staffId: staffId, dateFrom: today, dateTo: today)
            } catch {
                lessonsError = error.localizedDescription
                todayLessons = []
            }
        } else {
            await sessionManager.fetchStaffIdIfNeeded()
            if let staffId = sessionManager.staffId {
                do {
                    todayLessons = try await timetableClient.fetchLessons(session: session, staffId: staffId, dateFrom: today, dateTo: today)
                } catch {
                    lessonsError = error.localizedDescription
                    todayLessons = []
                }
            } else {
                lessonsError = "Could not load staff ID"
            }
        }
        lessonsLoading = false

        messagesLoading = true
        messagesError = nil
        do {
            messages = try await messagesClient.fetchMessages(session: session, limit: 5)
        } catch {
            messagesError = error.localizedDescription
            messages = []
        }
        messagesLoading = false
    }
}
