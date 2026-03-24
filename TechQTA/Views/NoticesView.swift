//
//  NoticesView.swift
//  TechQTA
//

import SwiftUI

struct NoticesView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @StateObject private var viewModel = NoticesViewModel()
    @State private var fluidProgress: CGFloat = 0
    @State private var fluidPhase = "Loading notices…"
    @State private var fluidGen = 0

    var body: some View {
        VStack(spacing: 0) {
            // Date picker (same style as Timetable)
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

            if viewModel.isLoading && viewModel.notices.isEmpty {
                FluidLoadingBarView(
                    progress: fluidProgress,
                    phaseText: fluidPhase,
                    accessibilityLabel: "Loading notices"
                )
                .padding(.horizontal, 32)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else if let errorMessage = viewModel.errorMessage, viewModel.notices.isEmpty {
                ContentUnavailableView(
                    "Couldn't load notices",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.notices.isEmpty {
                ContentUnavailableView(
                    "No notices",
                    systemImage: "doc.text",
                    description: Text("No notices for this date.")
                )
            } else {
                List(viewModel.notices) { notice in
                    NavigationLink {
                        NoticeDetailView(notice: notice)
                    } label: {
                        noticeRow(notice)
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.top, 0, for: .scrollContent)
                .refreshable {
                    await viewModel.load(session: sessionManager.session)
                }
            }
        }
        .task(id: AppDateFormatters.isoYMD.string(from: viewModel.selectedDate) + "-\(sessionManager.session?.jsessionId ?? "")") {
            fluidGen += 1
            let g = fluidGen
            fluidProgress = 0.06
            fluidPhase = "Loading notices…"
            withAnimation(.spring(.snappy)) { fluidProgress = 0.12 }
            let organic = Task {
                await FluidLoadingCoordinator.runOrganicMilestones(
                    phases: FluidLoadingCoordinator.Presets.notices,
                    generation: g,
                    currentGeneration: { fluidGen },
                    progress: $fluidProgress,
                    phaseText: $fluidPhase
                )
            }
            await viewModel.load(session: sessionManager.session)
            organic.cancel()
            await FluidLoadingCoordinator.snapFinish(
                generation: g,
                currentGeneration: { fluidGen },
                progress: $fluidProgress,
                phaseText: $fluidPhase,
                finishingText: "Notices ready",
                resetText: "Loading notices…"
            )
        }
    }

    @ViewBuilder
    private func noticeRow(_ notice: TeachNotice) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(labelColor(notice.colour).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(labelColor(notice.colour))
                }

            VStack(alignment: .center, spacing: 10) {
                Text(notice.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(alignment: .top, spacing: 8) {
                    if let labelTitle = notice.labelTitle, !labelTitle.isEmpty {
                        VStack(alignment: .center, spacing: 4) {
                            if let hex = notice.colour {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 6, height: 6)
                            }
                            Text(labelTitle)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let staff = notice.staff {
                        VStack(alignment: .center, spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(staff)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .premiumScrollRowTransition()
    }

    private func labelColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return .blue }
        return Color(hex: hex)
    }
}
