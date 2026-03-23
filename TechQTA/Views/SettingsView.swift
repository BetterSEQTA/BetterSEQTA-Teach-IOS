//
//  SettingsView.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/3/2026.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sessionManager: TeachSessionManager
    @AppStorage("attendanceViewMode") private var attendanceViewMode: String = AttendanceViewMode.list.rawValue
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @State private var showAbout = false
    @State private var showPrivacy = false

    private var accountDisplayName: String {
        if let name = sessionManager.displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        if let staffId = sessionManager.staffId {
            return "Staff \(staffId)"
        }
        return "User"
    }

    var body: some View {
        List {
            if let session = sessionManager.session {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.tint)
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(accountDisplayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(session.baseUrl.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.85)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        heartbeatStatusView
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }

                Section {
                    Button(role: .destructive) {
                        sessionManager.logout()
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Not logged in")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                Picker(selection: $attendanceViewMode) {
                    ForEach(AttendanceViewMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                } label: {
                    Label("Attendance view", systemImage: "rectangle.stack")
                }
            } header: {
                Text("Attendance")
            } footer: {
                Text("Choose how you view students when marking attendance.")
            }

            if sessionManager.session != nil && BiometricAuthHelper.isAvailable {
                Section {
                    Toggle(isOn: $faceIDEnabled) {
                        Label("Require \(BiometricAuthHelper.biometricTypeName) to open", systemImage: "faceid")
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Require \(BiometricAuthHelper.biometricTypeName) every time you open the app.")
                }
            }

            Section {
                Button {
                    showAbout = true
                } label: {
                    Label("About", systemImage: "info.circle")
                }
                Button {
                    showPrivacy = true
                } label: {
                    Label("Privacy", systemImage: "hand.raised")
                }
            } header: {
                Text("App")
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 0, for: .scrollContent)
        .sheet(isPresented: $showAbout) {
            AboutSheet()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet()
        }
        .task(id: sessionManager.session?.jsessionId) {
            if sessionManager.session != nil {
                await sessionManager.sendHeartbeat()
            }
        }
    }

    @ViewBuilder
    private var heartbeatStatusView: some View {
        HStack(spacing: 8) {
            Image(systemName: heartbeatStatusIcon)
                .font(.subheadline)
                .foregroundStyle(heartbeatStatusColor)
            switch sessionManager.heartbeatStatus {
            case .idle:
                Text("Last heartbeat: —")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 6) {
                    Text("Sending heartbeat…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            case .success(let date):
                Text("Last heartbeat: \(date, format: .dateTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unauthorized:
                Text("Session expired")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .error(let msg):
                Text("Error: \(msg)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var heartbeatStatusIcon: String {
        switch sessionManager.heartbeatStatus {
        case .success: return "checkmark.circle.fill"
        case .unauthorized, .error: return "exclamationmark.triangle.fill"
        default: return "circle.dotted"
        }
    }

    private var heartbeatStatusColor: Color {
        switch sessionManager.heartbeatStatus {
        case .success: return .green
        case .unauthorized, .error: return .red
        default: return .secondary
        }
    }
}

// MARK: - About Sheet

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("BetterSEQTA Teach")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("A cleaner, faster way to access SEQTA Teach — timetable, attendance, and Direqt messages.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Text("Not affiliated with SEQTA or Education Horizons.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        FeedbackManager.doubleTap()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Privacy Sheet

private struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your data stays on your device")
                        .font(.headline)

                    Text("Your SEQTA session cookie (JSESSIONID) is stored only in the iOS Keychain on this device. We do not send your login credentials to any server other than your school's SEQTA Teach site.")

                    Text("The app communicates directly with your school's SEQTA Teach instance. No third-party analytics or tracking is included.")

                    Text("You can log out at any time from Settings to remove your session from this device.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        FeedbackManager.doubleTap()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
