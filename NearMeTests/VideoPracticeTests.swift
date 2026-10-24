import Foundation
import XCTest
@testable import NearMe

@MainActor
final class VideoPracticeTests: XCTestCase {
    func testRouterPracticePhrasesWithFallbackAndFakeModel() async {
        let cases: [(String, HelpRoute)] = [
            ("practise playing a song", .practiceVideo),
            ("can I practise first", .practiceVideo),
            ("practise youtube", .practiceVideo),
            ("practice finding a video", .practiceVideo),
            ("rehearse playing music", .practiceVideo),
            ("I want to practise planning a train trip", .practiceTripPlanner),
            ("can I practise a bus journey first", .practiceTripPlanner)
        ]
        // A strong guide candidate must not swallow an explicit practice request.
        let guide = fixtureGuide()
        let model = VideoTestCoachBrain()
        let services = [
            CoachModelService(brain: nil, modelAccess: PlannerModelAccess(availability: { .available })),
            CoachModelService(brain: model, modelAccess: PlannerModelAccess(availability: { .available }))
        ]
        for (index, service) in services.enumerated() {
            let router = HelpRouter(guides: [guide], service: service, useEmbeddings: false)
            for (request, expected) in cases {
                model.choice = expected
                let answer = await router.route(request)
                XCTAssertEqual(answer.value.route, expected, request)
                XCTAssertEqual(answer.source, index == 0 ? .keywordFallback : .onDeviceModel)
            }
        }
        let router = HelpRouter(guides: [guide], service: services[1], useEmbeddings: false)
        for wrongChoice in [HelpRoute.general, .guide(guide.id), .practiceTripPlanner] {
            model.choice = wrongChoice
            let answer = await router.route("practise youtube")
            XCTAssertEqual(answer.value.route, .practiceVideo)
            XCTAssertEqual(answer.source, .keywordFallback)
        }
        model.choice = .guide(guide.id)
        let normalGuide = await router.route("play a song")
        XCTAssertEqual(normalGuide.value.route, .guide(guide.id))
    }

    func testEveryStepNamesATargetOnItsScreenAndPulsesThreeTimes() {
        for step in VideoPracticeStep.allCases {
            XCTAssertTrue(step.screen.targetLabels.contains(step.targetLabel), "\(step)")
            XCTAssertTrue(step.caption.contains(step.targetLabel), "\(step)")
            var highlight = PracticeHighlightState()
            let request = PracticePulseRequest(targetID: step.targetLabel, repeatRevision: 0, reduceMotion: false)
            highlight.update(request)
            XCTAssertEqual(highlight.pulsesRemaining, 3)
            for _ in 0..<3 { highlight.completeCycle() }
            highlight.update(request)
            XCTAssertEqual(highlight.pulsesRemaining, 0)
            highlight.update(PracticePulseRequest(targetID: step.targetLabel, repeatRevision: 1, reduceMotion: true))
            XCTAssertEqual(highlight.pulsesRemaining, 0)
        }
    }

    func testFiveActionsAcceptAnySongAndCompleteOnlyAfterPlay() {
        for song in ["Tum Hi Ho", "My own song", "नमस्ते", "", "123"] {
            let practice = VideoPracticeViewModel()
            var advances = 0
            practice.onStepAdvanced = { advances += 1 }
            XCTAssertEqual(practice.song, "Tum Hi Ho")
            practice.play()
            practice.search()
            XCTAssertEqual(practice.step, .tapSearch)
            practice.openSearch()
            XCTAssertEqual(practice.step, .typeSong)
            practice.song = song
            practice.enterSong()
            XCTAssertEqual(practice.step, .submitSearch)
            practice.search()
            XCTAssertEqual(practice.step, .selectResult)
            practice.selectFirstResult()
            XCTAssertEqual(practice.step, .tapPlay)
            XCTAssertFalse(practice.isComplete)
            practice.play()
            XCTAssertTrue(practice.isComplete)
            XCTAssertEqual(practice.song, song)
            XCTAssertEqual(practice.currentCaption, "That's the practice done. In the real app you'd do the same steps.")
            practice.play()
            XCTAssertEqual(advances, 5)
        }
    }

