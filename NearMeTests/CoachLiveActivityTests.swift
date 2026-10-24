import ActivityKit
import Foundation
import XCTest
@testable import NearMe

@MainActor
final class FakeCoachActivityUpdater: CoachActivityUpdating {
    var updates: [CoachActivityUpdate] = []
    var displayed: CoachActivitySnapshot?
    var alerts: [AlertConfiguration] = []
    var onEnqueue: ((CoachActivityUpdate) -> Void)?
    func enqueue(_ update: CoachActivityUpdate) {
        onEnqueue?(update)
        updates.append(update)
        if let alert = update.alertConfiguration(previous: displayed) { alerts.append(alert) }
        switch update {
        case .show(let snapshot, let startIfNeeded):
            if startIfNeeded || displayed?.attributes.sessionID == snapshot.attributes.sessionID {
                displayed = snapshot
            }
        case .finish, .stop:
            displayed = nil
        case .reconcile(let sessionID):
            if displayed?.attributes.sessionID != sessionID { displayed = nil }
        }
    }
    func flush() async {}
}

@MainActor
private final class FakeCoachProgressStore: CoachProgressStoring {
    var progress: CoachProgress?
    var writes = 0
    func load() -> CoachProgress? { progress }
    func save(_ progress: CoachProgress) { self.progress = progress; writes += 1 }
    func clear() { progress = nil; writes += 1 }
}

