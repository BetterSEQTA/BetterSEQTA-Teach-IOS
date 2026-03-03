//
//  TimetableView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

private let timetableDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

struct TimetableView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @State private var selectedDate = Date()
    @State private var lessons: [TeachLesson] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let client = TeachTimetableClient()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }

                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }

                Spacer()
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView("Loading timetable…")
                    .padding()
                Spacer()
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                Spacer()
            } else if lessons.isEmpty {
                ContentUnavailableView("No lessons", systemImage: "calendar", description: Text("No lessons found for this day."))
            } else {
                List(lessons) { lesson in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lesson.description ?? "Lesson")
                            .font(.headline)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text("\(lesson.from) – \(lesson.until)")
                            if let room = lesson.room, !room.isEmpty {
                                Text("· \(room)")
                            }
                            if lesson.isAdhoc {
                                Text("· Adhoc")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.insetGrouped)
            }
        }
        .task(id: timetableDateFormatter.string(from: selectedDate) + "-\(sessionManager.staffId ?? 0)") {
            await load()
        }
    }

    private func load() async {
        guard let session = sessionManager.session else { return }

        isLoading = true
        errorMessage = nil
        lessons = []

        if sessionManager.staffId == nil {
            await sessionManager.fetchStaffIdIfNeeded()
        }
        guard let staffId = sessionManager.staffId else {
            errorMessage = "Could not load staff ID."
            isLoading = false
            return
        }

        let dateString = timetableDateFormatter.string(from: selectedDate)
        do {
            lessons = try await client.fetchLessons(session: session, staffId: staffId, dateFrom: dateString, dateTo: dateString)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

