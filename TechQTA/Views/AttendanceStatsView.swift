//
//  AttendanceStatsView.swift
//  TechQTA
//

import SwiftUI

struct AttendanceStatsView: View {
    let summaryByStudent: [Int: (present: Int, percent: Int)]
    let students: [TeachAttendanceStudent]
    let lesson: TeachLesson
    let date: String

    private var lessonTimeDateTitle: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        guard let d = df.date(from: date) else { return "Stats" }
        let df2 = DateFormatter()
        df2.dateFormat = "d MMM yyyy"
        let dateStr = df2.string(from: d)
        return "\(dateStr), \(lesson.from) – \(lesson.until)"
    }

    var body: some View {
        List {
            Section {
                let presentCount = summaryByStudent.values.filter { $0.present >= 1 }.count
                let total = students.count
                HStack {
                    Label("\(presentCount) / \(total) present", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 8)
            } header: {
                Text("Summary")
            }

            Section {
                ForEach(students) { student in
                    if let summary = summaryByStudent[student.id] {
                        HStack {
                            Text(student.prefname ?? student.firstname)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(student.surname)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(summary.percent)%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(summary.present >= 1 ? .green : .secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("By student")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lessonTimeDateTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
