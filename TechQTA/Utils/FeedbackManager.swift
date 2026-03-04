//
//  FeedbackManager.swift
//  TechQTA
//

import SwiftUI
import UIKit
import AudioToolbox

/// Centralized haptic and audio feedback for the app.
enum FeedbackManager {

    // MARK: - Haptics

    /// Light tap – selection changes, picker, subtle interactions
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Soft impact – tap to cycle, small button taps
    static func light() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    /// Medium impact – swipe to mark, navigation, important taps
    static func medium() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    /// Heavy impact – save, major actions
    static func heavy() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
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
