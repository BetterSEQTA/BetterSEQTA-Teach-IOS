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
        .safeAreaInset(edge: .top) {
            labelPills
                .padding(.bottom, 8)
                .background(.bar)
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search"
        )
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: viewModel.searchText) {
            viewModel.searchDebounced(session: sessionManager.session)
        }
        .task(id: sessionManager.session?.jsessionId) {
            await viewModel.loadIfNeeded(session: sessionManager.session)
        }

            // Floating compose button
            Button {
                showCompose = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.blue))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
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
                        .padding(.horizontal, (isSelected || item.alwaysShowLabel) ? 16 : 12)
                        .padding(.vertical, 8)
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

    private var messageList: some View {
        Group {
            if viewModel.displayedMessages.isEmpty {
                ContentUnavailableView(
                    "No messages",
                    systemImage: "tray",
                    description: Text(viewModel.searchText.isEmpty ? "You're all caught up." : "No results for \"\(viewModel.searchText)\".")
                )
            } else {
                List {
                    ForEach(viewModel.displayedMessages) { msg in
                        if let messageID = msg.messageID {
                            NavigationLink {
                                DireqtMessageDetailView(messageID: messageID)
                            } label: {
                                messageRow(msg)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.trash(msg, session: sessionManager.session)
                                } label: {
                                    Label("Trash", systemImage: "trash")
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
