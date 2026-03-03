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
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 20) {
                    Image(systemName: "link")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.tint)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("School URL")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("Enter your school's SEQTA Teach address. You'll log in in the next step, then tap Done.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("school.seqta.com.au", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .submitLabel(.go)
                            .focused($isUrlFocused)
                            .onSubmit {
                                guard let url = validatedUrl else { return }
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
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        guard let url = validatedUrl else { return }
                        sessionManager.startLogin(with: url)
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isLoginEnabled)
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isUrlFocused = true
            }
        }
    }
}
