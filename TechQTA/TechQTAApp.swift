//
//  TechQTAApp.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationManager.shared.setUp()
        BackgroundPollManager.shared.registerTask()

        Task {
            let granted = await NotificationManager.shared.requestPermission()
            if granted {
                BackgroundPollManager.shared.scheduleAppRefresh()
            }
        }

        return true
    }
}

@main
struct TechQTAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
