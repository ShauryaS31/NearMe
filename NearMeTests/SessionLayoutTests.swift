import SwiftUI
import XCTest
@testable import NearMe

@MainActor
final class SessionLayoutTests: XCTestCase {
    func testNewHighlightRunsExactlyThreeCyclesThenStaysStatic() {
        var state = PracticeHighlightState()
        let request = PracticePulseRequest(targetID: "Journey Planner", repeatRevision: 0, reduceMotion: false)
        state.update(request)
        XCTAssertEqual(state.pulsesRemaining, 3)
        for remaining in [2, 1, 0] {
            state.completeCycle()
            XCTAssertEqual(state.pulsesRemaining, remaining)
            state.update(request) // An anchor/layout update must not restart the sequence.
            XCTAssertEqual(state.pulsesRemaining, remaining)
        }
        state.completeCycle()
        XCTAssertEqual(state.pulsesRemaining, 0)
    }

    func testRepeatResetsHighlightDuringAndAfterPulsing() {
        var state = PracticeHighlightState()
        state.update(PracticePulseRequest(targetID: "Search", repeatRevision: 0, reduceMotion: false))
        state.completeCycle()
        XCTAssertEqual(state.pulsesRemaining, 2)
        state.update(PracticePulseRequest(targetID: "Search", repeatRevision: 1, reduceMotion: false))
        XCTAssertEqual(state.pulsesRemaining, 3)
        for _ in 0..<3 { state.completeCycle() }
        XCTAssertEqual(state.pulsesRemaining, 0)
        state.update(PracticePulseRequest(targetID: "Search", repeatRevision: 2, reduceMotion: false))
        XCTAssertEqual(state.pulsesRemaining, 3)
    }

    func testReduceMotionSuppressesNewTargetRepeatAndAnActivePulse() {
        var state = PracticeHighlightState()
        state.update(PracticePulseRequest(targetID: "Journey Planner", repeatRevision: 0, reduceMotion: true))
        XCTAssertEqual(state.pulsesRemaining, 0)
        state.update(PracticePulseRequest(targetID: "Journey Planner", repeatRevision: 1, reduceMotion: true))
        XCTAssertEqual(state.pulsesRemaining, 0)
        state.update(PracticePulseRequest(targetID: "Choose origin", repeatRevision: 1, reduceMotion: true))
        state.completeCycle()
        XCTAssertEqual(state.pulsesRemaining, 0)

        state.update(PracticePulseRequest(targetID: "Search", repeatRevision: 1, reduceMotion: false))
        XCTAssertEqual(state.pulsesRemaining, 3)
        state.completeCycle()
        state.update(PracticePulseRequest(targetID: "Search", repeatRevision: 1, reduceMotion: true))
        XCTAssertEqual(state.pulsesRemaining, 0)
        state.update(PracticePulseRequest(targetID: "Search", repeatRevision: 1, reduceMotion: false))
        XCTAssertEqual(state.pulsesRemaining, 0, "Disabling Reduce Motion alone does not request another pulse")
    }

