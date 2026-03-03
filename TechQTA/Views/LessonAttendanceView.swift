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

    private let client = TeachAttendanceClient()

    private var lessonTimeDateTitle: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let d = df.date(from: date) else { return lesson.description ?? "Attendance" }
        let df2 = DateFormatter()
        df2.dateFormat = "d MMM yyyy"
        let dateStr = df2.string(from: d)
        return "\(dateStr), \(lesson.from) – \(lesson.until)"
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
                    if lesson.isAdhoc, !summaryByStudent.isEmpty {
                        Section {
                            Button {
                                showStats = true
                            } label: {
                                HStack {
                                    Label("View attendance stats", systemImage: "chart.bar.fill")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    Section {
                        ForEach(students) { student in
                            studentRow(student)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    cycleAttendance(for: student)
                                }
                        }
                    } header: {
                        Text("Students")
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
    private func studentRow(_ student: TeachAttendanceStudent) -> some View {
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
                    .fontWeight(.medium)
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

            attendanceStatusBadge(for: student)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func attendanceStatusBadge(for student: TeachAttendanceStudent) -> some View {
        let resolved = resolveAttendanceStatus(student)
        if let resolved {
            HStack(spacing: 4) {
                Image(systemName: resolved.icon)
                    .font(.caption)
                Text(resolved.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(statusColor(resolved.label).opacity(0.2)))
            .foregroundStyle(statusColor(resolved.label))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "minus.circle")
                    .font(.caption)
                Text("—")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
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

            if lesson.isAdhoc, !students.isEmpty {
                let studentIds = students.map(\.id)
                summaryByStudent = try await client.fetchAttendanceSummary(session: session, date: date, studentIds: studentIds, classunitIds: [classunitId])
            }
        } catch {
            errorMessage = error.localizedDescription
            students = []
        }

        isLoading = false
    }
}
