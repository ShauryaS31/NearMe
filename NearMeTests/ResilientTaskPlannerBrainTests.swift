import XCTest
@testable import NearMe

@MainActor
final class ResilientTaskPlannerBrainTests: XCTestCase {
    func testUnknownModelIntentBecomesKeywordJourney() async throws {
        // Include a model with both places already filled: upgrading the kind
        // alone must still report keyword fill.
        let modelIntents: [JourneyIntent] = [
            .empty,
            JourneyIntent(intent: .unknown, destination: "Holsworthy", origin: "Central", mode: nil)
        ]
        for intent in modelIntents {
            let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(intent: intent), fallback: KeywordFallbackBrain())
            let answer = try await brain.extractIntent(from: "I wanna go from Central to Holsworthy")
            XCTAssertEqual(answer.value.kind, .planJourney)
            XCTAssertEqual(answer.value.origin, "Central")
            XCTAssertEqual(answer.value.destination, "Holsworthy")
            XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
            XCTAssertEqual(answer.latencyMilliseconds, 840)
        }
    }

    func testUnknownModelIntentStaysUnknownWithoutKeywordPlace() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(), fallback: KeywordFallbackBrain())
        let answer = try await brain.extractIntent(from: "hello")
        XCTAssertEqual(answer.value.kind, .unknown)
        XCTAssertNil(answer.value.origin)
        XCTAssertNil(answer.value.destination)
        XCTAssertEqual(answer.source, .onDeviceModel)
    }

    func testWholeModelPlaceAnswerIsCleaned() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(place: "I'm leaving from Central"), fallback: KeywordFallbackBrain())
        let answer = try await brain.extractPlace(from: "I'm leaving from Central", for: .origin)
        XCTAssertEqual(answer.value, "Central")
        XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
        XCTAssertEqual(answer.latencyMilliseconds, 840)
    }

    func testMissingOrEmptyModelPlaceUsesKeywordAnswer() async throws {
        let modelPlaces: [String?] = [nil, " \n", "um"]
        for modelPlace in modelPlaces {
            for slot in [MissingSlot.origin, .destination] {
                let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(place: modelPlace), fallback: KeywordFallbackBrain())
                let answer = try await brain.extractPlace(from: "um, Town Hall please", for: slot)
                XCTAssertEqual(answer.value, "Town Hall")
                XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
            }
        }
    }

    func testCleanModelPlaceIsPreserved() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(place: "Central"), fallback: KeywordFallbackBrain())
        let answer = try await brain.extractPlace(from: "I'm leaving from Central please", for: .origin)
        XCTAssertEqual(answer.value, "Central")
        XCTAssertEqual(answer.source, .onDeviceModel)
    }

    func testKeywordFillForMissingAndWhitespaceSlots() async throws {
        for (sentence, origin, destination) in tripParsingCases {
            let model = StubModelBrain(intent: JourneyIntent(intent: .planJourney, destination: " \n", origin: nil, mode: nil))
            let brain = ResilientTaskPlannerBrain(primary: model, fallback: KeywordFallbackBrain())
            let answer = try await brain.extractIntent(from: sentence)
            XCTAssertEqual(normalizedPlace(answer.value.origin), normalizedPlace(origin), sentence)
            XCTAssertEqual(normalizedPlace(answer.value.destination), normalizedPlace(destination), sentence)
            XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
        }
    }

    func testKeywordFillNeverOverwritesModelPlacesOrMode() async throws {
        let model = StubModelBrain(intent: JourneyIntent(intent: .planJourney, destination: "Model destination", origin: "Model origin", mode: "bus"))
        let brain = ResilientTaskPlannerBrain(primary: model, fallback: KeywordFallbackBrain())
        let answer = try await brain.extractIntent(from: "train from Central to Holsworthy")
        XCTAssertEqual(answer.value.origin, "Model origin")
        XCTAssertEqual(answer.value.destination, "Model destination")
        XCTAssertEqual(answer.value.mode, "bus")
        XCTAssertEqual(answer.source, .onDeviceModel)
    }

    func testFillOneSlotPreservesOtherModelValue() async throws {
        let model = StubModelBrain(intent: JourneyIntent(intent: .planJourney, destination: "Model destination", origin: "", mode: nil))
        let brain = ResilientTaskPlannerBrain(primary: model, fallback: KeywordFallbackBrain())
        let answer = try await brain.extractIntent(from: "from Central to Holsworthy")
        XCTAssertEqual(answer.value.origin, "Central")
        XCTAssertEqual(answer.value.destination, "Model destination")
        XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
    }

    func testAllThrownModelAnswersFallBack() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(shouldThrow: true), fallback: KeywordFallbackBrain())
        let intent = try await brain.extractIntent(from: "from Central to Holsworthy")
        let place = try await brain.extractPlace(from: "I'm leaving from Central", for: .origin)
        let question = try await brain.clarifyingQuestion(for: .origin, currentIntent: .empty)
        let confirmation = try await brain.confirmationLine(for: .empty)
        XCTAssertEqual(intent.value.origin, "Central")
        XCTAssertEqual(intent.value.destination, "Holsworthy")
        XCTAssertEqual(place.value, "Central")
        for source in [intent.source, place.source] {
            XCTAssertEqual(source, .keywordFallback)
        }
        XCTAssertEqual(question.source, .template)
        XCTAssertEqual(confirmation.source, .template)
        for latency in [intent.latencyMilliseconds, place.latencyMilliseconds,
                        question.latencyMilliseconds, confirmation.latencyMilliseconds] {
            XCTAssertNil(latency)
        }
    }

    func testSuccessfulModelAnswersKeepTheirSourceAndNilPlace() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(), fallback: KeywordFallbackBrain())
        let place = try await brain.extractPlace(from: "um", for: .destination)
        let question = try await brain.clarifyingQuestion(for: .origin, currentIntent: .empty)
        let confirmation = try await brain.confirmationLine(for: .empty)
        XCTAssertNil(place.value)
        for source in [place.source] {
            XCTAssertEqual(source, .onDeviceModel)
        }
        XCTAssertEqual(place.latencyMilliseconds, 840)
        XCTAssertEqual(question.source, .template)
        XCTAssertEqual(confirmation.source, .template)
        XCTAssertNil(question.latencyMilliseconds)
        XCTAssertNil(confirmation.latencyMilliseconds)
    }

    func testTimeoutFallsBackWithoutModelLatency() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(shouldTimeout: true), fallback: KeywordFallbackBrain())
        let intent = try await brain.extractIntent(from: "from Central to Holsworthy")
        let place = try await brain.extractPlace(from: "from Central", for: .origin)
        let question = try await brain.clarifyingQuestion(for: .origin, currentIntent: .empty)
        let confirmation = try await brain.confirmationLine(for: .empty)
        XCTAssertEqual(intent.value.origin, "Central")
        XCTAssertEqual(place.value, "Central")
        for source in [intent.source, place.source] {
            XCTAssertEqual(source, .keywordFallback)
        }
        XCTAssertEqual(question.source, .template)
        XCTAssertEqual(confirmation.source, .template)
        for latency in [intent.latencyMilliseconds, place.latencyMilliseconds,
                        question.latencyMilliseconds, confirmation.latencyMilliseconds] {
            XCTAssertNil(latency)
        }
    }
}

private struct StubModelBrain: TaskPlannerBrain {
    let initialSource: BrainSource = .onDeviceModel
    var intent: JourneyIntent = .empty
    var place: String? = nil
    var shouldThrow = false
    var shouldTimeout = false

    private func answer<T: Sendable>(_ value: T) throws -> BrainAnswer<T> {
        if shouldThrow { throw NSError(domain: "TestModel", code: 1) }
        if shouldTimeout { throw PlannerCallTimeout.exceeded }
        return BrainAnswer(value: value, source: .onDeviceModel, latencyMilliseconds: 840)
    }

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> { try answer(intent) }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> { try self.answer(place) }
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> { try answer("Where are you leaving from?") }
    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> { try answer("Let's plan that journey.") }
}
