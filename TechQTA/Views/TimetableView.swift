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
    @State private var fluidProgress: CGFloat = 0
    @State private var fluidPhase = "Loading your day…"
    @State private var fluidGen = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button {
                    FeedbackManager.tripleTap()
                    viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                DatePicker(
                    "Date",
                    selection: $viewModel.selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Button {
                    FeedbackManager.tripleTap()
                    viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if viewModel.isLoading {
                FluidLoadingBarView(
                    progress: fluidProgress,
                    phaseText: fluidPhase,
                    accessibilityLabel: "Loading timetable"
                )
                .padding(.horizontal, 32)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Couldn't load timetable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.lessons.isEmpty {
                ContentUnavailableView("No lessons", systemImage: "calendar", description: Text("No lessons found for this day."))
            } else {
                List(viewModel.lessons) { lesson in
                    if lesson.classunitId != nil {
                        NavigationLink {
                            LessonAttendanceView(
                                lesson: lesson,
                                date: AppDateFormatters.isoYMD.string(from: viewModel.selectedDate)
                            )
                        } label: {
                            lessonRow(lesson)
                        }
                    } else {
                        lessonRow(lesson)
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
        .task(id: AppDateFormatters.isoYMD.string(from: viewModel.selectedDate) + "-\(sessionManager.staffId ?? 0)-\(sessionManager.session?.jsessionId ?? "")") {
            fluidGen += 1
            let g = fluidGen
            fluidProgress = 0.06
            fluidPhase = "Loading your timetable…"
            withAnimation(.spring(.snappy)) { fluidProgress = 0.12 }
            let organic = Task {
                await FluidLoadingCoordinator.runOrganicMilestones(
                    phases: FluidLoadingCoordinator.Presets.timetable,
                    generation: g,
                    currentGeneration: { fluidGen },
                    progress: $fluidProgress,
                    phaseText: $fluidPhase
                )
            }
            await viewModel.load(sessionManager: sessionManager)
            organic.cancel()
            await FluidLoadingCoordinator.snapFinish(
                generation: g,
                currentGeneration: { fluidGen },
                progress: $fluidProgress,
                phaseText: $fluidPhase,
                finishingText: "Timetable ready",
                resetText: "Loading your day…"
            )
        }
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
                    if lesson.isAdhoc {
                        Text("· Untimetabled")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .premiumScrollRowTransition()
    }
}

