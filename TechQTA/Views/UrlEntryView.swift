//
//  UrlEntryView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct UrlEntryView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @State private var urlString = ""
    @State private var validationError: String?

    private var validatedUrl: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var input = trimmed
        if !input.hasPrefix("http://") && !input.hasPrefix("https://") {
            input = "https://" + input
        }
        if input.hasSuffix("/") {
            input = String(input.dropLast())
        }
        return URL(string: input)
    }

    private var isLoginEnabled: Bool {
        validatedUrl != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to SEQTA Teach")
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text("Enter your school's SEQTA Teach URL to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("School URL")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("school.seqta.com.au", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: urlString) { _, _ in
                            validationError = nil
                        }

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    guard let url = validatedUrl else { return }
                    sessionManager.startLogin(with: url)
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isLoginEnabled)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }
}
