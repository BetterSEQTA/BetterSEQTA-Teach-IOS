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
    @State private var selectedTab: AppTab = .home

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

            tabContainer(title: "Messages") {
                DireqtMessagesView()
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
    }

    @ViewBuilder
    private func tabContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