    func testChangingPracticeStepResetsPulsesForItsNewTarget() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: "Central", mode: nil)
        let practice = TripPlannerPracticeViewModel(intent: intent)
        practice.fromFieldText = "Central"
        practice.destinationSearchQuery = "Town Hall"
        var state = PracticeHighlightState()
        for step in PracticeStep.allCases {
            XCTAssertEqual(practice.step, step)
            let targetID = practice.step.targetLabel(destination: practice.destinationDisplayName)
            state.update(PracticePulseRequest(targetID: targetID, repeatRevision: practice.highlightRepeatRevision,
                                             reduceMotion: false))
            XCTAssertEqual(state.pulsesRemaining, 3, "\(step)")
            for _ in 0..<3 { state.completeCycle() }
            XCTAssertEqual(state.pulsesRemaining, 0)
            practice.completeCurrentStep()
        }
    }

    func testFreshEngineShowsPendingUntilFirstUnderstanding() async {
        let engine = makeEngine(brain: LayoutBrain(source: .onDeviceModel))
        XCTAssertEqual(engine.latestBrainSource, .template)
        XCTAssertEqual(engine.debugBadge.lines[0], "Understood: Pending | reply: template")
        engine.useTypedInput()
        await submit("to Town Hall", to: engine)
        XCTAssertEqual(engine.latestBrainSource, .onDeviceModel)
        engine.endSession()
    }

    func testSpokenRepeatAndPracticeRepeatReplayCurrentHighlight() async throws {
        let input = LayoutInput()
        let output = LayoutOutput()
        let engine = makeEngine(input: input, output: output)
        engine.useTypedInput()
        engine.submitTypedInput("from Central to Town Hall")
        await eventually { engine.tripPlannerPracticeViewModel != nil && !engine.isVoiceOutputActive }
        let practice = try XCTUnwrap(engine.tripPlannerPracticeViewModel)
        output.suspend = true

        engine.repeatPracticeCaption()
        XCTAssertEqual(practice.highlightRepeatRevision, 1)
        await eventually { output.pending != nil }
        engine.stopSessionSpeech()
        engine.userTappedToTalk()
        await eventually { input.pending != nil }
        let transcript = try XCTUnwrap(input.pending)
        input.pending = nil
        transcript.resume(returning: "repeat")
        await eventually { output.pending != nil }
        XCTAssertEqual(practice.highlightRepeatRevision, 2)
        XCTAssertEqual(practice.step, .forYouOpened)
        XCTAssertEqual(output.lines.last, practice.currentCaption)
        engine.endSession()
    }

    func testRouterFallbackReasonSurvivesCoachReplyAndClearsOnCommand() async throws {
        let engine = makeEngine(router: LayoutFallbackRouter(), guides: try GuideLibrary.load())
        engine.useTypedInput()
        await submit("send a photo on WhatsApp", to: engine)
        XCTAssertEqual(engine.latestBrainSource, .keywordFallback)
        XCTAssertEqual(engine.latestBrainFallbackReason, .timeout)
        XCTAssertEqual(engine.debugBadge.lines[0], "Understood: Keyword fallback (timeout), 10000 ms | reply: template")
        await submit("repeat", to: engine)
        XCTAssertNil(engine.latestBrainFallbackReason)
        XCTAssertFalse(engine.debugBadge.text.contains("timeout"))
        engine.endSession()
    }

    func testExtractionReasonSurvivesTemplateThenClearsAfterModelRecoveryAndSessionReset() async {
        let engine = makeEngine(brain: RecoveringLayoutBrain())
        engine.useTypedInput()
        await submit("to Town Hall", to: engine)
        XCTAssertEqual(engine.latestBrainFallbackReason, .unavailable(.modelNotReady))
        XCTAssertEqual(engine.debugBadge.lines[0], "Understood: Keyword fallback (model not ready), 0 ms | reply: template")
        // A nil place keeps the engine idle for this assertion while still proving a fresh model call won.
        await submit("um", to: engine)
        XCTAssertEqual(engine.latestBrainSource, .onDeviceModel)
        XCTAssertNil(engine.latestBrainFallbackReason)
        XCTAssertFalse(engine.debugBadge.text.contains("model not ready"))
        engine.endSession()
        XCTAssertNil(engine.latestBrainFallbackReason)
    }

    func testUnderstandingAndLatencySurviveTemplateReply() async {
        for source in [BrainSource.onDeviceModel, .onDeviceModelWithKeywordFill, .keywordFallback] {
            let engine = makeEngine(brain: LayoutBrain(source: source))
            engine.useTypedInput()
            await submit("to Town Hall", to: engine)
            XCTAssertEqual(engine.latestBrainSource, source)
            XCTAssertEqual(engine.latestBrainLatencyMilliseconds, 840)
            XCTAssertEqual(engine.latestReplySource, .template)
            XCTAssertEqual(engine.debugBadge.lines[0], "Understood: \(source.label), 840 ms | reply: template")
            engine.endSession()
        }
    }

    func testDebugBadgeBuildsUnderstandingAndVoiceLines() {
        let model = SessionDebugBadge(understanding: .onDeviceModel, modelMilliseconds: 840,
            reply: .onDeviceModel, voice: "ElevenLabs", firstAudioMilliseconds: 1060, sttMilliseconds: 120)
        XCTAssertEqual(model.lines, ["Understood: On-device model, 840 ms",
                                     "Voice: ElevenLabs, first audio 1.06 s | STT 120 ms"])
        let fallback = SessionDebugBadge(understanding: .keywordFallback, modelMilliseconds: nil,
            reply: .template, voice: "System voice", firstAudioMilliseconds: 400, sttMilliseconds: 50)
        XCTAssertEqual(fallback.lines, ["Understood: Keyword fallback | reply: template",
                                        "Voice: System voice, first audio 0.40 s | STT 50 ms"])
        XCTAssertFalse(fallback.text.contains("Understood: Template"))
        XCTAssertEqual(fallback.text.components(separatedBy: "\n").count, 2)
    }

    func testCoachFallbackReplyDoesNotReplaceModelRouterUnderstanding() async throws {
        let engine = makeEngine(router: LayoutModelRouter(), guides: try GuideLibrary.load())
        engine.useTypedInput()
        await submit("send a photo on WhatsApp", to: engine)
        XCTAssertNotNil(engine.coach)
        XCTAssertEqual(engine.latestBrainSource, .onDeviceModel)
        XCTAssertEqual(engine.latestBrainLatencyMilliseconds, 840)
        XCTAssertEqual(engine.latestReplySource, .template)
        engine.endSession()
    }

    func testDockStopUsesPlaybackAndMicKeepsP04bStates() {
        for speaking in [false, true] {
            for plannerState in [TaskPlannerState.idle, .listening, .thinking, .finishing,
                                 .speaking("Hello"), .guiding(.tapFrom)] {
                let state = SessionDockState(plannerState: plannerState, isSpeaking: speaking, isStartingListening: false)
                XCTAssertEqual(state.showsStop, speaking)
                XCTAssertEqual(state.micDisabled, plannerState == .thinking || plannerState == .finishing)
                XCTAssertEqual(state.micState.accessibilityLabel, plannerState == .listening ? "Stop listening" : "Start listening")
            }
        }
        let starting = SessionDockState(plannerState: .idle, isSpeaking: false, isStartingListening: true)
        XCTAssertTrue(starting.micDisabled)
        XCTAssertEqual(starting.instruction, "Getting ready to listen...")
    }

    func testDockMenuActionsAndImmediateStopRetainPracticeStep() async throws {
        let output = LayoutOutput()
        let engine = makeEngine(output: output)
        engine.useTypedInput()
        engine.submitTypedInput("from Central to Town Hall")
        await eventually { engine.tripPlannerPracticeViewModel != nil && !engine.isVoiceOutputActive }
        let practice = try XCTUnwrap(engine.tripPlannerPracticeViewModel)
        XCTAssertEqual(SessionDockAction.allCases.map(\.title), ["Repeat", "Slower", "Type instead", "End session"])
        XCTAssertEqual(practice.highlightRepeatRevision, 0)
        output.suspend = true
        engine.performDockAction(.repeatStep)
        XCTAssertEqual(practice.highlightRepeatRevision, 1)
        await eventually { output.pending != nil }
        XCTAssertTrue(engine.isVoiceOutputActive)
        XCTAssertEqual(output.lines.last, practice.currentCaption)
        let stops = output.stops
        engine.stopSessionSpeech()
        XCTAssertEqual(output.stops, stops + 1)
        XCTAssertFalse(engine.isVoiceOutputActive)
        XCTAssertNil(output.pending)
        XCTAssertTrue(engine.tripPlannerPracticeViewModel === practice)
        XCTAssertEqual(practice.step, .forYouOpened)
        engine.performDockAction(.slower)
        XCTAssertEqual(practice.highlightRepeatRevision, 1)
        await eventually { output.pending != nil }
        XCTAssertTrue(output.slower)
        XCTAssertEqual(output.lines.last, practice.currentCaption)
        engine.performDockAction(.typeInstead)
        XCTAssertTrue(engine.isTyping)
        XCTAssertFalse(engine.isVoiceOutputActive)
        XCTAssertTrue(engine.tripPlannerPracticeViewModel === practice)
        XCTAssertEqual(engine.plannerState, .guiding(practice.step))
        XCTAssertTrue(engine.canSubmitTypedInput)
        engine.submitTypedInput("repeat")
        await eventually { output.pending != nil }
        XCTAssertEqual(practice.highlightRepeatRevision, 2)
        engine.performDockAction(.endSession)
        XCTAssertTrue(engine.isHome)
        XCTAssertNil(engine.tripPlannerPracticeViewModel)
        XCTAssertFalse(engine.isVoiceOutputActive)
    }

    func testDockMenuActionsAndStopRetainCoachStep() async throws {
        let output = LayoutOutput()
        let guides = try GuideLibrary.load()
        let engine = makeEngine(output: output, guides: guides)
        engine.useTypedInput()
        await submit("send a photo to Mum on WhatsApp", to: engine)
        let session = try XCTUnwrap(engine.coach)
        output.suspend = true
        engine.performDockAction(.repeatStep)
        await eventually { output.pending != nil }
        XCTAssertEqual(output.lines.last, session.text)
        engine.stopSessionSpeech()
        XCTAssertNil(output.pending)
        XCTAssertFalse(engine.isVoiceOutputActive)
        XCTAssertEqual(engine.coach?.id, session.id)
        XCTAssertEqual(engine.coach?.stepIndex, session.stepIndex)
        engine.performDockAction(.slower)
        await eventually { output.pending != nil }
        XCTAssertTrue(output.slower)
        engine.performDockAction(.typeInstead)
        XCTAssertTrue(engine.isTyping)
        XCTAssertEqual(engine.coach?.id, session.id)
        engine.performDockAction(.endSession)
        XCTAssertTrue(engine.isHome)
        XCTAssertNil(engine.coach)
    }

    func testEveryPracticeStepTargetsALabelOnItsScreen() {
        for destination in ["Town Hall", "Holsworthy"] {
            for step in PracticeStep.allCases {
                let label = step.targetLabel(destination: destination)
                let screenLabels = step.screen.targetLabels(destination: destination)
                XCTAssertTrue(screenLabels.contains(label), "\(step): \(label) must exist on \(step.screen)")
                XCTAssertTrue(step.caption(origin: "Central", destination: destination).contains(label),
                              "\(step): the instruction must name its target")
            }
        }
        XCTAssertEqual(PracticeStep.selectingDestination.targetLabel(destination: "Holsworthy"), "Use Holsworthy")
    }

    func testResultsTargetNamesTheActualMapsHandoff() {
        let label = PracticeScreen.ResultsLabels.openMaps
        XCTAssertEqual(label, "Find transit in Google Maps")
        XCTAssertEqual(PracticeScreen.results.targetLabels(destination: "Town Hall"), [label])
        XCTAssertEqual(PracticeStep.showingResults.targetLabel(destination: "Town Hall"), label)
        XCTAssertTrue(PracticeStep.showingResults.caption(origin: "Central", destination: "Town Hall").contains(label))
    }

    func testRestartKeepsBareDestinationInRealKeywordTripRouter() async {
        let engine = makeEngine()
        engine.useTypedInput()
        for text in ["to Holsworthy", "um", "uh"] { await submit(text, to: engine) }
        XCTAssertEqual(engine.conversation.last?.text, "Let's start again. Where would you like to go?")
        await submit("Town Hall", to: engine)
        XCTAssertEqual(engine.currentIntent.destination, "Town Hall")
        XCTAssertNil(engine.coach)
        XCTAssertEqual(engine.conversation.last?.text, PlannerTemplates.question(for: .origin))
        engine.endSession()
    }

    func testPracticeCardBypassesRouterAndModelAndKeepsVoiceMode() async {
        let input = LayoutInput()
        let router = UnexpectedLayoutRouter()
        let engine = makeEngine(input: input, router: router, brain: UnexpectedLayoutBrain())
        engine.startPractice()
        await eventually { input.pending != nil }
        XCTAssertFalse(engine.isTyping)
        XCTAssertEqual(router.calls, 0)
        XCTAssertEqual(engine.plannerState, .listening)
        XCTAssertEqual(engine.conversation.last?.text, PlannerTemplates.question(for: .destination))
        engine.endSession()
    }

    func testPracticeCardShowsPendingUntilTheNextTurnIsUnderstood() async {
        for source in [BrainSource.onDeviceModel, .onDeviceModelWithKeywordFill, .keywordFallback] {
            let input = LayoutInput()
            let engine = makeEngine(input: input, brain: LayoutBrain(source: source))
            engine.useTypedInput()
            await submit("to Town Hall", to: engine)
            XCTAssertEqual(engine.latestBrainSource, source)
            XCTAssertEqual(engine.latestBrainLatencyMilliseconds, 840)

            engine.startPractice()
            XCTAssertEqual(engine.latestBrainSource, .template)
            XCTAssertNil(engine.latestBrainLatencyMilliseconds)
            XCTAssertEqual(engine.debugBadge.lines[0], "Understood: Pending | reply: template")
            await eventually { input.pending != nil }
            XCTAssertEqual(engine.debugBadge.lines[0], "Understood: Pending | reply: template")

            engine.useTypedInput()
            await submit("Town Hall", to: engine)
            XCTAssertEqual(engine.latestBrainSource, source)
            XCTAssertEqual(engine.debugBadge.lines[0], "Understood: \(source.label), 840 ms | reply: template")
            engine.endSession()
        }
    }

    func testBackgroundPreservesPracticeIdentityFieldsAndStep() async throws {
        let engine = makeEngine()
        engine.useTypedInput()
        engine.submitTypedInput("from Central to Town Hall")
        await eventually { engine.tripPlannerPracticeViewModel != nil && !engine.isVoiceOutputActive }
        let practice = try XCTUnwrap(engine.tripPlannerPracticeViewModel)
        practice.completeCurrentStep()
        practice.fromFieldText = "Central"
        practice.completeCurrentStep()
        engine.appEnteredBackground()
        engine.appBecameActive()
        await Task.yield()
        XCTAssertTrue(engine.tripPlannerPracticeViewModel === practice)
        XCTAssertEqual(engine.plannerState, .guiding(.typeOrigin))
        XCTAssertEqual(practice.fromFieldText, "Central")
        engine.endSession()
    }

    func testTypingDuringPracticePreservesGuidingStateAfterSpeechCancellation() async throws {
        let input = LayoutInput()
        let output = LayoutOutput()
        let engine = makeEngine(input: input, output: output)
        engine.useTypedInput()
        engine.submitTypedInput("from Central to Town Hall")
        await eventually { engine.tripPlannerPracticeViewModel != nil && !engine.isVoiceOutputActive }
        let practice = try XCTUnwrap(engine.tripPlannerPracticeViewModel)
        practice.completeCurrentStep()
        practice.fromFieldText = "Central"
        practice.completeCurrentStep()
        await eventually { engine.plannerState == .guiding(.typeOrigin) && !engine.isVoiceOutputActive }

        output.suspend = true
        engine.repeatPracticeCaption()
        await eventually { output.pending != nil }
        engine.useTypedInput()
        XCTAssertTrue(engine.isTyping)
        XCTAssertTrue(engine.canSubmitTypedInput)
        XCTAssertNil(output.pending)
        XCTAssertFalse(engine.isVoiceOutputActive)
        XCTAssertEqual(engine.plannerState, .guiding(.typeOrigin))
        await Task.yield()
        XCTAssertEqual(engine.plannerState, .guiding(.typeOrigin))
        XCTAssertTrue(engine.tripPlannerPracticeViewModel === practice)
        XCTAssertEqual(practice.fromFieldText, "Central")

        engine.userTappedToTalk()
        await eventually { input.pending != nil }
        engine.useTypedInput()
        await Task.yield()
        XCTAssertNil(input.pending)
        XCTAssertEqual(engine.plannerState, .guiding(.typeOrigin))
        XCTAssertTrue(engine.canSubmitTypedInput)
        engine.endSession()
    }

    func testNearbyFallbackKeepsSecondSentenceAndGenericNumberReference() throws {
        let guides = try GuideLibrary.load()
        for id in ["set_alarm", "turn_on_torch"] {
            let guide = try XCTUnwrap(guides.first { $0.id == id })
            for step in guide.steps where step.labelIsNearby == true && CoachText.sentences(step.instruction).count == 2 {
                let text = CoachText.fallback(step: step, person: nil)
                XCTAssertTrue(text.localizedCaseInsensitiveContains(step.instruction))
                XCTAssertEqual(CoachText.sentences(text).count, 2)
            }
        }
        let step = HelpGuide.Step(instruction: "Tap the person or number.", uiLabelHint: "Recents")
        XCTAssertEqual(CoachText.fallback(step: step, person: "Mum"), step.instruction)
        let calls = try XCTUnwrap(guides.first { $0.id == "call_from_recents" })
        let callStep = try XCTUnwrap(calls.steps.last)
        XCTAssertFalse(CoachText.validRewrite("Tap the \"phone icon\" beside Mum or number.", guide: calls, step: callStep))
        XCTAssertTrue(CoachText.validRewrite("Tap the \"phone icon\" beside the person or number.", guide: calls, step: callStep))
    }

    func testPersonExtractionAcceptsFamilyAndCapitalisedNamesOnly() {
        for phrase in ["the bank", "the doctor", "the hospital", "The Bank", "mary jane", "a friend"] {
            XCTAssertNil(PersonNormalization.extract(from: "call \(phrase)"), phrase)
            XCTAssertNil(PersonNormalization.extractedPerson(phrase), phrase)
        }
        XCTAssertNil(PersonNormalization.extractedPerson("doctor"))
        XCTAssertEqual(PersonNormalization.extract(from: "call Mary Jane"), "Mary Jane")
        XCTAssertEqual(PersonNormalization.extract(from: "call my mum"), "Mum")
    }

    func testLoaderIgnoresNonJSONAndAcceptsValidCalendarDates() throws {
        let source = try XCTUnwrap(Bundle.main.url(forResource: "guides", withExtension: nil))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("notes".utf8).write(to: directory.appendingPathComponent("README.md"))
        let files = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        let jsonCount = files.filter { $0.pathExtension.lowercased() == "json" }.count
        XCTAssertEqual(try GuideLibrary.load(directory: directory).count, jsonCount)
        let file = directory.appendingPathComponent("connect_wifi.json")
        let original = try String(contentsOf: file, encoding: .utf8)
        for date in ["2025-10-24", "2028-02-29", "2027-01-01"] {
            let text = original.replacingOccurrences(of: "2026-10-24", with: date)
            XCTAssertNoThrow(try GuideLibrary.decode(Data(text.utf8), filename: "connect_wifi"))
        }
        for date in ["2027-02-29", "2026-13-01", "2026-1-01", "not a date"] {
            XCTAssertFalse(GuideLibrary.validReviewDate(date))
        }
    }

    private func makeEngine(input: LayoutInput? = nil, router: (any HelpRouting)? = nil,
                            brain: (any TaskPlannerBrain)? = nil,
                            output: LayoutOutput? = nil, guides: [HelpGuide]? = nil) -> TaskPlannerEngine {
        let service = CoachModelService(brain: nil)
        let library = guides ?? []
        return TaskPlannerEngine(brain: brain ?? KeywordFallbackBrain(), voiceInput: input ?? LayoutInput(),
            voiceOutput: output ?? LayoutOutput(), permissions: PermissionsManager(), userName: "",
            permissionCheck: { true }, settleBeforeListening: {}, guides: library,
            helpRouter: router ?? HelpRouter(guides: library, service: service, useEmbeddings: false), coachService: service,
            appOpener: UnavailableCoachAppOpener())
    }

    private func submit(_ text: String, to engine: TaskPlannerEngine) async {
        engine.submitTypedInput(text)
        await eventually { engine.plannerState == .idle }
    }

    private func eventually(_ condition: () -> Bool) async {
        await Task.yield()
        for _ in 0..<1500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Expected session state was not reached")
    }
}

