//
//  AppMotion.swift
//  TechQTA
//

import SwiftUI

/// Semantic spring animations used app-wide (iOS 17+ physics-based curves).
enum AppMotion {
    static let snappy = Animation.spring(.snappy)
    static let bouncy = Animation.spring(.bouncy)
    static let smooth = Animation.spring(.smooth)
}

// MARK: - Press styles (instant press-in, spring release)

/// Standard controls: slight shrink while pressed, snappy return.
struct BouncyPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .transaction { tx in
                tx.animation = configuration.isPressed ? nil : .spring(.snappy)
            }
    }
}

/// FABs and pills: a bit more playful bounce on release.
struct PlayfulPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .transaction { tx in
                tx.animation = configuration.isPressed ? nil : .spring(.bouncy)
            }
    }
}

// MARK: - Scroll polish

extension View {
    /// Subtle scale/opacity as rows move through the scroll viewport.
    func premiumScrollRowTransition() -> some View {
        scrollTransition(.animated(.spring(.smooth))) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.97)
                .opacity(phase.isIdentity ? 1.0 : 0.82)
        }
    }
}
