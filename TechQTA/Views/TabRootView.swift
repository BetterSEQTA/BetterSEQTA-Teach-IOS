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
            NavigationStack {
                HomePlaceholderView(selectedTab: $selectedTab)
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                TimetableView()
                    .navigationTitle("Timetable")
            }
            .tabItem {
                Label("Timetable", systemImage: "calendar")
            }
            .tag(AppTab.timetable)

            NavigationStack {
                DireqtMessagesView()
                    .navigationTitle("Messages")
            }
            .tabItem {
                Label("Messages", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(AppTab.messages)

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
    }
}

