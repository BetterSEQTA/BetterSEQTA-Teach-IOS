//
//  SmartReplyCache.swift
//  TechQTA
//

import Foundation

/// Caches smart replies per message ID. Persists to UserDefaults.
enum SmartReplyCache {
    private static let keyPrefix = "smart_reply_"
    private static let defaults = UserDefaults.standard

    static func get(messageID: Int) -> [String]? {
        guard let data = defaults.data(forKey: keyPrefix + "\(messageID)"),
              let cached = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return cached
    }

    static func set(messageID: Int, replies: [String]) {
        guard let data = try? JSONEncoder().encode(replies) else { return }
        defaults.set(data, forKey: keyPrefix + "\(messageID)")
    }

    static func clear(messageID: Int) {
        defaults.removeObject(forKey: keyPrefix + "\(messageID)")
    }
}
