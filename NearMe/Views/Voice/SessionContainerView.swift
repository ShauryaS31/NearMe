// Adapted from a prior prototype, used with permission.

import SwiftUI

enum SessionScreen: Equatable {
    case voice, coach, practice, opening

    static func resolve(isHome: Bool, showsCoach: Bool, hasPractice: Bool, isOpening: Bool) -> Self {
        if isHome { return .voice }
        if showsCoach { return .coach }
        if hasPractice { return .practice }
        if isOpening { return .opening }
        return .voice
    }
}

struct SessionContainerView: View {
    @StateObject private var engine: TaskPlannerEngine
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var didActivate = false
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
        sessionContent
        .preferredColorScheme(nil)
        #if DEBUG
        .safeAreaInset(edge: .top, spacing: 0) {
            if engine.showsDebugInfo {
                SessionDebugBadgeView(badge: engine.debugBadge, song: engine.coach?.song)
            }
        }
        #endif
        .onAppear {
            if scenePhase == .active { activateSession() }
        }
        .onChange(of: coordinator.pendingCoachURL) { _, _ in
            if scenePhase == .active { activateSession() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { engine.appEnteredBackground() }
            if phase == .inactive { engine.appBecameInactive() }
            if phase == .active { activateSession() }
        }
    }

    private var screen: SessionScreen {
        SessionScreen.resolve(isHome: engine.isHome,
                              showsCoach: CoachPresentation.showsCoachCard(session: engine.coach, error: engine.lastErrorMessage),
                              hasPractice: engine.tripPlannerPracticeViewModel != nil,
                              isOpening: engine.plannerState == .openingApp)
    }

    @ViewBuilder private var sessionContent: some View {
        // Ordinary launches stay on the orb. Explicit coach URLs still restore a guide.
        switch screen {
        case .voice:
            VoiceSessionView(engine: engine)
        case .coach:
            CoachView(engine: engine)
        case .practice:
            if let simulation = engine.tripPlannerPracticeViewModel {
                TripPlannerPracticeView(viewModel: simulation, engine: engine)
            }
        case .opening:
            OpeningPracticeView(confirmationText: openingConfirmation)
        }
    }

    private var openingConfirmation: String {
        engine.conversation.last(where: { $0.speaker == .nearme })?.text ?? "Great! I'll help you plan that journey."
    }

    private func handlePendingCoachURL() -> Bool {
        guard scenePhase == .active, let request = coordinator.pendingCoachURL else { return false }
        coordinator.pendingCoachURL = nil
        engine.openCoachURL(request.url)
        return true
    }

    private func activateSession() {
        engine.appBecameActive()
        if handlePendingCoachURL() { return }
        guard !didActivate else { return }
        didActivate = true
        PlannerModelAccess().prewarm()
    }

}

#if DEBUG
private struct SessionDebugBadgeView: View {
    let badge: SessionDebugBadge
    let song: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(badge.lines, id: \.self) { line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ScreenBroadcastDebugLine(song: song)
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
