// Adapted from a prior prototype, used with permission.

import SwiftUI

struct SessionContainerView: View {
    @StateObject private var engine: TaskPlannerEngine
    /// Called once the user taps "end session" (and the engine has finished
    /// tearing down). There's no dedicated "session ended" screen in the
    /// mockups — the caller (AppCoordinator, via ContentView) is expected to
    /// navigate back to onboarding immediately.
    let onSessionEnded: () -> Void

    @MainActor
    init(userName: String, onSessionEnded: @escaping () -> Void) {
        let permissions = PermissionsManager()
        _engine = StateObject(wrappedValue: TaskPlannerEngine(
            brain: TaskPlannerBrainFactory.makeDefault(),
            voiceInput: VoiceInputRouter(),
            voiceOutput: ElevenLabsVoiceOutput(),
            permissions: permissions,
            userName: userName
        ))
        self.onSessionEnded = onSessionEnded
    }

    var body: some View {
        Group {
            switch engine.plannerState {
            case .guiding:
                if let simulation = engine.tripPlannerPracticeViewModel {
                    TripPlannerPracticeView(viewModel: simulation,
                                            onRepeat: { engine.repeatPracticeCaption() },
                                            onSlower: { engine.repeatPracticeCaption(slower: true) },
                                            onStop: engine.stopPracticeSpeech,
                                            onTypeInstead: engine.useTypedInput, onEndSession: {
                        engine.endSession()
                        onSessionEnded()
                    })
                }
            case .openingApp:
                OpeningPracticeView(confirmationText: engine.conversation.last(where: { $0.speaker == .nearme })?.text ?? "Great! I'll help you plan that journey.")
            default:
                VoiceSessionView(engine: engine, onEndSession: {
                    engine.endSession()
                    onSessionEnded()
                })
            }
        }
        // Only the practice screens have moved to adaptive system colours.
        .preferredColorScheme(isGuiding || engine.plannerState == .openingApp ? nil : .light)
        #if DEBUG
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("\(brainBadge) | \(engine.latestVoice ?? "Voice pending")\n\(engine.timingBadge)")
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.background)
                .accessibilityLabel("Brain source: \(brainBadge). Voice: \(engine.latestVoice ?? "pending"). \(engine.timingBadge)")
        }
        #endif
        .onAppear { engine.beginSession() }
        .animation(.easeInOut(duration: 0.2), value: isGuiding)
    }

    #if DEBUG
    private var brainBadge: String { engine.latestBrainSource.label }
    #endif

    private var isGuiding: Bool {
        if case .guiding = engine.plannerState { return true }
        return false
    }
}
