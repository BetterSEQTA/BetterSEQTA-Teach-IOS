//
//  String+HTML.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/5/2026.
//

import Foundation

extension String {
    /// Extracts plain text from HTML by stripping tags.
    var plainTextFromHTML: String {
        guard let data = data(using: .utf8),
              let attr = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
        }
        return attr.string
    }

    /// Wraps plain text in HTML paragraph tags, escaping entities.
    var wrappedInHTMLParagraphs: String {
        let escaped = self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let paragraphs = escaped.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if paragraphs.isEmpty {
            return "<p></p>"
        }
        return paragraphs.map { "<p>\($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\n", with: "<br>"))</p>" }.joined()
    }
}
