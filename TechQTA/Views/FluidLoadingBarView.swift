//
//  FluidLoadingBarView.swift
//  TechQTA
//

import SwiftUI

/// Phase text + spring-interpolated progress bar (AI, network, and full-screen loads).
struct FluidLoadingBarView: View {
    var progress: CGFloat
    var phaseText: String
    var accessibilityLabel: String = "Loading"

    private var clampedProgress: CGFloat {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(phaseText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .id(phaseText)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )

            GeometryReader { geo in
                let fillWidth = clampedProgress * geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.indigo.opacity(0.95),
                                    Color.blue,
                                    Color.cyan.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, fillWidth))
                        .shadow(color: .blue.opacity(0.38), radius: 6, y: 0)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue("\(Int(clampedProgress * 100)) percent, \(phaseText)")
        }
        .padding(.vertical, 6)
        .animation(.spring(.smooth), value: phaseText)
    }
}

/// Backward-compatible name for smart-reply loading.
typealias FluidAIReplyLoadingView = FluidLoadingBarView
