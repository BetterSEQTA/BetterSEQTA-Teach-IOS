//
//  TeachTimetableClient.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import Foundation

struct TeachLesson: Identifiable {
    let id: String
    let from: String
    let until: String
    let period: String?
    let description: String?
    let code: String?
    let staff: String?
    let room: String?
    let classunit: String?
    let attendance: Any?
    let programmeID: Int?
    let metaID: Int?
    let isAdhoc: Bool
}

struct TeachTimetableClient {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func fetchLessons(session: TeachSession, staffId: Int, dateFrom: String, dateTo: String) async throws -> [TeachLesson] {
        try await fetchTerms(session: session)
        async let timetableResult = fetchTimetabled(session: session, staffId: staffId, dateFrom: dateFrom, dateTo: dateTo)
        async let adhocResult = fetchAdhoc(session: session, staffId: staffId, dateFrom: dateFrom, dateTo: dateTo)

        let (timetablePayload, adhocPayload) = try await (timetableResult, adhocResult)
        return processTimetableData(timetablePayload: timetablePayload, adhocPayload: adhocPayload, dateFrom: dateFrom, dateTo: dateTo)
    }

    private func fetchTerms(session: TeachSession) async throws {
        let body: [String: Any] = [
            "request": "terms",
            "asArray": true
        ]
        let (_, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/get", body: body)
        guard (200...299).contains(response.statusCode) else {
            throw SeqtaRequestError.invalidURL
        }
    }

    private func fetchTimetabled(session: TeachSession, staffId: Int, dateFrom: String, dateTo: String) async throws -> [String: Any] {
        let body: [String: Any] = [
            "timetabled": true,
            "untimetabled": true,
            "dateFrom": dateFrom,
            "dateTo": dateTo,
            "staff": staffId
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/timetable/get", body: body)
        guard (200...299).contains(response.statusCode) else {
            return [:]
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["payload"] as? [String: Any] ?? [:]
    }

    private func fetchAdhoc(session: TeachSession, staffId: Int, dateFrom: String, dateTo: String) async throws -> [String: Any] {
        let body: [String: Any] = [
            "dateFrom": dateFrom,
            "dateTo": dateTo,
            "staff": staffId
        ]
        let (data, response) = try await seqtaPOST(session: session, path: "/seqta/ta/json/timetable/adhoc/get", body: body)
        guard (200...299).contains(response.statusCode) else {
            return [:]
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["payload"] as? [String: Any] ?? [:]
    }

    private func processTimetableData(timetablePayload: [String: Any], adhocPayload: [String: Any], dateFrom: String, dateTo: String) -> [TeachLesson] {
        var lessons: [TeachLesson] = []

        // Build lookup: adhoc classunit id -> description, code, staff
        let adhocClassUnits = buildAdhocClassUnitLookup(adhocPayload)

        if let timetabled = timetablePayload["timetabled"] as? [String: Any],
           let periods = timetabled["periods"] as? [[String: Any]] {
            for period in periods {
                for (key, value) in period {
                    guard key.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil,
                          key >= dateFrom, key <= dateTo,
                          let lessonArray = value as? [[String: Any]] else { continue }
                    for (idx, lesson) in lessonArray.enumerated() {
                        if let l = parseLesson(lesson, index: idx, isAdhoc: false, adhocClassUnits: nil) {
                            lessons.append(l)
                        }
                    }
                }
            }
        }

        if let adhocList = adhocPayload["adhoc"] as? [[String: Any]] {
            for (idx, adhoc) in adhocList.enumerated() {
                guard let dateStr = adhoc["date"] as? String, dateStr >= dateFrom, dateStr <= dateTo else { continue }
                if let l = parseLesson(adhoc, index: idx, isAdhoc: true, adhocClassUnits: adhocClassUnits) {
                    lessons.append(l)
                }
            }
        }

        var seen = Set<String>()
        var unique: [TeachLesson] = []
        for l in lessons {
            let key = "\(l.id)-\(l.from)-\(l.until)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(l)
            }
        }
        return unique.sorted { $0.from < $1.from }
    }

    private struct AdhocClassUnitInfo {
        let description: String?
        let code: String?
        let staff: String?
    }

    private func buildAdhocClassUnitLookup(_ adhocPayload: [String: Any]) -> [Int: AdhocClassUnitInfo] {
        var map: [Int: AdhocClassUnitInfo] = [:]
        guard let units = adhocPayload["adhoc_classunits"] as? [[String: Any]] else { return map }
        for unit in units {
            guard let id = unit["id"] as? Int else { continue }
            let desc = unit["description"] as? String
            let code = unit["code"] as? String ?? unit["name"] as? String
            let staff = unit["staff"] as? String
            map[id] = AdhocClassUnitInfo(description: desc, code: code, staff: staff)
        }
        return map
    }

    private func parseLesson(_ raw: [String: Any], index: Int, isAdhoc: Bool, adhocClassUnits: [Int: AdhocClassUnitInfo]?) -> TeachLesson? {
        let from = (raw["from"] as? String).map { String($0.prefix(5)) } ?? ""
        let until = (raw["until"] as? String).map { String($0.prefix(5)) } ?? ""
        let id = (raw["id"] as? Int).map { "\($0)" } ?? "\(index)-\(from)-\(until)"
        let programmeID = raw["programmeID"] as? Int ?? raw["programme"] as? Int
        let metaID = raw["metaID"] as? Int ?? raw["metaclass"] as? Int

        var description: String?
        var code: String?
        var staff: String?
        var room: String?

        if isAdhoc, let classunitId = raw["classunit"] as? Int, let units = adhocClassUnits, let info = units[classunitId] {
            description = info.description
            code = info.code
            staff = info.staff
        }
        description = description ?? raw["description"] as? String
        code = code ?? raw["code"] as? String
        if staff == nil {
            if let s = raw["staff"] as? String { staff = s }
            else if let n = raw["staff"] as? Int { staff = "\(n)" }
        }
        room = raw["room_code"] as? String ?? raw["room"] as? String ?? (raw["room"] as? Int).map { "\($0)" }
        let period = raw["period"] as? String

        return TeachLesson(
            id: id,
            from: from,
            until: until,
            period: period,
            description: description,
            code: code,
            staff: staff,
            room: room,
            classunit: (raw["classunit"] as? Int).map { "\($0)" } ?? raw["classunit"] as? String,
            attendance: raw["attendance"],
            programmeID: programmeID,
            metaID: metaID,
            isAdhoc: isAdhoc
        )
    }
}
