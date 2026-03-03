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
        .task(id: AppDateFormatters.isoYMD.string(from: viewModel.selectedDate) + "-\(sessionManager.staffId ?? 0)-\(sessionManager.session?.jsessionId ?? "")") {
            await viewModel.load(sessionManager: sessionManager)
        }
    }
}

