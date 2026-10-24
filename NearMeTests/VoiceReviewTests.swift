import Foundation
import Speech
import XCTest
@testable import NearMe

@MainActor
final class VoiceReviewTests: XCTestCase {
    func testSilenceUsesEightTenthsRuleWithFakeClock() {
        let clock = SpeechTestClock()
        var rule = SpeechSilenceRule(now: { clock.now })
        clock.now = 10
        XCTAssertFalse(rule.hasEnded, "No speech must use the no-speech backstop")
        rule.observe(isSpeech: true)
        clock.now = 10.79
        rule.observe(isSpeech: false)
        XCTAssertFalse(rule.hasEnded)
        clock.now = 10.81
        XCTAssertTrue(rule.hasEnded)
        rule.observe(isSpeech: true)
        XCTAssertFalse(rule.hasEnded, "New speech resets the silence window")
        clock.now = 11.62
        XCTAssertTrue(rule.hasEnded)
        XCTAssertEqual(SpeechSilenceRule.interval, 0.8)
    }

    func testBothRecognizerPathsReceiveSameVocabulary() {
        XCTAssertEqual(PracticeVocabulary.places, ["Central", "Town Hall", "Parramatta", "Holsworthy",
                                                  "Circular Quay", "Bondi Junction", "Strathfield", "Chatswood"])
        XCTAssertEqual(Array(PracticeVocabulary.phrases.suffix(3)), ["help", "practice", "type instead"])
        let request = AppleSpeechFallbackService.makeRecognitionRequest()
        XCTAssertEqual(request.contextualStrings, PracticeVocabulary.phrases)
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertTrue(request.shouldReportPartialResults)
        if #available(iOS 26.0, *) {
            XCTAssertEqual(PracticeVocabulary.analysisContext().contextualStrings[.general], PracticeVocabulary.phrases)
        }
    }

    func testPlaceRankingIsCaseInsensitiveAndHandlesSentencesAndPrefixes() {
        for (text, expected) in [("Holsworth", "Holsworthy"), ("Town Hal", "Town Hall"),
                                 ("to hOLsWorth please", "Holsworthy"), ("CHATSW", "Chatswood")] {
            let suggestions = PracticeVocabulary.closestPlaces(to: text)
            XCTAssertEqual(suggestions.first, expected)
            XCTAssertEqual(suggestions.count, 2)
            XCTAssertEqual(Set(suggestions).count, 2)
        }
        XCTAssertTrue(PracticeVocabulary.containsPlace("Go to TOWN HALL, please"))
        XCTAssertFalse(PracticeVocabulary.containsPlace("Centralized"))
        XCTAssertEqual(PracticeVocabulary.closestPlaces(to: ""), PracticeVocabulary.closestPlaces(to: ""))
    }

    func testGreetingFinishesBeforePreparationAndPreparationRemainsCancellable() async {
        let input = ReviewInput()
        input.suspendPreparation = true
        let output = ReviewOutput()
        output.suspend = true
        let engine = makeEngine(input: input, output: output)
        engine.beginSession()
        await eventually { output.pending != nil }
        XCTAssertEqual(output.lines, ["Hi, what can we help you with?"])
        XCTAssertEqual(input.preparations, 0)
        output.stop()
        await eventually { input.preparation != nil }
        XCTAssertTrue(engine.isPreparingSpeech)
        XCTAssertEqual(input.starts, 0)
        engine.useTypedInput()
        input.releasePreparation()
        await Task.yield()
        XCTAssertTrue(engine.isTyping)
        XCTAssertFalse(engine.isPreparingSpeech)
        XCTAssertEqual(input.starts, 0)
        engine.endSession()
    }

    func testUnsupportedLocaleStillHearsGreetingBeforeTyping() async {
        let input = ReviewInput()
        input.preparationError = .unsupportedOnDeviceLocale
        let output = ReviewOutput()
        let engine = makeEngine(input: input, output: output)
        engine.beginSession()
        await eventually { engine.isTyping }
        XCTAssertEqual(output.lines, ["Hi, what can we help you with?"])
        XCTAssertEqual(input.starts, 0)
        engine.endSession()
    }

    func testNoSpeechAndTransientTimeoutRetryWithoutSwitchingToTyping() async {
        for error in [VoiceInputError.noSpeechDetected, .transcriptionFailed("timeout")] {
            let input = ReviewInput()
            input.outcomes = [.failure(error)]
            let output = ReviewOutput()
            let engine = makeEngine(input: input, output: output)
            engine.beginSession()
            await eventually { input.starts == 2 }
            XCTAssertFalse(engine.isTyping)
            XCTAssertEqual(engine.plannerState, .listening)
            XCTAssertTrue(output.lines.contains("Sorry, I didn't catch that. Could you say it again?"))
            engine.endSession()
        }
    }

    func testUnavailableRecognizerSwitchesToTypingWithoutRetry() async {
        let input = ReviewInput()
        input.outcomes = [.failure(VoiceInputError.recognizerUnavailable)]
        let engine = makeEngine(input: input)
        engine.beginSession()
        await eventually { engine.isTyping }
        XCTAssertEqual(input.starts, 1)
        engine.endSession()
    }

    func testQuestionsAndConfirmationNeverCallBrainForWording() async {
        let brain = ReviewBrain()
        let output = ReviewOutput()
        let engine = makeEngine(output: output, brain: brain)
        engine.useTypedInput()
        engine.submitTypedInput("to Town Hall")
        await eventually { engine.plannerState == .idle }
        XCTAssertEqual(output.lines.last, "Where are you starting from?")
        XCTAssertEqual(engine.latestBrainSource, .template)
        engine.submitTypedInput("Central")
        await eventually { engine.tripPlannerPracticeViewModel != nil }
        XCTAssertTrue(output.lines.contains("Great, let's practise planning a trip from Central to Town Hall."))
        XCTAssertEqual(brain.intentCalls, 1)
        XCTAssertEqual(brain.placeCalls, 1)
        XCTAssertEqual(brain.wordingCalls, 0)
        XCTAssertEqual(PlannerTemplates.question(for: .destination), "Where would you like to go?")
        engine.endSession()
    }

    func testUnrecognizedPlaceOffersButtonsAndTapFillsThePendingSlot() async {
        let input = ReviewInput()
        input.outcomes = [.success("to Town Hall"), .success("Holsworth")]
        let brain = ReviewBrain()
        let engine = makeEngine(input: input, brain: brain)
        engine.beginSession()
        await eventually { !engine.placeSuggestions.isEmpty }
        XCTAssertEqual(engine.suggestionTranscript, "Holsworth")
        XCTAssertEqual(engine.placeSuggestions.first, "Holsworthy")
        engine.chooseSuggestedPlace("Holsworthy")
        await eventually { engine.tripPlannerPracticeViewModel != nil }
        XCTAssertEqual(engine.currentIntent.origin, "Holsworthy")
        XCTAssertEqual(engine.currentIntent.destination, "Town Hall")
        XCTAssertEqual(brain.placeCalls, 0)
        engine.endSession()
    }

    func testLowConfidenceOffersSuggestionsEvenForAKnownPlaceAndNeitherRetries() async {
        let input = ReviewInput()
        input.confidence = 0.49
        input.outcomes = [.success("to Town Hall")]
        let engine = makeEngine(input: input)
        engine.beginSession()
        await eventually { !engine.placeSuggestions.isEmpty }
        XCTAssertEqual(engine.placeSuggestions.first, "Town Hall")
        engine.retrySuggestedPlace()
        await eventually { input.starts == 2 }
        XCTAssertTrue(engine.placeSuggestions.isEmpty)
        XCTAssertNil(engine.currentIntent.destination)
        XCTAssertFalse(engine.isTyping)
        engine.endSession()
    }

    func testFinalTranscriptIsPublishedBeforeModelAndFirstAudioWaitsForPlaybackEvent() async {
        let input = ReviewInput()
        input.outcomes = [.success("to Town Hall")]
        let output = ReviewOutput()
        let brain = ReviewBrain()
        let engine = makeEngine(input: input, output: output, brain: brain)
        brain.onExtract = {
            XCTAssertEqual(engine.liveTranscript, "to Town Hall")
            XCTAssertEqual(engine.plannerState, .thinking)
            XCTAssertNotNil(engine.sttMilliseconds)
            XCTAssertNil(engine.firstAudioMilliseconds)
            output.suspend = true
        }
        engine.beginSession()
        await eventually { output.pending != nil }
        XCTAssertNil(engine.firstAudioMilliseconds, "Queueing speech is not audible playback")
        output.onPlaybackStarted?()
        XCTAssertGreaterThanOrEqual(engine.firstAudioMilliseconds ?? 0, 800)
        XCTAssertGreaterThanOrEqual(engine.firstAudioMilliseconds ?? 0, engine.sttMilliseconds ?? 0)
        XCTAssertNotNil(engine.sttMilliseconds)
        XCTAssertEqual(engine.latestBrainLatencyMilliseconds, 123)
        brain.onExtract = nil
        engine.endSession()
    }

    func testStopKeepsCurrentAndFinalPracticeStepsAndRepeatStillWorks() async {
        let output = ReviewOutput()
        let engine = makeEngine(output: output)
        engine.useTypedInput()
        engine.submitTypedInput("from Central to Town Hall")
        await eventually { engine.tripPlannerPracticeViewModel != nil }
        guard let practice = engine.tripPlannerPracticeViewModel else { return XCTFail("No practice") }
        output.suspend = true
        engine.repeatPracticeCaption()
        await eventually { output.pending != nil }
        engine.stopPracticeSpeech()
        await Task.yield()
        XCTAssertTrue(engine.tripPlannerPracticeViewModel === practice)
        XCTAssertEqual(practice.step, .forYouOpened)
        XCTAssertEqual(engine.plannerState, .guiding(.forYouOpened))
        engine.repeatPracticeCaption()
        await eventually { output.pending != nil }
        engine.stopPracticeSpeech()
        while practice.step != .showingResults { practice.completeCurrentStep() }
        await eventually { output.pending != nil }
        engine.stopPracticeSpeech()
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(engine.plannerState, .guiding(.showingResults))
        XCTAssertTrue(engine.tripPlannerPracticeViewModel === practice)
        engine.endSession()
    }

    private func makeEngine(input: ReviewInput = ReviewInput(), output: ReviewOutput = ReviewOutput(),
                            brain: ReviewBrain = ReviewBrain()) -> TaskPlannerEngine {
        TaskPlannerEngine(brain: brain, voiceInput: input, voiceOutput: output,
                          permissions: PermissionsManager(), userName: "", permissionCheck: { true })
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<1500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Expected state was not reached")
    }
}