@MainActor
final class CoachLiveActivityTests: XCTestCase {
    func testCheckAndListenMetadataIsOptionalAndScopedToActiveYouTube() throws {
        let guide = try XCTUnwrap(GuideLibrary.load().first { $0.id == "youtube_play_song" }).activityGuide
        let progress = CoachProgress(guideID: guide.id, stepIndex: 1, sessionID: UUID(), revision: 0)
        let warm = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide, canCheckAndListen: true))
        XCTAssertEqual(warm.state.actionTitle, "Check & listen")
        XCTAssertTrue(warm.state.actionHint.contains("eight seconds"))
        let cold = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        XCTAssertEqual(cold.state.actionTitle, "Done")
        let completed = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide, completed: true, canCheckAndListen: true))
        XCTAssertNil(completed.state.canCheckAndListen)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(warm.state)) as? [String: Any])
        old.removeValue(forKey: "canCheckAndListen")
        let restored = try JSONDecoder().decode(CoachActivityAttributes.ContentState.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertEqual(restored.actionTitle, "Done")
        let other = try photoGuide()
        let otherProgress = CoachProgress(guideID: other.id, stepIndex: 1, sessionID: UUID(), revision: 0)
        let manual = try XCTUnwrap(CoachActivitySnapshot.build(progress: otherProgress, guide: other, canCheckAndListen: true))
        XCTAssertEqual(manual.state.actionTitle, "Done")
    }

    func testAlertsRequireAnExistingActivityAndAChangedStep() throws {
        let guide = try photoGuide()
        var progress = CoachProgress(guideID: guide.id, stepIndex: 0, sessionID: UUID(), revision: 0)
        let first = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        let updater = FakeCoachActivityUpdater()
        updater.enqueue(.show(first, startIfNeeded: false))
        XCTAssertNil(updater.displayed)
        XCTAssertTrue(updater.alerts.isEmpty)
        updater.enqueue(.show(first, startIfNeeded: true))
        XCTAssertTrue(updater.alerts.isEmpty, "The initial request does not alert")

        progress.stepIndex = 1
        progress.revision = 1
        let second = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        updater.enqueue(.show(second, startIfNeeded: true))
        XCTAssertEqual(updater.alerts.count, 1)
        updater.enqueue(.show(second, startIfNeeded: true))
        progress.revision = 2
        let repeated = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        updater.enqueue(.show(repeated, startIfNeeded: true))
        XCTAssertEqual(updater.alerts.count, 1, "Same-step resume/revision changes are silent")

        progress.stepIndex = 0
        progress.revision = 3
        let rollback = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        updater.enqueue(.show(rollback, startIfNeeded: true))
        XCTAssertEqual(updater.alerts.count, 2, "A failed auto-open returning to step 1 is a step change")
        let completed = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide, completed: true))
        updater.enqueue(.finish(completed))
        updater.enqueue(.stop(progress.sessionID))
        updater.enqueue(.reconcile(nil))
        updater.enqueue(.show(second, startIfNeeded: true))
        XCTAssertEqual(updater.alerts.count, 2, "End, cleanup and recreation must not alert")

        let otherProgress = CoachProgress(guideID: guide.id, stepIndex: 0, sessionID: UUID(), revision: 0)
        let otherSession = try XCTUnwrap(CoachActivitySnapshot.build(progress: otherProgress, guide: guide))
        updater.enqueue(.show(otherSession, startIfNeeded: true))
        XCTAssertEqual(updater.alerts.count, 2, "Replacing a different session is an initial start")
    }

    func testSilentAlertSoundIsIncludedInTheHostAppBundle() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "coach-step-silent", withExtension: "wav"))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 44, "The named sound must be a real bundled WAV, not a missing-file fallback")
    }

    func testDoneWithoutEnginePersistsBeforeUpdatingAndRejectsDuplicateStaleAndWrongSession() throws {
        let guide = try photoGuide()
        let progress = CoachProgress(guideID: guide.id, stepIndex: 1, sessionID: UUID(), revision: 4)
        let store = FakeCoachProgressStore()
        store.progress = progress
        let updater = FakeCoachActivityUpdater()
        updater.displayed = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        updater.onEnqueue = { _ in
            XCTAssertEqual(store.progress?.stepIndex, 2)
            XCTAssertEqual(store.progress?.revision, 5)
        }

        XCTAssertEqual(CoachDoneAction.perform(sessionID: progress.sessionID, expectedRevision: 4,
            store: store, guides: [guide], updater: updater), .advanced)
        for revision in [4, 3, 6] {
            XCTAssertEqual(CoachDoneAction.perform(sessionID: progress.sessionID, expectedRevision: revision,
                store: store, guides: [guide], updater: updater), .ignored)
        }
        XCTAssertEqual(CoachDoneAction.perform(sessionID: UUID(), expectedRevision: 5,
            store: store, guides: [guide], updater: updater), .ignored)
        XCTAssertEqual(store.writes, 1)
        XCTAssertEqual(updater.updates.count, 1)
        guard case .show(let snapshot, let start) = try XCTUnwrap(updater.updates.first) else {
            return XCTFail("Expected the activity's next state")
        }
        XCTAssertFalse(start, "An intent updates existing activities; it does not create one in the background")
        XCTAssertEqual(snapshot.state.stepNumber, 3)
        XCTAssertEqual(snapshot.state.revision, 5)
        XCTAssertEqual(updater.alerts.count, 1, "Only the accepted Done alerts")
        let alert = try XCTUnwrap(updater.alerts.first)
        XCTAssertEqual(String(localized: alert.title), guide.title)
        XCTAssertEqual(String(localized: alert.body), guide.steps[2].instruction)
        XCTAssertEqual(alert.sound, .named("coach-step-silent.wav"))
    }

    func testLastDoneWithoutEngineClearsSavedSessionAndEndsOnce() throws {
        let guide = try photoGuide()
        let progress = CoachProgress(guideID: guide.id, stepIndex: guide.steps.count - 1,
                                     sessionID: UUID(), revision: 10)
        let store = FakeCoachProgressStore()
        store.progress = progress
        let updater = FakeCoachActivityUpdater()
        updater.displayed = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        updater.onEnqueue = { _ in XCTAssertNil(store.load()) }
        XCTAssertEqual(CoachDoneAction.perform(sessionID: progress.sessionID, expectedRevision: 10,
            store: store, guides: [guide], updater: updater), .completed)
        XCTAssertEqual(CoachDoneAction.perform(sessionID: progress.sessionID, expectedRevision: 10,
            store: store, guides: [guide], updater: updater), .ignored)
        XCTAssertEqual(store.writes, 1)
        guard case .finish(let snapshot) = try XCTUnwrap(updater.updates.first) else { return XCTFail("Expected finish") }
        XCTAssertEqual(snapshot.state.instruction, "Done, well done")
        XCTAssertTrue(snapshot.state.isComplete)
        XCTAssertEqual(snapshot.state.revision, 11)
        XCTAssertTrue(updater.alerts.isEmpty, "Completion must not alert")
        XCTAssertEqual(CoachDeepLink.parse(try XCTUnwrap(CoachDeepLink.url(sessionID: progress.sessionID)),
                                         savedSessionID: store.load()?.sessionID), .home)
    }

    func testInvalidSavedGuideOrStepNeverAdvances() throws {
        let guide = try photoGuide()
        let store = FakeCoachProgressStore()
        let updater = FakeCoachActivityUpdater()
        for progress in [
            CoachProgress(guideID: "missing", stepIndex: 0, sessionID: UUID(), revision: 0),
            CoachProgress(guideID: guide.id, stepIndex: 999, sessionID: UUID(), revision: 0),
            CoachProgress(guideID: guide.id, stepIndex: -1, sessionID: UUID(), revision: 0)
        ] {
            store.progress = progress
            XCTAssertEqual(CoachDoneAction.perform(sessionID: progress.sessionID, expectedRevision: 0,
                store: store, guides: [guide], updater: updater), .ignored)
        }
        XCTAssertEqual(store.writes, 0)
        XCTAssertTrue(updater.updates.isEmpty)
    }

    func testPersistedPayloadContainsOnlyFourFieldsAndSurvivesANewStore() throws {
        let suite = "LiveActivityPersistence.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let guide = try XCTUnwrap(GuideLibrary.load().first)
        let session = CoachSession(guide: guide, request: "send to Alice in Sydney", person: "Alice",
                                   generalSteps: [], stepIndex: 1, text: "private rewrite in Sydney")
        CoachProgressStore(defaults: defaults).save(session)
        let data = try XCTUnwrap(defaults.data(forKey: CoachProgressStore.progressKey))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(payload.keys), ["guideID", "stepIndex", "sessionID", "revision"])
        XCTAssertEqual(Set(defaults.persistentDomain(forName: suite)?.keys.map { $0 } ?? []),
                       [CoachProgressStore.progressKey])
        let text = String(decoding: data, as: UTF8.self)
        for privateWord in ["Alice", "Sydney", "private", "rewrite"] { XCTAssertFalse(text.contains(privateWord)) }
        let reopened = CoachProgressStore(defaults: defaults)
        let restored = try XCTUnwrap(reopened.restore(guides: [guide]))
        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.revision, session.revision)
        XCTAssertEqual(restored.stepIndex, session.stepIndex)
        XCTAssertNil(restored.person)
        XCTAssertEqual(restored.request, "")
        let updater = FakeCoachActivityUpdater()
        XCTAssertEqual(CoachDoneAction.perform(sessionID: session.id, expectedRevision: session.revision,
            store: reopened, guides: [guide.activityGuide], updater: updater), .advanced)
        let nextLaunch = try XCTUnwrap(CoachProgressStore(defaults: defaults).restore(guides: [guide]))
        XCTAssertEqual(nextLaunch.stepIndex, 2)
        XCTAssertEqual(nextLaunch.revision, 1)
        XCTAssertEqual(nextLaunch.id, session.id)
    }

    func testP07ProgressMigrationKeepsStepAndAssignsStableIdentity() throws {
        let suite = "LiveActivityMigration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("whatsapp_send_photo", forKey: CoachProgressStore.guideKey)
        defaults.set(2, forKey: CoachProgressStore.stepKey)
        let first = try XCTUnwrap(CoachProgressStore(defaults: defaults).load())
        let second = CoachProgressStore(defaults: defaults).load()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.stepIndex, 2)
        XCTAssertEqual(first.revision, 0)
        XCTAssertNil(defaults.object(forKey: CoachProgressStore.guideKey))
        XCTAssertNil(defaults.object(forKey: CoachProgressStore.stepKey))
    }

    func testNormalColdLaunchUsesP07ResumePathOnlyWithValidSavedProgress() throws {
        let guide = try photoGuide()
        let store = FakeCoachProgressStore()
        let suite = "AskCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(AppCoordinator(progressStore: store, guides: [guide], defaults: defaults).route, .welcome)
        store.progress = CoachProgress(guideID: guide.id, stepIndex: 2, sessionID: UUID(), revision: 2)
        XCTAssertEqual(AppCoordinator(progressStore: store, guides: [guide], defaults: defaults).route, .session)
        store.progress?.stepIndex = 999
        XCTAssertEqual(AppCoordinator(progressStore: store, guides: [guide], defaults: defaults).route, .welcome)
    }

    func testURLParserResumesOnlyTheSavedSession() throws {
        let id = UUID()
        let url = try XCTUnwrap(CoachDeepLink.url(sessionID: id))
        XCTAssertEqual(url.absoluteString, "nearme://coach?session=\(id.uuidString)")
        XCTAssertEqual(CoachDeepLink.parse(url, savedSessionID: id), .coach(id))
        let mixedCase = try XCTUnwrap(URL(string: "NearMe://CoAcH?session=\(id.uuidString)"))
        XCTAssertEqual(CoachDeepLink.parse(mixedCase, savedSessionID: id), .coach(id))
        XCTAssertEqual(CoachDeepLink.parse(mixedCase, savedSessionID: nil), .home)
        XCTAssertEqual(CoachDeepLink.parse(url, savedSessionID: nil), .home)
        XCTAssertEqual(CoachDeepLink.parse(url, savedSessionID: UUID()), .home)
        let malformed = ["nearme://coach", "nearme://coach?session=", "nearme://coach?session=nope",
            "nearme:///coach?session=\(id)", "nearme://coach/path?session=\(id)",
            "nearme://coach?session=\(id)&session=\(id)", "nearme://coach?session=\(id)&extra=1",
            "nearme://coach?session=\(id)#fragment", "nearme://user@coach?session=\(id)",
            "nearme://coach:123?session=\(id)"]
        for text in malformed {
            XCTAssertEqual(CoachDeepLink.parse(try XCTUnwrap(URL(string: text)), savedSessionID: id), .home, text)
        }
        for text in ["nearme://ask", "nearme://other?session=\(id)", "https://coach?session=\(id)"] {
            XCTAssertEqual(CoachDeepLink.parse(try XCTUnwrap(URL(string: text)), savedSessionID: id), .ignored)
        }
    }

    func testBuilderUsesOnlyGuideInstructionsAndFormatsProgress() throws {
        let guide = try photoGuide()
        let progress = CoachProgress(guideID: guide.id, stepIndex: 2, sessionID: UUID(), revision: 2)
        let snapshot = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        XCTAssertEqual(snapshot.state.instruction, guide.steps[2].instruction)
        XCTAssertEqual(snapshot.state.progressText(totalSteps: 6), "3/6")
        for privateWord in ["Mum", "Alice", "Sydney"] { XCTAssertFalse(snapshot.state.instruction.contains(privateWord)) }
        let fullGuide = try XCTUnwrap(GuideLibrary.load().first { $0.id == guide.id })
        let personalized = CoachSession(guide: fullGuide, request: "send to Mum in Sydney", person: "Mum",
                                        generalSteps: [], stepIndex: 2, text: "Open your chat with Mum in Sydney")
        let editorialGuide = try XCTUnwrap(personalized.guide).activityGuide
        let safe = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: editorialGuide))
        XCTAssertEqual(safe.state, snapshot.state)
    }

    func testAllBundledStatesAndLongUnicodeContentFitUnderFourKB() throws {
        let guides = CoachActivityGuide.bundled()
        XCTAssertEqual(guides.count, 16)
        for guide in guides {
            for step in guide.steps.indices {
                let progress = CoachProgress(guideID: guide.id, stepIndex: step, sessionID: UUID(), revision: step)
                try assertBounded(try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide)))
            }
        }
        let long = String(repeating: "a", count: 200)
        let guide = CoachActivityGuide(id: "long", title: long, steps: [.init(instruction: long)])
        let progress = CoachProgress(guideID: guide.id, stepIndex: 0, sessionID: UUID(), revision: 0)
        let snapshot = try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: guide))
        XCTAssertEqual(snapshot.state.instruction.count, 120)
        try assertBounded(snapshot)
        let combining = "a" + String(repeating: "\u{0301}", count: 1_000)
        let pathological = CoachActivityGuide(id: "long", title: combining, steps: [.init(instruction: combining)])
        try assertBounded(try XCTUnwrap(CoachActivitySnapshot.build(progress: progress, guide: pathological)))
    }

    func testLaunchReconciliationKeepsOnlyAValidSavedSession() throws {
        let guide = try photoGuide()
        let store = FakeCoachProgressStore()
        let updater = FakeCoachActivityUpdater()
        let progress = CoachProgress(guideID: guide.id, stepIndex: 1, sessionID: UUID(), revision: 1)
        store.progress = progress
        CoachActivityLifecycle.reconcile(store: store, guides: [guide], updater: updater)
        guard case .reconcile(let validID) = try XCTUnwrap(updater.updates.last) else { return XCTFail("Expected reconciliation") }
        XCTAssertEqual(validID, progress.sessionID)
        CoachActivityLifecycle.reconcile(store: store, guides: [], updater: updater)
        guard case .reconcile(let staleID) = try XCTUnwrap(updater.updates.last) else { return XCTFail("Expected stale cleanup") }
        XCTAssertNil(staleID)
        XCTAssertNil(store.progress)
        CoachActivityLifecycle.reconcile(store: store, guides: [guide], updater: updater)
        guard case .reconcile(let absentID) = try XCTUnwrap(updater.updates.last) else { return XCTFail("Expected absent cleanup") }
        XCTAssertNil(absentID)
    }

    private func photoGuide() throws -> CoachActivityGuide {
        try XCTUnwrap(GuideLibrary.load().first { $0.id == "whatsapp_send_photo" }).activityGuide
    }

    private func assertBounded(_ snapshot: CoachActivitySnapshot) throws {
        let attributes = try JSONEncoder().encode(snapshot.attributes)
        let state = try JSONEncoder().encode(snapshot.state)
        XCTAssertLessThan(attributes.count + state.count, 4_096)
        XCTAssertLessThanOrEqual(snapshot.state.instruction.count, 120)
    }
}
