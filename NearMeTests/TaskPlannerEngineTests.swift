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
        XCTAssertEqual(engine.latestBrainSource, .keywordFallback)
        XCTAssertEqual(input.startCount, 0)
        XCTAssertEqual(engine.conversation.filter { $0.speaker == .user }.count, 2)
        engine.endSession()
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
        await submit("to Town Hall", to: engine)
        XCTAssertNil(engine.currentIntent.origin)
        XCTAssertEqual(engine.currentIntent.destination, "Town Hall")
        await submit("um", to: engine)
        XCTAssertEqual(engine.conversation.last?.text, "Sorry, which station or suburb?")
        engine.endSession()
    }

    private func makeEngine(input: SilentInput? = nil) -> TaskPlannerEngine {
        TaskPlannerEngine(brain: KeywordFallbackBrain(), voiceInput: input ?? SilentInput(),
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

@MainActor
private final class SilentInput: VoiceInputService {
    var isListening = false
    var stopCount = 0
    var startCount = 0
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        startCount += 1
        throw VoiceInputError.microphoneUnavailable
    }
    func stopListening() { stopCount += 1 }
}

@MainActor
private final class SilentOutput: VoiceOutputService {
    func speak(_ text: String) async {}
    func stop() {}
}
