//
//  AttendanceIconHelper.swift
//  TechQTA
//

import Foundation

/// Maps SEQTA attendance codes to SF Symbol names for display.
enum AttendanceIconHelper {
    private static let codeToSymbol: [String: String] = [
        "yes": "checkmark.circle.fill",
        "no": "xmark.circle.fill",
        "present": "checkmark.circle.fill",
        "in_class": "checkmark.circle.fill",
        "absent": "xmark.circle.fill",
        "alternate": "arrow.triangle.2.circlepath",
        "absenceapproved": "checkmark.circle",
        "camp": "tent.fill",
        "educationalactivity": "book.fill",
        "educationaloffcampus": "building.2",
        "excursion": "bus.fill",
        "exempted": "hand.raised",
        "kiosk": "tag",
        "late": "clock.badge.exclamationmark",
        "latetoclass": "clock",
        "learningathome": "house.fill",
        "medical": "cross.case.fill",
        "music": "music.note",
        "notapplicable": "minus.circle",
        "parentcontact": "phone.fill",
        "resolvedabsence": "checkmark.circle",
        "reset": "arrow.counterclockwise",
        "sickbay": "cross.case.fill",
        "staffadvice": "exclamationmark.bubble.fill",
        "suspendedexternal": "lock.fill",
        "suspended": "lock.open",
        "truant": "person.crop.circle.badge.xmark",
        "tutor": "person.fill",
        "absenceunapproved": "xmark.circle",
        "unresolvedabsence": "questionmark.circle",
        "unresolvedlate": "clock.badge.questionmark",
        "withdrawn": "person.crop.circle.badge.minus",
        "kiosk-zero": "tag",
    ]

    static func sfSymbol(for code: String) -> String? {
        codeToSymbol[code.lowercased()]
    }
}
