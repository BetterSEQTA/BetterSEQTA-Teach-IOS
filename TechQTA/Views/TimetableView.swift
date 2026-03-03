//
//  TimetableView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct TimetableView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @StateObject private var viewModel = TimetableViewModel()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }

                DatePicker(
                    "Date",
                    selection: $viewModel.selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Button {
                    viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }

                Spacer()
            }
            .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView("Loading timetable…")
                    .padding()
                Spacer()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                Spacer()
            } else if viewModel.lessons.isEmpty {
                ContentUnavailableView("No lessons", systemImage: "calendar", description: Text("No lessons found for this day."))
            } else {
                List(viewModel.lessons) { lesson in
                    lessonRow(lesson)
                }
                .listStyle(.insetGrouped)
            }
        }
        .task(id: AppDateFormatters.isoYMD.string(from: viewModel.selectedDate) + "-\(sessionManager.staffId ?? 0)-\(sessionManager.session?.jsessionId ?? "")") {
            await viewModel.load(sessionManager: sessionManager)
        }
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

                    if lesson.isAdhoc {
                        Text("· Untimetabled lesson")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

