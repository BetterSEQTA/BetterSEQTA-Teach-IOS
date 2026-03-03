//
//  LessonAttendanceView.swift
//  TechQTA
//

import SwiftUI

private let cycleTypes = ["yes", "no"]

struct LessonAttendanceView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager

    let lesson: TeachLesson
    let date: String

    @State private var students: [TeachAttendanceStudent] = []
    @State private var attendanceTypes: [TeachAttendanceType] = []
    @State private var summaryByStudent: [Int: (present: Int, percent: Int)] = [:]
    @State private var pendingChanges: [Int: String] = [:]
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveError: String?
    @State private var showStats = false
    @State private var typePickerStudent: TeachAttendanceStudent?

    private let client = TeachAttendanceClient()

    private var selectableTypes: [TeachAttendanceType] {
        attendanceTypes.filter { $0.isReset != true && $0.code != "kiosk-zero" }
    }

    private var lessonTimeDateTitle: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let d = df.date(from: date) else { return lesson.description ?? "Attendance" }
        let df2 = DateFormatter()
        df2.dateFormat = "d MMM yyyy"
        let dateStr = df2.string(from: d)
        let dateTime = "\(dateStr), \(lesson.from) – \(lesson.until)"
        if let subject = lesson.description, !subject.isEmpty {
            return "\(subject) · \(dateTime)"
        }
        return dateTime
    }

    var body: some View {
        Group {
            if isLoading && students.isEmpty {
                ProgressView("Loading attendance…")
                    .padding()
            } else if let errorMessage, students.isEmpty {
                ContentUnavailableView("Attendance unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if students.isEmpty {
                ContentUnavailableView("No students", systemImage: "person.2", description: Text("No students in this class."))
            } else {
                List {
                    if !summaryByStudent.isEmpty {
                        Section {
                            Button {
                                showStats = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title3)
                                        .foregroundStyle(.tint)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("View attendance stats")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text("See percentages by student")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        ForEach(students) { student in
                            studentRow(student, onLongPress: { typePickerStudent = student })
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    cycleAttendance(for: student)
                                }
                        }
                    } header: {
                        Text("Students")
                    } footer: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.caption2)
                            Text("Tap to mark attendance")
                            Text("•")
                            Image(systemName: "hand.raised.fill")
                                .font(.caption2)
                            Text("Long press for more options")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(lessonTimeDateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving || pendingChanges.isEmpty)
            }
        }
        .task {
            await load()
        }
        .navigationDestination(isPresented: $showStats) {
            AttendanceStatsView(
                summaryByStudent: summaryByStudent,
                students: students,
                lesson: lesson,
                date: date
            )
        }
        .alert("Save failed", isPresented: .init(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "")
        }
        .sheet(item: $typePickerStudent) { student in
            AttendanceTypePickerSheet(
                types: selectableTypes,
                studentName: (student.prefname ?? student.firstname) + " " + student.surname,
                currentCode: effectiveCode(for: student),
                onSelect: { code in
                    pendingChanges[student.id] = code
                    typePickerStudent = nil
                },
                onClear: {
                    pendingChanges.removeValue(forKey: student.id)
                    typePickerStudent = nil
                },
                onDismiss: { typePickerStudent = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func cycleAttendance(for student: TeachAttendanceStudent) {
        let current = effectiveCode(for: student)
        let next: String
        if let idx = cycleTypes.firstIndex(of: current ?? "") {
            let nextIdx = (idx + 1) % cycleTypes.count
            next = cycleTypes[nextIdx]
        } else {
            next = cycleTypes[0]
        }
        pendingChanges[student.id] = next
    }

    private func effectiveCode(for student: TeachAttendanceStudent) -> String? {
        if let pending = pendingChanges[student.id] { return pending }
        return student.attendance[lesson.id]?["detail"] as? String
    }

    private func save() async {
        guard let session = sessionManager.session, !pendingChanges.isEmpty else { return }
        isSaving = true
        saveError = nil
        do {
            let studentDict = Dictionary(uniqueKeysWithValues: pendingChanges.map { ("\($0.key)", $0.value) })
            let body: [String: [String: String]] = [lesson.id: studentDict]
            try await client.saveAttendance(session: session, attendance: body)
            await MainActor.run {
                pendingChanges.removeAll()
            }
            await load()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    @ViewBuilder
    private func studentRow(_ student: TeachAttendanceStudent, onLongPress: @escaping () -> Void = {}) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String((student.prefname ?? student.firstname).prefix(1)))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(student.prefname ?? student.firstname)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(student.surname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let rollgroup = student.rollgroupname, !rollgroup.isEmpty {
                    Text(rollgroup)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            attendanceStatusBadge(for: student, onLongPress: onLongPress)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func attendanceStatusBadge(for student: TeachAttendanceStudent, onLongPress: @escaping () -> Void) -> some View {
        let resolved = resolveAttendanceStatus(student)
        Group {
            if let resolved {
                HStack(spacing: 6) {
                    Image(systemName: resolved.icon)
                        .font(.subheadline)
                    Text(resolved.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(statusColor(resolved.label).opacity(0.2)))
                .foregroundStyle(statusColor(resolved.label))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "minus.circle")
                        .font(.subheadline)
                    Text("Not marked")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.systemGray5)))
                .foregroundStyle(.secondary)
            }
        }
        .onLongPressGesture {
            onLongPress()
        }
    }

    private func resolveAttendanceStatus(_ student: TeachAttendanceStudent) -> (label: String, icon: String)? {
        let code = effectiveCode(for: student)
        guard let code else { return nil }
        let displayLabel = attendanceTypes.first { $0.code == code }?.label ?? code.capitalized
        let icon = AttendanceIconHelper.sfSymbol(for: code) ?? "questionmark.circle"
        return (displayLabel, icon)
    }

    private func statusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("absent") || lower.contains("no") || lower.contains("truant") || lower.contains("unapproved") || lower.contains("unresolved") {
            return .red
        }
        if lower.contains("present") || lower.contains("in-class") || lower.contains("yes") || lower.contains("approved") || lower.contains("resolved") || lower.contains("exempted") || lower.contains("camp") || lower.contains("excursion") || lower.contains("educational") || lower.contains("sick bay") || lower.contains("tutor") || lower.contains("music") || lower.contains("transit") || lower.contains("suspended (internal)") {
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

    private func load() async {
        guard let session = sessionManager.session else {
            errorMessage = "Not logged in."
            return
        }
        guard let classunitId = lesson.classunitId else {
            errorMessage = "No class unit for this lesson."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let types = try await client.fetchAttendanceTypes(session: session)
            attendanceTypes = types

            let classIds: [Int] = lesson.isAdhoc ? [classunitId] : [classunitId, classunitId]
            let payload = try await client.fetchAttendanceLoad(session: session, date: date, classunitIds: classIds, isAdhoc: lesson.isAdhoc)
            students = client.parseStudents(from: payload)

            if !students.isEmpty {
                let studentIds = students.map(\.id)
                summaryByStudent = try await client.fetchAttendanceSummary(session: session, date: date, studentIds: studentIds, classunitIds: classIds, isAdhoc: lesson.isAdhoc)
            }
        } catch {
            errorMessage = error.localizedDescription
            students = []
        }

        isLoading = false
    }
}
