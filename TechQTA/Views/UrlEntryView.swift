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
    @FocusState private var isUrlFocused: Bool

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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign in to SEQTA Teach")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Enter your school's address to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("School URL")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        TextField("school.seqta.com.au", text: $urlString)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .submitLabel(.go)
                            .focused($isUrlFocused)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            )
                            .onSubmit {
                                guard let url = validatedUrl else { return }
                                FeedbackManager.doubleTap()
                                sessionManager.startLogin(with: url)
                            }
                            .onChange(of: urlString) { _, _ in
                                validationError = nil
                            }

                        if let error = validationError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                Text(error)
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                        } else {
                            Text("Example: teach.school.edu.au")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 0) {
                Divider()
                Button {
                    guard let url = validatedUrl else { return }
                    FeedbackManager.longThenShort()
                    sessionManager.startLogin(with: url)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isLoginEnabled)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isUrlFocused = true
            }
        }
    }
}
