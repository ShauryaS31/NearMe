import ActivityKit
import AVFoundation
import Foundation
import Speech
import UIKit

@MainActor final class AskRecordingActivity: AskActivityPresenting {
    var onDismiss: (() -> Void)?
    private var activity: Activity<AskActivityAttributes>?
    private var observation: Task<Void, Never>?
    private var authorization: Task<Void, Never>?

    func start(id: UUID, expiresAt: Date) throws {
        let state = AskActivityAttributes.ContentState(phase: .starting, startedAt: nil, expiresAt: expiresAt)
        let activity = try Activity.request(attributes: AskActivityAttributes(sessionID: id),
            content: ActivityContent(state: state, staleDate: expiresAt), pushType: nil)
        self.activity = activity
        observation = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                if state == .dismissed || state == .ended { self?.onDismiss?(); return }
            }
        }
        authorization = Task { [weak self] in
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                guard !Task.isCancelled else { return }
                if !enabled { self?.onDismiss?(); return }
            }
        }
    }

    func update(_ state: AskWidgetState) async {
        guard let activity, let expiresAt = state.expiresAt,
              activity.attributes.sessionID == state.sessionID else { return }
        await activity.update(ActivityContent(state: AskActivityAttributes.ContentState(
            phase: state.phase, startedAt: state.startedAt, expiresAt: expiresAt,
            continueInApp: state.continueInApp), staleDate: expiresAt))
    }

    func end() async {
        observation?.cancel(); observation = nil
        authorization?.cancel(); authorization = nil
        let previous = activity; activity = nil
        await previous?.end(nil, dismissalPolicy: .immediate)
    }
}

/// The same engine serves the app UI and widget intent. Never create a second coach.
@MainActor final class NearMeSessionStore {
    static let shared = NearMeSessionStore()
    private var stored: TaskPlannerEngine?
    func engine(userName: String = "Friend") -> TaskPlannerEngine {
        if let stored { return stored }
        let engine = TaskPlannerEngine(brain: TaskPlannerBrainFactory.makeDefault(),
            voiceInput: VoiceInputRouter(), voiceOutput: NearMeVoiceOutput.make(),
            permissions: PermissionsManager(), userName: userName)
        stored = engine
        return engine
    }
}

@MainActor final class AskNearMeRuntime {
    static let shared = AskNearMeRuntime()
    let session: AskNearMeSession

    init() {
        session = AskNearMeSession(input: AskNearMeCapture(), activity: AskRecordingActivity(),
            allowed: {
                UserDefaults.standard.bool(forKey: AskWidgetStore.onboardingKey)
                    && UserDefaults.standard.bool(forKey: AskWidgetStore.setupKey)
                    && AVAudioApplication.shared.recordPermission == .granted
                    && SFSpeechRecognizer.authorizationStatus() == .authorized
                    && AskNearMeCapture.availableRecognizer() != nil
                    && ActivityAuthorizationInfo().areActivitiesEnabled
            }, prepare: {
                let engine = NearMeSessionStore.shared.engine()
                engine.beginWidgetTurn()
                engine.onWidgetSpeechChanged = { AskNearMeRuntime.shared.session.externalSpeechChanged($0) }
            },
            submit: {
                let engine = NearMeSessionStore.shared.engine()
                await engine.receiveWidgetTranscript($0)
                return engine.offersScreenSharing ? .needsApp : .ready
            },
            say: { await NearMeSessionStore.shared.engine().speakWidgetSessionLine($0) },
            cancel: {
                let engine = NearMeSessionStore.shared.engine()
                engine.cancelWidgetTurn()
                engine.onWidgetSpeechChanged = nil
            },
            publish: { AskWidgetStore.write($0) }, now: { Date() },
            interrupt: { NearMeSessionStore.shared.engine().stopSessionSpeech() })
    }

    static func reconcileAtLaunch() {
        let ready = UserDefaults.standard.bool(forKey: AskWidgetStore.setupKey)
        AskWidgetStore.write(AskWidgetState(phase: ready ? .ready : .setup))
        let stale = Activity<AskActivityAttributes>.activities
        Task { for activity in stale { await activity.end(nil, dismissalPolicy: .immediate) } }
    }
}
