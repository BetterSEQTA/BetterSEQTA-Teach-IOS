//
//  LessonAttendanceView.swift
//  TechQTA
//

import SwiftUI

private let cycleTypes = ["yes", "no"]

enum AttendanceViewMode: String, CaseIterable {
    case list = "List"
    case card = "Cards"
}

let attendanceViewModeKey = "attendanceViewMode"

struct LessonAttendanceView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Environment(\.dismiss) private var dismiss

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
    @State private var showDiscardConfirmation = false
    @AppStorage(attendanceViewModeKey) private var viewModeRaw: String = AttendanceViewMode.list.rawValue
    private var viewMode: AttendanceViewMode {
        AttendanceViewMode(rawValue: viewModeRaw) ?? .list
    }
    @State private var cardIndex = 0
    @State private var cardDragOffset: CGFloat = 0
    @State private var isFlickingAway = false

    private let client = TeachAttendanceClient()
    private let cardStackSize = 3

    private var currentCardStudent: TeachAttendanceStudent? {
        guard cardIndex >= 0, cardIndex < students.count else { return nil }
        return students[cardIndex]
    }

    private var visibleCardRange: Range<Int> {
        let start = max(0, cardIndex)
        let end = min(students.count, cardIndex + cardStackSize)
        return start..<end
    }

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
                VStack(spacing: 0) {
                    if viewMode == .list {
                        listView
                    } else {
                        cardView
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    FeedbackManager.longThenShort()
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
        .navigationTitle(lessonTimeDateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved attendance changes. Are you sure you want to leave?")
        }
.sheet(item: $typePickerStudent) { student in
                AttendanceTypePickerSheet(
                    types: selectableTypes,
                    studentName: (student.prefname ?? student.firstname) + " " + student.surname,
                    currentCode: effectiveCode(for: student),
                    onSelect: { code in
                        pendingChanges[student.id] = code
                        typePickerStudent = nil
                        if viewMode == .card {
                            advanceCard()
                        }
                    },
                    onClear: {
                        pendingChanges.removeValue(forKey: student.id)
                        typePickerStudent = nil
                        if viewMode == .card {
                            advanceCard()
                        }
                    },
                    onDismiss: { typePickerStudent = nil }
                )
                        .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var listView: some View {
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
                    studentRow(student)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            cycleAttendance(for: student)
                        }
                        .onLongPressGesture {
                            FeedbackManager.tripleTap()
                            typePickerStudent = student
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                pendingChanges[student.id] = "yes"
                            } label: {
                                Label("Yes", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                pendingChanges[student.id] = "no"
                            } label: {
                                Label("No", systemImage: "xmark.circle.fill")
                            }
                            .tint(.red)
                        }
                }
            } header: {
                Text("Students")
            } footer: {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                    Text("Tap to cycle")
                    Text("•")
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                    Text("Swipe left = No, right = Yes")
                    Text("•")
                    Image(systemName: "hand.raised.fill")
                        .font(.caption2)
                    Text("Long press for more")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var cardView: some View {
        if students.isEmpty {
            ContentUnavailableView(
                "All done",
                systemImage: "checkmark.circle.fill",
                description: Text("You've marked all students. Switch to List to review or save.")
            )
        } else if cardIndex >= students.count {
            ContentUnavailableView(
                "All done",
                systemImage: "checkmark.circle.fill",
                description: Text("You've marked all students. Switch to List to review or save.")
            )
        } else {
            VStack(spacing: 0) {
                Text("\(cardIndex + 1) of \(students.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .animation(.easeInOut(duration: 0.2), value: cardIndex)

                ZStack {
                    ForEach(Array(visibleCardRange), id: \.self) { idx in
                        let student = students[idx]
                        let isTop = idx == cardIndex
                        let stackOffset = idx - cardIndex
                        studentCardContent(student: student)
                            .scaleEffect(1 - CGFloat(stackOffset) * 0.04)
                            .offset(y: CGFloat(stackOffset) * 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: cardIndex)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(isTop ? 0.12 : 0.06), radius: isTop ? 16 : 8, y: isTop ? 8 : 4)
                            .offset(x: isTop ? cardDragOffset : 0)
                            .rotationEffect(.degrees(isTop ? Double(cardDragOffset) / 12 : 0))
                            .onLongPressGesture {
                                if isTop {
                                    typePickerStudent = student
                                }
                            }
                            .overlay(alignment: .leading) {
                                if isTop && cardDragOffset > 15 {
                                    let progress = min(1, Double(cardDragOffset) / 90)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundStyle(.green)
                                        .opacity(progress)
                                        .scaleEffect(0.6 + 0.4 * progress)
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                                            removal: .scale(scale: 0.8).combined(with: .opacity)
                                        ))
                                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: cardDragOffset)
                                        .padding(.leading, 28)
                                }
                            }
                            .overlay(alignment: .trailing) {
                                if isTop && cardDragOffset < -15 {
                                    let progress = min(1, Double(-cardDragOffset) / 90)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 56))
                                        .foregroundStyle(.red)
                                        .opacity(progress)
                                        .scaleEffect(0.6 + 0.4 * progress)
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                                            removal: .scale(scale: 0.8).combined(with: .opacity)
                                        ))
                                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: cardDragOffset)
                                        .padding(.trailing, 28)
                                }
                            }
                            .zIndex(Double(cardStackSize - stackOffset))
                    }
                    if let student = currentCardStudent {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .zIndex(Double(cardStackSize + 1))
                            .onLongPressGesture {
                                typePickerStudent = student
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        guard !isFlickingAway else { return }
                                        cardDragOffset = value.translation.width
                                    }
                                    .onEnded { value in
                                        guard !isFlickingAway else { return }
                                        let threshold: CGFloat = 80
                                        let velocity = value.predictedEndTranslation.width - value.translation.width
                                        if value.translation.width > threshold || velocity > 200 {
                                            flickCard(direction: 1, student: student, code: "yes")
                                        } else if value.translation.width < -threshold || velocity < -200 {
                                            flickCard(direction: -1, student: student, code: "no")
                                        } else {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                cardDragOffset = 0
                                            }
                                        }
                                    }
                            )
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 8) {
                    HStack(spacing: 24) {
                        if cardIndex > 0 {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    cardIndex -= 1
                                }
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    cardIndex += 1
                                }
                            } label: {
                                Label("Skip", systemImage: "forward.fill")
                                .font(.subheadline)
                        }
                    }
                    Text("Swipe right = Here · Swipe left = Not here · Long press for more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    private func flickCard(direction: Int, student: TeachAttendanceStudent, code: String) {
        isFlickingAway = true
        pendingChanges[student.id] = code
        let exitX = CGFloat(direction) * 450
        withAnimation(.easeOut(duration: 0.28)) {
            cardDragOffset = exitX
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                advanceCard()
                cardDragOffset = 0
            }
            isFlickingAway = false
        }
    }

    private func studentCardContent(student: TeachAttendanceStudent) -> some View {
        let resolved = resolveAttendanceStatus(student)
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))

            VStack(spacing: 28) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 88, height: 88)
                    .overlay {
                        Text(String((student.prefname ?? student.firstname).prefix(1)))
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                VStack(spacing: 8) {
                    Text((student.prefname ?? student.firstname) + " " + student.surname)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    if let rollgroup = student.rollgroupname, !rollgroup.isEmpty {
                        Text(rollgroup)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let resolved {
                    HStack(spacing: 8) {
                        Image(systemName: resolved.icon)
                            .font(.title3)
                        Text(resolved.label)
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(statusColor(resolved.label))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(statusColor(resolved.label).opacity(0.2)))
                } else {
                    Text("Swipe to mark")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(36)
        }
    }

    private func advanceCard() {
        if cardIndex < students.count - 1 {
            cardIndex += 1
        } else {
            cardIndex = students.count
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
                FeedbackManager.longVibration()
                FeedbackManager.playSuccess()
            }
            await load()
        } catch {
            saveError = error.localizedDescription
            await MainActor.run {
                // Error feedback removed
            }
        }
        isSaving = false
    }

    @ViewBuilder
    private func studentRow(_ student: TeachAttendanceStudent) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(student.prefname ?? student.firstname)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                Text(student.surname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                if let rollgroup = student.rollgroupname, !rollgroup.isEmpty {
                    Text(rollgroup)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            Spacer()

            attendanceStatusBadge(for: student)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func attendanceStatusBadge(for student: TeachAttendanceStudent) -> some View {
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
