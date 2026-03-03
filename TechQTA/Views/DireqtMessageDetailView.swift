import SwiftUI
import WebKit

struct DireqtMessageDetailView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let messageID: Int

    @StateObject private var viewModel = MessageDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading message...")
                    .padding()
            } else if let errorMessage = viewModel.errorMessage, viewModel.detail == nil {
                ContentUnavailableView("Message unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let detail = viewModel.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !detail.participants.isEmpty {
                            participantPills(detail.participants)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.subject ?? "No subject")
                                .font(.title3)
                                .fontWeight(.semibold)

                            HStack(spacing: 6) {
                                if let sender = detail.sender {
                                    Text(sender)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let date = detail.date {
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text(date, format: .dateTime.day().month().year().hour().minute())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        if let body = detail.body, !body.isEmpty {
                            HTMLStringView(html: body, colorScheme: colorScheme)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 120)
                        } else {
                            Text("No message content.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        if !detail.files.isEmpty {
                            Divider()
                            attachmentsSection(detail.files)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Message")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            viewModel.toggleStar(session: sessionManager.session)
                        } label: {
                            Image(systemName: detail.starred ? "star.fill" : "star")
                                .foregroundStyle(detail.starred ? .yellow : .secondary)
                        }

                        Button(role: .destructive) {
                            viewModel.trash(session: sessionManager.session)
                        } label: {
                            Image(systemName: "trash")
                        }

                        moreMenu(detail: detail)
                    }
                }
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
        .onChange(of: viewModel.didTrash) {
            if viewModel.didTrash {
                dismiss()
            }
        }
    }

    // MARK: - More Menu

    @ViewBuilder
    private func moreMenu(detail: TeachMessageDetail) -> some View {
        Menu {
            Button {
                viewModel.toggleRead(session: sessionManager.session)
            } label: {
                Label(
                    detail.read ? "Mark as Unread" : "Mark as Read",
                    systemImage: detail.read ? "envelope.badge" : "envelope.open"
                )
            }

            Divider()

            // Reply placeholders
            Button { } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            .disabled(true)

            Button { } label: {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }
            .disabled(true)

            Button { } label: {
                Label("Forward", systemImage: "arrowshape.turn.up.right")
            }
            .disabled(true)

            if !viewModel.labels.isEmpty {
                Divider()
                moveToMenu
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var moveToMenu: some View {
        Menu {
            ForEach(viewModel.labels) { label in
                Button {
                    viewModel.moveToLabel(label.label, session: sessionManager.session)
                } label: {
                    Label(
                        label.label.capitalized,
                        systemImage: iconForLabel(label.label)
                    )
                }
            }
        } label: {
            Label("Move to...", systemImage: "folder")
        }
    }

    private func iconForLabel(_ label: String) -> String {
        switch label {
        case "inbox": return "tray"
        case "outbox": return "paperplane"
        case "trash": return "trash"
        default: return "folder"
        }
    }

    // MARK: - Participant Pills

    @ViewBuilder
    private func participantPills(_ participants: [TeachMessageParticipant]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(participants) { participant in
                    HStack(spacing: 5) {
                        Image(systemName: participant.read ? "checkmark.circle.fill" : "circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(participant.read ? .green : .blue)

                        Text(participant.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
    }

    // MARK: - Attachments

    @ViewBuilder
    private func attachmentsSection(_ files: [TeachMessageFile]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Attachments", systemImage: "paperclip")
                .font(.headline)

            ForEach(files) { file in
                HStack(spacing: 12) {
                    Image(systemName: iconForMime(file.mimetype))
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(formattedFileSize(file.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func iconForMime(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("video/") { return "film" }
        if mime.hasPrefix("audio/") { return "waveform" }
        if mime.contains("pdf") { return "doc.richtext" }
        return "doc"
    }

    private func formattedFileSize(_ sizeStr: String) -> String {
        guard let kb = Int(sizeStr) else { return sizeStr }
        if kb < 1024 { return "\(kb) KB" }
        let mb = Double(kb) / 1024.0
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - HTML WebView

private struct HTMLStringView: UIViewRepresentable {
    let html: String
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
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
        let rendered = wrapHTML(html, colorScheme: colorScheme)
        webView.loadHTMLString(rendered, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
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
                if let height = result as? CGFloat {
                    webView.frame.size.height = height
                    webView.invalidateIntrinsicContentSize()
                }
            }
        }
    }

    private func wrapHTML(_ html: String, colorScheme: ColorScheme) -> String {
        let textColor = colorScheme == .dark ? "#ffffff" : "#000000"
        let linkColor = colorScheme == .dark ? "#8ab4ff" : "#0a84ff"

        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <style>
              body { margin: 0; padding: 0; font: -apple-system-body; color: \(textColor); font-family: -apple-system, Helvetica, Arial, sans-serif; }
              a { color: \(linkColor); }
              img { max-width: 100%; height: auto; }
            </style>
          </head>
          <body>
            \(html)
          </body>
        </html>
        """
    }
}
