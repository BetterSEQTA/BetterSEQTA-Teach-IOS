//
//  ContentView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @State private var setupCompleteForThisLogin = false
    @State private var isLocked = false
    @StateObject private var sessionManager = TeachSessionManager()

    private var shouldShowLockGate: Bool {
        faceIDEnabled && sessionManager.session?.isAuthenticated == true && isLocked
    }

    var body: some View {
        Group {
            if let session = sessionManager.session, session.isAuthenticated {
                ZStack {
                    TabRootView()
                    if shouldShowLockGate {
                        FaceIDLockOverlay(
                            onUnlock: unlockWithBiometrics,
                            onDismiss: { isLocked = false }
                        )
                        .id(scenePhase)
                    }
                }
            } else {
                NavigationStack {
                    Group {
                        if let session = sessionManager.session {
                            TeachLoginWebView(
                                baseUrl: session.baseUrl,
                                onLoginSuccess: { session in
                                    FeedbackManager.success()
                                    FeedbackManager.playSuccess()
                                    sessionManager.completeLogin(with: session)
                                },
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
        .onAppear {
            sessionManager.onLogout = { setupCompleteForThisLogin = false }
            if sessionManager.session?.isAuthenticated == true && faceIDEnabled {
                isLocked = true
            }
        }
        .onChange(of: sessionManager.session?.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated == true && faceIDEnabled {
                isLocked = true
            }
        }
        .task(id: sessionManager.session?.jsessionId) {
            if sessionManager.session?.isAuthenticated == true && faceIDEnabled {
                isLocked = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                BackgroundPollManager.shared.startForegroundPolling()
            case .background:
                BackgroundPollManager.shared.stopForegroundPolling()
                BackgroundPollManager.shared.scheduleAppRefresh()
                if faceIDEnabled && sessionManager.session?.isAuthenticated == true {
                    isLocked = true
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private func unlockWithBiometrics() async -> Bool {
        await BiometricAuthHelper.authenticate(reason: "Unlock BetterSEQTA Teach")
    }
}

// MARK: - Face ID Lock Overlay

private struct FaceIDLockOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let onUnlock: () async -> Bool
    let onDismiss: () -> Void
    @State private var phase: OverlayPhase = .idle
    @State private var hasAttempted = false

    private enum OverlayPhase {
        case idle
        case authenticating
        case success
        case failed
    }

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            (isDark ? Color.black : Color.white).opacity(isDark ? 0.95 : 0.98)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)

                    Image(systemName: phase == .success ? "checkmark.circle.fill" : (BiometricAuthHelper.biometricType == .faceID ? "faceid" : "touchid"))
                        .font(.system(size: phase == .success ? 56 : 52))
                        .foregroundStyle(phase == .success ? .green : (isDark ? .white : .primary))
                        .symbolEffect(.bounce, value: phase == .success)
                }
                .scaleEffect(phase == .success ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: phase)

                VStack(spacing: 8) {
                    Text(phase == .success ? "Unlocked" : "Unlock with \(BiometricAuthHelper.biometricTypeName)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(isDark ? .white : .primary)
                }

                if phase == .failed {
                    Button {
                        FeedbackManager.light()
                        phase = .authenticating
                        Task { await attemptUnlock() }
                    } label: {
                        Text("Try again")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(isDark ? .white.opacity(0.8) : .primary.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 1.02)))
        .onAppear {
            if !hasAttempted {
                hasAttempted = true
                phase = .authenticating
                Task { await attemptUnlock() }
            }
        }
    }

    private func attemptUnlock() async {
        let success = await onUnlock()
        await MainActor.run {
            if success {
                phase = .success
                FeedbackManager.success()
                FeedbackManager.playSuccess()
            } else {
                phase = .failed
            }
        }
        if success {
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    onDismiss()
                }
            }
        }
    }
}
