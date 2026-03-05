import SwiftUI
import WebKit
import QuickLook

struct DireqtMessageDetailView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let messageID: Int

    @StateObject private var viewModel = MessageDetailViewModel()
    @State private var participantsExpanded = false
    @State private var previewItemURL: URL?
    @State private var isDownloadingAttachment = false
    @State private var attachmentError: String?
    @State private var showReplyComposer = false
    @State private var showReplyAllComposer = false
    @State private var showForwardComposer = false
    @State private var webViewHeight: CGFloat = 120
    @State private var smartReplies: [String] = []
    @State private var isLoadingSmartReplies = false
    @State private var replyWithSmartReply: String?

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
                        // Subject and metadata
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detail.subject ?? "No subject")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            HStack(spacing: 12) {
                                if let sender = detail.sender {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(sender)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let date = detail.date {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(date, format: .dateTime.day().month().year().hour().minute())
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // Participants below subject
                        if !detail.participants.isEmpty {
                            participantPills(detail.participants)
                        }

                        Divider()

                        // Message body
                        if let body = detail.body, !body.isEmpty {
                            AutoHeightWebView(html: body, colorScheme: colorScheme, height: $webViewHeight)
                                .frame(maxWidth: .infinity)
                                .frame(height: max(webViewHeight, 120))
                        } else {
                            Text("No message content.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        // Smart replies
                        if AppleIntelligenceService.isAvailable, let body = detail.body, !body.isEmpty {
                            smartRepliesSection(body: body)
                        }

                        // Attachments
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
                            FeedbackManager.light()
                            viewModel.toggleStar(session: sessionManager.session)
                        } label: {
                            Image(systemName: detail.starred ? "star.fill" : "star")
                                .foregroundStyle(detail.starred ? .yellow : .secondary)
                        }

                        Button(role: .destructive) {
                            FeedbackManager.medium()
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
        .fullScreenCover(isPresented: previewPresentedBinding) {
            if let previewItemURL {
                AttachmentQuickLookPreview(url: previewItemURL)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showReplyComposer) {
            ComposeMessageView(
                mode: .reply(messageID: messageID),
                prefillRecipientNames: detailPrefillRecipientsForReply,
                prefillParticipants: detailPrefillParticipantsForReply,
                prefillSubject: viewModel.detail?.subject,
                prefillBodyHTML: replyPrefillBody,
                selfStaffId: sessionManager.staffId
            )
            .onDisappear { replyWithSmartReply = nil }
        }
        .fullScreenCover(isPresented: $showReplyAllComposer) {
            ComposeMessageView(
                mode: .replyAll(messageID: messageID),
                prefillRecipientNames: detailPrefillRecipientsForReplyAll,
                prefillParticipants: detailPrefillParticipantsForReplyAll,
                prefillSubject: viewModel.detail?.subject,
                prefillBodyHTML: quotePrefillBody,
                selfStaffId: sessionManager.staffId
            )
        }
        .fullScreenCover(isPresented: $showForwardComposer) {
            ComposeMessageView(
                mode: .forward(messageID: messageID),
                prefillRecipientNames: [],
                prefillSubject: viewModel.detail?.subject,
                prefillBodyHTML: quotePrefillBody,
                selfStaffId: sessionManager.staffId
            )
        }
        .alert("Couldn't open attachment", isPresented: attachmentErrorPresentedBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(attachmentError ?? "Unknown error")
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
                FeedbackManager.light()
                viewModel.toggleRead(session: sessionManager.session)
            } label: {
                Label(
                    detail.read ? "Mark as Unread" : "Mark as Read",
                    systemImage: detail.read ? "envelope.badge" : "envelope.open"
                )
            }

            Divider()

            Button {
                FeedbackManager.light()
                replyWithSmartReply = nil
                showReplyComposer = true
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Button {
                FeedbackManager.light()
                showReplyAllComposer = true
            } label: {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }

            Button {
                FeedbackManager.light()
                showForwardComposer = true
            } label: {
                Label("Forward", systemImage: "arrowshape.turn.up.right")
            }

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

    // MARK: - Participant Pills (expandable)

    @ViewBuilder
    private func participantPills(_ participants: [TeachMessageParticipant]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let pillContent = FlowLayout(spacing: 6) {
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

            if participantsExpanded {
                pillContent
            } else {
                pillContent
                    .frame(maxHeight: 32, alignment: .topLeading)
                    .clipped()
                    .overlay(alignment: .trailing) {
                        if participants.count > 3 {
                            LinearGradient(
                                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 60)
                        }
                    }
            }

                        if participants.count > 3 {
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    participantsExpanded.toggle()
                                }
                            } label: {
                                Text(participantsExpanded ? "Show less" : "Show all (\(participants.count))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.top, 4)
                        }
        }
    }

    // MARK: - Smart Replies

    @ViewBuilder
    private func smartRepliesSection(body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Smart replies", systemImage: "sparkles")
                    .font(.headline)
                if isLoadingSmartReplies {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if smartReplies.isEmpty && !isLoadingSmartReplies {
                Button {
                    FeedbackManager.light()
                    loadSmartReplies(body: body)
                } label: {
                    Label("Suggest replies", systemImage: "text.bubble")
                        .font(.subheadline)
                }
            } else if !smartReplies.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(smartReplies, id: \.self) { reply in
                        Button {
                            FeedbackManager.light()
                            replyWithSmartReply = reply
                            showReplyComposer = true
                        } label: {
                            Text(reply)
                                .font(.subheadline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: body) {
            if smartReplies.isEmpty && !isLoadingSmartReplies {
                loadSmartReplies(body: body)
            }
        }
    }

    private func loadSmartReplies(body: String) {
        guard !isLoadingSmartReplies else { return }
        isLoadingSmartReplies = true
        smartReplies = []
        Task {
            let plainText = body.plainTextFromHTML
            let replies = await AppleIntelligenceService.suggestReplies(for: plainText)
            await MainActor.run {
                smartReplies = replies ?? []
                isLoadingSmartReplies = false
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
                        Button {
                            openAttachment(file)
                        } label: {
                            HStack(spacing: 14) {
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
                                .foregroundStyle(.primary)

                            Text(formattedFileSize(file.size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isDownloadingAttachment {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isDownloadingAttachment)
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

    private var detailPrefillRecipientsForReply: [String] {
        guard let detail = viewModel.detail else { return [] }
        return [detail.sender].compactMap { $0 }
    }

    private var detailPrefillRecipientsForReplyAll: [String] {
        guard let detail = viewModel.detail else { return [] }
        var names = [detail.sender].compactMap { $0 }
        names.append(contentsOf: detail.participants.map(\.name))
        return Array(Set(names)) // selfStaffId exclusion handled by ComposeMessageViewModel
    }

    private var detailPrefillParticipantsForReply: [TeachMessageParticipant] {
        guard let detail = viewModel.detail,
              let senderId = detail.senderId,
              let senderName = detail.sender else { return [] }
        return [TeachMessageParticipant(
            id: senderId,
            name: senderName,
            type: detail.senderType ?? "staff",
            read: false
        )]
    }

    private var detailPrefillParticipantsForReplyAll: [TeachMessageParticipant] {
        guard let detail = viewModel.detail else { return [] }
        var all = detail.participants
        if let senderId = detail.senderId, let senderName = detail.sender {
            let senderParticipant = TeachMessageParticipant(
                id: senderId,
                name: senderName,
                type: detail.senderType ?? "staff",
                read: false
            )
            if !all.contains(where: { $0.id == senderId }) {
                all.append(senderParticipant)
            }
        }
        return all
    }

    private var replyPrefillBody: String? {
        if let reply = replyWithSmartReply {
            let escaped = reply
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<p>\(escaped)</p><br><br>\n\(quotePrefillBody ?? "")"
        }
        return quotePrefillBody
    }

    private var quotePrefillBody: String? {
        guard let detail = viewModel.detail else { return nil }
        let sender = detail.sender ?? "Unknown"
        let dateText: String
        if let date = detail.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, d MMMM yyyy"
            dateText = formatter.string(from: date)
        } else {
            dateText = ""
        }
        let original = detail.body ?? ""
        return """
        <br>\n<br>\n\u{00a0}
        <blockquote class="forward">
        \t<div class="preamble">
        \t\t<div class="title">Original message</div>
        \t\t<div class="date"><span class="label">Sent: </span><span class="value">\(dateText)</span></div>
        \t\t<div class="sender"><span class="label">Sender: </span><span class="value">\(sender)</span></div>
        \t</div>
        \t<div class="body">\(original)</div>
        </blockquote>
        """
    }

    private var previewPresentedBinding: Binding<Bool> {
        Binding(
            get: { previewItemURL != nil },
            set: { if !$0 { previewItemURL = nil } }
        )
    }

    private var attachmentErrorPresentedBinding: Binding<Bool> {
        Binding(
            get: { attachmentError != nil },
            set: { if !$0 { attachmentError = nil } }
        )
    }

    private func openAttachment(_ file: TeachMessageFile) {
        guard !isDownloadingAttachment else { return }
        isDownloadingAttachment = true
        attachmentError = nil

        Task {
            do {
                let localURL = try await viewModel.downloadAttachment(file: file, session: sessionManager.session)
                await MainActor.run {
                    previewItemURL = localURL
                    isDownloadingAttachment = false
                }
            } catch {
                await MainActor.run {
                    attachmentError = error.localizedDescription
                    isDownloadingAttachment = false
                }
            }
        }
    }
}

private struct AttachmentQuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: - Flow Layout for wrapping pills

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Auto-sizing HTML WebView

private struct AutoHeightWebView: UIViewRepresentable {
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

        if coordinator.lastColorScheme != colorScheme {
            coordinator.lastColorScheme = colorScheme
            coordinator.hasLoaded = true
            let rendered = wrapHTML(html, colorScheme: colorScheme)
            webView.loadHTMLString(rendered, baseURL: nil)
            return
        }

        guard !coordinator.hasLoaded else { return }
        coordinator.hasLoaded = true
        coordinator.lastColorScheme = colorScheme
        let rendered = wrapHTML(html, colorScheme: colorScheme)
        webView.loadHTMLString(rendered, baseURL: nil)
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
        let darkClass = isDark ? " class=\"dark\"" : ""

        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
            <style>
              body { margin: 0; padding: 0; color: \(textColor); font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 16px; line-height: 1.5; background: transparent; }
              a { color: \(linkColor); }
              img { max-width: 100%; height: auto; }
              blockquote.forward {
                border-left: 3px solid \(isDark ? "#555" : "#d1d5db");
                padding-left: 12px;
                margin: 12px 0;
                color: \(isDark ? "#aaa" : "#6b7280");
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
            </style>
          </head>
          <body\(darkClass)>
            \(html)
          </body>
          \(isDark ? Self.darkModeContrastScript : "")
        </html>
        """
    }

    private static let darkModeContrastScript = """
    <script>
    (function() {
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
        if (el.getAttribute('bgcolor')) return true;
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
          el.dataset.darkPreserved = '1';
          var children = el.querySelectorAll('*');
          for (var j = 0; j < children.length; j++) {
            if (!hasExplicitBg(children[j])) {
              children[j].style.color = '';
              children[j].dataset.darkPreserved = '1';
            }
          }
        }
      }
    })();
    </script>
    """
}
