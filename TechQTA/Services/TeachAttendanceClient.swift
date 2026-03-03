//
//  TeachAttendanceClient.swift
//  TechQTA
//

import Foundation

/// Attendance type from POST /seqta/ta/attendance/types
struct TeachAttendanceType: Identifiable {
    let id: Int
    let code: String
    let label: String
    let icon: String?
    let consideredPresent: Bool?
    let isReset: Bool?
    let kioskEnabled: Bool?
    let explanation: String?
}

/// Student from attendance load payload
struct TeachAttendanceStudent: Identifiable {
    let id: Int
    let firstname: String
    let surname: String
    let prefname: String?
    let code: String
    let email: String?
    let year: String?
    let rollgroupname: String?
    let attendance: [String: [String: Any]]
}

struct TeachAttendanceClient {
    /// Fetch attendance types. Use only "yes" and "no" for now; full list stored for later.
    func fetchAttendanceTypes(session: TeachSession) async throws -> [TeachAttendanceType] {
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/attendance/types", body: [:])
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [[String: Any]] ?? []
        return payload.compactMap { parseAttendanceType($0) }
    }

    /// Load attendance for a lesson. Adhoc: classes=[classunitId], current=true. Timetabled: classes=[classunitId,classunitId], current=false.
    func fetchAttendanceLoad(session: TeachSession, date: String, classunitIds: [Int], isAdhoc: Bool) async throws -> [String: Any] {
        let body: [String: Any] = [
            "mode": "normal",
            "date": date,
            "classes": classunitIds,
            "current": isAdhoc
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/attendance/load", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["payload"] as? [String: Any] ?? [:]
    }

    /// Save attendance. Body: {"attendance":{"<classInstanceId>":{"<studentId>":"<typeCode>"}}}
    func saveAttendance(session: TeachSession, attendance: [String: [String: String]]) async throws {
        let body: [String: Any] = ["attendance": attendance]
        let (_, response) = try await seqtaPOST(session: session, path: "/seqta/ta/attendance/save", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
    }

    /// Fetch attendance summary (adhoc only). Call after fetchAttendanceLoad. Returns studentId -> (present, percent).
    func fetchAttendanceSummary(session: TeachSession, date: String, studentIds: [Int], classunitIds: [Int]) async throws -> [Int: (present: Int, percent: Int)] {
        let body: [String: Any] = [
            "date": date,
            "students": studentIds,
            "classes": classunitIds,
            "mode": "inclass"
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/attendance/summary", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = json?["payload"] as? [String: Any] ?? [:]
        let studentsRaw = payload["students"] as? [[String: Any]] ?? []
        var result: [Int: (present: Int, percent: Int)] = [:]
        for item in studentsRaw {
            guard let studentId = item["student"] as? Int else { continue }
            let att = item["attendance"] as? [String: Any] ?? [:]
            let present = att["present"] as? Int ?? 0
            let percent = att["percent"] as? Int ?? 0
            result[studentId] = (present, percent)
        }
        return result
    }

    private func parseAttendanceType(_ raw: [String: Any]) -> TeachAttendanceType? {
        guard let id = raw["id"] as? Int else { return nil }
        let code = raw["code"] as? String ?? ""
        let label = raw["label"] as? String ?? ""
        let icon = raw["icon"] as? String
        let consideredPresent: Bool? = (raw["considered_present"] as? Bool) ?? (raw["considered_present"] as? Int).map { $0 == 1 }
        let isReset = (raw["is_reset"] as? Int) == 1 || (raw["is_reset"] as? Bool) == true
        let kioskEnabled = (raw["kioskEnabled"] as? Int) == 1 || (raw["kioskEnabled"] as? Bool) == true
        let explanation = raw["explanation"] as? String
        return TeachAttendanceType(
            id: id,
            code: code,
            label: label,
            icon: icon,
            consideredPresent: consideredPresent,
            isReset: isReset == true ? true : nil,
            kioskEnabled: kioskEnabled ? true : nil,
            explanation: explanation
        )
    }

    func parseStudents(from payload: [String: Any]) -> [TeachAttendanceStudent] {
        let raw = payload["students"] as? [[String: Any]] ?? []
        return raw.compactMap { parseStudent($0) }
    }

    private func parseStudent(_ raw: [String: Any]) -> TeachAttendanceStudent? {
        guard let id = raw["id"] as? Int else { return nil }
        let firstname = raw["firstname"] as? String ?? ""
        let surname = raw["surname"] as? String ?? ""
        let prefname = raw["prefname"] as? String
        let code = raw["code"] as? String ?? ""
        let email = raw["email"] as? String
        let year = raw["year"] as? String
        let rollgroupname = raw["rollgroupname"] as? String
        let attendance = raw["attendance"] as? [String: [String: Any]] ?? [:]
        return TeachAttendanceStudent(
            id: id,
            firstname: firstname,
            surname: surname,
            prefname: prefname,
            code: code,
            email: email,
            year: year,
            rollgroupname: rollgroupname,
            attendance: attendance
        )
    }
}
