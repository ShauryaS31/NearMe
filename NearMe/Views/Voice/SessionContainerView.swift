// Adapted from a prior prototype, used with permission.

import SwiftUI

struct SessionContainerView: View {
    @StateObject private var engine: TaskPlannerEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var didRestore = false
    @MainActor
    init(userName: String) {
        let permissions = PermissionsManager()
        _engine = StateObject(wrappedValue: TaskPlannerEngine(
            brain: TaskPlannerBrainFactory.makeDefault(),
            voiceInput: VoiceInputRouter(),
            voiceOutput: ElevenLabsVoiceOutput(),
            permissions: permissions,
            userName: userName
        ))
    }

    var body: some View {
        Group {
            if engine.isHome {
                HelpHomeView(engine: engine)
            } else if engine.coach != nil {
                CoachView(engine: engine)
            } else if let simulation = engine.tripPlannerPracticeViewModel {
                TripPlannerPracticeView(viewModel: simulation, engine: engine)
            } else if engine.plannerState == .openingApp {
                OpeningPracticeView(confirmationText: engine.conversation.last(where: { $0.speaker == .nearme })?.text ?? "Great! I'll help you plan that journey.")
            } else {
                VoiceSessionView(engine: engine, onEndSession: {
                    engine.endSession()
                })
            }
        }
        .preferredColorScheme(nil)
        #if DEBUG
        .safeAreaInset(edge: .top, spacing: 0) {
            ScrollView {
                Text(engine.debugBadge.text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 84 : 48)
            .background(.background)
        }
        #endif
        .onAppear {
            guard !didRestore else { return }
            didRestore = true
            engine.restoreCoach()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { engine.appEnteredBackground() }
            if phase == .active { engine.appBecameActive() }
        }
    }

}
