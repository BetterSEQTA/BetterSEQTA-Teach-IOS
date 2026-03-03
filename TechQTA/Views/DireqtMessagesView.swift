import SwiftUI

struct DireqtMessagesView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @StateObject private var viewModel = DireqtMessagesViewModel()
    @State private var showCompose = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    ProgressView("Loading messages...")
                        .padding()
                } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                    ContentUnavailableView("Messages unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    messageList
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.searchText) {
                viewModel.searchDebounced(session: sessionManager.session)
            }
            .task(id: sessionManager.session?.jsessionId) {
                await viewModel.loadIfNeeded(session: sessionManager.session)
            }

            // Floating search + compose
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $viewModel.searchText)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))

                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $showCompose) {
            ComposeMessageView(mode: .new)
        }
    }

    // MARK: - Label Pills

    private var labelPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(allLabelItems, id: \.label) { item in
                    let isSelected = viewModel.selectedLabel == item.label
                    let unread = viewModel.labels.first(where: { $0.label == item.label })?.unread ?? 0

                    Button {
                        let label = item.label
                        let session = sessionManager.session
                        withAnimation(.snappy(duration: 0.25)) {
                            viewModel.selectedLabel = label
                        }
                        Task {
                            await viewModel.switchLabel(label, session: session)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.subheadline)

                            if isSelected || item.alwaysShowLabel {
                                Text(item.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .transition(.asymmetric(
                                        insertion: .push(from: .leading).combined(with: .opacity),
                                        removal: .push(from: .trailing).combined(with: .opacity)
                                    ))
                            }

                            if unread > 0 && !isSelected {
                                Text("\(unread)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(.blue.opacity(0.15))
                                    )
                            }
                        }
                        .padding(.horizontal, (isSelected || item.alwaysShowLabel) ? 18 : 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.blue : Color(.systemGray5))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.25), value: isSelected)
                }
            }
            .padding(.horizontal)
        }
    }

    private struct LabelItem {
        let label: String
        let displayName: String
        let icon: String
        let alwaysShowLabel: Bool
    }

    private var allLabelItems: [LabelItem] {
        let builtIn: [LabelItem] = [
            LabelItem(label: "inbox", displayName: "Inbox", icon: "person.2.fill", alwaysShowLabel: false),
            LabelItem(label: "outbox", displayName: "Sent", icon: "paperplane", alwaysShowLabel: false),
            LabelItem(label: "starred", displayName: "Starred", icon: "star.fill", alwaysShowLabel: false),
            LabelItem(label: "trash", displayName: "Trash", icon: "trash", alwaysShowLabel: false)
        ]
        let builtInNames = Set(builtIn.map(\.label))

        let custom: [LabelItem] = viewModel.labels
            .filter { !builtInNames.contains($0.label) }
            .map { LabelItem(label: $0.label, displayName: $0.label.capitalized, icon: "folder", alwaysShowLabel: true) }

        return builtIn + custom
    }

    // MARK: - Message List

    private var messageListHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            labelPills
        }
        .padding(.vertical, 12)
    }

    private var messageList: some View {
        VStack(spacing: 0) {
            messageListHeader

            if viewModel.displayedMessages.isEmpty {
                ScrollView {
                    ContentUnavailableView(
                        "No messages",
                        systemImage: "tray",
                        description: Text(viewModel.searchText.isEmpty ? "You're all caught up." : "No results for \"\(viewModel.searchText)\".")
                    )
                    .padding(.top, 40)
                }
                .refreshable {
                    await viewModel.refresh(session: sessionManager.session)
                }
            } else {
                List {
                    ForEach(Array(viewModel.displayedMessages.enumerated()), id: \.element.id) { index, msg in
                        if let messageID = msg.messageID {
                            NavigationLink(value: messageID) {
                                messageRow(msg)
                            }
                            .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                            .listRowSeparator(index == viewModel.displayedMessages.count - 1 ? .hidden : .visible, edges: .bottom)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if viewModel.selectedLabel == "trash" {
                                    Button {
                                        viewModel.restore(msg, session: sessionManager.session)
                                    } label: {
                                        Label("Restore", systemImage: "tray.and.arrow.up")
                                    }
                                    .tint(.green)
                                } else {
                                    Button(role: .destructive) {
                                        viewModel.trash(msg, session: sessionManager.session)
                                    } label: {
                                        Label("Trash", systemImage: "trash")
                                    }
                                }

                                Button {
                                    viewModel.toggleStar(msg, session: sessionManager.session)
                                } label: {
                                    Label(msg.starred ? "Unflag" : "Flag", systemImage: msg.starred ? "flag.slash" : "flag.fill")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    viewModel.toggleRead(msg, session: sessionManager.session)
                                } label: {
                                    Label(
                                        msg.read ? "Unread" : "Read",
                                        systemImage: msg.read ? "envelope.badge" : "envelope.open"
                                    )
                                }
                                .tint(.blue)
                            }
                        } else {
                            messageRow(msg)
                                .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                                .listRowSeparator(index == viewModel.displayedMessages.count - 1 ? .hidden : .visible, edges: .bottom)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.refresh(session: sessionManager.session)
                }
            }
        }
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ msg: TeachMessage) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Unread dot -- vertically centered with the avatar
            Circle()
                .fill(msg.read ? .clear : .blue)
                .frame(width: 8, height: 8)
                .padding(.trailing, 8)
                .accessibilityHidden(true)

            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String((msg.sender ?? "U").prefix(1)))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .overlay {
                    if msg.starred {
                        Circle()
                            .strokeBorder(Color.orange, lineWidth: 2.5)
                    }
                }
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 3) {
                // Row 1: Subject (primary heading) + date
                HStack(alignment: .firstTextBaseline) {
                    Text(msg.subject ?? "No subject")
                        .font(.subheadline)
                        .fontWeight(msg.read ? .regular : .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 4) {
                        if msg.attachments {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let date = msg.date {
                            Text(AppDateFormatters.relativeMessageDate(date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Row 2: From
                HStack(spacing: 0) {
                    Text("From: ")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Text(msg.sender ?? "Unknown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                // Row 3: To
                if !msg.participants.isEmpty {
                    HStack(spacing: 0) {
                        Text("To: ")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(msg.participants.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
