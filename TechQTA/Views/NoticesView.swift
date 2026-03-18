//
//  NoticesView.swift
//  TechQTA
//

import SwiftUI

struct NoticesView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @StateObject private var viewModel = NoticesViewModel()

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
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading notices…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
            await viewModel.load(session: sessionManager.session)
        }
    }

    @ViewBuilder
    private func noticeRow(_ notice: TeachNotice) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(labelColor(notice.colour).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(labelColor(notice.colour))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let labelTitle = notice.labelTitle, !labelTitle.isEmpty {
                        Text(labelTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let staff = notice.staff {
                        Text(staff)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let from = notice.from {
                        Text(from)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func labelColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return .blue }
        return Color(hex: hex)
    }
}
