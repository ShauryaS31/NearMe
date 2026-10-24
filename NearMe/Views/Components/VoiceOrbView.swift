// Adapted from a prior prototype, used with permission.

import SwiftUI

enum VoiceOrbState: Equatable {
    case speaking
    case listening
    case idle

    var symbolName: String {
        switch self {
        case .speaking: return "speaker.wave.2.fill"
        case .listening: return "mic.fill"
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
}

struct VoiceOrbButton: View {
    let state: VoiceOrbState
    let instruction: String
    var emphasis: ButtonEmphasis = .primary
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Group {
                switch emphasis {
                case .primary: button.buttonStyle(.borderedProminent)
                case .secondary: button.buttonStyle(.bordered)
                }
            }
            HStack(alignment: .top, spacing: TTSpacing.relatedGap) {
                VoiceOrbView(state: state)
                Text(instruction)
                    .font(TTFont.body())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(TTColor.accent)
    }

    private var button: some View {
        Button(action: action) {
            Label(state == .listening ? "Stop listening" : "Talk to NearMe", systemImage: "mic.fill")
                .font(TTFont.title())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: TTControl.talkHeight)
        }
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint(instruction)
    }
}

/// A small, static state symbol. No pulse or scale animation, including Reduce Motion.
struct VoiceOrbView: View {
    let state: VoiceOrbState

    var body: some View {
        Image(systemName: state.symbolName)
            .font(.body)
            .accessibilityHidden(true)
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

    var body: some View {
        HStack(alignment: .top, spacing: TTSpacing.relatedGap) {
            if activity == .preparing {
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
