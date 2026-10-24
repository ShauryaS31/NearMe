import Foundation
import XCTest
@testable import NearMe

@MainActor
final class ScreenCoachIntegrationTests: XCTestCase {
    func testSharingStartingDuringAnnouncementDoesNotSkipOpeningStep() async throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        fixture.output.suspendOn = "I'll open YouTube for you now."
        let store = fixture.store
        var stepAtOpen: Int?
        fixture.opener.onOpen = { stepAtOpen = store.load()?.stepIndex }
        fixture.start()
        await eventually { fixture.output.pending != nil }
        XCTAssertEqual(store.load()?.stepIndex, 0)
        fixture.show(["Home", "Shorts", "Search"])
        fixture.engine.pollScreen()
        fixture.output.finish()
        await eventually { fixture.engine.coach?.stepIndex == 1 && fixture.engine.plannerState == .idle }
        XCTAssertEqual(stepAtOpen, 0, "Only the post-handoff observation may advance the guide")
        XCTAssertEqual(fixture.output.lines.filter { $0 == "I'll open YouTube for you now." }.count, 1)
    }

    func testStopDuringObservedAnnouncementCancelsHandoffAndPolling() async throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        fixture.show(["Home", "Shorts", "Search"])
        fixture.output.suspendOn = "I'll open YouTube for you now."
        fixture.start()
        await eventually { fixture.output.pending != nil }
        fixture.engine.endSession()
        await Task.yield()
        fixture.show(["Search YouTube", "space", "return"])
        fixture.engine.pollScreen()
        await Task.yield()
        XCTAssertTrue(fixture.opener.urls.isEmpty)
        XCTAssertNil(fixture.engine.coach)
        XCTAssertTrue(fixture.engine.isHome)
        XCTAssertNil(fixture.store.load())
    }

    func testEngineRechecksDoneThenFollowsChangedPageAndPublishesGenericActivity() async throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        fixture.show(["Home", "Shorts", "Search"])
        fixture.start()
        await eventually { fixture.engine.coach?.stepIndex == 1 && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.opener.urls.map(\.absoluteString), ["youtube://"])
        XCTAssertFalse(fixture.engine.screenManualMode)
        let before = fixture.output.lines.count
        fixture.engine.coachCommand(.next)
        await eventually { fixture.output.lines.count > before && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.engine.coach?.stepIndex, 1)
        XCTAssertEqual(fixture.store.load()?.stepIndex, 1)
        fixture.engine.appEnteredBackground()
        fixture.show(["Search YouTube", "space", "return"])
        fixture.engine.pollScreen()
        await eventually { fixture.engine.coach?.stepIndex == 2 && fixture.engine.plannerState == .idle }
        XCTAssertTrue(fixture.engine.coach?.text.contains("Tum Hi Ho") == true)
        XCTAssertFalse(fixture.activity.instructions.contains { $0.contains("Tum Hi Ho") })
        XCTAssertGreaterThan(fixture.audio.starts, 0)
        fixture.show(["Home", "Shorts", "Tum Hi Ho", "10M views", "2 years ago"])
        fixture.engine.pollScreen()
        await eventually { fixture.engine.coach?.stepIndex == 4 && fixture.engine.plannerState == .idle }
        fixture.show(["Subscribe", "Share", "Comments", "Up next"])
        fixture.engine.pollScreen()
        await eventually { fixture.engine.coach?.stepIndex == 5 && fixture.engine.plannerState == .idle }
        fixture.engine.coachCommand(.next)
        await eventually { fixture.engine.plannerState == .idle }
        XCTAssertNotNil(fixture.engine.coach, "Done is not confirmation of playback")
        fixture.engine.appBecameActive()
        fixture.engine.useTypedInput()
        fixture.engine.submitTypedInput("yes")
        await eventually { fixture.engine.isHome }
        XCTAssertNil(fixture.store.load())
        XCTAssertTrue(fixture.output.lines.contains("Enjoy your song."))
    }

    func testPromptInterruptsProgressAndUnknownDescriptionStaysWithinGuide() async throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        fixture.show(["Home", "Shorts", "Search"])
        fixture.start()
        await eventually { fixture.engine.coach?.stepIndex == 1 && fixture.engine.plannerState == .idle }
        fixture.show(["Home", "Shorts", "Sign in", "Not now"])
        fixture.engine.pollScreen()
        await eventually { fixture.engine.coach?.text.contains("\"Not now\"") == true && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.engine.coach?.stepIndex, 1)
        fixture.show([])
        fixture.engine.pollScreen()
        await eventually { fixture.engine.coach?.text.contains("What do you see?") == true && fixture.engine.plannerState == .idle }
        fixture.engine.useTypedInput()
        fixture.engine.submitTypedInput("a sign in box")
        await eventually { fixture.engine.coach?.text.hasPrefix("From your description") == true && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.engine.coach?.guide?.id, "youtube_play_song")
        XCTAssertEqual(fixture.engine.coach?.stepIndex, 1)
    }

    func testWrongAppOffersOnceAndYesUsesOpenPathWithoutAdvancing() async throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        fixture.show(["Home", "Shorts", "Search"])
        fixture.start()
        await eventually { fixture.engine.coach?.stepIndex == 1 && fixture.engine.plannerState == .idle }
        fixture.show(["WhatsApp", "Chats", "Calls"])
        fixture.engine.pollScreen()
        fixture.now += 3
        fixture.show(["WhatsApp", "Chats", "Calls"])
        fixture.engine.pollScreen()
        await eventually { fixture.output.lines.contains { $0.contains("Shall I open it again?") } && fixture.engine.plannerState == .idle }
        for _ in 0..<5 {
            fixture.now += 4
            fixture.show(["WhatsApp", "Chats", "Calls"])
            fixture.engine.pollScreen()
        }
        XCTAssertEqual(fixture.output.lines.filter { $0.contains("Shall I open it again?") }.count, 1)
        fixture.engine.useTypedInput()
        fixture.engine.submitTypedInput("yes")
        await eventually { fixture.opener.urls.count == 2 && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.engine.coach?.stepIndex, 1)
        XCTAssertEqual(fixture.opener.urls.map(\.absoluteString), ["youtube://", "youtube://"])
    }

    func testStaleSpeaksOnceAndDoneReturnsToManualAdvance() async throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        fixture.show(["Home", "Shorts", "Search"])
        fixture.start()
        await eventually { fixture.engine.coach?.stepIndex == 1 && fixture.engine.plannerState == .idle }
        fixture.now += 4
        fixture.engine.pollScreen()
        await eventually { fixture.output.lines.contains { $0.hasPrefix("I can't see your screen right now.") } && fixture.engine.plannerState == .idle }
        XCTAssertTrue(fixture.engine.screenManualMode)
        fixture.engine.pollScreen()
        fixture.engine.pollScreen()
        XCTAssertEqual(fixture.output.lines.filter { $0.hasPrefix("I can't see your screen right now.") }.count, 1)
        fixture.engine.coachCommand(.next)
        await eventually { fixture.engine.coach?.stepIndex == 2 && fixture.engine.plannerState == .idle }
        XCTAssertGreaterThan(fixture.audio.stops, 0)
    }

    func testLiveActivityDoneUsesFreshScreenAndStaleStillAdvancesManually() throws {
        let fixture = try ScreenCoachFixture()
        defer { fixture.cleanUp() }
        let progress = CoachProgress(guideID: fixture.guide.id, stepIndex: 1, sessionID: UUID(), revision: 0)
        fixture.store.save(progress)
        fixture.show(["Home", "Shorts", "Search"])
        func done(_ expected: Int) -> CoachDoneResult {
            CoachDoneAction.perform(sessionID: progress.sessionID, expectedRevision: expected,
                store: fixture.store, guides: [fixture.guide.activityGuide], updater: fixture.activity,
                recheck: { value in
                    ScreenCoachIntentRecheck.perform(progress: value, source: fixture.source, now: fixture.now,
                        store: fixture.store, guides: [fixture.guide.activityGuide], updater: fixture.activity)
                })
        }
        XCTAssertEqual(done(0), .rechecked)
        XCTAssertEqual(fixture.store.load()?.stepIndex, 1)
        XCTAssertEqual(done(0), .ignored, "Old revision cannot consume a newer recheck")
        fixture.show(["Search YouTube", "space", "return"])
        XCTAssertEqual(done(1), .rechecked)
        XCTAssertEqual(fixture.store.load()?.stepIndex, 2)
        fixture.show(["Search YouTube", "Sign in", "Not now"])
        XCTAssertEqual(done(2), .rechecked)
        XCTAssertEqual(fixture.store.load()?.stepIndex, 2)
        XCTAssertTrue(fixture.activity.instructions.last?.contains("\"Not now\"") == true)
        fixture.now += 4
        XCTAssertEqual(done(3), .advanced)
        XCTAssertEqual(fixture.store.load()?.stepIndex, 3)
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Expected screen coach state was not reached")
    }
}

