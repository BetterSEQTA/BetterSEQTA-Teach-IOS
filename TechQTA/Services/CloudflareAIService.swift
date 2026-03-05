//
//  CloudflareAIService.swift
//  TechQTA
//

import Foundation

/// Cloudflare Workers AI: Llama for rewrites, BART for summaries.
enum CloudflareAIService {

    // MARK: - Llama (rewrites: proofread, tone, smart replies)

    /// Proofread: fix spelling, grammar, punctuation.
    static func proofread(_ text: String) async -> String? {
        let prompt = """
        You are a proofreader. Fix spelling, grammar, and punctuation in the user's text.
        Return ONLY the corrected text. Do not add explanations, quotes, or extra formatting.
        Preserve the original meaning and structure.
        """
        return await runLlama(system: prompt, user: text)
    }

    /// Rewrite with specified tone.
    static func changeTone(_ text: String, to tone: String) async -> String? {
        let prompt = """
        You are a writing assistant. Rewrite the user's text to be \(tone).
        Return ONLY the rewritten text. Do not add explanations, quotes, or extra formatting.
        Keep the same general meaning and length.
        """
        return await runLlama(system: prompt, user: text)
    }

    /// Suggest 2–3 short reply options.
    static func suggestReplies(for messageContent: String) async -> [String]? {
        let prompt = """
        You are a helpful assistant suggesting short email replies. Given a message, suggest 2–3 brief, professional reply options.
        Return ONLY the replies, one per line. No numbering, bullets, or labels. Each reply should be 1–2 sentences max.
        Be concise and appropriate for a teacher replying to students or colleagues.
        """
        let user = "Message to reply to:\n\n\(messageContent.prefix(2000))"
        guard let result = await runLlama(system: prompt, user: user) else { return nil }
        let lines = result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines.prefix(3))
    }

    private static func runLlama(system: String, user: String) async -> String? {
        guard let base = CloudflareConfig.baseURL(),
              let auth = CloudflareConfig.authHeader() else { return nil }
        let url = base.appendingPathComponent("@cf/meta/llama-3.1-8b-instruct-fast")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let result = json?["result"] as? [String: Any]
            let content = result?["response"] as? String
            return content?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - BART (summaries – free tier)

    /// Summarize text using BART-large-CNN.
    /// - Parameters:
    ///   - text: Plain text to summarize.
    ///   - maxLength: Max summary length (default 3 sentences).
    static func summarize(_ text: String, maxLength: Int = 130) async -> String? {
        guard let base = CloudflareConfig.baseURL(),
              let auth = CloudflareConfig.authHeader() else { return nil }
        let url = base.appendingPathComponent("@cf/facebook/bart-large-cnn")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "input_text": String(text.prefix(1024)),
            "max_length": maxLength
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let result = json?["result"] as? [String: Any]
            let summary = result?["summary"] as? String
            return summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