@MainActor
private final class UnexpectedLayoutRouter: HelpRouting {
    var calls = 0
    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        calls += 1
        XCTFail("The practice card must not call the router")
        return BrainAnswer(value: HelpChoice(route: .general), source: .keywordFallback)
    }
}

@MainActor
private final class LayoutInput: VoiceInputService {
    var acceptsTranscript: () -> Bool = { true }
    var isListening = false
    var pending: CheckedContinuation<String, Error>?
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        isListening = true
        defer { isListening = false }
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finishListening() {}
    func stopListening() {
        let continuation = pending
        pending = nil
        continuation?.resume(throwing: CancellationError())
    }
}

@MainActor
private final class LayoutOutput: VoiceOutputService {
    var lines: [String] = []
    var slower = false
    var stops = 0
    var suspend = false
    var pending: CheckedContinuation<Void, Never>?
    func speak(_ text: String) async {
        lines.append(text)
        if suspend { await withCheckedContinuation { pending = $0 } }
    }
    func stop() {
        stops += 1
        let continuation = pending
        pending = nil
        continuation?.resume()
    }
    func setSlower(_ slower: Bool) { self.slower = slower }
}

private struct LayoutBrain: TaskPlannerBrain {
    let source: BrainSource
    var initialSource: BrainSource { source }
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        BrainAnswer(value: JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: nil, mode: nil),
                    source: source, latencyMilliseconds: 840)
    }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        BrainAnswer(value: answer, source: source, latencyMilliseconds: 840)
    }
}