@MainActor
private final class ScreenCoachFixture {
    let source = FakeScreenSnapshotSource()
    let output = ScreenTestOutput()
    let opener = ScreenTestOpener()
    let activity = ScreenTestActivity()
    let audio = ScreenTestAudio()
    let guide: HelpGuide
    let suite: String
    let defaults: UserDefaults
    let store: CoachProgressStore
    private let clock = ScreenTestClock()
    var now: TimeInterval {
        get { clock.now }
        set { clock.now = newValue }
    }
    let engine: TaskPlannerEngine

    init() throws {
        guide = try XCTUnwrap(GuideLibrary.load().first { $0.id == "youtube_play_song" })
        suite = "ScreenCoachTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        store = CoachProgressStore(defaults: defaults)
        let clock = self.clock
        engine = TaskPlannerEngine(brain: KeywordFallbackBrain(), voiceInput: ScreenTestInput(), voiceOutput: output,
            permissions: PermissionsManager(), userName: "", permissionCheck: { false }, settleBeforeListening: {},
            guides: [guide], helpRouter: ScreenTestRouter(), coachService: CoachModelService(brain: nil),
            coachStore: store, appOpener: opener, activityUpdater: activity, screenSource: source,
            screenNow: { clock.now }, screenAudio: audio)
        engine.appBecameActive()
    }

