//
//  AppleIntelligenceService.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/5/2026.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceService {
    /// Whether Apple Intelligence (Foundation Models) is available on this device.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            case .unavailable:
                return false
            @unknown default:
                return false
            }
        }
        #endif
        return false
    }

    /// Proofreads the given text: fixes spelling, grammar, and punctuation.
    /// - Parameter text: Plain text to proofread.
    /// - Returns: Proofread text, or nil if unavailable or failed.
    static func proofread(_ text: String) async -> String? {
        #if canImport(FoundationModels)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard #available(iOS 26.0, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let instructions = """
        You are a proofreader. Fix spelling, grammar, and punctuation in the user's text.
        Return ONLY the corrected text. Do not add explanations, quotes, or extra formatting.
        Preserve the original meaning and structure.
        """

        do {
            let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
            let response = try await session.respond(to: text)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Rewrites the text with the specified tone.
    /// - Parameters:
    ///   - text: Plain text to rewrite.
    ///   - tone: Desired tone (e.g. "professional", "friendly", "concise").
    /// - Returns: Rewritten text, or nil if unavailable or failed.
    static func changeTone(_ text: String, to tone: String) async -> String? {
        #if canImport(FoundationModels)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard #available(iOS 26.0, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let instructions = """
        You are a writing assistant. Rewrite the user's text to be \(tone).
        Return ONLY the rewritten text. Do not add explanations, quotes, or extra formatting.
        Keep the same general meaning and length.
        """

        do {
            let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
            let response = try await session.respond(to: text)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Suggests 2–3 short reply options based on the message content.
    /// - Parameter messageContent: Plain text of the message to reply to.
    /// - Returns: Array of suggested reply strings, or nil if unavailable or failed.
    static func suggestReplies(for messageContent: String) async -> [String]? {
        #if canImport(FoundationModels)
        guard !messageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard #available(iOS 26.0, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let instructions = """
        You are a helpful assistant suggesting short email replies. Given a message, suggest 2–3 brief, professional reply options.
        Return ONLY the replies, one per line. No numbering, bullets, or labels. Each reply should be 1–2 sentences max.
        Be concise and appropriate for a teacher replying to students or colleagues.
        """

        let prompt = "Message to reply to:\n\n\(messageContent.prefix(2000))"

        do {
            let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
            let response = try await session.respond(to: prompt)
            let lines = response.content
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Array(lines.prefix(3))
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
