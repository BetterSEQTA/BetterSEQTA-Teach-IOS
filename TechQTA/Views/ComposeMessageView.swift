import SwiftUI
import WebKit

struct ComposeMessageView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: ComposeMessageViewModel
    @State private var showRecipientPicker = false
    @FocusState private var subjectFocused: Bool

    init(
        mode: ComposeMode = .new,
        prefillRecipientNames: [String] = [],
        prefillParticipants: [TeachMessageParticipant] = [],
        prefillSubject: String? = nil,
        prefillBodyHTML: String? = nil,
        selfStaffId: Int? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: ComposeMessageViewModel(
                mode: mode,
                prefillRecipientNames: prefillRecipientNames,
                prefillParticipants: prefillParticipants,
                prefillSubject: prefillSubject,
                prefillBodyHTML: prefillBodyHTML,
                selfStaffId: selfStaffId
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recipients
                recipientSection

                Divider()

                // Subject
                HStack {
                    Text("Subject:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Subject", text: $viewModel.subject)
                        .font(.subheadline)
                        .focused($subjectFocused)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                // HTML Editor
                ComposeHTMLEditor(html: $viewModel.bodyHTML)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.send(session: sessionManager.session) }
                    } label: {
                        if viewModel.isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(viewModel.isSending || viewModel.selectedRecipients.isEmpty)
                }
            }
            .alert("Error", isPresented: sendErrorPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.sendError ?? "")
            }
            .sheet(isPresented: $showRecipientPicker) {
                RecipientPickerView(viewModel: viewModel)
            }
            .onChange(of: viewModel.didSend) {
                if viewModel.didSend { dismiss() }
            }
            .task {
                await viewModel.loadRecipients(session: sessionManager.session)
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.mode {
        case .new: return "New Message"
        case .reply: return "Reply"
        case .replyAll: return "Reply All"
        case .forward: return "Forward"
        }
    }

    private var sendErrorPresented: Binding<Bool> {
        Binding(get: { viewModel.sendError != nil }, set: { if !$0 { viewModel.clearSendError() } })
    }

    // MARK: - Recipient Section

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("To:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.selectedRecipients, id: \.self) { recipient in
                            HStack(spacing: 4) {
                                Text(recipient.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)

                                Button {
                                    viewModel.removeRecipient(recipient)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color(.systemGray5)))
                        }
                    }
                }

                Spacer()

                Button {
                    showRecipientPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            Toggle("BCC (hide recipients)", isOn: $viewModel.blind)
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - Recipient Picker

private struct RecipientPickerView: View {
    @ObservedObject var viewModel: ComposeMessageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: RecipientType? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", selected: selectedType == nil) {
                            selectedType = nil
                        }
                        filterChip("Staff", selected: selectedType == .staff) {
                            selectedType = .staff
                        }
                        filterChip("Students", selected: selectedType == .student) {
                            selectedType = .student
                        }
                        filterChip("Tutors", selected: selectedType == .tutor) {
                            selectedType = .tutor
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List(filteredList, id: \.self) { recipient in
                    Button {
                        viewModel.toggleRecipient(recipient)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipient.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(recipient.type.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.isRecipientSelected(recipient) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Recipients")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.recipientSearchText, prompt: "Search recipients")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filteredList: [Recipient] {
        let base = viewModel.filteredRecipients
        guard let type = selectedType else { return base }
        return base.filter { $0.type == type }
    }

    @ViewBuilder
    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.blue : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HTML Compose Editor (WKWebView contenteditable)

struct ComposeHTMLEditor: UIViewRepresentable {
    @Binding var html: String

    private static let editorCSS = """
          body {
            font-family: -apple-system, Helvetica, Arial, sans-serif;
            font-size: 16px;
            line-height: 1.5;
            padding: 12px;
            margin: 0;
            min-height: 200px;
            outline: none;
            -webkit-user-modify: read-write;
          }
          body:empty:before {
            content: "Write your message...";
            color: #999;
          }
          blockquote.forward {
            border-left: 3px solid #d1d5db;
            padding-left: 12px;
            margin: 12px 0;
            color: #6b7280;
          }
          blockquote.forward .preamble {
            margin-bottom: 8px;
            font-size: 13px;
          }
          blockquote.forward .preamble .title {
            font-weight: 600;
            margin-bottom: 4px;
          }
          blockquote.forward .preamble .label {
            font-weight: 600;
          }
        """

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let handler = context.coordinator
        config.userContentController.add(handler, name: "htmlChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = handler

        let shell = Self.editorShellHTML("")
        webView.loadHTMLString(shell, baseURL: nil)
        context.coordinator.hasLoaded = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.isReady else {
            coordinator.pendingHTML = html
            return
        }

        if coordinator.lastSetHTML != html {
            coordinator.lastSetHTML = html
            let escaped = html
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            webView.evaluateJavaScript("setContent('\(escaped)')") { _, _ in }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(html: $html)
    }

    private static func editorShellHTML(_ initialContent: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(editorCSS)</style>
        </head>
        <body contenteditable="true" id="editor">\(initialContent)</body>
        <script>
          const editor = document.getElementById('editor');
          let ignoreNext = false;
          function setContent(html) {
            ignoreNext = true;
            editor.innerHTML = html;
          }
          editor.addEventListener('input', () => {
            if (ignoreNext) { ignoreNext = false; return; }
            window.webkit.messageHandlers.htmlChanged.postMessage(editor.innerHTML);
          });
          editor.focus();
        </script>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var hasLoaded = false
        var isReady = false
        var pendingHTML: String?
        var lastSetHTML: String?
        private var html: Binding<String>

        init(html: Binding<String>) {
            self.html = html
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "htmlChanged", let body = message.body as? String {
                DispatchQueue.main.async {
                    self.lastSetHTML = body
                    self.html.wrappedValue = body
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let pending = pendingHTML {
                pendingHTML = nil
                lastSetHTML = pending
                let escaped = pending
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "")
                webView.evaluateJavaScript("setContent('\(escaped)')") { _, _ in }
            }
        }
    }
}
