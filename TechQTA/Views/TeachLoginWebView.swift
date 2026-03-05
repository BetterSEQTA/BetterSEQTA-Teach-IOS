//
//  TeachLoginWebView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI
import WebKit

struct TeachLoginWebView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @State private var captureTrigger = 0
    let baseUrl: URL
    let onLoginSuccess: (TeachSession) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            WebViewRepresentable(
                baseUrl: baseUrl,
                captureTrigger: captureTrigger,
                onLoginSuccess: onLoginSuccess,
                onCancel: onCancel,
                onTimeout: { sessionManager.setLoginError("Login timed out. Please try again.") }
            )
            .overlay(alignment: .top) {
                if case .error(let msg) = sessionManager.loginStatus {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap **Done** when you're signed in")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Your session stays on this device only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .navigationTitle(baseUrl.host ?? "SEQTA Teach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    FeedbackManager.doubleTap()
                    onCancel()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    FeedbackManager.longThenShort()
                    captureTrigger += 1
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let baseUrl: URL
    let captureTrigger: Int
    let onLoginSuccess: (TeachSession) -> Void
    let onCancel: () -> Void
    let onTimeout: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.processPool = WKProcessPool()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        let teachUrl = buildTeachUrl(from: baseUrl)
        webView.load(URLRequest(url: teachUrl))

        context.coordinator.startCookiePolling(webView: webView, baseUrl: baseUrl, onTimeout: onTimeout)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.captureCookiesIfTriggered(webView: uiView, trigger: captureTrigger, baseUrl: baseUrl, onSuccess: onLoginSuccess)
    }

    private func buildTeachUrl(from base: URL) -> URL {
        let baseString = base.absoluteString
        let trimmed = baseString.hasSuffix("/") ? String(baseString.dropLast()) : baseString
        if trimmed.contains("/seqta/ta") {
            return base
        }
        return URL(string: trimmed + "/seqta/ta") ?? base
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable
        private var cookiePollTimer: Timer?
        private let pollInterval: TimeInterval = 1.0
        private let timeout: TimeInterval = 180
        private var startTime: Date?
        private var lastCaptureTrigger = 0

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func captureCookiesIfTriggered(webView: WKWebView, trigger: Int, baseUrl: URL, onSuccess: @escaping (TeachSession) -> Void) {
            guard trigger != lastCaptureTrigger, trigger > 0 else { return }
            lastCaptureTrigger = trigger
            stopPolling()
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let host = baseUrl.host ?? ""
                let jsessionId = cookies.first { cookie in
                    cookie.name == "JSESSIONID" &&
                    (cookie.domain == host || host.hasSuffix(cookie.domain) || cookie.domain.hasSuffix("." + host)) &&
                    (cookie.path == "/" || cookie.path.hasPrefix("/seqta"))
                }?.value
                if let jsessionId, !jsessionId.isEmpty {
                    let session = TeachSession(baseUrl: baseUrl, jsessionId: jsessionId, lastHeartbeatAt: nil)
                    Task { @MainActor in
                        onSuccess(session)
                    }
                }
            }
        }

        func startCookiePolling(webView: WKWebView, baseUrl: URL, onTimeout: @escaping () -> Void) {
            startTime = Date()
            cookiePollTimer?.invalidate()
            cookiePollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
                self?.checkCookies(webView: webView, baseUrl: baseUrl, onTimeout: onTimeout)
            }
            cookiePollTimer?.tolerance = 0.2
        }

        func checkCookies(webView: WKWebView, baseUrl: URL, onTimeout: @escaping () -> Void) {
            guard let start = startTime, Date().timeIntervalSince(start) < timeout else {
                stopPolling()
                Task { @MainActor in
                    onTimeout()
                }
                return
            }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                let host = baseUrl.host ?? ""
                let jsessionId = cookies.first { cookie in
                    cookie.name == "JSESSIONID" &&
                    (cookie.domain == host || host.hasSuffix(cookie.domain) || cookie.domain.hasSuffix("." + host)) &&
                    (cookie.path == "/" || cookie.path.hasPrefix("/seqta"))
                }?.value

                guard let jsessionId, !jsessionId.isEmpty else { return }

                let path = webView.url?.path ?? ""
                let fragment = webView.url?.fragment ?? ""
                let isOnWelcomePage = path.contains("welcome") || fragment.contains("welcome")

                if isOnWelcomePage {
                    stopPolling()
                    let session = TeachSession(baseUrl: baseUrl, jsessionId: jsessionId, lastHeartbeatAt: nil)
                    Task { @MainActor in
                        self.parent.onLoginSuccess(session)
                    }
                }
            }
        }

        func checkCookies(webView: WKWebView, baseUrl: URL) {
            checkCookies(webView: webView, baseUrl: baseUrl, onTimeout: {})
        }

        func stopPolling() {
            cookiePollTimer?.invalidate()
            cookiePollTimer = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(webView: webView, baseUrl: parent.baseUrl)
        }

        deinit {
            stopPolling()
        }
    }
}
