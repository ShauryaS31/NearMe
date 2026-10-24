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
            voiceOutput: SystemVoiceOutputService(),
            permissions: permissions,
            userName: userName
        ))
        self.onSessionEnded = onSessionEnded
    }

    var body: some View {
        Group {
            switch engine.plannerState {
            case .guiding:
                if let simulation = engine.ptvSimulationViewModel {
                    PTVSimulationView(viewModel: simulation)
                }
            case .openingApp:
                OpeningPTVView(confirmationText: engine.conversation.last(where: { $0.speaker == .nearme })?.text ?? "Great! I'll help you plan that journey.")
            default:
                VoiceSessionView(engine: engine, onEndSession: {
                    engine.endSession()
                    onSessionEnded()
                })
            }
        }
        .onAppear { engine.beginSession() }
        .animation(.easeInOut(duration: 0.2), value: isGuiding)
    }

    private var isGuiding: Bool {
        if case .guiding = engine.plannerState { return true }
        return false
    }
}
