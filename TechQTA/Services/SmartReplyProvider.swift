//
//  SmartReplyProvider.swift
//  TechQTA
//

import Foundation

/// Unified smart reply provider: Apple Intelligence first, then Cloudflare. Uses cache per message.
enum SmartReplyProvider {
    static var isAvailable: Bool {
        AppleIntelligenceService.isAvailable || CloudflareConfig.isAvailable
    }

    /// Fetch smart replies, using cache when available. Pass forceRegenerate: true to bypass cache.
    static func suggestReplies(for messageContent: String, messageID: Int, forceRegenerate: Bool = false) async -> [String]? {
        if !forceRegenerate, let cached = SmartReplyCache.get(messageID: messageID) {
            return cached
        }
        let replies: [String]?
        if AppleIntelligenceService.isAvailable {
            replies = await AppleIntelligenceService.suggestReplies(for: messageContent)
        } else if CloudflareConfig.isAvailable {
            replies = await CloudflareAIService.suggestReplies(for: messageContent)
        } else {
            replies = nil
        }
        if let replies, !replies.isEmpty {
            SmartReplyCache.set(messageID: messageID, replies: replies)
        }
        return replies
    }
}
