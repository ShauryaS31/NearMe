import ActivityKit
import Foundation

nonisolated enum CoachActivityUpdate: Sendable {
    case show(CoachActivitySnapshot, startIfNeeded: Bool)
    case finish(CoachActivitySnapshot)
    case stop(UUID?)
    case reconcile(UUID?)
}

@MainActor
protocol CoachActivityUpdating {
    func enqueue(_ update: CoachActivityUpdate)
    func flush() async
}

@MainActor
enum CoachActivityLifecycle {
    static func reconcile(store: any CoachProgressStoring, guides: [CoachActivityGuide],
                          updater: any CoachActivityUpdating) {
        let saved = store.load()
        let valid = saved.flatMap { progress -> CoachProgress? in
            guard let guide = guides.first(where: { $0.id == progress.guideID }),
                  guide.steps.indices.contains(progress.stepIndex) else { return nil }
            return progress
        }
        if saved != nil, valid == nil { store.clear() }
        updater.enqueue(.reconcile(valid?.sessionID))
    }
}

#if !NEARME_LIVE_ACTIVITY_EXTENSION
extension CoachActivityUpdate {
    /// Compare with the activity's displayed state, including after a cold launch.
    /// Repeated publications/resume at the same step must not alert again.
    func alertConfiguration(previous: CoachActivitySnapshot?) -> AlertConfiguration? {
        guard case .show(let snapshot, _) = self,
              let previous,
              previous.attributes.sessionID == snapshot.attributes.sessionID,
              !previous.state.isComplete, !snapshot.state.isComplete,
              previous.state.stepNumber != snapshot.state.stepNumber else { return nil }
        // ActivityKit requires a sound. This bundled PCM file contains only silence.
        return AlertConfiguration(title: LocalizedStringResource("\(snapshot.attributes.guideTitle)"),
                                  body: LocalizedStringResource("\(snapshot.state.instruction)"),
                                  sound: .named("coach-step-silent.wav"))
    }
}

// All ActivityKit mutations belong to the app, including background intent execution.
@MainActor
final class CoachActivityUpdater: CoachActivityUpdating {
    static let shared = CoachActivityUpdater()
    private var pending: Task<Void, Never>?

    func enqueue(_ update: CoachActivityUpdate) {
        let previous = pending
        pending = Task {
            await previous?.value
            await self.apply(update)
        }
    }

    func flush() async { await pending?.value }

    private var active: [Activity<CoachActivityAttributes>] {
        Activity<CoachActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    private var visible: [Activity<CoachActivityAttributes>] {
        Activity<CoachActivityAttributes>.activities.filter { $0.activityState != .dismissed }
    }

    private func apply(_ update: CoachActivityUpdate) async {
        switch update {
        case .show(let snapshot, let startIfNeeded):
            var matching: Activity<CoachActivityAttributes>?
            for activity in visible {
                if activity.attributes.sessionID == snapshot.attributes.sessionID,
                   activity.activityState != .ended, matching == nil {
                    matching = activity
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            let content = ActivityContent(state: snapshot.state, staleDate: nil)
            if let matching {
                let previous = CoachActivitySnapshot(attributes: matching.attributes, state: matching.content.state)
                await matching.update(content, alertConfiguration: update.alertConfiguration(previous: previous))
            } else if startIfNeeded, ActivityAuthorizationInfo().areActivitiesEnabled {
                // Denied/unavailable activities never prevent the in-app guide from working.
                _ = try? Activity<CoachActivityAttributes>.request(attributes: snapshot.attributes, content: content, pushType: nil)
            }
        case .finish(let snapshot):
            for activity in active where activity.attributes.sessionID == snapshot.attributes.sessionID {
                await activity.end(ActivityContent(state: snapshot.state, staleDate: nil),
                                   dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        case .stop(let sessionID):
            for activity in visible where sessionID == nil || activity.attributes.sessionID == sessionID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        case .reconcile(let sessionID):
            for activity in visible where activity.attributes.sessionID != sessionID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
