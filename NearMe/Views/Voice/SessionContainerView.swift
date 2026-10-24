// Adapted from a prior prototype, used with permission.

import SwiftUI

struct SessionContainerView: View {
    @StateObject private var engine: TaskPlannerEngine
    @Environment(\.scenePhase) private var scenePhase
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
            if engine.showsDebugInfo {
                SessionDebugBadgeView(badge: engine.debugBadge)
            }
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

#if DEBUG
private struct SessionDebugBadgeView: View {
    let badge: SessionDebugBadge

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(badge.lines, id: \.self) { line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
    }
}
#endif
