//
//  ContentView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var setupCompleteForThisLogin = false
    @StateObject private var sessionManager = TeachSessionManager()

    var body: some View {
        Group {
            if let session = sessionManager.session, session.isAuthenticated {
                TabRootView()
            } else {
                NavigationStack {
                    Group {
                        if let session = sessionManager.session {
                            TeachLoginWebView(
                                baseUrl: session.baseUrl,
                                onLoginSuccess: { sessionManager.completeLogin(with: $0) },
                                onCancel: { sessionManager.cancelLogin() }
                            )
                            .transition(.move(edge: .bottom))
                        } else {
                            if setupCompleteForThisLogin {
                                UrlEntryView()
                                    .transition(.opacity)
                            } else {
                                SetupOnboardingView {
                                    withAnimation {
                                        setupCompleteForThisLogin = true
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
        }

        .environmentObject(sessionManager)
        .onChange(of: sessionManager.session) { _, newValue in
            if newValue == nil {
                setupCompleteForThisLogin = false
            }
        }
    }
}