    func testRoutedPracticeSpeaksEachCaptionAndCompletionWithoutJourneyQuestions() async throws {
        let output = VideoTestOutput()
        let engine = try makeEngine(output: output)
        engine.useTypedInput()
        engine.submitTypedInput("practise playing a song")
        await eventually { engine.videoPracticeViewModel != nil && !engine.isVoiceOutputActive }
        let practice = try XCTUnwrap(engine.videoPracticeViewModel)
        await eventually { output.lines.last == practice.currentCaption }
        XCTAssertNil(engine.coach)
        XCTAssertNil(engine.tripPlannerPracticeViewModel)
        XCTAssertEqual(engine.currentIntent.kind, .unknown)
        XCTAssertNil(engine.currentIntent.origin)
        XCTAssertNil(engine.currentIntent.destination)
        let actions: [() -> Void] = [practice.openSearch, practice.enterSong, practice.search,
                                    practice.selectFirstResult, practice.play]
        for action in actions {
            action()
            await eventually { output.lines.last == practice.currentCaption && !engine.isVoiceOutputActive }
        }
        XCTAssertEqual(output.lines.last, VideoPracticeStep.completionLine)
        XCTAssertTrue(practice.isComplete)
        XCTAssertFalse(engine.isHome, "Keep the completion caption readable until Close or End session")
        engine.endSession()
        XCTAssertTrue(engine.isHome)
        XCTAssertNil(engine.videoPracticeViewModel)
    }

    func testRepeatSlowerStopAndStaleCallbacksRetainOrEndPracticeCorrectly() async throws {
        let output = VideoTestOutput()
        let engine = try makeEngine(output: output)
        engine.startVideoPractice()
        let practice = try XCTUnwrap(engine.videoPracticeViewModel)
        await eventually { output.lines.last == practice.currentCaption }
        output.suspend = true
        engine.performDockAction(.repeatStep)
        await eventually { output.pending != nil }
        XCTAssertEqual(practice.highlightRepeatRevision, 1)
        engine.performDockAction(.slower)
        await eventually { output.pending != nil && output.slower }
        XCTAssertEqual(practice.highlightRepeatRevision, 1)
        engine.stopSessionSpeech()
        XCTAssertFalse(engine.isVoiceOutputActive)
        XCTAssertNil(output.pending)
        XCTAssertEqual(practice.step, .tapSearch)
        practice.openSearch()
        await eventually { output.pending != nil }
        XCTAssertEqual(output.lines.last, practice.currentCaption)
        engine.endSession()
        let count = output.lines.count
        practice.enterSong() // A removed screen cannot restart speech.
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(engine.isHome)
        XCTAssertEqual(output.lines.count, count)
        XCTAssertNil(output.pending)
    }

    func testGuideCompletionOffersPracticeAndButtonsAcceptOrDecline() async throws {
        for accept in [true, false] {
            let output = VideoTestOutput()
            let engine = try makeEngine(output: output)
            await finishGuide(engine)
            XCTAssertNil(engine.coach)
            XCTAssertFalse(engine.isHome)
            XCTAssertEqual(output.lines.last, "Want to practise this again safely?")
            engine.respondToVideoPracticeOffer(accept: accept)
            XCTAssertFalse(engine.offersVideoPractice)
            XCTAssertEqual(engine.videoPracticeViewModel != nil, accept)
            XCTAssertEqual(engine.isHome, !accept)
            engine.endSession()
        }
    }

    func testOfferAcceptsTypedAndSpokenAnswers() async throws {
        for spoken in [true, false] {
            for answer in ["yes please", "no thanks", "can I practise first"] {
                let input = VideoTestInput()
                let engine = try makeEngine(input: input)
                await finishGuide(engine)
                if spoken {
                    input.transcript = answer
                    engine.userTappedToTalk()
                } else {
                    engine.useTypedInput()
                    engine.submitTypedInput(answer)
                }
                await eventually { !engine.offersVideoPractice }
                XCTAssertEqual(engine.isHome, answer == "no thanks")
                XCTAssertEqual(engine.videoPracticeViewModel != nil, answer != "no thanks")
                engine.endSession()
            }
        }
    }

    func testPractiseFirstDuringGuideUsesVideoContext() async throws {
        let engine = try makeEngine()
        engine.useTypedInput()
        engine.submitTypedInput("play a song")
        await eventually { engine.coach != nil && engine.plannerState == .idle }
        engine.submitTypedInput("can I practise first")
        await eventually { engine.videoPracticeViewModel != nil }
        XCTAssertNil(engine.coach)
        XCTAssertNil(engine.tripPlannerPracticeViewModel)
        engine.endSession()
    }

