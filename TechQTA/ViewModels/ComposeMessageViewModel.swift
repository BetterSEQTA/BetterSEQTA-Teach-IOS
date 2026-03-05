import Foundation

enum ComposeMode {
    case new
    case reply(messageID: Int)
    case replyAll(messageID: Int)
    case forward(messageID: Int)
}

@MainActor
final class ComposeMessageViewModel: ObservableObject {
    @Published var subject: String = ""
    @Published var bodyHTML: String = ""
    @Published var selectedRecipients: [Recipient] = []
    @Published var recipientSearchText: String = ""
    @Published var blind: Bool = false

    @Published private(set) var allRecipients: [Recipient] = []
    @Published private(set) var isLoadingRecipients = false
    @Published private(set) var isSending = false
    @Published private(set) var sendError: String?
    @Published var didSend = false
    @Published private(set) var isAIProcessing = false
    @Published var aiError: String?

    let mode: ComposeMode
    private let client: TeachMessagesClient
    private let prefillRecipientNames: [String]
    private let prefillParticipants: [TeachMessageParticipant]
    private let prefillSubject: String?
    private let prefillBodyHTML: String?
    private let prefillBodyPrefix: String?
    private let selfStaffId: Int?

    var filteredRecipients: [Recipient] {
        guard !recipientSearchText.isEmpty else { return allRecipients }
        let query = recipientSearchText.lowercased()
        return allRecipients.filter { $0.displayName.lowercased().contains(query) }
    }

    /// True when we're loading prefill that might affect body (reply, replyAll, forward with smart reply)
    var hasPrefillContent: Bool {
        switch mode {
        case .new: return prefillBodyPrefix != nil
        case .reply, .replyAll, .forward: return true
        }
    }

    init(
        mode: ComposeMode = .new,
        client: TeachMessagesClient = TeachMessagesClient(),
        prefillRecipientNames: [String] = [],
        prefillParticipants: [TeachMessageParticipant] = [],
        prefillSubject: String? = nil,
        prefillBodyHTML: String? = nil,
        prefillBodyPrefix: String? = nil,
        selfStaffId: Int? = nil
    ) {
        self.mode = mode
        self.client = client
        self.prefillRecipientNames = prefillRecipientNames
        self.prefillParticipants = prefillParticipants
        self.prefillSubject = prefillSubject
        self.prefillBodyHTML = prefillBodyHTML
        self.prefillBodyPrefix = prefillBodyPrefix
        self.selfStaffId = selfStaffId
    }

    func loadRecipients(session: TeachSession?) async {
        guard let session else { return }
        isLoadingRecipients = true

        async let contactsResult = client.fetchContacts(session: session)
        async let staffResult = client.fetchStaff(session: session)
        async let studentsResult = client.fetchStudents(session: session)
        async let tutorsResult = client.fetchTutors(session: session)

        let contacts = (try? await contactsResult) ?? []
        let staff = (try? await staffResult) ?? []
        let students = (try? await studentsResult) ?? []
        let tutors = (try? await tutorsResult) ?? []

        allRecipients = dedupRecipients(contacts + staff + students + tutors)

        // Prefill for reply/forward from API metadata
        await prefill(session: session)
        // Fallback prefill from source message detail, if API metadata is sparse
        applyFallbackPrefillIfNeeded()
        // Prepend smart reply or other prefix (must run after API prefill)
        applyPrefillBodyPrefixIfNeeded()

        if prefillBodyPrefix != nil {
            try? await Task.sleep(for: .milliseconds(350))
        }

        isLoadingRecipients = false
    }

    func clearSendError() {
        sendError = nil
    }

    func clearAIError() {
        aiError = nil
    }