private struct UnexpectedLayoutBrain: TaskPlannerBrain {
    var initialSource: BrainSource { .onDeviceModel }
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        XCTFail("The practice card must not call journey extraction")
        return BrainAnswer(value: .empty, source: .onDeviceModel)
    }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        XCTFail("The practice card must not call place extraction")
        return BrainAnswer(value: nil, source: .onDeviceModel)
    }
}

@MainActor
private struct LayoutModelRouter: HelpRouting {
    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        BrainAnswer(value: HelpChoice(route: .guide("whatsapp_send_photo")), source: .onDeviceModel, latencyMilliseconds: 840)
    }
}

@MainActor
private struct LayoutFallbackRouter: HelpRouting {
    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        BrainAnswer(value: HelpChoice(route: .guide("whatsapp_send_photo")), source: .keywordFallback,
                    latencyMilliseconds: 10_000, fallbackReason: .timeout)
    }
}

private struct RecoveringLayoutBrain: TaskPlannerBrain {
    var initialSource: BrainSource { .onDeviceModel }
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        BrainAnswer(value: JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: nil, mode: nil),
                    source: .keywordFallback, latencyMilliseconds: 0, fallbackReason: .unavailable(.modelNotReady))
    }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        BrainAnswer(value: nil, source: .onDeviceModel, latencyMilliseconds: 840)
    }
}
