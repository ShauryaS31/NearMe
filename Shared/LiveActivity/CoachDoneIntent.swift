import AppIntents
import Foundation

nonisolated enum CoachDoneResult: Equatable, Sendable { case ignored, advanced, completed, rechecked }

@MainActor
enum CoachDoneAction {
    /// The compare/save/enqueue portion has no suspension point. Concurrent taps cannot
    /// both consume a revision, including when no engine or view has been created.
    static func perform(sessionID: UUID, expectedRevision: Int, store: any CoachProgressStoring,
                        guides: [CoachActivityGuide], updater: any CoachActivityUpdating,
                        recheck: ((CoachProgress) -> Bool)? = nil) -> CoachDoneResult {
        guard var progress = store.load(), progress.sessionID == sessionID,
              progress.revision == expectedRevision, progress.revision >= 0, progress.revision < Int.max - 1,
              let guide = guides.first(where: { $0.id == progress.guideID }),
              guide.steps.indices.contains(progress.stepIndex) else { return .ignored }
        if recheck?(progress) == true { return .rechecked }
        progress.revision += 1
        if progress.stepIndex + 1 == guide.steps.count {
            guard let snapshot = CoachActivitySnapshot.build(progress: progress, guide: guide, completed: true)
            else { return .ignored }
            store.clear()
            updater.enqueue(.finish(snapshot))
            return .completed
        }
        progress.stepIndex += 1
        guard let snapshot = CoachActivitySnapshot.build(progress: progress, guide: guide) else { return .ignored }
        store.save(progress)
        updater.enqueue(.show(snapshot, startIfNeeded: false))
        return .advanced
    }
}

/// Included in BOTH targets. LiveActivityIntent runs perform in the app process,
/// including background launch; ordinary AppIntent would not provide that guarantee.
nonisolated struct CoachDoneIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark step done"
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = false

    @Parameter(title: "Session") var sessionID: String
    @Parameter(title: "Expected revision") var expectedRevision: Int

    init() {}

    init(sessionID: UUID, expectedRevision: Int) {
        self.sessionID = sessionID.uuidString
        self.expectedRevision = expectedRevision
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !NEARME_LIVE_ACTIVITY_EXTENSION
        guard let id = UUID(uuidString: sessionID) else { return .result() }
        let updater = CoachActivityUpdater.shared
        let store = CoachProgressStore()
        let guides = CoachActivityGuide.bundled()
        var screenSpeech: String?
        _ = CoachDoneAction.perform(sessionID: id, expectedRevision: expectedRevision,
            store: store, guides: guides, updater: updater, recheck: { progress in
                ScreenCoachIntentRecheck.perform(progress: progress, source: AppGroupScreenSnapshotSource(),
                    now: Date().timeIntervalSince1970, store: store, guides: guides, updater: updater,
                    speech: { screenSpeech = $0 })
            })
        await updater.flush()
        if let screenSpeech {
            // The warm engine owns speech when present; a cold launch has no engine.
            let output = ElevenLabsVoiceOutput()
            await output.speak(screenSpeech)
        }
        #endif
        // The extension only supplies Button(intent:) metadata; execution is in the app.
        return .result()
    }
}