    func proofreadBody() async {
        guard AppleIntelligenceService.isAvailable || CloudflareConfig.isAvailable else {
            aiError = "AI is not available. Add Cloudflare credentials for non-Apple devices."
            return
        }
        let plainText = bodyHTML.plainTextFromHTML
        guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            aiError = "Add some text to proofread."
            return
        }
        isAIProcessing = true
        aiError = nil
        let result: String?
        if AppleIntelligenceService.isAvailable {
            result = await AppleIntelligenceService.proofread(plainText)
        } else {
            result = await CloudflareAIService.proofread(plainText)
        }
        if let result {
            bodyHTML = result.wrappedInHTMLParagraphs
        } else {
            aiError = "Proofreading failed. Please try again."
        }
        isAIProcessing = false
    }

    func changeBodyTone(to tone: String) async {
        guard AppleIntelligenceService.isAvailable || CloudflareConfig.isAvailable else {
            aiError = "AI is not available. Add Cloudflare credentials for non-Apple devices."
            return
        }
        let plainText = bodyHTML.plainTextFromHTML
        guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            aiError = "Add some text to rewrite."
            return
        }
        isAIProcessing = true
        aiError = nil
        let result: String?
        if AppleIntelligenceService.isAvailable {
            result = await AppleIntelligenceService.changeTone(plainText, to: tone)
        } else {
            result = await CloudflareAIService.changeTone(plainText, to: tone)
        }
        if let result {
            bodyHTML = result.wrappedInHTMLParagraphs
        } else {
            aiError = "Could not change tone. Please try again."
        }
        isAIProcessing = false
    }

    func send(session: TeachSession?) async {
        guard let session else {
            sendError = "Not logged in."
            return
        }
        guard !selectedRecipients.isEmpty else {
            sendError = "Add at least one recipient."
            return
        }
        guard !subject.trimmingCharacters(in: .whitespaces).isEmpty else {
            sendError = "Subject cannot be empty."
            return
        }

        isSending = true
        sendError = nil

        let replyTo: Int? = {
            switch mode {
            case .reply(let id), .replyAll(let id): return id
            default: return nil
            }
        }()

        do {
            _ = try await client.sendMessage(
                session: session,
                subject: subject,
                contents: bodyHTML.isEmpty ? "<p></p>" : bodyHTML,
                participants: selectedRecipients,
                blind: blind,
                files: [],
                inReplyTo: replyTo
            )
            didSend = true
        } catch {
            sendError = error.localizedDescription
        }

        isSending = false
    }

    // MARK: - Prefill

    private func prefill(session: TeachSession) async {
        switch mode {
        case .new:
            break
        case .reply(let id):
            if let meta = try? await client.fetchReplyMeta(session: session, messageID: id) {
                applyMeta(meta, subjectPrefix: "Re: ")
            }
        case .replyAll(let id):
            if let meta = try? await client.fetchReplyAllMeta(session: session, messageID: id) {
                applyMeta(meta, subjectPrefix: "Re: ")
            }
        case .forward(let id):
            if let meta = try? await client.fetchForwardMeta(session: session, messageID: id) {
                applyMeta(meta, subjectPrefix: "Fwd: ")
            }
        }
    }

    private func applyMeta(_ meta: [String: Any], subjectPrefix: String) {
        if let s = meta["subject"] as? String {
            subject = s.hasPrefix(subjectPrefix) ? s : subjectPrefix + s
        }
        if prefillBodyPrefix == nil, let c = meta["contents"] as? String {
            bodyHTML = c
        }
        if let participantsRaw = meta["participants"] as? [[String: Any]] {
            var recipients = participantsRaw.compactMap { dict -> Recipient? in
                guard let id = dict["id"] as? Int else { return nil }
                let name = dict["name"] as? String ?? dict["xx_display"] as? String ?? "Unknown"
                let type: RecipientType
                if dict["student"] as? Bool == true { type = .student }
                else if dict["tutor"] as? Bool == true { type = .tutor }
                else if dict["staff"] as? Bool == true { type = .staff }
                else if let t = dict["type"] as? String {
                    type = RecipientType(rawValue: t) ?? .staff
                } else {
                    type = .staff
                }
                return Recipient(id: id, displayName: name, type: type)
            }
            if let selfId = selfStaffId {
                recipients.removeAll { $0.type == .staff && $0.id == selfId }
            }
            selectedRecipients = recipients
        }
    }

    private func applyFallbackPrefillIfNeeded() {
        if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let prefillSubject, !prefillSubject.isEmpty {
            switch mode {
            case .reply, .replyAll:
                subject = prefillSubject.hasPrefix("Re: ") ? prefillSubject : "Re: \(prefillSubject)"
            case .forward:
                subject = prefillSubject.hasPrefix("Fwd: ") ? prefillSubject : "Fwd: \(prefillSubject)"
            case .new:
                subject = prefillSubject
            }
        }

        if bodyHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let prefillBodyHTML, !prefillBodyHTML.isEmpty {
            bodyHTML = prefillBodyHTML
        }

        if selectedRecipients.isEmpty {
            var matched: [Recipient] = []

            if !prefillParticipants.isEmpty {
                let participantIds = Set(prefillParticipants.map(\.id))
                matched = allRecipients.filter { participantIds.contains($0.id) }
            }

            if matched.isEmpty, !prefillRecipientNames.isEmpty {
                let lower = Set(prefillRecipientNames.map { $0.lowercased() })
                matched = allRecipients.filter { lower.contains($0.displayName.lowercased()) }
            }

            if let selfId = selfStaffId {
                matched.removeAll { $0.type == .staff && $0.id == selfId }
            }
            selectedRecipients = matched
        }
    }

    private func applyPrefillBodyPrefixIfNeeded() {
        guard let prefix = prefillBodyPrefix, !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let prefillHTML = prefillBodyHTML, !prefillHTML.isEmpty {
            bodyHTML = prefillHTML
        } else {
            let escaped = prefix
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            let paragraphs = escaped.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\n", with: "<br>") }
                .filter { !$0.isEmpty }
            let prefixHTML = paragraphs.isEmpty ? "<p>\(escaped)</p>" : paragraphs.map { "<p>\($0)</p>" }.joined()
            bodyHTML = "\(prefixHTML)<br><br>\n\(bodyHTML)"
        }
    }

    func toggleRecipient(_ recipient: Recipient) {
        if let idx = selectedRecipients.firstIndex(of: recipient) {
            selectedRecipients.remove(at: idx)
        } else {
            selectedRecipients.append(recipient)
        }
    }

    func removeRecipient(_ recipient: Recipient) {
        selectedRecipients.removeAll { $0 == recipient }
    }

    func isRecipientSelected(_ recipient: Recipient) -> Bool {
        selectedRecipients.contains(recipient)
    }

    private func dedupRecipients(_ recipients: [Recipient]) -> [Recipient] {
        var seen = Set<String>()
        var result: [Recipient] = []
        for recipient in recipients {
            let key = recipient.displayName.lowercased()
            if seen.insert(key).inserted {
                result.append(recipient)
            }
        }
        return result
    }
}

