//
//  NoticeDetailView.swift
//  TechQTA
//

import SwiftUI
import WebKit

struct NoticeDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let notice: TeachNotice

    @State private var webViewHeight: CGFloat = 120

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                // Title and metadata (centered pills)
                VStack(alignment: .center, spacing: 12) {
                    Text(notice.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .top, spacing: 3) {
                        if let labelTitle = notice.labelTitle, !labelTitle.isEmpty {
                            DetailMetaPill {
                                VStack(alignment: .center, spacing: 6) {
                                    if let hex = notice.colour {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(labelTitle)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        if let staff = notice.staff {
                            DetailMetaPill {
                                VStack(alignment: .center, spacing: 6) {
                                    Image(systemName: "person.fill")
                                        .font(.footnote)
                                    Text(staff)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        if let from = notice.from {
                            DetailMetaPill {
                                VStack(alignment: .center, spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.footnote)
                                    Text(from)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider()

                // Notice body (HTML)
                if let contents = notice.contents, !contents.isEmpty {
                    NoticeHTMLView(html: contents, colorScheme: colorScheme, height: $webViewHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(webViewHeight, 120))
                } else {
                    Text("No content.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Notice")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail metadata pills

private struct DetailMetaPill<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }
}

// MARK: - Notice HTML WebView

private struct NoticeHTMLView: UIViewRepresentable {
    let html: String
    let colorScheme: ColorScheme
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.lastColorScheme != colorScheme || !coordinator.hasLoaded {
            coordinator.lastColorScheme = colorScheme
            coordinator.hasLoaded = true
            let rendered = wrapHTML(html, colorScheme: colorScheme)
            webView.loadHTMLString(rendered, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var hasLoaded = false
        var lastColorScheme: ColorScheme?
        private var height: Binding<CGFloat>

        init(height: Binding<CGFloat>) {
            self.height = height
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let h = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.height.wrappedValue = h
                    }
                }
            }
        }
    }

    private func wrapHTML(_ html: String, colorScheme: ColorScheme) -> String {
        let isDark = colorScheme == .dark
        let textColor = isDark ? "#ffffff" : "#000000"
        let linkColor = isDark ? "#8ab4ff" : "#0a84ff"

        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <style>
              body { margin: 0; padding: 0; color: \(textColor); font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 16px; line-height: 1.5; background: transparent; }
              a { color: \(linkColor); }
              img { max-width: 100%; height: auto; }
              table { border-collapse: collapse; width: 100%; }
              th, td { border: 1px solid \(isDark ? "#555" : "#d1d5db"); padding: 8px; text-align: left; }
            </style>
          </head>
          <body>
            \(html)
          </body>
        </html>
        """
    }
}
