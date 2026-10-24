// Adapted from a prior prototype, used with permission.

import SwiftUI

enum VoiceOrbState: Equatable {
    case speaking
    case listening
    case idle

    var symbolName: String {
        switch self {
        case .speaking: return "speaker.wave.2.fill"
        case .listening: return "waveform"
        case .idle: return "mic.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .speaking: return "NearMe is speaking"
        case .listening: return "NearMe is listening"
        case .idle: return "Tap to talk to NearMe"
        }
    }
}

struct VoiceOrbView: View {
    let state: VoiceOrbState
    var diameter: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Three concentric rings fading from the light chip tint out to
            // the accent purple, echoing the halo behind the orb in the
            // mockups (node 47:78 — ellipse53/54/55). Those three were
            // exported as flat SVG fills we couldn't recover exact hex
            // values for, so this reproduces the look from confirmed palette
            // colors rather than the literal asset.
            Circle()
                .fill(TTColor.accent.opacity(0.16))
                .frame(width: diameter * 1.65, height: diameter * 1.65)
            Circle()
                .fill(TTColor.accent.opacity(0.24))
                .frame(width: diameter * 1.375, height: diameter * 1.375)
            Circle()
                .fill(TTColor.chip.opacity(0.9))
                .frame(width: diameter * 1.08, height: diameter * 1.08)

            Circle()
                .fill(TTColor.ink)
                .frame(width: diameter, height: diameter)
                .scaleEffect(pulseScale)

            Image(systemName: state.symbolName)
                .font(.system(size: diameter * 0.34, weight: .medium))
                .foregroundStyle(TTColor.buttonLabel)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: state == .listening && !reduceMotion)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: state) { _, _ in startPulseIfNeeded() }
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)
    }

    private var pulseScale: CGFloat {
        guard !reduceMotion, state != .idle else { return 1 }
        return isPulsing ? 1.04 : 0.98
    }

    private func startPulseIfNeeded() {
        isPulsing = false
        guard !reduceMotion, state != .idle else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isPulsing = true
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VoiceOrbView(state: .speaking)
        VoiceOrbView(state: .listening)
        VoiceOrbView(state: .idle)
    }
    .padding()
    .background(TTColor.background)
}
