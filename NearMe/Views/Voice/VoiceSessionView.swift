// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VoiceSessionView: View {
    @ObservedObject var engine: TaskPlannerEngine
    let onEndSession: () -> Void

    var body: some View {
        ScreenScaffold {
            VStack(spacing: TTSpacing.xl) {
                Spacer(minLength: TTSpacing.xxl)

                Text(statusLabel)
                    .font(TTFont.statusLabel())
                    .foregroundStyle(TTColor.accent)
                    .tracking(1.5)
                    .accessibilityHidden(true) // the orb already announces this via its own label

                VoiceOrbView(state: orbState)
                    .onTapGesture {
                        if case .idle = engine.plannerState {
                            engine.userTappedToTalk()
                        }
                    }

                Text(subtitleText)
                    .font(TTFont.title())
                    .foregroundStyle(TTColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(subtitleAccessibilityLabel)

                if let error = engine.lastErrorMessage {
                    Text(error)
                        .font(TTFont.callout())
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                PrimaryButton(title: buttonTitle) {
                    if engine.hasCompletedAtLeastOneJourney {
                        onEndSession()
                    } else {
                        engine.cancelCurrentAction()
                    }
                }
            }
            .frame(minHeight: 520)
        }
    }

    private var buttonTitle: String {
        engine.hasCompletedAtLeastOneJourney ? "end session" : "cancel"
    }

    private var orbState: VoiceOrbState {
        switch engine.plannerState {
        case .listening: return .listening
        case .speaking, .thinking: return .speaking
        default: return .idle
        }
    }

    private var statusLabel: String {
        switch engine.plannerState {
        case .listening: return "LISTENING...."
        default: return "NearMe"
        }
    }

    private var subtitleText: String {
        switch engine.plannerState {
        case .speaking(let text):
            return text
        case .listening:
            if !engine.liveTranscript.isEmpty { return engine.liveTranscript }
            return engine.conversation.last?.text ?? "Listening..."
        case .thinking:
            return engine.conversation.last?.text ?? "One moment..."
        case .idle:
            return engine.lastErrorMessage == nil ? "Tap the mic to talk to NearMe." : "Tap the mic to try again."
        default:
            return ""
        }
    }

    private var subtitleAccessibilityLabel: String {
        switch engine.plannerState {
        case .listening: return "NearMe is listening. \(subtitleText)"
        default: return subtitleText
        }
    }
}
