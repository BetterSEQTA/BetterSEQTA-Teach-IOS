import SwiftUI
import WebKit

struct DireqtMessageDetailView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Environment(\.colorScheme) private var colorScheme

    let messageID: Int

    @StateObject private var viewModel = MessageDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading message…")
                    .padding()
            } else if let errorMessage = viewModel.errorMessage, viewModel.detail == nil {
                ContentUnavailableView("Message unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let detail = viewModel.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.subject ?? "No subject")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)

                            if let sender = detail.sender {
                                Text(sender)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let date = detail.date {
                                Text(date, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        if let body = detail.body, !body.isEmpty {
                            if isProbablyHTML(body) {
                                HTMLStringView(html: body, colorScheme: colorScheme)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 420)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Text(body)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        } else {
                            Text("No message content.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        if !detail.participants.isEmpty {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Participants")
                                    .font(.headline)

                                ForEach(detail.participants) { participant in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(participant.name)
                                                .font(.subheadline)
                                            if !participant.type.isEmpty {
                                                Text(participant.type.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if participant.read {
                                            Text("Read")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Unread")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Message")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Message unavailable",
                    systemImage: "bubble.left.and.exclamationmark.bubble.right",
                    description: Text("Couldn't load this message.")
                )
            }
        }
        .task(id: "\(sessionManager.session?.jsessionId ?? "")-\(messageID)") {
            await viewModel.loadIfNeeded(session: sessionManager.session, messageID: messageID)
        }
    }

    private func isProbablyHTML(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("<!doctype html") { return true }
        if trimmed.hasPrefix("<html") { return true }
        if trimmed.contains("<body") { return true }
        if trimmed.contains("<div") || trimmed.contains("<table") { return true }
        return false
    }
}

private struct HTMLStringView: UIViewRepresentable {
    let html: String
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = false
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let rendered = wrapHTMLIfNeeded(html, colorScheme: colorScheme)
        webView.loadHTMLString(rendered, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Keep content in-app, but allow tapping external links (Safari handles them).
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }

    private func wrapHTMLIfNeeded(_ html: String, colorScheme: ColorScheme) -> String {
        let css = """
        <style>
          body { margin: 0; padding: 0; font-family: -apple-system, Helvetica, Arial, sans-serif; \(colorScheme == .dark ? "color:#ffffff;" : "color:#000000;") }
          a { color: \(colorScheme == .dark ? "#8ab4ff" : "#0a84ff"); }
          img { max-width: 100%; height: auto; }
        </style>
        """

        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.contains("<html") && lower.contains("<head") {
            // Inject CSS right after <head> if possible.
            if let range = lower.range(of: "<head>") {
                let insertIndex = trimmed.index(range.upperBound, offsetBy: 0, limitedBy: trimmed.endIndex) ?? trimmed.startIndex
                return String(trimmed[..<insertIndex]) + css + String(trimmed[insertIndex...])
            }
            return trimmed
        }

        // Wrap fragments into a minimal document.
        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(css)
          </head>
          <body>
            \(trimmed)
          </body>
        </html>
        """
    }
}

