//
//  FluidLoadingCoordinator.swift
//  TechQTA
//

import SwiftUI

/// Organic milestone progress + snap-to-complete, for use alongside real network work.
@MainActor
enum FluidLoadingCoordinator {
    struct Phase: Sendable {
        let delayNanoseconds: UInt64
        let progress: CGFloat
        let text: String
    }

    /// Preset phase sequences (copy matches each screen’s domain).
    enum Presets {
        static let smartReplies: [Phase] = [
            .init(delayNanoseconds: 450_000_000, progress: 0.22, text: "Understanding context…"),
            .init(delayNanoseconds: 700_000_000, progress: 0.46, text: "Thinking…"),
            .init(delayNanoseconds: 550_000_000, progress: 0.68, text: "Drafting replies…"),
            .init(delayNanoseconds: 900_000_000, progress: 0.82, text: "Polishing…")
        ]

        static let messageDetail: [Phase] = [
            .init(delayNanoseconds: 400_000_000, progress: 0.22, text: "Connecting to Direqt…"),
            .init(delayNanoseconds: 550_000_000, progress: 0.45, text: "Fetching message…"),
            .init(delayNanoseconds: 650_000_000, progress: 0.68, text: "Loading thread & labels…"),
            .init(delayNanoseconds: 750_000_000, progress: 0.84, text: "Almost there…")
        ]

        static let messagesList: [Phase] = [
            .init(delayNanoseconds: 380_000_000, progress: 0.24, text: "Opening your inbox…"),
            .init(delayNanoseconds: 600_000_000, progress: 0.48, text: "Syncing messages…"),
            .init(delayNanoseconds: 700_000_000, progress: 0.72, text: "Applying labels…"),
            .init(delayNanoseconds: 800_000_000, progress: 0.85, text: "Finishing up…")
        ]

        static let timetable: [Phase] = [
            .init(delayNanoseconds: 400_000_000, progress: 0.24, text: "Loading your timetable…"),
            .init(delayNanoseconds: 600_000_000, progress: 0.48, text: "Fetching lessons…"),
            .init(delayNanoseconds: 650_000_000, progress: 0.70, text: "Matching rooms & times…"),
            .init(delayNanoseconds: 800_000_000, progress: 0.86, text: "Preparing your day…")
        ]

        static let notices: [Phase] = [
            .init(delayNanoseconds: 400_000_000, progress: 0.24, text: "Loading notices…"),
            .init(delayNanoseconds: 600_000_000, progress: 0.50, text: "Fetching school posts…"),
            .init(delayNanoseconds: 700_000_000, progress: 0.72, text: "Organising by date…"),
            .init(delayNanoseconds: 750_000_000, progress: 0.85, text: "Almost ready…")
        ]

        static let homeLessons: [Phase] = [
            .init(delayNanoseconds: 350_000_000, progress: 0.26, text: "Fetching today’s classes…"),
            .init(delayNanoseconds: 550_000_000, progress: 0.52, text: "Checking your timetable…"),
            .init(delayNanoseconds: 650_000_000, progress: 0.76, text: "Sorting periods…"),
            .init(delayNanoseconds: 700_000_000, progress: 0.88, text: "Wrapping up…")
        ]

        static let homeMessages: [Phase] = [
            .init(delayNanoseconds: 350_000_000, progress: 0.26, text: "Opening Direqt…"),
            .init(delayNanoseconds: 550_000_000, progress: 0.52, text: "Loading recent messages…"),
            .init(delayNanoseconds: 650_000_000, progress: 0.76, text: "Checking read status…"),
            .init(delayNanoseconds: 700_000_000, progress: 0.88, text: "Almost there…")
        ]

        static let attendance: [Phase] = [
            .init(delayNanoseconds: 400_000_000, progress: 0.22, text: "Opening class roll…"),
            .init(delayNanoseconds: 550_000_000, progress: 0.46, text: "Loading attendance codes…"),
            .init(delayNanoseconds: 650_000_000, progress: 0.68, text: "Fetching students…"),
            .init(delayNanoseconds: 700_000_000, progress: 0.82, text: "Loading summaries…"),
            .init(delayNanoseconds: 750_000_000, progress: 0.90, text: "Finalising roll…")
        ]

        static let composeRecipients: [Phase] = [
            .init(delayNanoseconds: 350_000_000, progress: 0.26, text: "Loading contacts…"),
            .init(delayNanoseconds: 500_000_000, progress: 0.48, text: "Fetching staff & students…"),
            .init(delayNanoseconds: 550_000_000, progress: 0.68, text: "Building recipient list…"),
            .init(delayNanoseconds: 650_000_000, progress: 0.84, text: "Preparing your draft…")
        ]
    }

    static func runOrganicMilestones(
        phases: [Phase],
        generation: Int,
        currentGeneration: @escaping () -> Int,
        progress: Binding<CGFloat>,
        phaseText: Binding<String>
    ) async {
        for phase in phases {
            try? await Task.sleep(nanoseconds: phase.delayNanoseconds)
            guard currentGeneration() == generation else { return }
            guard progress.wrappedValue < 0.9 else { return }
            withAnimation(.spring(.smooth)) {
                progress.wrappedValue = max(progress.wrappedValue, phase.progress)
                phaseText.wrappedValue = phase.text
            }
        }
    }

    static func snapFinish(
        generation: Int,
        currentGeneration: @escaping () -> Int,
        progress: Binding<CGFloat>,
        phaseText: Binding<String>,
        finishingText: String,
        resetText: String
    ) async {
        guard currentGeneration() == generation else { return }
        withAnimation(.spring(.snappy)) {
            progress.wrappedValue = 1.0
            phaseText.wrappedValue = finishingText
        }
        try? await Task.sleep(nanoseconds: 280_000_000)
        guard currentGeneration() == generation else { return }
        withAnimation(.spring(.smooth)) {
            progress.wrappedValue = 0
            phaseText.wrappedValue = resetText
        }
    }
}
