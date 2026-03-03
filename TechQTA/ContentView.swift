//
//  ContentView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @StateObject private var sessionManager = TeachSessionManager()

    var body: some View {
        NavigationStack {
            Group {
                if !hasCompletedSetup {
                    SetupOnboardingView()
                } else if let session = sessionManager.session {
                    if session.isAuthenticated {
                        HomePlaceholderView()
                    } else {
                        TeachLoginWebView(
                            baseUrl: session.baseUrl,
                            onLoginSuccess: { sessionManager.completeLogin(with: $0) },
                            onCancel: { sessionManager.cancelLogin() }
                        )
                    }
                } else {
                    UrlEntryView()
                }
            }
        }
        .environmentObject(sessionManager)
    }
}