    func show(_ texts: [String]) {
        let lines: [ScreenSnapshot.Line] = texts.enumerated().map { index, text in
            ScreenSnapshot.Line(text: text,
                box: ScreenSnapshot.Box(x: 0.1, y: 0.2 + Double(index) * 0.05, width: 0.5, height: 0.03))
        }
        source.value = ScreenSnapshot(timestamp: now, lines: lines)
    }

    func start() {
        engine.useTypedInput()
        engine.submitTypedInput("play tum hi ho on youtube")
    }

    func cleanUp() {
        engine.endSession()
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
private final class ScreenTestClock { var now = 100.0 }

@MainActor
private final class ScreenTestOutput: VoiceOutputService {
    var lines: [String] = []
    var suspendOn: String?
    var pending: CheckedContinuation<Void, Never>?
    func speak(_ text: String) async {
        lines.append(text)
        if text == suspendOn { await withCheckedContinuation { pending = $0 } }
    }
    func stop() { finish() }
    func finish() {
        let next = pending
        pending = nil
        next?.resume()
    }
}

@MainActor
private final class ScreenTestInput: VoiceInputService {
    var isListening = false
    var acceptsTranscript: () -> Bool = { true }
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String { throw CancellationError() }
    func finishListening() {}
    func stopListening() {}
}

@MainActor
private struct ScreenTestRouter: HelpRouting {
    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        BrainAnswer(value: HelpChoice(route: .guide("youtube_play_song"), person: nil, song: "Tum Hi Ho"), source: .template)
    }
}

@MainActor
private final class ScreenTestOpener: CoachAppOpening {
    var urls: [URL] = []
    var onOpen: (() -> Void)?
    func canOpen(_ url: URL) -> Bool { true }
    func open(_ url: URL) async -> Bool { onOpen?(); urls.append(url); return true }
}

@MainActor
private final class ScreenTestActivity: CoachActivityUpdating {
    var instructions: [String] = []
    func enqueue(_ update: CoachActivityUpdate) {
        if case .show(let snapshot, _) = update { instructions.append(snapshot.state.instruction) }
    }
    func flush() async {}
}

@MainActor
private final class ScreenTestAudio: ScreenGuidanceKeepingAlive {
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
}
