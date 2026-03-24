//
//  FeedbackManager.swift
//  TechQTA
//

import SwiftUI
import UIKit
import AudioToolbox
import CoreHaptics

/// Centralized haptic and audio feedback for the app.
enum FeedbackManager {

    // MARK: - Core Haptics Engine

    private static var engine: CHHapticEngine?
    private static let engineLock = NSLock()

    private static func ensureEngine() -> CHHapticEngine? {
        engineLock.lock()
        defer { engineLock.unlock() }
        if engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let e = try CHHapticEngine()
                e.stoppedHandler = { _ in }
                e.resetHandler = {
                    try? engine?.start()
                }
                try e.start()
                engine = e
            } catch {
                return nil
            }
        }
        return engine
    }

    private static func playPattern(_ events: [CHHapticEvent]) {
        guard let eng = ensureEngine() else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try eng.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - Standard Haptics

    /// Light tap – selection changes, picker, subtle interactions
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Soft impact – tap to cycle, small button taps (reduced intensity)
    static func light() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    /// Light-medium impact – swipe to mark, navigation (reduced from medium)
    static func medium() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    /// Rigid snap – format / toggle ON (heavier click)
    static func rigidSnap() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.impactOccurred()
    }

    /// Medium impact – save, major actions (reduced from heavy)
    static func heavy() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    /// Success notification – save completed, action succeeded
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    /// Error notification – save failed, validation error
    static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
    }

    /// Warning notification – discard confirmation, caution
    static func warning() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }

    // MARK: - Custom Haptic Patterns (Core Haptics)

    /// Two quick taps – tab changes, list selection, secondary actions (reduced intensity)
    static func doubleTap() {
        let e1 = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0)
        let e2 = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.08)
        playPattern([e1, e2])
    }

    /// Three quick taps – date navigation, cycle actions, quick sequences (reduced intensity)
    static func tripleTap() {
        let e1 = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0)
        let e2 = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.07)
        let e3 = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.14)
        playPattern([e1, e2, e3])
    }

    /// Long sustained vibration – major completion (reduced duration from 0.4s to 0.25s)
    static func longVibration() {
        let e = CHHapticEvent(eventType: .hapticContinuous, parameters: [], relativeTime: 0, duration: 0.25)
        playPattern([e])
    }

    /// Long buzz then short tap – primary actions (Send, Save) (reduced intensity and duration)
    static func longThenShort() {
        let long = CHHapticEvent(eventType: .hapticContinuous, parameters: [], relativeTime: 0, duration: 0.15)
        let short = CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.20)
        playPattern([long, short])
    }

    // MARK: - Audio

    /// Subtle tick – selection, light feedback
    private static let soundTick: SystemSoundID = 1104

    /// Soft tap – button press
    private static let soundTap: SystemSoundID = 1104

    /// Slightly more pronounced – swipe, mark
    private static let soundMark: SystemSoundID = 1057

    /// Success chime
    private static let soundSuccess: SystemSoundID = 1057

    static func playTick() {
        AudioServicesPlaySystemSound(soundTick)
    }

    static func playTap() {
        AudioServicesPlaySystemSound(soundTap)
    }

    static func playMark() {
        AudioServicesPlaySystemSound(soundMark)
    }

    static func playSuccess() {
        AudioServicesPlaySystemSound(soundSuccess)
    }
}
