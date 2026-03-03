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
}

struct TabRootView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomePlaceholderView(selectedTab: $selectedTab)
                    .navigationTitle("Home")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Logout") { sessionManager.logout() }
                        }
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                TimetableView()
                    .navigationTitle("Timetable")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Logout") { sessionManager.logout() }
                        }
                    }
            }
            .tabItem {
                Label("Timetable", systemImage: "calendar")
            }
            .tag(AppTab.timetable)

            NavigationStack {
                DireqtMessagesView()
                    .navigationTitle("Messages")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Logout") { sessionManager.logout() }
                        }
                    }
            }
            .tabItem {
                Label("Messages", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(AppTab.messages)
        }
    }
}