    func testOtherGuidesFinishAtHomeWithoutVideoOffer() async throws {
        let engine = try makeEngine(guideID: "another_guide")
        engine.useTypedInput()
        engine.submitTypedInput("play a song")
        await eventually { engine.coach != nil && engine.plannerState == .idle }
        engine.coachCommand(.next)
        await eventually { engine.isHome }
        XCTAssertFalse(engine.offersVideoPractice)
        XCTAssertNil(engine.videoPracticeViewModel)
    }

    func testEndingDuringOfferSpeechCannotStartPracticeLater() async throws {
        let output = VideoTestOutput()
        let engine = try makeEngine(output: output)
        engine.useTypedInput()
        engine.submitTypedInput("play a song")
        await eventually { engine.coach != nil && engine.plannerState == .idle }
        output.suspend = true
        engine.coachCommand(.next)
        await eventually { engine.offersVideoPractice && output.pending != nil }
        engine.endSession()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(engine.isHome)
        XCTAssertFalse(engine.offersVideoPractice)
        XCTAssertNil(engine.videoPracticeViewModel)
        XCTAssertNil(output.pending)
    }

    private func finishGuide(_ engine: TaskPlannerEngine) async {
        engine.useTypedInput()
        engine.submitTypedInput("play a song")
        await eventually { engine.coach != nil && engine.plannerState == .idle }
        engine.coachCommand(.next)
        await eventually { engine.offersVideoPractice && !engine.isVoiceOutputActive }
    }

    private func fixtureGuide(id: String = "youtube_play_song") -> HelpGuide {
        HelpGuide(id: id, title: "Play a song", app: "Video app", appURLScheme: nil,
                  aliases: ["play a song", "practise youtube"],
                  steps: [HelpGuide.Step(instruction: "Tap Play.", uiLabelHint: "Play")],
                  sourceNote: "Local test fixture", lastChecked: "2026-10-24")
    }

    private func makeEngine(output: VideoTestOutput? = nil, input: VideoTestInput? = nil,
                            guideID: String = "youtube_play_song") throws -> TaskPlannerEngine {
        let guides = [fixtureGuide(id: guideID)]
        let service = CoachModelService(brain: nil, modelAccess: PlannerModelAccess(availability: { .available }))
        let suite = "VideoPracticeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return TaskPlannerEngine(brain: KeywordFallbackBrain(), voiceInput: input ?? VideoTestInput(),
            voiceOutput: output ?? VideoTestOutput(), permissions: PermissionsManager(), userName: "",
            permissionCheck: { true }, settleBeforeListening: {}, guides: guides,
            helpRouter: HelpRouter(guides: guides, service: service, useEmbeddings: false),
            coachService: service, coachStore: CoachProgressStore(defaults: defaults),
            appOpener: UnavailableCoachAppOpener(), activityUpdater: FakeCoachActivityUpdater())
    }

    private func eventually(_ condition: () -> Bool) async {
        await Task.yield()
        for _ in 0..<1500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Video practice did not reach the expected state")
    }
}

@MainActor
private final class VideoTestCoachBrain: CoachBrain {
    var choice: HelpRoute = .practiceVideo
    func route(request: String, candidates: [GuideCandidate]) async throws -> HelpChoice {
        HelpChoice(route: choice)
    }
    func rewrite(request: String, guide: HelpGuide, step: HelpGuide.Step, person: String?, stuck: Bool) async throws -> String {
        step.instruction
    }
    func general(request: String) async throws -> [String] { [CoachText.generalFallback] }
}

@MainActor
private final class VideoTestInput: VoiceInputService {
    var acceptsTranscript: () -> Bool = { true }
    var isListening = false
    var transcript = ""
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String { transcript }
    func finishListening() {}
    func stopListening() {}
}

@MainActor
private final class VideoTestOutput: VoiceOutputService {
    var lines: [String] = []
    var slower = false
    var suspend = false
    var pending: CheckedContinuation<Void, Never>?
    func speak(_ text: String) async {
        lines.append(text)
        if suspend { await withCheckedContinuation { pending = $0 } }
    }
    func setSlower(_ slower: Bool) { self.slower = slower }
    func stop() {
        let continuation = pending
        pending = nil
        continuation?.resume()
    }
}
