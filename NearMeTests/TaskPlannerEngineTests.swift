import Combine
import XCTest
@testable import NearMe

@MainActor
final class TaskPlannerEngineTests: XCTestCase {
    func testTypedFollowUpExtractsPlaceAndPreservesPendingQuestion() async {
        let input = SilentInput()
        let engine = makeEngine(input: input)
        engine.useTypedInput()
        await submit("I need to get to Holsworthy", to: engine)
        XCTAssertNil(engine.currentIntent.origin)
        XCTAssertEqual(engine.currentIntent.destination, "Holsworthy")

        // Re-entering typed mode stops capture without clearing the question.
        engine.useTypedInput()
        XCTAssertEqual(input.stopCount, 2)
        await submit("I'm leaving from Central", to: engine, until: .guiding(.forYouOpened))
        XCTAssertEqual(engine.currentIntent.origin, "Central")
        XCTAssertEqual(engine.currentIntent.destination, "Holsworthy")
        XCTAssertEqual(engine.latestBrainSource, .template)
        XCTAssertEqual(input.startCount, 0)
        XCTAssertEqual(engine.conversation.filter { $0.speaker == .user }.count, 2)
        engine.endSession()
        XCTAssertFalse(engine.isTyping)
    }

    func testInvalidOriginFollowUpRetriesOnceThenClearsTrip() async {
        let engine = makeEngine()
        engine.useTypedInput()
        await submit("to Holsworthy", to: engine)
        await submit("um", to: engine)
        XCTAssertNil(engine.currentIntent.origin)
        XCTAssertEqual(engine.currentIntent.destination, "Holsworthy")
        XCTAssertEqual(engine.conversation.last?.text, "Sorry, which station or suburb?")
        await submit("uh", to: engine)
        XCTAssertEqual(engine.currentIntent.kind, .unknown)
        XCTAssertNil(engine.currentIntent.origin)
        XCTAssertNil(engine.currentIntent.destination)
        XCTAssertEqual(engine.conversation.last?.text, "Let's start again. Where would you like to go?")

        await submit("to Town Hall", to: engine)
        XCTAssertEqual(engine.currentIntent.destination, "Town Hall")
        await submit("um", to: engine)
        XCTAssertEqual(engine.conversation.last?.text, "Sorry, which station or suburb?")
        engine.endSession()
    }

    func testDestinationFollowUpRetriesSameSlotAndAcceptsCleanedPlace() async {
        let engine = makeEngine()
        engine.useTypedInput()
        await submit("travel from Central", to: engine)
        await submit("um", to: engine)
        XCTAssertEqual(engine.currentIntent.origin, "Central")
        XCTAssertNil(engine.currentIntent.destination)
        XCTAssertEqual(engine.conversation.last?.text, "Sorry, which station or suburb?")
        await submit("to Holsworthy please", to: engine, until: .guiding(.forYouOpened))
        XCTAssertEqual(engine.currentIntent.destination, "Holsworthy")
        engine.endSession()
    }

    func testCancelClearsPendingSlotAndRetryCount() async {
        let engine = makeEngine()
        engine.useTypedInput()
        await submit("to Holsworthy", to: engine)
        await submit("um", to: engine)
        engine.cancelCurrentAction()
        XCTAssertFalse(engine.isTyping)
        engine.useTypedInput()
        await submit("to Town Hall", to: engine)
        XCTAssertNil(engine.currentIntent.origin)
        XCTAssertEqual(engine.currentIntent.destination, "Town Hall")
        await submit("um", to: engine)
        XCTAssertEqual(engine.conversation.last?.text, "Sorry, which station or suburb?")
        engine.endSession()
    }

    func testLatestCallLatencyIsPublishedAndClearedForKeywordAnswer() async {
        let engine = makeEngine(brain: CannedEngineBrain(reportsModelLatency: true))
        XCTAssertNil(engine.latestBrainLatencyMilliseconds)
        engine.useTypedInput()
        await submit("hello", to: engine)
        XCTAssertEqual(engine.latestBrainLatencyMilliseconds, 120)
        await submit("to Holsworthy", to: engine)
        XCTAssertEqual(engine.latestBrainLatencyMilliseconds, 120)
        XCTAssertEqual(engine.latestBrainSource, .template)
        await submit("um", to: engine)
        XCTAssertEqual(engine.latestBrainSource, .keywordFallback)
        XCTAssertNil(engine.latestBrainLatencyMilliseconds)
        await submit("I'm leaving from Central", to: engine, until: .guiding(.forYouOpened))
        XCTAssertEqual(engine.latestBrainSource, .template)
        XCTAssertNil(engine.latestBrainLatencyMilliseconds)
        engine.endSession()
    }

    // Defaults are built in the body: default arguments are evaluated outside the main actor.
    private func makeEngine(input: SilentInput? = nil, brain: TaskPlannerBrain? = nil) -> TaskPlannerEngine {
        TaskPlannerEngine(brain: brain ?? CannedEngineBrain(), voiceInput: input ?? SilentInput(),
                          voiceOutput: SilentOutput(), permissions: PermissionsManager(), userName: "")
    }

    private func submit(_ text: String, to engine: TaskPlannerEngine, until expected: TaskPlannerState = .idle) async {
        let ready = expectation(description: "Planner reaches \(expected)")
        let subscription = engine.$plannerState.dropFirst().filter { $0 == expected }.prefix(1).sink { _ in
            ready.fulfill()
        }
        engine.submitTypedInput(text)
        await fulfillment(of: [ready], timeout: 5)
        subscription.cancel()
    }
}

/// Canned answers keep engine state tests independent of parsing and model availability.
private struct CannedEngineBrain: TaskPlannerBrain {
    var reportsModelLatency = false
    var initialSource: BrainSource { reportsModelLatency ? .onDeviceModel : .keywordFallback }

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        let intents: [String: JourneyIntent] = [
            "I need to get to Holsworthy": JourneyIntent(intent: .planJourney, destination: "Holsworthy", origin: nil, mode: nil),
            "to Holsworthy": JourneyIntent(intent: .planJourney, destination: "Holsworthy", origin: nil, mode: nil),
            "to Town Hall": JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: nil, mode: nil),
            "travel from Central": JourneyIntent(intent: .planJourney, destination: nil, origin: "Central", mode: nil)
        ]
        return BrainAnswer(value: intents[utterance] ?? .empty, source: initialSource,
                           latencyMilliseconds: reportsModelLatency ? 120 : nil)
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        let places = ["I'm leaving from Central": "Central", "to Holsworthy please": "Holsworthy"]
        return BrainAnswer(value: places[answer], source: .keywordFallback)
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> {
        BrainAnswer(value: "Which place?", source: initialSource,
                    latencyMilliseconds: reportsModelLatency ? 240 : nil)
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> {
        BrainAnswer(value: "Let's plan that journey.", source: initialSource,
                    latencyMilliseconds: reportsModelLatency ? 360 : nil)
    }
}

@MainActor
private final class SilentInput: VoiceInputService {
    var acceptsTranscript: () -> Bool = { true }
    var isListening = false
    var stopCount = 0
    var startCount = 0
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        startCount += 1
        throw VoiceInputError.microphoneUnavailable
    }
    func finishListening() { isListening = false }
    func stopListening() { stopCount += 1 }
}

@MainActor
private final class SilentOutput: VoiceOutputService {
    func speak(_ text: String) async {}
    func stop() {}
}
