//
//  AttendanceTypePickerSheet.swift
//  TechQTA
//

import SwiftUI

struct AttendanceTypePickerSheet: View {
    let types: [TeachAttendanceType]
    let studentName: String
    let currentCode: String?
    let onSelect: (String) -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        FeedbackManager.doubleTap()
                        onClear()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("Clear attendance")
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ForEach(types) { type in
                        let color = statusColor(type.label)
                        let isSelected = type.code == currentCode
                        Button {
                            onSelect(type.code)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: AttendanceIconHelper.sfSymbol(for: type.code) ?? "questionmark.circle")
                                    .font(.title3)
                                    .foregroundStyle(color)
                                    .frame(width: 32, height: 32)
                                    .background(Capsule().fill(color.opacity(0.15)))

                                Text(type.label)
                                    .font(.body)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(color)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Mark as")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(studentName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        FeedbackManager.doubleTap()
                        onDismiss()
                    }
                }
            }
        }
    }

    private func statusColor(_ label: String) -> Color {
        let lower = label.lowercased()
        if lower.contains("absent") || lower.contains("no") || lower.contains("truant") {
            return .red
        }
        if lower.contains("present") || lower.contains("in-class") || lower.contains("yes") {
            return .green
        }
        if lower.contains("late") {
            return .orange
        }
        if lower.contains("learning at home") || lower.contains("medical") {
            return .blue
        }
        return .secondary
    }
}
