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
        case .speaking, .idle: return "Start listening"
        case .listening: return "Stop listening"
        }
    }

    var instruction: String {
        switch self {
        case .listening: return "Listening... tap when you're done"
        case .speaking, .idle: return "Tap to talk"
        }
    }

    var inputLabels: [String] {
        if self == .listening { return [instruction, "Stop listening"] }
        return ["Talk to NearMe", "Start listening", "Use voice"]
    }
}

/// The orb is the Talk control. Only its decorative halo moves during capture.
struct VoiceOrbButton: View {
    let state: VoiceOrbState
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var inputLabels: [String] { state.inputLabels }

    var body: some View {
        Button(action: action) {
            ZStack {
                halo.accessibilityHidden(true)
                Circle()
                    .fill(TTColor.violet)
                    .padding(TTSpacing.relatedGap)
                Image(systemName: state.symbolName)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(TTColor.onAccent)
                    .accessibilityHidden(true)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityInputLabels(inputLabels)
    }

    @ViewBuilder private var halo: some View {
        if state == .listening && !reduceMotion {
            Circle().fill(TTColor.lavender)
                .phaseAnimator([false, true]) { content, expanded in
                    content.scaleEffect(expanded ? 1.04 : 0.94)
                } animation: { _ in
                    .easeInOut(duration: 1.1)
                }
        } else {
            Circle().fill(TTColor.lavender)
        }
    }
}

enum VoiceActivity: String, CaseIterable, Identifiable {
    case ready, listening, preparing, speaking, paused
    var id: Self { self }

    var title: String {
        switch self {
        case .ready: return "Ready"
        case .listening: return "Listening... tap when you're done"
        case .preparing: return "Preparing your next step"
        case .speaking: return "Speaking"
        case .paused: return "We paused here"
        }
    }

    var symbol: String {
        switch self {
        case .ready, .listening: return "mic.fill"
        case .preparing: return "hourglass"
        case .speaking: return "speaker.wave.2.fill"
        case .paused: return "pause.circle"
        }
    }

    static func resolve(plannerState: TaskPlannerState, isSpeaking: Bool,
                        isPreparing: Bool, isStartingListening: Bool, isPaused: Bool) -> Self {
        if plannerState == .listening { return .listening }
        if isPreparing || isStartingListening || plannerState == .thinking || plannerState == .finishing {
            return .preparing
        }
        if isSpeaking { return .speaking }
        return isPaused ? .paused : .ready
    }
}

struct VoiceStateRow: View {
    let activity: VoiceActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: TTSpacing.relatedGap) {
            if activity == .preparing && !reduceMotion {
                ProgressView().accessibilityHidden(true)
            } else {
                Image(systemName: activity.symbol).accessibilityHidden(true)
            }
            Text(activity.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(TTFont.body())
        .foregroundStyle(TTColor.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
