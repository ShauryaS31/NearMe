import Foundation

@MainActor
enum ScreenCoachIntentRecheck {
    static let requested = Notification.Name("NearMe.screenCoachRecheck")

    /// Also works on a cold intent launch: choose a step from the current screen,
    /// never from stepIndex + 1. The warm engine speaks after the notification.
    static func perform(progress: CoachProgress, source: any ScreenSnapshotSource, now: TimeInterval,
                        store: any CoachProgressStoring, guides: [CoachActivityGuide],
                        updater: any CoachActivityUpdating) -> Bool {
        guard progress.guideID == "youtube_play_song", let screen = source.latest(), screen.isFresh(at: now),
              let guide = guides.first(where: { $0.id == progress.guideID }) else { return false }
        var loop = ScreenCoachLoop()
        let value = loop.update(snapshot: screen, guideID: progress.guideID, song: nil, now: now, recheck: true)
        var checked = progress
        if let index = value?.stepIndex, guide.steps.indices.contains(index) { checked.stepIndex = index }
        checked.revision += 1
        let text = value?.activityText ?? "Return to NearMe to check your screen."
        if let snapshot = CoachActivitySnapshot.build(progress: checked, guide: guide, observedInstruction: text) {
            store.save(checked)
            updater.enqueue(.show(snapshot, startIfNeeded: false))
        }
        NotificationCenter.default.post(name: requested, object: progress.sessionID)
        return true
    }
}
