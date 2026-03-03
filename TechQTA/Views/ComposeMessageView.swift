import SwiftUI
import WebKit

struct ComposeMessageView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: ComposeMessageViewModel
    @State private var showRecipientPicker = false
    @State private var toSearchText: String = ""
    @FocusState private var toFieldFocused: Bool
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
                ComposeHTMLEditor(html: $viewModel.bodyHTML, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
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

    private var toAutocompleteSuggestions: [Recipient] {
        guard !toSearchText.isEmpty else { return [] }
        let query = toSearchText.lowercased()
        return viewModel.allRecipients
            .filter { $0.displayName.lowercased().contains(query) }
            .filter { !viewModel.selectedRecipients.contains($0) }
    }

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // To: row with pills and inline text field
            HStack(alignment: viewModel.selectedRecipients.isEmpty ? .center : .top) {
                Text("To:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, viewModel.selectedRecipients.isEmpty ? 0 : 6)

                RecipientFlowLayout(spacing: 6) {
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

                    TextField("Add recipient...", text: $toSearchText)
                        .font(.subheadline)
                        .focused($toFieldFocused)
                        .frame(minWidth: 120)
                        .onSubmit {
                            if toSearchText.isEmpty {
                                toFieldFocused = false
                            } else if let first = toAutocompleteSuggestions.first {
                                viewModel.selectedRecipients.append(first)
                                toSearchText = ""
                            }
                        }
                }

                Button {
                    showRecipientPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Autocomplete suggestions
            if toFieldFocused && !toAutocompleteSuggestions.isEmpty {
                let suggestions = Array(toAutocompleteSuggestions.prefix(5))
                VStack(spacing: 0) {
                    ForEach(suggestions, id: \.self) { recipient in
                        Button {
                            viewModel.selectedRecipients.append(recipient)
                            toSearchText = ""
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipient.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(recipient.type.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if recipient != suggestions.last {
                            Divider().padding(.leading)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
            }

            Divider()

            Toggle("BCC (hide recipients)", isOn: $viewModel.blind)
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - Recipient Flow Layout

private struct RecipientFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let pos = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y),
                proposal: ProposedViewSize(width: result.widths[index], height: nil)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], widths: [CGFloat]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var widths: [CGFloat] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let isLast = index == subviews.count - 1
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = isLast ? max(size.width, maxWidth - x) : size.width

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            widths.append(isLast ? max(0, maxWidth - x) : size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: max(maxX, maxWidth), height: y + rowHeight), positions, widths)
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
                        filterChip("Parents", selected: selectedType == .contact) {
                            selectedType = .contact
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
                                Text(recipient.type.displayName)
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
            .navigationBarTitleDisplayMode(.large)
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
    let colorScheme: ColorScheme

    private static func editorCSS(isDark: Bool) -> String {
        let textColor = isDark ? "#ffffff" : "#000000"
        let placeholderColor = isDark ? "#666" : "#999"
        let borderColor = isDark ? "#555" : "#d1d5db"
        let quoteColor = isDark ? "#aaa" : "#6b7280"

        return """
          body {
            font-family: -apple-system, Helvetica, Arial, sans-serif;
            font-size: 16px;
            line-height: 1.5;
            padding: 12px;
            margin: 0;
            min-height: 200px;
            outline: none;
            -webkit-user-modify: read-write;
            color: \(textColor);
            background: transparent;
          }
          body:empty:before {
            content: "Write your message...";
            color: \(placeholderColor);
          }
          blockquote.forward {
            border-left: 3px solid \(borderColor);
            padding-left: 12px;
            margin: 12px 0;
            color: \(quoteColor);
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
    }

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

        let isDark = colorScheme == .dark
        let shell = Self.editorShellHTML("", isDark: isDark)
        webView.loadHTMLString(shell, baseURL: nil)
        context.coordinator.hasLoaded = true
        context.coordinator.lastColorScheme = colorScheme

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        if coordinator.lastColorScheme != colorScheme {
            coordinator.lastColorScheme = colorScheme
            coordinator.isReady = false
            coordinator.hasLoaded = true
            let currentHTML = coordinator.lastSetHTML ?? html
            let isDark = colorScheme == .dark
            let shell = Self.editorShellHTML(currentHTML, isDark: isDark)
            webView.loadHTMLString(shell, baseURL: nil)
            return
        }

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

    private static func editorShellHTML(_ initialContent: String, isDark: Bool) -> String {
        let darkClass = isDark ? " class=\"dark\"" : ""
        let contrastScript = isDark ? """
          function fixContrast() {
            function luminance(r, g, b) {
              var a = [r, g, b].map(function(v) {
                v /= 255;
                return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
              });
              return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2];
            }
            function parseColor(str) {
              var m = str.match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/);
              if (m) return { r: +m[1], g: +m[2], b: +m[3], a: m[4] !== undefined ? parseFloat(m[4]) : 1 };
              return null;
            }
            function hasExplicitBg(el) {
              var inline = el.style.backgroundColor;
              if (inline && inline !== '' && inline !== 'transparent' && inline !== 'rgba(0, 0, 0, 0)') return true;
              if (el.getAttribute && el.getAttribute('bgcolor')) return true;
              return false;
            }
            var els = document.body.querySelectorAll('*');
            for (var i = 0; i < els.length; i++) {
              var el = els[i];
              if (!hasExplicitBg(el)) continue;
              var bg = getComputedStyle(el).backgroundColor;
              var c = parseColor(bg);
              if (!c || c.a < 0.1) continue;
              var lum = luminance(c.r, c.g, c.b);
              if (lum > 0.4) {
                el.style.color = '';
                var children = el.querySelectorAll('*');
                for (var j = 0; j < children.length; j++) {
                  if (!hasExplicitBg(children[j])) children[j].style.color = '';
                }
              }
            }
          }
        """ : "function fixContrast() {}"

        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(editorCSS(isDark: isDark))</style>
        </head>
        <body contenteditable="true" id="editor"\(darkClass)>\(initialContent)</body>
        <script>
          \(contrastScript)
          const editor = document.getElementById('editor');
          let ignoreNext = false;
          function setContent(html) {
            ignoreNext = true;
            editor.innerHTML = html;
            fixContrast();
          }
          editor.addEventListener('input', () => {
            if (ignoreNext) { ignoreNext = false; return; }
            window.webkit.messageHandlers.htmlChanged.postMessage(editor.innerHTML);
          });
          fixContrast();
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
        var lastColorScheme: ColorScheme?
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
