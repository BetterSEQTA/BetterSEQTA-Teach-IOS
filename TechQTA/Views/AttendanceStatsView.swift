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
        let dateTime = "\(dateStr), \(lesson.from) – \(lesson.until)"
        if let subject = lesson.description, !subject.isEmpty {
            return "\(subject) · \(dateTime)"
        }
        return dateTime
    }

    var body: some View {
        List {
            Section {
                statsSummaryCard
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(students) { student in
                    if let summary = summaryByStudent[student.id] {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(summary.present >= 1 ? Color.green.opacity(0.2) : Color(.systemGray5))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Text(String((student.prefname ?? student.firstname).prefix(1)))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(summary.present >= 1 ? .green : .secondary)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text((student.prefname ?? student.firstname) + " " + student.surname)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Text("\(summary.percent)%")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(summary.present >= 1 ? .green : .secondary)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
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

    private var statsSummaryCard: some View {
        let presentCount = summaryByStudent.values.filter { $0.present >= 1 }.count
        let total = students.count
        let percent = total > 0 ? Int((Double(presentCount) / Double(total)) * 100) : 0

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("\(presentCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("present")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(spacing: 6) {
                    Text("\(percent)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("attendance")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
            }

            Text("\(presentCount) of \(total) students marked present")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