nonisolated private final class SpeechTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    var now: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); defer { lock.unlock() }; value = newValue }
    }
}

@MainActor
private final class ReviewInput: VoiceInputService {
    var isListening = false
    var lastTurn = SpeechTurn()
    var onSpeechEnd: ((String) -> Void)?
    var outcomes: [Result<String, Error>] = []
    var starts = 0
    var preparations = 0
    var confidence: Double = 0.9
    var preparationError: VoiceInputError?
    var suspendPreparation = false
    var preparation: CheckedContinuation<Void, Never>?
    var pending: CheckedContinuation<String, Error>?

    func prepareForListening() async throws {
        preparations += 1
        if suspendPreparation { await withCheckedContinuation { preparation = $0 } }
        if let preparationError { throw preparationError }
    }
    func releasePreparation() { let continuation = preparation; preparation = nil; continuation?.resume() }
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        starts += 1
        isListening = true
        defer { isListening = false }
        if outcomes.isEmpty { return try await withCheckedThrowingContinuation { pending = $0 } }
        let text = try outcomes.removeFirst().get()
        onPartialTranscript("to Town")
        lastTurn = SpeechTurn(endedAt: ProcessInfo.processInfo.systemUptime - 0.8, confidence: confidence)
        onSpeechEnd?(text)
        onPartialTranscript(text)
        return text
    }
    func stopListening() {
        isListening = false
        let continuation = pending
        pending = nil
        continuation?.resume(throwing: CancellationError())
    }
}

