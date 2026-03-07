//
//  TabRootView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case timetable
    case messages
    case settings
}

struct TabRootView: View {
    @StateObject private var deepLink = DeepLinkNavigator.shared
    @State private var selectedTab: AppTab = .home
    @State private var messagesPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            tabContainer(title: "Home") {
                HomePlaceholderView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            tabContainer(title: "Timetable") {
                TimetableView()
            }
            .tabItem {
                Label("Timetable", systemImage: "calendar")
            }
            .tag(AppTab.timetable)

            NavigationStack(path: $messagesPath) {
                DireqtMessagesView()
                    .navigationDestination(for: Int.self) { messageID in
                        DireqtMessageDetailView(messageID: messageID)
                    }
                    .navigationTitle("Messages")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Messages", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(AppTab.messages)

            tabContainer(title: "Settings") {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        // Removed haptic feedback from tab navigation
        .onChange(of: deepLink.pendingMessageID) { _, messageID in
            guard let messageID else { return }
            selectedTab = .messages
            // Small delay to let the tab switch complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                messagesPath.append(messageID)
                deepLink.pendingMessageID = nil
            }
        }
    }

    @ViewBuilder
    private func tabContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

