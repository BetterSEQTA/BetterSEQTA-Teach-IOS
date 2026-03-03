//
//  SetupOnboardingView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct SetupOnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let cards: [(title: String, icon: String, body: String)] = [
        (
            "Enter your SEQTA Teach URL",
            "link",
            "Type your school's SEQTA Teach address (e.g. school.seqta.com.au). The app will open a secure browser for the next step."
        ),
        (
            "Log in as usual",
            "person.crop.circle.badge.checkmark",
            "Sign in with your normal SEQTA Teach credentials in the in-app browser. Use your school login or SSO—whatever you usually use."
        ),
        (
            "Tap Done when you're in",
            "checkmark.circle.fill",
            "Once you see your SEQTA Teach home or welcome screen, tap **Done** in the top right. The app will then securely capture your session so you can use timetable and messages."
        ),
        (
            "Your data stays on your device",
            "lock.shield.fill",
            "Your session cookie is stored only in the iOS Keychain on this device. We don't send your login to any other server. You can log out anytime from the app."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    setupCard(
                        title: card.title,
                        icon: card.icon,
                        body: card.body
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if currentPage == cards.count - 1 {
                Button {
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage += 1
                    }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func setupCard(title: String, icon: String, body: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(28)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}