@MainActor
private final class ReviewOutput: VoiceOutputService {
    var lines: [String] = []
    var onPlaybackStarted: (() -> Void)?
    var suspend = false
    var pending: CheckedContinuation<Void, Never>?
    func speak(_ text: String) async {
        lines.append(text)
        if suspend { await withCheckedContinuation { pending = $0 } }
    }
    func stop() { let continuation = pending; pending = nil; continuation?.resume() }
}

@MainActor
private final class ReviewBrain: TaskPlannerBrain, @unchecked Sendable {
    let initialSource: BrainSource = .keywordFallback
    var intentCalls = 0
    var placeCalls = 0
    var wordingCalls = 0
    var onExtract: (() -> Void)?
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        intentCalls += 1
        onExtract?()
        return BrainAnswer(value: JourneyIntent(intent: .planJourney, destination: "Town Hall",
                                               origin: utterance.contains("from Central") ? "Central" : nil, mode: nil),
                           source: .keywordFallback, latencyMilliseconds: 123)
    }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        placeCalls += 1
        return BrainAnswer(value: answer, source: .keywordFallback)
    }
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> {
        wordingCalls += 1
        XCTFail("Questions must use a template")
        return BrainAnswer(value: "Unexpected model question", source: .keywordFallback)
    }
    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> {
        wordingCalls += 1
        XCTFail("Confirmation must use a template")
        return BrainAnswer(value: "Unexpected model confirmation", source: .keywordFallback)
    }
}
